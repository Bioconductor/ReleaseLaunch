.BIOC_DEFAULT_BRANCH <- "devel"
.BIOC_GIT_ADDRESS <- "git@git.bioconductor.org"
.BIOC_CONFIG_FILE <- "https://bioconductor.org/config.yaml"

.tag_to_version <- function(tag) {
    stopifnot(grepl("RELEASE_", tag, fixed = TRUE))
    version <- gsub("RELEASE_", "", tag, fixed = TRUE)
    gsub("_", ".", version, fixed = TRUE)
}

.version_to_tag <- function(version) {
    paste0("RELEASE_", gsub(".", "_", version, fixed = TRUE))
}

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

#' @name get-github-repos
#'
#' @title Get all repositories for a given GitHub organization or username
#'
#' @description `get_user_github_repos` and `get_org_github_repos` use the
#' GitHub API, to obtain the repositories hosted on GitHub via the 'username' or
#' the organization ('org') names, respectively.
#'
#' @inheritParams gh::gh
#'
#' @param pages `numeric(1)` The number of pages to 'flip' through (default 10)
#'
#' @param org `character(1)` The organization for which to extract the names of
#'   the repositories on GitHub (default "Bioconductor").
#'
#' @param archived `logical(1)` Whether to include archived repositories in the
#'   query results (default FALSE)
#'
#' @return A vector of default branches whose names correspond to the
#'   organization or user GitHub repositories
#'
#' @aliases get_org_github_repos get_user_github_repos
#'
#' @export
get_org_github_repos <-
    function(per_page = 100, pages = 10, org = "Bioconductor", archived = FALSE)
{
    results <- .get_gh_repos(
        api = "/orgs/{org}/repos", per_page = per_page, pages = pages, org = org
    )
    ## return all repo names and filter archived
    if (!archived)
        results <- Filter(function(x) { !x[["archived"]] }, results)
    defaults <- vapply(results, `[[`, character(1L), "default_branch")
    repos <- vapply(results, `[[`, character(1L), "name")
    names(defaults) <- repos
    defaults
}

#' @rdname get-github-repos
#'
#' @param username `character(1)` The GitHub username used to query repositories
#'
#' @examples
#'
#' if (interactive()) {
#'   get_user_github_repos(username = "github-username")
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
    function(packages, release, per_page = 100, pages = 10, owner, without)
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
    if (without) packages[!hasRELEASE] else packages[hasRELEASE]
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

get_org_packages <- function(version, org, type) {
    ## software <- get_bioc_software_manifest()
    repos <- BiocManager:::.repositories_bioc(version)[type]
    db <- utils::available.packages(repos = repos, type = "source")
    software <- rownames(db)
    pre_existing_pkgs <- get_org_github_repos(org = org)
    candidates <- intersect(names(pre_existing_pkgs), software)
    pre_existing_pkgs[candidates]
}

#' Generate the list of packages to be updated
#'
#' These functions obtain all the repositories from the designated organization
#' and filters them to only valid R packages and repositories that do not have a
#' `RELEASE_X_Y` branch or that do, depending on the function called.
#'
#' @inheritParams get-github-repos
#'
#' @param version `character(1)` The numeric version of the Bioconductor release,
#'   e.g., "3.16"
#'
#' @param type `character()` The repository names to look through as returned by
#'   `BiocManager::repositories()`. Currently, only software and experiment data
#'   ('BioCsoft' and 'BioCexp', respectively) are supported.
#'
#' @return A named scalar string of the default branch whose name corresponds to
#'   a Bioconductor GitHub repository
#'
#' @examples
#' if (interactive()) {
#'     packages_without_release_branch(version = "3.19")
#' }
#' @export
packages_without_release_branch <- function(
    version = "3.16", org = "Bioconductor", type = c("BioCsoft", "BioCexp")
) {
    release_tag <- .version_to_tag(version)
    candidates <- get_org_packages(version = version, org = org, type = type)
    .filter_gh_repos_branch(
        candidates, release_tag, owner = org, without = TRUE
    )
}

#' @rdname packages_without_release_branch
#'
#' @export
packages_with_release_branch <- function(
    version = "3.16", org = "Bioconductor", type = c("BioCsoft", "BioCexp")
) {
    release_tag <- .version_to_tag(version)
    candidates <- get_org_packages(version = version, org = org, type = type)
    .filter_gh_repos_branch(
        candidates, release_tag, owner = org, without = FALSE
    )
}

