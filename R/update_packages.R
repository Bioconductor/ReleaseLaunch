## This code is being developed to help with the core team transition
#' @importFrom gh gh gh_token
.gh_organization_repos_get <- function(
    api="/orgs/{org}/repos", org = "Bioconductor", token = gh::gh_token(), ...
) {
    gh::gh(api, org = org, token = token, ...)
}


#' Get list of packages for Bioconductor's github organization.
#'
#' This uses the github API, to get the bioconductor packages hosted
#' on github.  Return all packages in https:://github.com/Bioconductor
#'
#' @inheritParams gh::gh
#'
#' @param pages numeric(1) The number of pages to 'flip' through (default 10)
#'
#' @export
get_bioc_github_repos <-
    function(per_page = 100, pages = 10)
{
    reslist <- vector("list", length = pages)
    for (i in seq_len(pages)) {
        reslist[[i]] <-
            .gh_organization_repos_get(per_page = per_page, page = i)
        if (length(reslist[[i]]) < per_page) {
            break
        }
    }
    results <- do.call(c, reslist)
    ## return all repo names
    vapply(results, `[[`, character(1L), "name")
}


#' Get bioconductor software manifest
#'
#' The software packages are the only packages hosted on github, by
#' the organization.
#'
#' @export
get_bioc_software_manifest <-
    function()
{
    ## Git command to get the software.txt file from the manifest
    args <- c("archive",
              "--remote=git@git.bioconductor.org:admin/manifest", "HEAD",
              "software.txt","|" , "tar", "-x")
    system2("git", args, wait=TRUE)
    software <- readLines("software.txt")
    software <- sub(
        "Package: *", "",
        regmatches(software, regexpr("Package:.*", software))
    )
    ## Return all software packages
    software
}

#' Generate list of packages to be updated
#'
#' @export
packages_list_to_be_updated <-
    function(version = "3.16")
{
    ## software <- get_bioc_software_manifest()
    repos <- BiocManager:::.repositories_bioc(version)["BioCsoft"]
    db <- utils::available.packages(repos = repos)
    software <- rownames(db)
    pre_existing_pkgs <- get_bioc_github_repos()
    intersect(pre_existing_pkgs, software)
}


#' Clone and update a GitHub repository.
#'
#' This function assumes that you have admin push access to the
#' bioconductor github organization.
#'
#' @param package_name character(1) The name of the package to be cloned and
#'   updated
#'
#' @param release character(1) The Bioconductor version tag, e.g.,
#'   "RELEASE_3_16"
#'
#' @import gert
#'
#' @export
clone_and_push_git_repo <- function(
    package_name, release="RELEASE_3_16",
    gh_branch = "master", bioc_branch = "master"
) {
    ## git clone git@github.com:Bioconductor/ShortRead.git
    bioc_gh_slug <- paste0("git@github.com:Bioconductor/", package_name)
    if (!dir.exists(package_name))
        git_clone(bioc_gh_slug)
    ## cd to package dir
    owd <- setwd(package_name)
    on.exit({ setwd(owd) })
    git_pull("origin")
    cbranch <- git_branch()
    if (!identical(cbranch, "devel"))
        warning("Consider using 'devel' as the default GitHub branch")
    if (!identical(cbranch, gh_branch))
        git_branch_checkout(gh_branch)
    bioc_git_slug <- paste0("git@git.bioconductor.org:packages/", package_name)
    ## git remote add upstream git@git.bioconductor.org:packages/<pkg>.git
    if (!"upstream" %in% git_remote_list()[["name"]])
        git_remote_add(bioc_git_slug, name = "upstream")
    git_fetch("upstream")
    git_merge("upstream/master")
    ## git push origin master
    git_push("origin")
    ##
    if (!git_branch_exists(branch = release))
        git_branch_create(release, ref = paste0("upstream/", release))

    git_push("origin", set_upstream = TRUE)
    git_branch_checkout(cbranch)
}


#' Function to update all the packages.
#'
#' Updates all the packages in the GitHub organization maintained by
#' the core team.
#'
#' @inheritParams clone_and_push_git_repo
#'
#' @export
update_all_packages <-
    function(release)
{
    packages <- packages_list_to_be_updated()
    for (package in packages) {
        clone_and_push_git_repo(package, release=release)
    }
}
