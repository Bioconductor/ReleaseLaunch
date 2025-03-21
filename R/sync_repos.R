#' @importFrom BiocReporting account_repositories
#'
#' @examples
#' library(BiocPkgTools)
#' missing_bins <- repositoryStats()[["missing_binaries"]]
#' sync_repos(missing_bins, "~/bioc/", org = "Bioconductor")
#'
#' library(BiocParallel)
#' bpparam <- MulticoreParam(workers = 22)
#' register(bpparam)
#'
#' sync_repos(missing_bins, "~/bioc/", org = "Bioconductor", BPPARAM = bpparam)
#' @export
sync_repos <- function(
    packages,
    dest_dir,
    username,
    org = username,
    set_upstream = "upstream/devel",
    restart_from = character(0L),
    BPPARAM = NULL
) {
    stopifnot(
        isScalarCharacter(dest_dir) && dir.exists(dest_dir),
        isScalarCharacter(set_upstream)
    )
    if (missing(username) && missing(org))
        stop("Either 'username' or 'org' must be provided")

    if (isScalarCharacter(restart_from)) {
        indx <- which(packages == restart_from)
        if (!length(indx))
            stop("Package '", restart_from, "' not found in 'dest_dir'")
        packages <- packages[indx:length(packages)]
    }
    repos <- account_repositories(org = org)
    repo_names <- vapply(repos, `[[`, character(1L), "name")
    ghs_exists <- packages %in% repo_names

    if (!is.null(BPPARAM))
        BiocParallel::bpmapply(
            FUN = sync_repo,
            package = packages,
            gh_exists = ghs_exists,
            MoreArgs = list(
                dest_dir = dest_dir,
                set_upstream = set_upstream,
                org = org
            ),
            BPPARAM = BPPARAM
        )
    else
        mapply(
            FUN = sync_repo,
            package = packages,
            gh_exists = ghs_exists,
            MoreArgs = list(
                dest_dir = dest_dir,
                set_upstream = set_upstream,
                org = org
            )
        )
}

#' @examples
#' sync_repo("S4Vectors", "~/test", gh_exists = TRUE)
#'
#' @export
sync_repo <- function(
    package,
    dest_dir,
    org,
    gh_exists,
    set_upstream = "upstream/devel"
) {
    repo_dir <- file.path(normalizePath(dest_dir), package)

    message("Working on: ", package)

    if (!dir.exists(repo_dir))
        clone_repo(package, dest_dir, org, gh_exists)
    else
        update_repo(package, dest_dir, org, gh_exists)

    old <- setwd(repo_dir)
    on.exit(setwd(old))

    ## actually sync
    system2("git", c("fetch", "--all"))
    gert::git_pull("upstream", refspec = "devel")
    system2("git", c("branch -u", set_upstream))

    repo_dir
}

clone_repo <- function(package, dest_dir, org, gh_exists) {
    repo_dir <- file.path(normalizePath(dest_dir), package)
    bioc_slug <- .bioc_slug(package)
    if (!gh_exists) {
        gert::git_clone(bioc_slug, path = repo_dir)
        old <- setwd(repo_dir)
        .git_remote_rename("origin", "upstream")
    } else {
        gh_slug <- .gh_slug(org = org, package_name = package)
        gert::git_clone(gh_slug, path = repo_dir)
        old <- setwd(repo_dir)
        gert::git_remote_add(bioc_slug, name = "upstream")
    }
    on.exit(setwd(old))
    TRUE
}

update_repo <-
    function(package, dest_dir, org, gh_exists)
{
    repo_dir <- file.path(normalizePath(dest_dir), package)
    bioc_slug <- .bioc_slug(package)
    gh_slug <- .gh_slug(org = org, package_name = package)
    old <- setwd(repo_dir)
    on.exit(setwd(old))
    system2("git", c("fetch", "--all"))
    gert::git_branch_checkout("devel")
    if (gh_exists && !.is_origin_github(gh_slug = gh_slug)) {
        message("Setting 'origin' remote to GitHub")
        old <- setwd(repo_dir)
        on.exit(setwd(old))
        ## validity checks and correct remotes
        gert::git_remote_set_url(gh_slug, remote = "origin")
        if (!.git_remote_exists(remote = "upstream"))
            gert::git_remote_add(bioc_slug, name = "upstream")
    } else if (!gh_exists && .git_remote_exists(remote = "origin")) {
        .git_remote_rename("origin", "upstream")
    }
    TRUE
}

.git_remote_rename <- function(from, to) {
    system2("git", c("remote", "rename", from, to))
}

.git_remote_exists <- function(remotes, remote) {
    if (missing(remotes))
        remotes <- gert::git_remote_list()
    remote %in% unlist(remotes[["name"]])
}
