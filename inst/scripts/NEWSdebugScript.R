
prevRepos="3.11"
currRepos="3.12"
repo = "bioc"
#repo = "data/experiment"
URL_BASE <- "http://master.bioconductor.org/packages/"
VIEWS <- "%s%s/%s/VIEWS"

    prevUrl <- url(sprintf(VIEWS, URL_BASE, prevRepos, repo))
    prev <- read.dcf(prevUrl, fields=c("Package", "Version"))
    rownames(prev) <- prev[,1]
    close(prevUrl)
    currUrl <- url(sprintf(VIEWS, URL_BASE, currRepos, repo))
    curr <- read.dcf(currUrl, fields=c("Package", "Version"))
    rownames(curr) <- curr[,1]
    close(currUrl)

    prev <- prev[rownames(prev) %in% rownames(curr),]
    newpkgs <- setdiff(rownames(curr), rownames(prev))

    idx <- package_version(curr[newpkgs, "Version"]) >= "0.99.0"
    newpkgs <- newpkgs[idx]
    vers <- c(sub("\\.[[:digit:]]?$", ".0", prev[,"Version"]),
              sturcture(rep("0.0", length(newpkgs)), .Names = newpkgs))

pkg = "ggtreeExtra"
srcdir = "/home/shepherd/BioconductorPackages/Software"
ver = vers[pkg]

#    getNews <- function(pkg, ver, srcdir) {


        newsloc <- file.path(srcdir, pkg, c("inst", "inst", "inst", ".","."),
                             c("NEWS.Rd", "NEWS", "NEWS.md", "NEWS.md", "NEWS"))
        news <- head(newsloc[file.exists(newsloc)], 1)
        if (0L == length(news))
            return(NULL)
	if (length(newsloc[file.exists(newsloc)]) > 1)
	    message("More than 1 news file found")
        tryCatch({
            db <-
                if (grepl("Rd$", news)){
                    tools:::.build_news_db_from_package_NEWS_Rd(news)
                } else if (grepl("md$", news)){
                    tools:::.build_news_db_from_package_NEWS_md(news)
                } else {
                    tools:::.news_reader_default(news)
                }
            if (!is.null(db))
                utils::news(Version > ver, db=db)
            else NULL
        }, error=function(...) NULL)


#    }




###
dbs = list(OmnipathR = omnipathr_ver, BiocCheck = bioccheck_ver)

## this does not work with how R reads in
##   db = tools:::.build_news_db_from_package_NEWS_md(news)
##   utils::news(Version > ver, db=db)

## compare bioccheck to omnipathr
## bioccheck is a character vector
## omnipathr is a single character string



    dbs <- lapply(dbs, function(db) {
        db[["Text"]] <- sapply(db[["Text"]], function(elt) {
            paste(strwrap(elt, width=options()[["width"]] - 10),
                  collapse="\n")
        })
        db
    })
