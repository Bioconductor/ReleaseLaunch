.BIOC_DEFAULT_BRANCH <- "master"
.BIOC_GIT_ADDRESS <- "git@git.bioconductor.org"
.GITHUB_ADDRESS <- "git@github.com"

#' @importFrom gh gh gh_token
.get_gh_repos <- function(api, per_page, pages, ...) {
    reslist <- vector("list", length = pages)
    for (i in seq_len(pages)) {
        reslist[[i]] <- gh::gh(
            endpoint = api,
            ...,
            page = i,
            per_page = per_page,
            .token = gh::gh_token()
        )
        if (length(reslist[[i]]) < per_page) {
            break
        }
    }
    do.call(c, reslist)
}

#' Get all repositories for a given GitHub organization or username
#'
#' `get_user_github_repos` and `get_org_github_repos` use the
#' GitHub API, to obtain the repositories hosted on GitHub via the 'username'
#' or the organization ('org') names, respectively.
#'
#' @inheritParams gh::gh
#'
#' @param pages numeric(1) The number of pages to 'flip' through (default 10)
#'
#' @param org character(1) The organization for which to extract the names of
#'   the repositories on GitHub (default "Bioconductor").
#'
#' @return A vector of default branches whose names correspond to the
#'   organization or user GitHub repositories
#'
#' @name get-github-repos
#'
#' @aliases get_org_github_repos get_user_github_repos
#'
#' @export
get_org_github_repos <-
    function(per_page = 100, pages = 10, org = "Bioconductor")
{
    results <- .get_gh_repos(
        api = "/orgs/{org}/repos", per_page = per_page, pages = pages, org = org
    )
    ## return all repo names
    defaults <- vapply(results, `[[`, character(1L), "default_branch")
    repos <- vapply(results, `[[`, character(1L), "name")
    names(defaults) <- repos
    defaults
}

#' @rdname get-github-repos
#'
#' @param username character(1) The GitHub username used to query repositories
#'
#' @param archived logical(1) Whether to include archived repositories in the
#'   query results (default FALSE)
#'
#' @examples
#'
#' if (interactive()) {
#'   my_repos <- get_user_github_repos(username = "github-username")
#'   change <- my_repos[my_repos == "master"]
#'   if (length(change))
#'     rename_branch_repos(
#'       repos = change,
#'       org = "github-username",
#'       clone = TRUE
#'     )
#' }
#'
#' @export
get_user_github_repos <-
    function(per_page = 100, pages = 10, username, archived = FALSE)
{
    results <- .get_gh_repos(
        api = "/users/{username}/repos", per_page = 100,
        pages = 10, username = username
    )
    if (!archived)
        results <- Filter(function(x) { !x[["archived"]] }, results)
    archived <- vapply(results, `[[`, logical(1L), "archived")
    defaults <- vapply(results, `[[`, character(1L), "default_branch")
    repos <- vapply(results, `[[`, character(1L), "name")
    names(defaults) <- repos
    defaults
}

.filter_gh_repos_branch <-
    function(packages, release, per_page = 100, pages = 10, owner)
{
    pkgs <- names(packages)
    hasRELEASE <- structure(
        vector("logical", length = length(packages)), .Names = pkgs
    )
    for (pkg in pkgs) {
        result <- .get_gh_repos(
            api = "/repos/{owner}/{repo}/branches",
            owner = owner,
            repo = pkg,
            per_page = per_page,
            pages = pages
        )
        branches <- vapply(result, `[[`, character(1L), "name")
        hasRELEASE[pkg] <- release %in% branches
    }
    packages[!hasRELEASE]
}

#' Get the Bioconductor packages in the software manifest
#'
#' To ensure that a GitHub repository is a software package, its name is
#' checked against a list of Bioconductor packages. This list is called
#' the manifest. This function obtains the manifest using `git`.
#'
#' @export
get_bioc_software_manifest <-
    function()
{
    ## Git command to get the software.txt file from the manifest
    args <- c("archive",
              "--remote=git@git.bioconductor.org:admin/manifest", "HEAD",
              "software.txt")
    software <- system2("git", args, wait=TRUE, stdout = TRUE)
    software <- Filter(
        function(x) !identical(x, "pax_global_header") && nchar(x),
        software
    )
    gsub("Package:\\s+", "", software)
}

