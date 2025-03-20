
#' @export
clone_repos <- function(
    packages,
    dest_dir,
    username,
    org = username,
    set_upstream = "origin/devel",
    restart_from = character(0L),
    BPPARAM = NULL
) {
    stopifnot(
        isScalarCharacter(repos_dir) && dir.exists(repos_dir),
        isScalarCharacter(set_upstream)
    )
    if (missing(username) && missing(org))
        stop("Either 'username' or 'org' must be provided")

    if (isScalarCharacter(restart_from)) {
        indx <- which(packages == restart_from)
        if (!length(indx))
            stop("Package '", restart_from, "' not found in 'repos_dir'")
        packages <- packages[indx:length(packages)]
    }

    mapply(
        FUN = clone_repo,
        package = packages,
        MoreArgs = list(
            dest_dir = dest_dir,
            set_upstream = set_upstream,
            org = org
        )
    )
}

#' @export
clone_repo <- function(
    package,
    dest_dir,
    org,
    set_upstream = "origin/devel"
) {
    repo_dir <- file.path(normalizePath(dest_dir), package)
    bioc_slug <- .get_bioc_slug(package)
    gh_slug <- .get_gh_slug(org = org, package_name = package)
    gh_exists <- .repo_exists(pkg = package, org = org)
    if (!dir.exists(repo_dir)) {
        clone_slug <- if (gh_exists) gh_slug else bioc_slug
        gert::git_clone(clone_slug, path = repo_dir)
        old <- setwd(repo_dir)
        on.exit(setwd(old))
        if (gh_exists)
            gert::git_remote_add(bioc_slug, name = "upstream")
        else
            .git_remote_rename("origin", "upstream")
    } else {
        if (gh_exists && !.is_origin_github(gh_slug = gh_slug)) {
            old <- setwd(repo_dir)
            on.exit(setwd(old))
            ## validity checks and correct remotes
            gert::git_remote_set_url(gh_slug, remote = "origin")
            gert::git_remote_add(bioc_slug, name = "upstream")
        } else if (!gh_exists && .git_remote_exists(remote = "origin")) {
            .git_remote_rename("origin", "upstream")
        }
    }
    system2("git", "fetch", "--all")
    gert::git_pull("upstream", refspec = "devel")
    git_branch_set_upstream(set_upstream)
    repo_dir
}


.git_remote_rename <- function(from, to) {
    system2("git", c("remote", "rename", from, to))
}

.git_remote_exists <- function(remotes, remote) {
    if (missing(remotes))
        remotes <- gert::git_remote_list()
    remote %in% unlist(remotes[["name"]])
}
