#' Clone or update local git repositories of Bioconductor packages
#'
#' `sync_repos` clones any `packages` missing from `dest_dir` and updates the
#' ones already present. When a package's repository exists on GitHub under
#' `org` (or `username`), it is cloned from there as the `origin` remote and the
#' Bioconductor git server is added as the `upstream` remote. Otherwise, the
#' package is cloned from the Bioconductor git server and that remote is named
#' `upstream`. The local `devel` branch is then updated from `origin/devel`
#' (when on GitHub) and `upstream/devel`, and set to track `set_upstream`.
#'
#' @details Existing local repositories have their remotes corrected: `origin`
#'   is pointed at GitHub when the GitHub repository exists, and the
#'   Bioconductor `upstream` remote is added when missing. Updates are
#'   fast-forwards when possible; when `devel` has diverged from
#'   `upstream/devel`, see `strategy`. Conflicts stop the process; resolve
#'   them and resume with `restart_from`. Clones
#'   and fetches use the command-line `git` client with SSH connection and
#'   keep-alive timeouts, and are retried up to 3 times.
#'
#' @param packages `character()` A vector of Bioconductor package names to
#'   clone or update.
#'
#' @param dest_dir `character(1)` The directory where the repositories are
#'   (or will be) located.
#'
#' @param package `character(1)` A single Bioconductor package name.
#'
#' @param gh_exists `logical(1)` Whether the repository exists on GitHub under
#'   `org`. By default, this is checked with the GitHub API.
#'
#' @param set_upstream `character(1)` The remote branch that the local `devel`
#'   branch will track, either "upstream/devel" (default) or "origin/devel".
#'   Packages without a GitHub repository always track "upstream/devel".
#'
#' @param strategy `character(1)` How to update `devel` when it has diverged
#'   from `upstream/devel`. With "rebase" (default), the local-only (e.g.,
#'   GitHub-only) commits are replayed on top of `upstream/devel`, keeping
#'   the history linear; the rebased `devel` must then be pushed to GitHub
#'   with `git push --force-with-lease origin devel`. A rebase with conflicts
#'   is aborted and stops, leaving the branch unchanged. With "merge", a
#'   merge commit is created.
#'
#' @param restart_from `character(1)` The name of a package in `packages` from
#'   which to resume, e.g., after an interruption due to merge conflicts.
#'   Default `character(0L)`.
#'
#' @inheritParams update_local_repos
#'
#' @return `sync_repo`: the path to the local repository, invisibly.
#'   `sync_repos`: a `character` vector of local repository paths, invisibly.
#'
#' @examples
#' if (interactive()) {
#'     sync_repos(
#'         c("S4Vectors", "IRanges"), dest_dir = "~/bioc", org = "Bioconductor"
#'     )
#'
#'     ## in parallel
#'     library(BiocParallel)
#'     sync_repos(
#'         c("S4Vectors", "IRanges"), dest_dir = "~/bioc",
#'         org = "Bioconductor", BPPARAM = MulticoreParam(workers = 4)
#'     )
#'
#'     ## a single package
#'     sync_repo("S4Vectors", dest_dir = "~/bioc", org = "Bioconductor")
#' }
#' @export
sync_repos <- function(
    packages,
    dest_dir,
    username,
    org = username,
    set_upstream = "upstream/devel",
    restart_from = character(0L),
    BPPARAM = NULL,
    strategy = c("rebase", "merge")
) {
    strategy <- match.arg(strategy)
    stopifnot(
        is.character(packages) && length(packages) && !anyNA(packages),
        isScalarCharacter(dest_dir) && dir.exists(dest_dir),
        isScalarCharacter(set_upstream)
    )
    if (missing(username) && missing(org))
        stop("Either 'username' or 'org' must be provided")

    if (isScalarCharacter(restart_from)) {
        indx <- which(packages == restart_from)
        if (!length(indx))
            stop("Package '", restart_from, "' not found in 'packages'")
        packages <- packages[indx:length(packages)]
    }

    if (!missing(org))
        repos <- get_org_github_repos(org = org)
    else
        repos <- get_user_github_repos(username = username)
    gh_exists <- packages %in% names(repos)

    dest_dir <- normalizePath(dest_dir)
    if (requireNamespace("BiocParallel", quietly = TRUE) && !is.null(BPPARAM))
        res <- BiocParallel::bpmapply(
            FUN = sync_repo,
            package = packages,
            gh_exists = gh_exists,
            MoreArgs = list(
                dest_dir = dest_dir,
                org = org,
                set_upstream = set_upstream,
                strategy = strategy
            ),
            SIMPLIFY = TRUE,
            BPPARAM = BPPARAM
        )
    else
        res <- mapply(
            FUN = sync_repo,
            package = packages,
            gh_exists = gh_exists,
            MoreArgs = list(
                dest_dir = dest_dir,
                org = org,
                set_upstream = set_upstream,
                strategy = strategy
            )
        )
    invisible(res)
}