#' Generate the list of packages to be updated
#'
#' This function obtains all the repositories from the Bioconductor organization
#' and filters them to only valid R packages and repositories that do not have a
#' `RELEASE_XX_YY` branch.
#'
#' @inheritParams get-github-repos
#'
#' @param version character(1L) The numeric version of the Bioconductor release,
#'   e.g., "3.16"
#'
#' @param type character(1L) The official repository name as given by
#'   `BiocManager::repositories()`. Currently, only software and experiment data
#'   ('BioCsoft' and 'BioCexp', respectively) are supported.
#'
#' @return A named scalar string of the default branch whose name corresponds to
#'   a Bioconductor GitHub repository
#'
#' @export
packages_without_release_branch <- function(
    version = "3.16", org = "Bioconductor", type = c("BioCsoft", "BioCexp")
) {
    type <- match.arg(type)
    release_slug <- paste0("RELEASE_", gsub("\\.", "_", version))
    ## software <- get_bioc_software_manifest()
    repos <- BiocManager:::.repositories_bioc(version)[type]
    db <- utils::available.packages(repos = repos, type = "source")
    software <- rownames(db)
    pre_existing_pkgs <- get_org_github_repos(org = org)
    candidates <- intersect(names(pre_existing_pkgs), software)
    candidates <- pre_existing_pkgs[candidates]
    .filter_gh_repos_branch(candidates, release_slug, owner = org)
}

#' Add the release branch to GitHub package repositories
#'
#' This function assumes that you have admin push access to the GitHub
#' organization indicated by `org`.
#'
#' @param package_name character(1) The name of the organization R package that
#'   is also available on GitHub.
#'
#' @param release character(1) The Bioconductor version branch tag, e.g.,
#'   "RELEASE_3_16"
#'
#' @param gh_branch character(1) The name of the default branch on GitHub. It
#'   may be 'main', 'master', or 'devel' depending on the repository
#'
#' @param bioc_branch character(1) The name of the default branch on the
#'   Bioconductor git server (default 'master')
#'
#' @inheritParams get-github-repos
#'
#' @name branch-release-gh
#'
#' @aliases add_gh_release_branch add_gh_release_branches
#'
#' @import gert
#'
#' @examples
#' if (interactive()) {
#'   add_gh_release_branch (
#'     package_name = "updateObject", gh_branch = "master"
#'   )
#' }
#'
#' @export
add_gh_release_branch <- function(
    package_name, release = "RELEASE_3_16",
    gh_branch = .BIOC_DEFAULT_BRANCH, bioc_branch = .BIOC_DEFAULT_BRANCH,
    org = "Bioconductor"
) {
    message("Working on: ", package_name)
    ## git clone git@github.com:Bioconductor/ShortRead.git
    bioc_gh_slug <- paste0("git@github.com:", org, "/", package_name)
    if (!dir.exists(package_name))
        git_clone(bioc_gh_slug)
    ## cd to package dir
    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })
    git_pull("origin")
    cbranch <- git_branch()
    if (!identical(cbranch, "devel"))
        warning("Consider using 'devel' as the default GitHub branch")
    if (!identical(cbranch, gh_branch))
        git_branch_checkout(gh_branch)
    bioc_git_slug <- .get_bioc_slug(package_name)
    ## git remote add upstream git@git.bioconductor.org:packages/<pkg>.git
    remotes <- git_remote_list()
    if (!.check_remote_exists(remotes, "upstream"))
        git_remote_add(bioc_git_slug, name = "upstream")
    git_fetch("upstream")
    up_remote <- paste0("upstream/", bioc_branch)
    git_merge(up_remote)
    ## git push origin master
    git_push("origin")
    ##
    if (!git_branch_exists(branch = release))
        git_branch_create(release, ref = paste0("upstream/", release))

    git_push("origin", set_upstream = TRUE)
    git_branch_checkout(cbranch)
}

.add_gh_release_branches <- function(packages, release, bioc_branch, org) {
    Map(
        add_gh_release_branch,
        package_name = names(packages),
        release = release,
        gh_branch = packages,
        bioc_branch = bioc_branch,
        org = org
    )
}

#' @rdname branch-release-gh
#'
#' @param packages named character() A character vector of default branches
#'   whose names correspond to Bioconductor package names. See
#'   `packages_without_release_branch`.
#'
#' @seealso packages_without_release_branch
#'
#' @export
add_gh_release_branches <- function(
    packages = character(0L),
    release = "RELEASE_3_16",
    bioc_branch = .BIOC_DEFAULT_BRANCH,
    org = "Bioconductor"
) {
    if (!length(packages))
        packages <- packages_without_release_branch(org = org)
    if (is.null(names(packages)))
        stop("'packages' must have names")
    .add_gh_release_branches(
        packages, release=release, bioc_branch = bioc_branch, org = org
    )
}
