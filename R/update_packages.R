#' Get API keys from location
#'
#' Most important step of all of the code! Without getting access to
#' the API keys, it is impossible to run this code.
#'
#'
.github_userpwd <-
    function()
 {
     paste(
         getOption("git_contributions_github_user"),
         getOption("git_contributions_github_auth"),
         sep=":"
     )
 }


## This code is being developed to help with the core team transition
#' @importFrom httr accept GET config stop_for_status content
.github_organization_get <-
    function(path, api="https://api.github.com",
             path_root="/orgs/Bioconductor/repos")
{
    query <- sprintf("%s%s%s", api, path_root, path)
    response <- GET(
        query,
        config(userpwd=.github_userpwd(), httpauth=1L),
        accept("application/vnd.github.v3+json"))
    stop_for_status(response)
    content(response)
}


#' Get list of packages for Bioconductor's github organization.
#'
#' This uses the github API, to get the bioconductor packages hosted
#' on github.  Return all packages in https:://github.com/Bioconductor
#'
#' @export
get_bioc_github_repos <-
    function()
{
    ## Page 1
    results <- c()
    for (i in 1:10) {
    	result <- .github_organization_get(paste0("?page=",i,"&per_page=100"))
    	results <- c(results, result)
    }
    ## Page 2
    ## Combined list of results
    pkgs <- sapply(results, `[[`, "name")
    ## Return all packages
    pkgs
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
    function()
{
    software = get_bioc_software_manifest()
    pre_existing_pkgs = get_bioc_github_repos()
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
#' @export
clone_and_push_git_repo <-
    function(package_name, release="RELEASE_3_12")
{
    ## git clone git@github.com:Bioconductor/ShortRead.git
    args <- paste("clone", sprintf("git@github.com:Bioconductor/%s", package_name))
    system2("git", args, wait=TRUE)
    ## cd ShortRead
    owd <- setwd(package_name)
    ## git remote add upstream git@git.bioconductor.org:packages/ShortRead.git
    getwd()
    args <- paste(
        "remote", "add", "upstream",
        sprintf("git@git.bioconductor.org:packages/%s", package_name)
    )
    system2("git", args, wait=TRUE)
    ## git fetch upstream
    args <- paste("fetch", "upstream")
    system2("git", args, wait=TRUE)
    ## git merge upstream/master
    args <- paste("merge", "upstream/master")
    system2("git", args, wait=TRUE)
    ## git push origin master
    args <- paste("push", "origin", "master")
    system2("git", args, wait=TRUE)
    ## For release_branches, check if branch exists
    remote_release <- paste0("upstream/", release)
    args <- paste("branch", "-a", "--list", remote_release)
    check_release <- system2("git", args, stdout=TRUE)
    if (any(grepl(release, check_release))) {

        ## git checkout -b RELEASE_3_5 upstream/RELEASE_3_5
        args <- paste("checkout", "-b", release, remote_release)
        system2("git", args, wait=TRUE)
        ## git push -u origin RELEASE_3_5
        args <- paste("push", "-u", "origin", release)
        system2("git", args, wait=TRUE)
    }
    setwd(owd)
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
