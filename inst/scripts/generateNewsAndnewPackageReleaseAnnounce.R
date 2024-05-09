library(biocViews)

## src only used if local checkout of repositories (preferred becasue:
## when accessing directly on server we loose the file extension and will have
## to manually add)


softNEWS = getPackageNEWS("3.18", "devel", repo="bioc", srcdir="/home/lorikern/BioconductorPackages/SoftwarePkg")
dataNEWS = getPackageNEWS("3.18", "devel", repo="data/experiment")
WFNEWS = getPackageNEWS("3.18", "devel",repo="workflows",srcdir="/home/lorikern/BioconductorPackages/WorkflowPkg")

printNEWS(softNEWS, "softwareNews.md", relativeLink=TRUE, overwrite=TRUE)
printNEWS(dataNEWS, "dataNews.md", relativeLink=TRUE, overwrite=TRUE)
printNEWS(WFNEWS, "workflowNEWS.md", relativeLink=TRUE, overwrite=TRUE)

rmarkdown::render("softwareNews.md")
rmarkdown::render("dataNews.md")
rmarkdown::render("workflowNEWS.md")


newSoft = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch = "RELEASE_3_19")
rmSoft = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18",currBranch="RELEASE_3_19", status="removed")
deprecatedSoft = setdiff(biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch = "devel",status="removed"),rmSoft)

newData = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch = "RELEASE_3_19", manifest="data-experiment.txt")
rmData = biocViews:::getPackageTitles(prevBranch="RELEASE_3_18", currBranch="RELEASE_3_19", manifest="data-experiment.txt", status="removed")
deprecatedData = setdiff(biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch ="devel",manifest="data-experiment.txt", status="removed"), rmData)

newWork = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch = "RELEASE_3_19", manifest="workflows.txt")
rmWork = biocViews:::getPackageTitles(prevBranch="RELEASE_3_18", currBranch="RELEASE_3_19", manifest="workflows.txt", status="removed")
deprecatedWork = setdiff(biocViews:::getPackageTitles(prevBranch ="RELEASE_3_18", currBranch = "devel",manifest="workflows.txt",status="removed"), rmWork)

newBook = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch = "RELEASE_3_19", manifest="books.txt")
rmBook = biocViews:::getPackageTitles(prevBranch="RELEASE_3_18", currBranch="RELEASE_3_19", manifest="books.txt", status="removed")
deprecatedBook = setdiff(biocViews:::getPackageTitles(prevBranch ="RELEASE_3_18", currBranch = "devel",manifest="books.txt",status="removed"), rmBook)

newAnn = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_18", currBranch = "RELEASE_3_19", manifest="data-annotation.txt")
rmAnn = biocViews:::getPackageTitles(prevBranch="RELEASE_3_18", currBranch="RELEASE_3_19", manifest="data-annotation.txt", status="removed")
deprecatedAnn = setdiff(biocViews:::getPackageTitles(prevBranch ="RELEASE_3_18", currBranch = "devel",manifest="data-annotation.txt",status="removed"), rmAnn)


sink("PackageOverview.txt")
cat("\n\nnewSoft:\n", length(newSoft), "\n\n",paste(sort(newSoft), collapse=", "))
cat("\n\nremovedSoft:\n",length(rmSoft),"\n\n",paste(sort(rmSoft), collapse=", "))
cat("\n\ndeprecatedSoft:\n",length(deprecatedSoft), "\n\n",paste(sort(deprecatedSoft), collapse=", "))

cat("\n\nnewData:\n",length(newData), "\n\n",paste(sort(newData), collapse=", "))
cat("\n\nremovedData:\n", length(rmData), "\n\n",paste(sort(rmData), collapse=", "))
cat("\n\ndeprecatedData:\n",length(deprecatedData), "\n\n",paste(sort(deprecatedData), collapse=", "))

cat("\n\nnewWorkflow:\n",length(newWork), "\n\n",paste(sort(newWork), collapse=", "))
cat("\n\nremovedWorkflow:\n", length(rmWork), "\n\n",paste(sort(rmWork), collapse=", "))
cat("\n\ndeprecatedWorkflow:\n", length(deprecatedWork), "\n\n",paste(sort(deprecatedWork), collapse=", "))

cat("\n\nnewAnnotation:\n",length(newAnn), "\n\n",paste(sort(newAnn), collapse=", "))
cat("\n\nremovedAnnotation:\n", length(rmAnn), "\n\n",paste(sort(rmAnn), collapse=", "))
cat("\n\ndeprecatedAnnotation:\n", length(deprecatedAnn), "\n\n",paste(sort(deprecatedAnn), collapse=", "))

cat("\n\nnewBook:\n",length(newBook), "\n\n",paste(sort(newBook), collapse=", "))
cat("\n\nremovedBook:\n", length(rmBook), "\n\n",paste(sort(rmBook), collapse=", "))
cat("\n\ndeprecatedBook:\n", length(deprecatedBook), "\n\n",paste(sort(deprecatedBook), collapse=", "))

sink()

biocViews:::getPackageDescriptions(newSoft, "newSoft.md", relativeLink=TRUE)
biocViews:::getPackageDescriptions(newData, "newData.md", relativeLink=TRUE)
biocViews:::getPackageDescriptions(newWork, "newWork.md", relativeLink=TRUE)
biocViews:::getPackageDescriptions(newAnn, "newAnn.md", relativeLink=TRUE)
biocViews:::getPackageDescriptions(newBook, "newBook.md", relativeLink=TRUE)



## when accessing directly on server we loose the file extension and will have
## to manually add esp those using .md/.Rmd extension
depmap
scpdata


## Software
statTarget

- always will display poorly include 2.0 section but package only at 1.25


## There are some software that will just be deleted as uninformative
## some will need minor formatting but not because of NEWS (spaces/overlines/etc)
