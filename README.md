# [ReleaseLaunch](https://bioconductor.github.io/ReleaseLaunch/) <a href='https://bioconductor.github.io/ReleaseLaunch/'><img src='https://raw.githubusercontent.com/Bioconductor/BiocStickers/devel/ReleaseLaunch/ReleaseLaunch.png' alt='ReleaseLaunch sticker' class="logo" align="right" height="139" /></a>

<!-- badges: start -->
[![pkgdown](https://img.shields.io/badge/pkgdown-site-blue.svg)](https://bioconductor.github.io/ReleaseLaunch/)
[![Build and deploy site](https://github.com/Bioconductor/ReleaseLaunch/actions/workflows/build_site.yml/badge.svg)](https://github.com/Bioconductor/ReleaseLaunch/actions/workflows/build_site.yml)
<!-- badges: end -->

R utilities and documentation for Bioconductor release tasks.

`ReleaseLaunch` supports the Bioconductor core team during a release. It
hosts the release checklist and step-by-step how-tos, and provides R
functions that propagate a release to package repositories on GitHub, e.g.,
creating the `RELEASE_X_Y` branch from the Bioconductor git server and pushing
it to the `Bioconductor` organization.

## Installation

`ReleaseLaunch` is not distributed through Bioconductor. Install it from
GitHub with:

```r
if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
BiocManager::install("Bioconductor/ReleaseLaunch")
```

## Documentation

* [The Release Checklist](https://bioconductor.github.io/ReleaseLaunch/articles/ReleaseChecklist.html)
* How-tos:
  * [Version bump and branch](https://bioconductor.github.io/ReleaseLaunch/articles/Version-bump-and-branch-creation-HOWTO.html)
  * [Branch the annotation package repository](https://bioconductor.github.io/ReleaseLaunch/articles/Branch-annotation-repo-HOWTO.html)
  * [Flush the software repository](https://bioconductor.github.io/ReleaseLaunch/articles/Flush-Packages-HOWTO.html)
* [Function reference](https://bioconductor.github.io/ReleaseLaunch/reference/)

## Functions

| Task | Functions |
|------|-----------|
| Release version from the Bioconductor config | `bioc_version_yaml()`, `bioc_release_yaml()` |
| Create `RELEASE_X_Y` branches on GitHub | `add_gh_release_branches()`, `add_gh_release_branch()` |
| Find repositories that need the release branch | `packages_without_release_branch()`, `packages_with_release_branch()` |
| List packages and GitHub repositories | `get_bioc_software_manifest()`, `get_org_packages()`, `get_org_github_repos()`, `get_user_github_repos()` |
| Clone or update local repositories | `sync_repos()`, `sync_repo()`, `update_local_repos()`, `update_local_repo()` |
| Configure `origin` / `upstream` remotes | `set_bioc_remotes()`, `add_bioc_remote()` |
| Compile NEWS for the release announcement | `getPackagesNEWS()`, `printNEWS()`, `extractNEWS()` |

## Usage

Functions that write to GitHub need a Personal Access Token (PAT) with access
to the organization; see section F4 of the
[version bump and branch how-to](https://bioconductor.github.io/ReleaseLaunch/articles/Version-bump-and-branch-creation-HOWTO.html).
Store it with:

```r
gitcreds::gitcreds_set()
```

Add the release branch to all `Bioconductor` organization repositories that
are Bioconductor packages and lack it (repositories are cloned into the
current working directory):

```r
library(ReleaseLaunch)

add_gh_release_branches(release = bioc_release_yaml(), org = "Bioconductor")
```

or to a single package:

```r
add_gh_release_branch(
    package_name = "BiocParallel", release = bioc_release_yaml()
)
```

Clone, or update, local copies of packages with GitHub as `origin` (when the
repository exists there) and the Bioconductor git server as `upstream`:

```r
sync_repos(c("S4Vectors", "IRanges"), dest_dir = "~/bioc", org = "Bioconductor")
```

## Contributing

Report issues at <https://github.com/Bioconductor/ReleaseLaunch/issues>.
