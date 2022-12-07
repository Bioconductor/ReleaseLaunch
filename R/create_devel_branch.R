#' Find packages with default branches for an organization
#'
#' This function will search through an organizations repositories and identify
#' packages whose default branches are in the `branches` argument. This allows
#' the user to identify which repositories will need to have a `devel` branch
#' added.
#'
#' @inheritParams create_devel_branch
#'
#' @param branches character() A vector of branches that are sought as default
#'   branches
#'
#' @seealso repos_with_default_branch
#'
#' @return A named character vector of default branches whose names correspond
#'   to package repositories on GitHub
#'
#' @export
packages_with_default_branch <- function(
    version = BiocManager::version(),
    branches = c(.OLD_DEFAULT_BRANCH, "main"),
    org = "Bioconductor"
) {
    repos <- BiocManager:::.repositories_bioc(version)["BioCsoft"]
    db <- utils::available.packages(repos = repos, type = "source")
    software <- rownames(db)
    pre_existing_pkgs <- get_org_github_repos(org = org)
    candidates <- intersect(names(pre_existing_pkgs), software)
    candidates <- pre_existing_pkgs[candidates]
    candidates[candidates %in% branches]
}

#' Identify repositories that have old default branches
#'
#' The function obtains all the repositories within the given organization
#' (Bioconductor) that match the `branches` argument.
#'
#' @details
#'
#' The output of this function is used to rename branches with
#' `branch_all_repos`.
#'
#' @inheritParams packages_with_default_branch
#'
#' @return A named character vector of default branches whose names correspond
#'   to organization repositories on GitHub
#'
#' @seealso packages_with_default_branch
#'
#' @export
repos_with_default_branch <- function(
    branches = c(.OLD_DEFAULT_BRANCH, "main"),
    org = "Bioconductor"
) {
    repos <- get_org_github_repos(org = org)
    repos[repos %in% branches]
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
#' @param is_package logical(1) Whether the repository is an R package on
#'   Bioconductor. If so, additional validity checks will be run on the git
#'   remotes.
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
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = FALSE, is_package = TRUE
) {
    if (!dir.exists(package_name) && clone)
        git_clone(url = .get_slug_gh(package_name, org))
    else if (!dir.exists(package_name))
        stop("'package_name' not found in the current 'getwd()'")

    old_wd <- setwd(package_name)
    on.exit({ setwd(old_wd) })
    if (is_package)
        .validate_remotes()

    has_devel <- git_branch_exists("devel")
    if (has_devel)
        stop("'devel' branch already exists")

    git_branch_checkout(from_branch)
    git_pull(remote = "origin")
    if (is_package)
        git_pull(remote = "upstream")
    git_branch_move(branch = from_branch, new_branch = "devel", repo = I("."))
    if (git_branch_exists(from_branch))
        git_branch_delete(from_branch)
    gh::gh(
        "POST /repos/{owner}/{repo}/branches/{branch}/rename",
        owner = org,
        repo = package_name,
        branch = from_branch, new_name = "devel",
        .token = gh::gh_token()
    )

    set_upstream <- match.arg(set_upstream)
    ## push first then set upstream
    git_push(remote = "origin")

    ## set head to origin/devel
    system2("git", "remote set-head origin devel")
    git_branch_set_upstream(set_upstream)
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
add_bioc_remote <- function(package_name, remote = "upstream") {
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

.create_devel_branch <- function(
    packages,
    org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = TRUE,
    is_package = TRUE
) {
    mapply(
        FUN = create_devel_branch,
        package_name = names(packages),
        from_branch = packages,
        MoreArgs = list(
            org = org,
            set_upstream = set_upstream,
            clone = clone,
            is_package = is_package
        ),
        SIMPLIFY = FALSE
    )
}

#' Convenience function to create the devel branch for all GitHub packages
#'
#' This function identifies an organization's repositories that are packages
#' given the current version of Bioconductor (from `BiocManager::version()`)
#' and identifies which repositories need to have a `devel` branch added.
#' It then adds the `devel` branch using the `create_devel_branch` function.
#' It is highly recommended that the user run this on the devel version of
#' Bioconductor to avoid missing packages that are only in devel.
#'
#' @details
#'
#' Note that the `clone` argument allows the user to clone the repository first
#' from GitHub via SSH. It is recommended that this be enabled and that the
#' user running this function can clone packages via SSH and have access to
#' modifying packages on the GitHub organization.
#'
#' @inheritParams create_devel_branch
#'
#' @param old_branches character() A vector of default branch names to be
#'   replaced, by default this includes 'master' and 'main'
#'
#' @export
branch_all_packages <- function(
    version = BiocManager::version(),
    old_branches = c(.OLD_DEFAULT_BRANCH, "main"),
    org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = TRUE
) {
    packages <- packages_with_default_branch(version, old_branches, org)
    .create_devel_branch(
        packages = packages,
        org = org,
        set_upstream = set_upstream,
        clone = clone,
        is_package = TRUE
    )
}

#' Convenience function to create the devel branch for all GitHub repositories
#'
#' This function identifies all repositories within an organization that have
#' `old_branches`, i.e., either 'master' or 'main' by default. It then
#' sets the default branch to `devel`.
#'
#'
#' @export
branch_all_repos <- function(
    old_branches = c(.OLD_DEFAULT_BRANCH, "main"),
    org = "Bioconductor",
    set_upstream = c("origin/devel", "upstream/devel"),
    clone = TRUE
) {
    repos <- repos_with_default_branch(old_branches, org)
    .create_devel_branch(
        packages = repos,
        org = org,
        set_upstream = set_upstream,
        clone = clone,
        is_package = FALSE
    )
}
