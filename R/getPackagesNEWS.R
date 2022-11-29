.NEWS_LOCS <- c("inst/NEWS.Rd", "inst/NEWS", "inst/NEWS.md", "NEWS.md", "NEWS")

findNEWS <- function(pkg) {
    newsloc <- file.path(pkg, .NEWS_LOCS)
    head(newsloc[file.exists(newsloc)], 1)
}

emptyNewsDB <- function() {
    newsdb <- data.frame(
        Version = character(0L),
        Date = character(0L),
        Category = character(0L),
        Text = character(0L),
        row.names = character(0L)
    )
    class(newsdb) <- c("news_db", "data.frame")
    newsdb
}

getNEWSdb <- function(news, def_FUN = tools:::.news_reader_default) {
    fext <- tools::file_ext(news)
    build_news_db <- switch(fext,
        Rd = tools:::.build_news_db_from_package_NEWS_Rd,
        md = tools:::.build_news_db_from_package_NEWS_md,
        def_FUN
    )
    tryCatch({ build_news_db(news) }, error = function(e) emptyNewsDB())
}

getLatestNews <- function(news, ver) {
    db <- getNEWSdb(news)
    if (nrow(db))
        utils::news(Version > ver, db=db)
    else
        character(0L)
}

getNEWS <- function(pkg, ver, srcdir) {
    news <- findNEWS(file.path(srcdir, pkg))
    getLatestNews(news, ver)
}

.BIOC_BASE_URL <- "http://master.bioconductor.org/packages/"

getDCFPackageVer <- function(version, repo) {
    views_url <- sprintf("%s%s/%s/VIEWS", .BIOC_BASE_URL, version, repo)
    url <- url(views_url)
    pkgs <- read.dcf(url, fields=c("Package", "Version"))
    on.exit(close(url))
    views <- pkgs[, "Version"]
    names(views) <- pkgs[, "Package"]
    views
}

## collate package NEWS files using starting version number in
## prevRepos, and membership in currRepos as references. Package
## source tree rooted at srcDir, possibiblly as tarred files

# repo:  bioc data/experiment workflows

#' Compare the old and current releases to generate the release announcements
#' NEWS compilation
#'
#' The function uses previous and current versions of Bioconductor to generate
#' a single package's `NEWS` file.
#'
#' @param prevRepos character(1) The version string indicating the old release
#'   version of Bioconductor
#'
#' @param currRepos character(1) The version string indicating the newest and
#'   current release version of Bioconductor
#'
#' @param repo character(1) The repository nickname indicating which repository
#'   to compare news
#'
#' @param srcdir (Optional) character(1) The source directory in which all the
#'   Bioconductor packages, whose `NEWS` files are to be interrogated, reside
#'
#' @return A list of NEWS
#'
#' @export
getPackagesNEWS <- function(
        prevRepos="3.15", currRepos="3.16",
        repo=c("bioc", "data/experiment", "workflows"), srcdir=NULL
) {
    repo <- match.arg(repo)
    prev <- getDCFPackageVer(prevRepos, repo)
    curr <- getDCFPackageVer(currRepos, repo)

    prev <- prev[names(prev) %in% names(curr)]
    newpkgs <- setdiff(names(curr), names(prev))

    idx <- package_version(curr[newpkgs], strict=FALSE) >= "0.99.0"
    newpkgs <- newpkgs[idx]
    vers <- c(sub("\\.[[:digit:]]?$", ".0", prev),
              structure(rep("0.0", length(newpkgs)), .Names = newpkgs))
    if (is.null(srcdir))
        srcdir <- scpNEWS(version = currRepos, repo = repo)

    anews <- Map(getNEWS, names(vers), vers, srcdir)
    ret <- Filter(length, anews)
    nms <- names(ret)
    s <- sort(nms)
    ret[s]
}

scpNEWS <- function(
    srcdir = tempdir(), version,
    repo = c("bioc", "data/experiment" , "workflows")
) {
    remote_loc <- paste0(
        "webadmin@master.bioconductor.org:/extra/www/bioc/packages/",
        version, "/", repo, "/news"
    )
    system2("scp", c("-r", remote_loc, srcdir))
    paste0(srcdir, "/news")
}

mdIfy <- function(txt) {
    lines <- strsplit(txt, "\n")
    segs <- lines[[1]]
    segs <- sub("^    o +", "- ", segs)
    segs <- sub("^\t", "  ", segs)
    paste(segs, collapse="\n")
}

## based on tools:::.build_news_db()
getNEWSFromFile <- function(
    dir, destfile, format = NULL, reader = NULL, output=c("md", "text")
) {
    if (!is.null(format))
        .NotYetUsed("format", FALSE)
    if (!is.null(reader))
        .NotYetUsed("reader", FALSE)

    file <- file(destfile, "w+")
    on.exit(close(file))

    output <- match.arg(output)

    news <- findNEWS(dir)
    file_ext <- tools::file_ext(news)
    if (!length(news))
        return(invisible())
    db <- getNEWSdb(news, def_FUN = function(nfile) {
        paste(readLines(nfile), collapse="\n")
    })
    if (is.character(db)) {
        news <- db
    } else if (nrow(db)) {
        news <- capture.output(print(db))
        news <- paste(news, collapse="\n")
    } else {
        message(
            sprintf("Error building news database for %s/%s", dir, destfile)
        )
        return(invisible())
    }

    if (identical("md", output) && !identical(file_ext, "md"))
        news <- mdIfy(news)
    cat(news, file=file)
    return(invisible())
}


