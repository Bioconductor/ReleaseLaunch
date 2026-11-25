.GITHUB_SSH_ADDRESS <- "git@github.com"

## Use this helper to format all error / warning / message text
.msg <-
    function(fmt, ..., width=getOption("width"))
{
    strwrap(sprintf(fmt, ...), width=width, exdent=4)
}

## Retry a network operation (clone, pull, fetch, push) that may fail
## transiently, e.g., when GitHub throttles rapid SSH connections. Waits
## `pause` seconds between attempts, doubling the wait each time.
.with_retry <- function(FUN, ..., attempts = 3L, pause = 5) {
    for (i in seq_len(attempts)) {
        res <- tryCatch(FUN(...), error = identity)
        if (!inherits(res, "error"))
            return(invisible(res))
        if (i == attempts)
            stop(res)
        message(
            "  Attempt ", i, "/", attempts, " failed: ",
            conditionMessage(res), "\n  Retrying in ", pause, "s..."
        )
        Sys.sleep(pause)
        pause <- pause * 2
    }
}

## OpenSSH options so that a stalled connection fails instead of hanging:
## ConnectTimeout covers the TCP connect and the SSH banner exchange;
## ServerAlive* drops a connection that stops responding mid-transfer;
## BatchMode prevents passphrase prompts (keys come from the ssh-agent).
.GIT_SSH_COMMAND <- paste(
    "ssh -o ConnectTimeout=30 -o ServerAliveInterval=15",
    "-o ServerAliveCountMax=4 -o BatchMode=yes"
)

## Run a network git command (clone, pull, fetch, push) with the command-line
## client rather than gert, whose libssh2 transport has no timeout and can
## hang indefinitely. `timeout` (seconds) is a hard limit as a backstop.
## `repo` is the repository directory the command runs in (`git -C`).
.git_net <- function(args, repo = ".", timeout = 600) {
    old <- Sys.getenv(c("GIT_SSH_COMMAND", "GIT_TERMINAL_PROMPT"), unset = NA)
    on.exit({
        for (var in names(old)) {
            if (is.na(old[[var]]))
                Sys.unsetenv(var)
            else
                do.call(Sys.setenv, as.list(old[var]))
        }
    })
    Sys.setenv(GIT_SSH_COMMAND = .GIT_SSH_COMMAND, GIT_TERMINAL_PROMPT = "0")
    cmd <- paste("git", paste(args, collapse = " "))
    out <- suppressWarnings(system2(
        "git", c("-C", shQuote(repo), args),
        stdout = TRUE, stderr = TRUE, timeout = timeout
    ))
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        if (identical(status, 124L))
            stop("'", cmd, "' timed out after ", timeout, "s", call. = FALSE)
        stop(
            "'", cmd, "' failed (status ", status, "):\n",
            paste(out, collapse = "\n"),
            call. = FALSE
        )
    }
    invisible(out)
}

## Replacement for `gert::git_pull(remote)`: fetch `remote/branch` with the
## command-line client (timeouts and retries), then merge it locally with
## gert. The merge is not retried, so a conflict stops immediately.
.git_fetch_merge <- function(remote, branch, repo = ".") {
    .with_retry(.git_net, c("fetch", remote, branch), repo = repo)
    .git_merge_or_stop(paste0(remote, "/", branch), repo = repo)
}

## `gert::git_merge()` only prints a message on conflicts and leaves the
## repository mid-merge; stop instead so the conflict can be resolved.
.git_merge_or_stop <- function(ref, repo = ".") {
    git_merge(ref, repo = repo)
    conflicts <- git_conflicts(repo = repo)
    if (nrow(conflicts))
        stop(
            "Merge conflicts merging '", ref, "' in '",
            normalizePath(repo), "':\n  ",
            paste(unique(conflicts[["our"]]), collapse = "\n  "),
            "\nResolve and commit (or 'git merge --abort'), then resume.",
            call. = FALSE
        )
    invisible(TRUE)
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
    all_repos <- BiocManager::repositories()
    bioc_repos <- all_repos[grepl("BioC", names(all_repos))]
    bioc_avail <- utils::available.packages(repos = bioc_repos)
    bioc_pkgs <- rownames(bioc_avail)
    basename(pkg_dirs) %in% bioc_pkgs
}

.repo_exists <- function(pkg, org) {
    repo_info <- tryCatch({
        gh::gh(
            endpoint = "/repos/{owner}/{repo}",
            owner = org,
            repo = pkg
        )
    }, error = function(e) {
        list(name = NULL)
    })
    !is.null(repo_info[["name"]])
}
