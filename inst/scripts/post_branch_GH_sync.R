library(ReleaseLaunch)

## Update Bioconductor GH org repos
setwd("~/bioc/")
add_gh_release_branches(
    packages = packages_without_release_branch(
        version = "3.22",
        release = "RELEASE_3_22",
        org = "Bioconductor"
    ),
    release = "RELEASE_3_22",
    org = "Bioconductor"
)

## Example update of non-Bioconductor GH repos
setwd("~/gh/")
add_gh_release_branches(
    packages = packages_without_release_branch(
        version = "3.22",
        release = "RELEASE_3_22",
        org = "waldronlab"
    ),
    release = "RELEASE_3_22",
    org = "waldronlab"
)