#' @rdname sync_repos
#'
#' @export
sync_repo <- function(
    package,
    dest_dir,
    org = "Bioconductor",
    gh_exists = .repo_exists(pkg = package, org = org),
    set_upstream = "upstream/devel",
    strategy = c("rebase", "merge")
) {
    strategy <- match.arg(strategy)
    stopifnot(
        isScalarCharacter(package),
        isScalarCharacter(dest_dir) && dir.exists(dest_dir),
        isTRUE(gh_exists) || isFALSE(gh_exists),
        isScalarCharacter(set_upstream)
    )
    repo_dir <- file.path(normalizePath(dest_dir), package)
    bioc_slug <- .get_bioc_slug(package)
    gh_slug <- .get_gh_slug(org = org, package_name = package)

    message("Working on: ", package)
    if (!dir.exists(repo_dir))
        .clone_repo(repo_dir, bioc_slug, gh_slug, gh_exists)
    else
        .fix_remotes(repo_dir, bioc_slug, gh_slug, gh_exists)

    .with_retry(.git_net, c("fetch", "upstream"), repo = repo_dir)
    if (gh_exists)
        .with_retry(.git_net, c("fetch", "origin"), repo = repo_dir)

    if (git_branch_exists("devel", repo = repo_dir))
        git_branch_checkout("devel", repo = repo_dir)
    else
        git_branch_create(
            "devel", ref = "upstream/devel", checkout = TRUE, repo = repo_dir
        )
    ## catch up with GitHub first, so that a rebase onto upstream does not
    ## drop commits pushed to GitHub since the last sync
    if (gh_exists &&
        git_branch_exists("origin/devel", local = FALSE, repo = repo_dir))
        .git_update_branch("origin/devel", repo = repo_dir, strategy = strategy)
    ## remotes were fetched above; update locally (stops on conflicts)
    how <- .git_update_branch(
        "upstream/devel", repo = repo_dir, strategy = strategy
    )
    if (identical(how, "rebased") && gh_exists)
        message(
            "  'devel' was rebased onto upstream/devel; push it with:\n",
            "    git push --force-with-lease origin devel"
        )

    if (!gh_exists)
        set_upstream <- "upstream/devel"
    git_branch_set_upstream(set_upstream, branch = "devel", repo = repo_dir)

    invisible(repo_dir)
}

.clone_repo <- function(repo_dir, bioc_slug, gh_slug, gh_exists) {
    if (gh_exists) {
        .with_retry(.git_net, c("clone", gh_slug, shQuote(repo_dir)))
        git_remote_add(bioc_slug, name = "upstream", repo = repo_dir)
    } else {
        .with_retry(.git_net, c("clone", bioc_slug, shQuote(repo_dir)))
        .rename_remote("origin", "upstream", repo = repo_dir)
    }
    invisible(repo_dir)
}

.fix_remotes <- function(repo_dir, bioc_slug, gh_slug, gh_exists) {
    remotes <- git_remote_list(repo = repo_dir)
    has_origin <- .remote_exists(remotes, "origin")
    has_upstream <- .remote_exists(remotes, "upstream")
    if (gh_exists) {
        if (!has_origin) {
            git_remote_add(gh_slug, name = "origin", repo = repo_dir)
        } else if (!.is_origin_github(remotes, gh_slug)) {
            message("  Setting 'origin' remote to GitHub")
            git_remote_set_url(gh_slug, remote = "origin", repo = repo_dir)
        }
    } else if (has_origin && !has_upstream) {
        origin_url <- remotes[["url"]][remotes[["name"]] == "origin"]
        if (grepl("git.bioconductor.org", origin_url, fixed = TRUE)) {
            message("  Renaming Bioconductor 'origin' remote to 'upstream'")
            .rename_remote("origin", "upstream", repo = repo_dir)
            has_upstream <- TRUE
        }
    }
    if (!has_upstream)
        git_remote_add(bioc_slug, name = "upstream", repo = repo_dir)
    else if (!.has_bioc_upstream(git_remote_list(repo = repo_dir)))
        git_remote_set_url(bioc_slug, remote = "upstream", repo = repo_dir)
    invisible(repo_dir)
}

.rename_remote <- function(from, to, repo = ".") {
    remotes <- git_remote_list(repo = repo)
    url <- remotes[["url"]][remotes[["name"]] == from]
    git_remote_add(url, name = to, repo = repo)
    git_remote_remove(from, repo = repo)
}
