
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
    if (dir.exists(repo_dir))
        return(repo_dir)
    bioc_slug <- .get_bioc_slug(package)
    gh_slug <- .get_gh_slug(org = org, package_name = package)
    if (.repo_exists(pkg = package, org = org)) {
        gert::git_clone(gh_slug, path = repo_dir)
        old <- setwd(repo_dir)
        on.exit(setwd(old))
        gert::git_remote_add(bioc_slug, name = "upstream")
    } else {
        gert::git_clone(bioc_slug, path = repo_dir)
    }
    git_branch_set_upstream(set_upstream)
    repo_dir
}
