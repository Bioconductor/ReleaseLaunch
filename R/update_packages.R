.OLD_DEFAULT_BRANCH <- "master"

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

#' Get all repositories for a given GitHub organization
#'
#' This uses the GitHub API, to get the Bioconductor repositories hosted
#' on GitHub. It returns all packages in https:://github.com/Bioconductor
#' by default.
#'
#' @inheritParams gh::gh
#'
#' @param pages numeric(1) The number of pages to 'flip' through (default 10)
#'
#' @param org character(1L) The organization for which to extract the names of
#'   the repositories on GitHub (default "Bioconductor").
#'
#' @return A vector of default branches whose names correspond to the
#'   organization's GitHub repositories
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
#' @inheritParams get_org_github_repos
#'
#' @param version character(1L) The numeric version of the Bioconductor release,
#'   e.g., "3.16"
#'
#' @return A named scalar string of the default branch whose name corresponds to
#'   a Bioconductor GitHub repository
#'
#' @export
packages_list_to_be_updated <-
    function(version = "3.16", org = "Bioconductor")
{
    release_slug <- paste0("RELEASE_", gsub("\\.", "_", version))
    ## software <- get_bioc_software_manifest()
    repos <- BiocManager:::.repositories_bioc(version)["BioCsoft"]
    db <- utils::available.packages(repos = repos, type = "source")
    software <- rownames(db)
    pre_existing_pkgs <- get_org_github_repos(org = org)
    candidates <- intersect(names(pre_existing_pkgs), software)
    candidates <- pre_existing_pkgs[candidates]
    .filter_gh_repos_branch(candidates, release_slug, owner = org)
}

.BIOC_GIT_ADDRESS <- "git@git.bioconductor.org"

.get_bioc_slug <- function(package_name) {
    paste0(.BIOC_GIT_ADDRESS, ":packages/", package_name)
}

#' Clone and update a GitHub repository.
#'
#' This function assumes that you have admin push access to the
#' bioconductor github organization.
#'
#' @param package_name named character(1) A scalar string of the default
#'   branch whose name corresponds to a Bioconductor GitHub repository, as
#'   given by `packages_list_to_be_updated()`.
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
#' @inheritParams get_org_github_repos
#'
#' @import gert
#'
#' @examples
#' if (interactive()) {
#'   clone_and_push_git_repo(
#'     package_name = "updateObject", gh_branch = "master"
#'   )
#' }
#'
#' @export
clone_and_push_git_repo <- function(
    package_name, release = "RELEASE_3_16",
    gh_branch = .OLD_DEFAULT_BRANCH, bioc_branch = .OLD_DEFAULT_BRANCH,
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
    if (.check_remote_exists(remotes, "upstream"))
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

.clone_and_push_git_repos <- function(packages, release, bioc_branch, org) {
    Map(
        clone_and_push_git_repo,
        package_name = names(packages),
        release = release,
        gh_branch = packages,
        bioc_branch = bioc_branch,
        org = org
    )
}

#' Function to update all the packages.
#'
#' Updates all the packages in the GitHub organization maintained by
#' the core team.
#'
#' @inheritParams clone_and_push_git_repo
#'
#' @export
update_all_packages <- function(
    release = "RELEASE_3_16",
    bioc_branch = .OLD_DEFAULT_BRANCH,
    org = "Bioconductor"
) {
    packages <- packages_list_to_be_updated(org = org)
    .clone_and_push_git_repos(
        packages, release=release, bioc_branch = bioc_branch, org = org
    )
}

.validate_bioc_remote <- function(remotes, remote = "upstream") {
    remote_url <- remotes[remotes[["name"]] == remote, "url"]
    bioc_remote <- grepl("git.bioconductor.org", unlist(remote_url))
    if (!bioc_remote)
        stop(
            sQuote(remote, FALSE),
            " remote not set to Bioconductor git repository"
        )
}

.validate_remote_names <- function(remotes) {
    all_remotes <- all(c("origin", "upstream") %in% remotes[["name"]])
    if (!all_remotes)
        stop("'origin' and 'upstream' remotes are not set")
}

.validate_remotes <- function() {
    remotes <- git_remote_list()
    .validate_remote_names(remotes)
    .validate_bioc_remote(remotes)
    TRUE
}

#' Create the 'devel' branch locally and on GitHub
#'
#' The function is meant to be run one level up from the local git repository.
#' It will create the 'devel' branch and push to the `origin` remote which
#' should be set to GitHub. Upstream tracking can be configured to either the
#' `origin` or `upstream` remote.
#'
#' @details The `origin` remote is assumed to be GitHub, i.e.,
#'   `git@github.com:user/package` but this requirement is not checked or
#'   enforced; thus, allowing flexibility in remote `origin` locations. The
#'   `upstream` remote is validated against the Bioconductor git repository
#'   address, i.e., `git@git.bioconductor.org:packages/package`. The local
#'   repository is validated before the `devel` branch is created.
#'
#' @inheritParams clone_and_push_git_repo
#'
#' @param from_branch character(1) The old default branch from which to base the
#'   new 'devel' branch from (default: 'master')
#'
#' @param set_upstream character(1) The remote location that will be tracked by
#'   the local branch, either "origin/devel" (default) or "upstream/devel"
#'
#' @return Called for the side effect of creating a 'devel' branch on the local
#'   and remote repositories on GitHub
#'
#' @examples
#' if (interactive()) {
#'
#'   create_devel_branch(
#'     package_name = "SummarizedExperiment",
#'     org = "Bioconductor",
#'     set_upstream = "upstream/devel"
#'   )
#'
#' }
#'
#' @export
create_devel_branch <- function(
    package_name, from_branch = .OLD_DEFAULT_BRANCH, org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel")
) {
    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })
    .validate_remotes()

    has_devel <- git_branch_exists("devel")
    if (has_devel)
        stop("'devel' branch already exists")

    git_branch_checkout(from_branch)
    git_pull(remote = "origin")
    git_pull(remote = "upstream")
    git_branch_create("devel", checkout = TRUE)

    set_upstream <- match.arg(set_upstream)
    git_branch_set_upstream(set_upstream)

    git_push(remote = "origin")
}

.check_remote_exists <- function(remotes, remote) {
    remote %in% remotes[["name"]]
}

#' A convenience function to set the 'upstream' Bioconductor remote
#'
#' The function will create an 'upstream' remote using
#' `git@git.bioconductor.org` as the primary address. If an `upstream` remote
#' already exists, it will be validated. The remote name can be changed to the
#' desired name via the `remote` argument but it is customarily called the
#' 'upstream' remote.
#'
#' @inheritParams create_devel_branch
#'
#' @param remote character(1L) The name of the remote to be created. This is
#'   usually named 'upstream' (default)
#'
#' @return Called for the side effect of creating an 'upstream' remote with the
#'   Bioconductor git address for a given package
#'
#' @export
set_bioc_remote <- function(package_name, remote = "upstream") {
    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })

    remotes <- git_remote_list()
    has_remote <- .check_remote_exists(remotes, remote)
    if (has_remote)
        return(
            .validate_bioc_remote(remotes, remote)
        )

    ## add upstream to Bioc
    bioc_git_slug <- .get_bioc_slug(package_name)

    git_remote_add(bioc_git_slug, remote)
}