#' @name branch-release-gh
#'
#' @title Add the release branch to GitHub package repositories
#'
#' @description This function assumes that you have admin push access to the
#'   GitHub organization indicated by `org`.
#'
#' @param package_name `character(1)` The name of the organization R package
#'   that is also available on GitHub.
#'
#' @param release `character(1)` The Bioconductor version branch tag, e.g.,
#'   "RELEASE_3_17"
#'
#' @param gh_branch `character(1)` The name of the default branch on GitHub. It
#'   may be 'devel' or 'main' depending on the repository
#'
#' @param bioc_branch `character(1)` The name of the default branch on the
#'   Bioconductor git server (default 'devel')
#'
#' @inheritParams get-github-repos
#'
#' @aliases add_gh_release_branch add_gh_release_branches
#'
#' @import gert
#'
#' @examples
#' get_bioc_release_yaml()
#' if (interactive()) {
#'     add_gh_release_branch(
#'       package_name = "BiocParallel",
#'       release = "RELEASE_3_19"
#'     )
#'
#'     add_gh_release_branches(
#'         release = get_bioc_release_yaml(),
#'         org = "Bioconductor"
#'     )
#' }
#' @export
add_gh_release_branch <- function(
    package_name, release = "RELEASE_3_17",
    gh_branch = .BIOC_DEFAULT_BRANCH, bioc_branch = .BIOC_DEFAULT_BRANCH,
    org = "Bioconductor"
) {
    message("Working on: ", package_name)
    ## git clone git@github.com:Bioconductor/ShortRead.git
    org_gh_slug <- .get_gh_slug(org, package_name)
    if (!dir.exists(package_name))
        git_clone(org_gh_slug)
    ## cd to package dir
    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })
    remotes <- git_remote_list()
    if (!.is_origin_github(remotes, org_gh_slug))
        stop("'origin' remote is not set to GitHub")
    cbranch <- git_branch()
    if (!identical(cbranch, gh_branch))
        git_branch_checkout(gh_branch)
    git_pull("origin")
    bioc_git_slug <- .get_bioc_slug(package_name)
    ## git remote add upstream git@git.bioconductor.org:packages/<pkg>.git
    if (!.remote_exists(remotes, "upstream"))
        git_remote_add(bioc_git_slug, name = "upstream")
    git_fetch("upstream")
    up_remote <- paste0("upstream/", bioc_branch)
    git_merge(up_remote)
    ## git push origin devel
    git_push("origin")
    ##
    if (!git_branch_exists(branch = release))
        git_branch_create(release, ref = paste0("upstream/", release))

    git_push("origin", set_upstream = TRUE)
    git_branch_checkout(cbranch)
}

.add_gh_release_branches <-
    function(packages, release, bioc_branch, org)
{
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
#' @param packages `named character()` A character vector of default branches
#'   whose names correspond to Bioconductor package names. See
#'   `packages_without_release_branch`.
#'
#' @seealso packages_without_release_branch
#'
#' @export
add_gh_release_branches <- function(
    packages = character(0L),
    release = "RELEASE_3_19",
    bioc_branch = .BIOC_DEFAULT_BRANCH,
    org = "Bioconductor"
) {
    if (!missing(release))
        version <- .tag_to_version(release)
    else
        version <- .get_bioc_version()
    message("Working on Bioconductor version: ", version)
    if (!length(packages))
        packages <- packages_without_release_branch(
            version = version, org = org
        )
    message(
        "Packages without release branch: ",
        paste(names(packages), collapse = ", ")
    )
    if (is.null(names(packages)))
        stop("'packages' must have names")
    .add_gh_release_branches(
        packages,
        release = release,
        bioc_branch = bioc_branch,
        org = org
    )
}

#' @rdname branch-release-gh
#'
#' @param config `character(1)` The path to the Bioconductor configuration file
#'   that contains the release version (defaults to website URL from
#'   `.BIOC_CONFIG_FILE`)
#'
#' @export
get_bioc_release_yaml <- function(config = .BIOC_CONFIG_FILE) {
    conf <- yaml::read_yaml(config)
    relver <- conf[["release_version"]]
    .version_to_tag(relver)
}
