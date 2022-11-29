library(biocViews)

## src only used if local checkout of repositories (preferred becasue:
## when accessing directly on server we loose the file extension and will have
## to manually add)


softNEWS = getPackageNEWS("3.14", "3.15", repo="bioc", srcdir="/home/shepherd/BioconductorPackages/Software")
dataNEWS = getPackageNEWS("3.14", "3.15", repo="data/experiment")
WFNEWS = getPackageNEWS("3.14", "3.15",repo="workflows",srcdir="/home/shepherd/BioconductorPackages/Workflows")

printNEWS(softNEWS, "softwareNews.md", relativeLink=TRUE, overwrite=TRUE)
printNEWS(dataNEWS, "dataNews.md", relativeLink=TRUE, overwrite=TRUE)
printNEWS(WFNEWS, "workflowNEWS.md", relativeLink=TRUE, overwrite=TRUE)





newSoft = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_14", currBranch = "RELEASE_3_15")
rmSoft = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_14",currBranch="RELEASE_3_15", status="removed")
deprecatedSoft = setdiff(biocViews:::getPackageTitles(prevBranch = "RELEASE_3_15", currBranch = "master",status="removed"),rmSoft)

newData = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_14", currBranch = "RELEASE_3_15", manifest="data-experiment.txt")
rmData = biocViews:::getPackageTitles(prevBranch="RELEASE_3_14", currBranch="RELEASE_3_15", manifest="data-experiment.txt", status="removed")
deprecatedData = setdiff(biocViews:::getPackageTitles(prevBranch = "RELEASE_3_14", currBranch ="master",manifest="data-experiment.txt", status="removed"), rmData)

newWork = biocViews:::getPackageTitles(prevBranch = "RELEASE_3_14", currBranch = "RELEASE_3_15", manifest="workflows.txt")
rmWork = biocViews:::getPackageTitles(prevBranch="RELEASE_3_14", currBranch="RELEASE_3_15", manifest="workflows.txt", status="removed")
deprecatedWork = setdiff(biocViews:::getPackageTitles(prevBranch ="RELEASE_3_14", currBranch = "master",manifest="workflows.txt",status="removed"), rmWork)


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
sink()

biocViews:::getPackageDescriptions(newSoft, "newSoft.md", relativeLink=TRUE)
biocViews:::getPackageDescriptions(newData, "newData.md", relativeLink=TRUE)
biocViews:::getPackageDescriptions(newWork, "newWork.md", relativeLink=TRUE)




## when accessing directly on server we loose the file extension and will have
## to manually add esp those using .md/.Rmd extension
depmap
scpdata


## Software
statTarget

- always will display poorly include 2.0 section but package only at 1.25


## There are some software that will just be deleted as uninformative
## some will need minor formatting but not because of NEWS (spaces/overlines/etc)
