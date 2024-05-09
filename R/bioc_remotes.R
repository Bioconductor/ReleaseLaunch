#' @name bioc_remotes
#'
#' @title Convenience functions to set, rename, or validate a repo's remotes
#'
#' @aliases add_bioc_remote set_bioc_remotes
#'
#' @description The function `add_bioc_remote` adds an 'upstream' remote that
#'   points to `git@git.bioconductor.org`. If an `upstream` remote already
#'   exists, it will be validated against the SSH URL. By design, the
#'   Bioconductor remote location is called the 'upstream' remote. The 'origin'
#'   is set to the GitHub location.
#'
#' @details The `set_bioc_remotes` function will update a repository's remotes
#' by setting `origin` to the GitHub location and `upstream` to the Bioconductor
#' git server. If the `origin` remote is not set to the GitHub location, the
#' function will overwrite the URL. If the `upstream` remote is not set, the
#' function will add it. If the `upstream` remote is set, the function will
#' overwrite the URL with the Bioconductor SSH URL.
#' Note that the remotes will follow this template:
#'
#' ```
#' origin git@github.com:{org}/{package}
#' upstream git@git.bioconductor.org:packages/{package}
#' ```
#'
#' @param repo `character(1)` The local path to the git repository whose
#'   upstream remote should be set
#'
#' @param remote `character(1)` The name of the remote to be created. This is
#'   usually named 'upstream' (default)
#'
#' @return
#'   * `add_bioc_remote`: adds an 'upstream' remote with the Bioconductor git
#'     address for a given package.
#'   * `set_bioc_remotes`: updates the remotes for a given package, setting the
#'     'origin' remote to the GitHub location and the 'upstream' remote to the
#'     Bioconductor git server.
#'
#' @export
add_bioc_remote <- function(repo = ".") {
    package_path <- normalizePath(repo)
    package <- basename(package_path)

    oldwd <- setwd(package_path)
    on.exit({ setwd(oldwd) })

    remotes <- git_remote_list()
    has_remote <- .remote_exists(remotes, "upstream")
    if (has_remote)
        return(
            .validate_bioc_remote(remotes)
        )

    .remote_add_bioc_up(package)

    git_remote_list()
}

.remote_add_bioc_up <- function(package, bioc_slug) {
    ## add upstream to Bioc
    if (missing(bioc_slug))
        bioc_slug <- .get_bioc_slug(package)

    git_remote_add(bioc_slug, "upstream")
}

#' @rdname bioc_remotes
#'
#' @inheritParams update_local_repo
#'
#' @export
set_bioc_remotes <- function(repo = ".", org = "Bioconductor") {
    old_wd <- setwd(repo)
    on.exit({ setwd(old_wd) })

    package <- basename(normalizePath(repo))
    gh_slug <- .get_gh_slug(org, package)
    bioc_slug <- .get_bioc_slug(package)
    remotes <- git_remote_list()
    if (!.is_origin_github(remotes, gh_slug))
        git_remote_set_url(gh_slug, remote = "origin")

    if (!.is_bioc_pkgs(package))
        stop("This package is not a Bioconductor package")

    if (!.has_bioc_upstream(remotes)) {
        if (!.remote_exists(remotes, "upstream"))
            .remote_add_bioc_up(package, bioc_slug)
        else
            git_remote_set_url(bioc_slug, "upstream")
    }

    git_remote_list()
}
