.GITHUB_SSH_ADDRESS <- "git@github.com"

## Use this helper to format all error / warning / message text
.msg <-
    function(fmt, ..., width=getOption("width"))
{
    strwrap(sprintf(fmt, ...), width=width, exdent=4)
}

.remote_exists <- function(remotes, remote) {
    remote %in% remotes[["name"]]
}

.is_origin_github <- function(remotes, gh_slug) {
    if (missing(remotes))
        remotes <- git_remote_list()
    remote_url <- unlist(
        remotes[remotes[["name"]] == "origin", "url"], use.names = FALSE
    )
    git_url <- gsub(".git", "", remote_url, fixed = TRUE)
    grepl(gh_slug, git_url, ignore.case = TRUE)
}

.get_bioc_slug <- function(package_name) {
    paste0(.BIOC_GIT_ADDRESS, ":packages/", package_name)
}

.get_gh_slug <- function(org = "Bioconductor", package_name) {
    paste0(.GITHUB_SSH_ADDRESS, ":", org, "/", package_name)
}

.has_bioc_upstream <- function(remotes) {
    if (missing(remotes))
        remotes <- git_remote_list()
    remote_url <- unlist(
        remotes[remotes[["name"]] == "upstream", "url"]
    )
    if (length(remote_url))
        grepl("git.bioconductor.org", remote_url)
    else
        FALSE
}

.validate_bioc_remote <- function(remotes) {
    bioc_remote <- .has_bioc_upstream(remotes)
    if (!bioc_remote)
        stop(
            sQuote("upstream", FALSE),
            " remote not set to Bioconductor git repository"
        )
    TRUE
}

.validate_remote_names <- function(remotes) {
    all_remotes <- all(c("origin", "upstream") %in% remotes[["name"]])
    if (!all_remotes)
        stop("'origin' and 'upstream' remotes are not set")
    TRUE
}

.validate_remotes <- function(remotes) {
    if (missing(remotes))
        remotes <- git_remote_list()
    .validate_remote_names(remotes) && .validate_bioc_remote(remotes)
}

.is_bioc_pkgs <- function(pkg_dirs) {
    bioc_pkgs <- rownames(
        available.packages(repos = BiocManager::repositories()["BioCsoft"])
    )
    basename(pkg_dirs) %in% bioc_pkgs
}
