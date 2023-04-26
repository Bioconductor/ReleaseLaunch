## Use this helper to format all error / warning / message text
.msg <-
    function(fmt, ..., width=getOption("width"))
{
    strwrap(sprintf(fmt, ...), width=width, exdent=4)
}

.check_remote_exists <- function(remotes, remote) {
    remote %in% remotes[["name"]]
}

.check_origin_gh <- function(remotes, gh_slug) {
    git_url <- remotes[remotes[["name"]] == "origin", "url"]
    git_url <- gsub(".git", "", as.character(git_url), fixed = TRUE)
    identical(gh_slug, git_url)
}

.get_bioc_slug <- function(package_name) {
    paste0(.BIOC_GIT_ADDRESS, ":packages/", package_name)
}
