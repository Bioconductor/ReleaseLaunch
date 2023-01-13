## Use this helper to format all error / warning / message text
.msg <-
    function(fmt, ..., width=getOption("width"))
{
    strwrap(sprintf(fmt, ...), width=width, exdent=4)
}

.check_remote_exists <- function(remotes, remote) {
    remote %in% remotes[["name"]]
}

.get_bioc_slug <- function(package_name) {
    paste0(.BIOC_GIT_ADDRESS, ":packages/", package_name)
}
