#' Update local repositories after Bioconductor Release
#'
#' These functions should be used after a Bioconductor Release. They ensure that
#' the local repositories are in sync with Bioconductor. For convenience, the
#' singular `update_local_repo` function will update a single local repository
#' on the user's system.
#'
#' @param repos_dir `character(1)` The base directory where all packages /
#'   repositories exist for the user
#'
#' @param repo_dir `character(1)` The full path to a single package / repository
#'   whose default branch should be updated
#'
#' @param username `character(1)` (optional) The GitHub username used in the
#'   query to check default packages
#'
#' @param `character(1)` The remote location that will be tracked by the local
#'   branch, either "origin/devel" (default) or "upstream/devel"
#'
#' @inheritParams get-github-repos
#'
#' @examples
#' if (interactive()) {
#'     update_local_repo("~/bioc/AnnotationHub", is_bioc = TRUE)
#' }
#' @export
update_local_repos <- function(
    repos_dir,
    release = get_bioc_release_yaml(),
    username, org = username,
    set_upstream = "origin/devel"
) {
    if (missing(username) && missing(org))
        stop("Either 'username' or 'org' must be provided")
    if (!missing(org))
        repos <- get_org_github_repos(org = org)
    else
        repos <- get_user_github_repos(username = username)

    folders <- list.dirs(repos_dir, recursive = FALSE)
    pkg_dirs <- folders[basename(folders) %in% names(repos)]

    is_bioc <- .is_bioc_pkgs(pkg_dirs)
    pkg_dirs <- pkg_dirs[is_bioc]

    if (!length(matching))
        stop("No local folders in 'repos_dir' to update")

    mapply(
        FUN = update_local_repo,
        repo_dir = pkg_dirs,
        MoreArgs = list(
            release = release,
            set_upstream = set_upstream,
            org = org
        ),
        SIMPLIFY = FALSE
    )
}

#' @rdname update_local_repos
#'
#' @export
update_local_repo <- function(
    repo_dir, release, set_upstream = "origin/devel", org = "Bioconductor"
) {
    old_wd <- setwd(repo_dir)
    on.exit({ setwd(old_wd) })

    package <- basename(normalizePath(repo_dir))
    gh_slug <- .get_gh_slug(org = org, package_name = package)
    message("Working on: ", repo_dir)
    git_branch_checkout("devel")
    if (!.is_origin_github(gh_slug = gh_slug))
        stop("'origin' remote should be set to GitHub")
    if (!.has_bioc_upstream()) {
        bioc_slug <- .get_bioc_slug(package)
        git_remote_add(bioc_slug, name = "upstream")
    }
    git_pull(remote = "origin", refspec = "devel")
    git_pull(remote = "upstream", refspec = "devel")
    git_push(remote = "origin")
    if (!git_branch_exists(branch = release)) {
        git_branch_create(release, ref = paste0("upstream/", release))
        git_push(remote = "origin")
        git_checkout_branch("devel")
    }
    git_branch_set_upstream(set_upstream)
}