printNEWS <- function(
    dbs, destfile, overwrite=FALSE, width=68, output=c("md", "text"),
    relativeLink=FALSE, ...
) {
    output <- match.arg(output)
    dbs <- lapply(dbs, function(db) {
         db[["Text"]] <- sapply(db[["Text"]], function(elt) {
             elt <- unlist(strsplit(elt, "\n"))
             paste(strwrap(elt, width=options()[["width"]] - 10),
                   collapse="\n")
         })
         db
     })
    urlBase <- ifelse(relativeLink, "/packages/","https://bioconductor.org/packages/")
    txt <- capture.output({
        for (i in seq_along(dbs)) {
            tryCatch({
                cat(sprintf(
                    "\n[%s](%s%s)\n%s\n\n",
                    names(dbs)[[i]], urlBase, names(dbs)[[i]],
                    paste(rep("-", nchar(names(dbs)[[i]])), collapse="")))
                print(dbs[[i]])
            }, error=function(err) {
                warning("print() failed for ", sQuote(names(dbs)[[i]]),
                        immediate.=TRUE, call.=FALSE)
            })
        }
    })
    if ("md" == output) {
        txt <- sub("^    o  ", "-", txt)
        txt <- sub("^\t", "  ", txt)
    }

    if (!is(destfile, "connection")) {
        if (file.exists(destfile) && !overwrite)
            stop(.msg("'%s' exists and overwrite=FALSE", destfile))
        file <- file(destfile, "w+")
        on.exit(close(file))
    } else file = destfile
    writeLines(txt, file)
}

# manifest:  software.txt data-experiment.txt workflows.txt
# status:  new or removed
getPackageTitles <- function(
    prevBranch="RELEASE_3_6", currBranch="master",
    manifest=c("software.txt", "data-experiment.txt", "workflows.txt"),
    status = c("new", "removed")
) {
   manifest <- match.arg(manifest)
   status <- match.arg(status)

   GIT_ARCHIVE <-
       "git archive --remote=ssh://git@git.bioconductor.org/admin/manifest %s %s | tar -xO"
   prevRepo <- system(sprintf(GIT_ARCHIVE, prevBranch, manifest), intern=TRUE)
   prevRepo <- trimws(gsub(pattern = "Package: ", replacement="",
                           prevRepo[-which(prevRepo=="")]))
   currRepo <- system(sprintf(GIT_ARCHIVE, currBranch, manifest), intern=TRUE)
   currRepo <- trimws(gsub(pattern = "Package: ", replacement="",
                           currRepo[-which(currRepo=="")]))

   # switch statement
   pkgs <- switch(status,
                  new = setdiff(currRepo, prevRepo),
                  removed = setdiff(prevRepo, currRepo)
                  )
   pkgs
}

printNewPackageTitles <-
    function(titles, destfile, overwrite=FALSE)
{
    if (!is(destfile, "connection")) {
        if (file.exists(destfile) && !overwrite)
            stop(.msg("'%s' exists and overwrite=FALSE", destfile))
        file <- file(destfile, "w+")
        on.exit(close(file))
    } else file = destfile
    cat(strwrap(sprintf("\n- %s: %s", names(titles), titles),
                width=70, exdent=2),
        file=stdout(), sep="\n")
}

getPackageDescriptions <-
    function(pkgs, outfile, output=c("md", "text"),relativeLink=FALSE)
{

    output <- match.arg(output)
    if (output == "text")
        exdent = 4
    else
        exdent = 2
    plower <- tolower(pkgs)
    names(plower) <- pkgs
    pkgs <- names(sort(plower))

    file <- tempfile()
    DESC_FILE <-
        "git archive --remote=ssh://git@git.bioconductor.org/packages/%s master DESCRIPTION|tar -xO > %s"

    urlBase <- ifelse(relativeLink, "/packages/","https://bioconductor.org/packages/")
    desc = lapply(pkgs, function(pkg) {
        system(sprintf(DESC_FILE, pkg, file))
        d = read.dcf(file)[,"Description"]
        paste(strwrap(sprintf("- [%s](%s%s) %s",
                              pkg, urlBase, pkg, d), width=70, exdent=exdent),
              collapse="\n")
    })
    cat(noquote(unlist(desc)), sep="\n\n", file=outfile)
    invisible(NULL)
}

extractNewsFromTarball <- function(tarball, unpackDir) {
    files <- untar(tarball, list = TRUE)
    newsfiles <- grep("NEWS", files, value = TRUE)
    newsfile <- head(newsfiles, 1L)
    untar(tarball, files = newsfile, exdir = unpackDir)
}

pkgName <- function(tarball) {
    tarball <- basename(tarball)
    strsplit(tarball, "_", fixed = TRUE)[[1L]][[1L]]
}

convertNEWSToText <- function(tarball, srcDir, destDir) {
    pkg <- pkgName(tarball)
    srcDir <- file.path(srcDir, pkg)
    destDir <- file.path(destDir, pkg)
    if (!file.exists(destDir))
        dir.create(destDir, recursive=TRUE)
    destFile <- file.path(destDir, "NEWS")
    getNEWSFromFile(srcDir, destFile, output="text")
}

extractNEWS <- function(
    reposRoot, srcContrib,
    destDir = file.path(reposRoot, "news"),
    unpackDir = tempdir()
) {
    if (!dir.exists(destDir))
        dir.create(destDir, recursive=TRUE)

    tarballs <- list.files(
        path = file.path(reposRoot, srcContrib),
        pattern = "\\.tar\\.gz$", full.names = TRUE
    )

    lapply(tarballs, function(tarball) {
        message("Attempting to extract NEWS from ", tarball)
        extractNewsFromTarball(tarball, unpackDir=unpackDir)
        res <- try(
            convertNEWSToText(tarball, srcDir=unpackDir, destDir=destDir)
        )
        if (inherits(res, "try-error"))
            cat("FAILED!\n")
    })

    invisible(NULL)
}
