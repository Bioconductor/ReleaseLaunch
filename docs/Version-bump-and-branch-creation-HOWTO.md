# Version-bump-and-branch-creation-HOWTO


## A. Introduction

On the day prior to the release, we will need to apply and push the following
changes to all the Bioconductor packages that go in the release, **in this
order**:

- **First version bump**: bump x.y.z version to even y **in the `master`
  branch**
- **Branch creation**: create the release branch
- **Second version bump**: bump x.y.z version to odd y **in the `master`
  branch**

For example, for the BioC 3.16 release, we will need to do this for all
the packages listed in the `software.txt`, `data-experiment.txt`,
`workflows.txt`, and `books.txt` files of the `RELEASE_3_16` branch
of the `manifest` repo.

Note that there are some exceptions:

- The BiocVersion package (software package): This package will only need
  the new branch and a simple y -> y + 1 version bump.

- The data-annotation packages: For these packages we will create the new
  branch but we won't bump versions.

We'll use Python script `bump_version_and_create_branch.py` to apply and
push these changes. This will need to be done on the day prior to the release
before the BioC 3.16 builds start for software, data-experiment, workflow, and
book packages.

Look for the prerun jobs in the crontab for the `biocbuild` user on the main
BioC 3.16 builder to get the times the software and data-experiment builds get
kicked off. Make sure to check the crontab again a couple of days before the
release as we sometimes make small adjustments to the crontabs on the build
machines.  Also be sure to translate to your local time if you are not on the
East Coast.


## B. Preliminary steps

These steps should be performed typically a couple of days before the steps
in sections **C.** and **D.**.

* Update this document to reflect the BioC version to be released i.e.
  replace all occurrences of `3.16` and `RELEASE_3_16` with appropriate
  version. This will avoid potentially disastrous mistakes when
  copying/pasting/executing commands from this document.

* Choose a Linux machine with enough disk space to clone all the software,
  data-experiment, workflow, and book packages (as of October 2021, the total
  size of all the package clones is about 122G). The machine needs to have
  the `git` client and Python. The procedure described here doesn't require
  `sudo` privileges.
  Make sure to pick up a machine that has fast and reliable internet access.
  The Linux build machines are a good choice. If you want to use one of
  them, use your personal account or the `biocpush` account. Do NOT use
  the `biocbuild` account to not interfere with the builds. Using a Mac
  server might work but was not tested.

* Make sure to use the `-A` flag to enable forwarding of the authentication
  agent connection when you `ssh` to the machine e.g.:

      ssh -A hpages@malbec1.bioconductor.org

* Clone (or update) the `BBS` git repo:

      # clone
      git clone https://github.com/Bioconductor/BBS
      # update
      cd ~/BBS
      git pull

* Create the `git.bioconductor.org` folder:

      mkdir git.bioconductor.org

* Populate `git.bioconductor.org` with git clones of the `manifest` repo
  and all the package repos (software, data-annotation, data-experiment,
  workflows, and books).
  This takes more than 3h so is worth doing in advance e.g. a couple of days
  before the release. It will save time when performing the steps described
  in sections **C.**, **D.**, and **E.** below on the day prior to the release.

      export BBS_HOME="$HOME/BBS"

      # clone `manifest` repo
      $BBS_HOME/utils/update_bioc_git_repos.py manifest RELEASE_3_16

      # clone software package repos (takes approx. 1h20)
      time $BBS_HOME/utils/update_bioc_git_repos.py software master RELEASE_3_16

      # clone data-annotation package repos (takes a couple of minutes)
      time $BBS_HOME/utils/update_bioc_git_repos.py data-annotation master RELEASE_3_16

      # clone data-experiment package repos (takes approx. 1h50)
      time $BBS_HOME/utils/update_bioc_git_repos.py data-experiment master RELEASE_3_16

      # clone workflow package repos (takes approx. 4 min)
      time $BBS_HOME/utils/update_bioc_git_repos.py workflows master RELEASE_3_16

      # clone book repos (takes < 1 min)
      time $BBS_HOME/utils/update_bioc_git_repos.py books master RELEASE_3_16

* Make sure you can push changes to the BioC git server (at
  git.bioconductor.org):

      # check config file
      cat ~/.gitconfig

      # make any necessary adjustment with
      git config --global user.email "you@example.com"
      git config --global user.name "Your Name"

      # also make sure to set push.default to matching
      git config --global push.default matching

      # check config file again
      cat ~/.gitconfig

      # try to push
      cd ~/git.bioconductor.org/software/affy
      git push  # should display 'Everything up-to-date'

* Clone (or update) the `bioc_git_transition` git repo:

      # clone
      git clone https://github.com/Bioconductor/bioc_git_transition
      # update
      cd ~/bioc_git_transition
      git pull

* Find packages with duplicate commits

    Historically the GIT-SVN mirror was the primary source of duplicate commits.
    Since the transition to git, we should not be seeing many new duplicates.
    Additionally, we've implemented a gitolite hook to prevent any new
    duplicate commits from getting through. For these reasons, this check for
    duplicates is becoming obsolete and can probably be removed at the next
    release in Spring 2019.
    ```
    # Local copy of bioc_git_transition
    export BIOC_GIT_TRANSITION="$HOME/bioc_git_transition"
    
    # software packages
    export WORKING_DIR="$HOME/git.bioconductor.org/software"
    export MANIFEST_FILE="$HOME/git.bioconductor.org/manifest/software.txt"
    cd $WORKING_DIR
    pkgs_in_manifest=`grep 'Package: ' $MANIFEST_FILE | sed 's/Package: //g'`
    
    # Check last 30 commits in each package (like the duplicate commits hook
    # does):
    for pkg in $pkgs_in_manifest; do
        echo ""
        echo ">>> check $pkg package for duplicate commits"
        python3 $BIOC_GIT_TRANSITION/misc/detect_duplicate_commits.py $pkg 30
    done > duplicatecommits.out 2>&1
    ```

* Anyone involved in the "bump and branch" procedure should temporarily
  be added to the `admin` group in `gitolite-admin/conf/gitolite.conf`.
  Membership in this group enables the creation of a new branch and
  _pushing_ to any branch regardless of inactivated (commented out) lines
  in `gitolite-admin/conf/packages.conf`.


## C. Version bumps and branch creation for software packages

Perform these steps on the day prior to the release. They must be completed
before the software builds get kicked off (see **A. Introduction**). The full
procedure should take about 2.5 hours. Make sure to reserve enough time.

### C1. Ask people to stop committing/pushing changes to the BioC git server

Announce or ask a core team member to announce on the bioc-devel mailing
list that people must stop committing/pushing changes to the BioC git server
(git.bioconductor.org) for the next 2.5 hours.

### C2. Modify packages.conf to block all commits

The `RELEASE_3_15` lines in `gitolite-admin/conf/packages.conf` were commented
out when the release builds were frozen. At this point, only the `master`
lines are still active.

Deactivate all push access by commenting out the `master` lines in
`gitolite-admin/conf/packages.conf`.

NOTE: Do not change the branch from RELEASE_3_15 to RELEASE_3_16, it is
not a good solution. Maintainers now will be able to push their own
RELEASE_3_16 branch before we are able to create it at release
time. This issue reflects the issue
https://stat.ethz.ch/pipermail/bioc-devel/2019-May/015048.html.

Using vim, it is possible with a one liner,

       :g/RW master/s/^/#

Or Lori created sed commands see scripts/sedCommandsForVariousTasks.txt

Once `packages.conf` is updated, push to `gitolite-admin` on the git server
to make the changes effective.

### C3. Disable hooks

Log on to git.bioconductor.org as the `git` user.

- Comment out the hook lines in `packages.conf`.

- Remove the `pre-receive.h00-pre-receive-hook-software` file from the
  `hook/` directory in each package, e.g.,
  `/home/git/repositories/packages/<PACKAGE>.git/hooks`
    ```
    rm -rf ~/repositories/packages/*.git/hooks/pre-receive.h00-pre-receive-hook-software
    ```

Or (trying as of release 3.16) try using hooks exclusion file. See
scripts/sedCommandsForVariousTasks.txt. This changes is made in the
hook_maintainer repo. 


### C4. Login to the machine where you've performed the preliminary steps

Make sure to use the `-A` flag to enable forwarding of the authentication
agent connection e.g.:

    ssh -A hpages@malbec1.bioconductor.org

See **B. Preliminary steps** above for the details.

### C5. Checkout/update the `RELEASE_3_16` branch of the `manifest` repo

    cd ~/git.bioconductor.org/manifest
    git pull --all
    git checkout RELEASE_3_16
    git branch
    git status

### C6. Set the `BBS_HOME`, `WORKING_DIR` and `MANIFEST_FILE` environment variables

- `BBS_HOME`:
    ```
    export BBS_HOME="$HOME/BBS"
    ```

IMPORTANT NOTE: The settings for `WORKING_DIR` and `MANIFEST_FILE` are
specific to the type of packages. The following settings are for the
_software_ packages. Make sure to adapt for data-experiment packages,
workflows, and books.

- `WORKING_DIR`: Point `WORKING_DIR` to the folder containing the software
  packages:
    ```
    export WORKING_DIR="$HOME/git.bioconductor.org/software"
    ```
  All the remaining steps in section **C.** must be performed from _within_
  this folder:
    ```
    cd $WORKING_DIR
    ```

- `MANIFEST_FILE`: Point `MANIFEST_FILE` to the manifest file for software
  packages. This must be the file from the `RELEASE_3_16` branch of
  the `manifest` repo:
    ```
    export MANIFEST_FILE="$HOME/git.bioconductor.org/manifest/software.txt"
    ```

### C7. Run `bump_version_and_create_branch.py`

We're going to run the script on all the software packages. It will take care
of applying and pushing the changes described in **A. Introduction**.

    cd $WORKING_DIR
    pkgs_in_manifest=`grep 'Package: ' $MANIFEST_FILE | sed 's/Package: //g'`
    
    $BBS_HOME/utils/bump_version_and_create_branch.py --push RELEASE_3_16 $pkgs_in_manifest >bump_version_and_create_branch.log 2>&1 &

The `bump_version_and_create_branch.py` run above can be replaced with
a 2-pass run:

    # First pass (apply all the changes but do NOT push them):
    $BBS_HOME/utils/bump_version_and_create_branch.py RELEASE_3_16 $pkgs_in_manifest >bump_version_and_create_branch.log1 2>&1 &
    # Second pass (push all the changes):
    $BBS_HOME/utils/bump_version_and_create_branch.py --push RELEASE_3_16 $pkgs_in_manifest >bump_version_and_create_branch.log2 2>&1 &

The 2-pass run can be useful if one wants to inspect the changes before pushing them.

Notes:

* You can follow progress with `tail -f bump_version_and_create_branch.log`.

* The BiocVersion package will automatically receive special treatment.

* In the 2-pass run, the second pass checks the packages and applies the
  changes only if needed (i.e. if a package does not already have the
  `RELEASE_3_16` branch) before pushing the changes.

* If for some reason the `bump_version_and_create_branch.py` script stops
  prematurly, it can be safely re-run with the same arguments. This is
  because the script only does things to packages that need treatment.
  Packages that were already successfully treated will no longer be touched.

* A typical error is `Error: duplicate commits` (happened for affyPLM and
  Rdisop first time I tested this). Report these errors to `gitolite`
  experts Lori or Jen. Once the problem is fixed, re-run the script.

### C8. Check `bump_version_and_create_branch.log`

After completion of the `bump_version_and_create_branch.py` run,
open `bump_version_and_create_branch.log` and make sure everything
looks ok.


## D. Version bumps and branch creation for data-experiment packages, workflows, and books

### Data-experiment packages

Repeat steps C5 to C8 above **but for C6 define the environment variables
as follows**:

    export WORKING_DIR="$HOME/git.bioconductor.org/data-experiment"
    export MANIFEST_FILE="$HOME/git.bioconductor.org/manifest/data-experiment.txt"

### Workflows

Repeat steps C5 to C8 above **but for C6 define the environment variables
as follows**:

    export WORKING_DIR="$HOME/git.bioconductor.org/workflows"
    export MANIFEST_FILE="$HOME/git.bioconductor.org/manifest/workflows.txt"

### Books

Repeat steps C5 to C8 above **but for C6 define the environment variables
as follows**:

    export WORKING_DIR="$HOME/git.bioconductor.org/books"
    export MANIFEST_FILE="$HOME/git.bioconductor.org/manifest/books.txt"


## E. Branch creation for data-annotation packages

Note that for data-annotation packages we **create the new branch WITHOUT
BUMPING VERSIONS**.

Repeat steps C5 to C8 above **but for C6 define the environment variables
as follows**:

    export WORKING_DIR="$HOME/git.bioconductor.org/data-annotation"
    export MANIFEST_FILE="$HOME/git.bioconductor.org/manifest/data-annotation.txt"

Then for C7, **make sure to call the `bump_version_and_create_branch.py`
script with the `--no-bump` option**:

    cd $WORKING_DIR
    pkgs_in_manifest=`grep 'Package: ' $MANIFEST_FILE | sed 's/Package: //g'`
    
    $BBS_HOME/utils/bump_version_and_create_branch.py --no-bump --push RELEASE_3_16 $pkgs_in_manifest >bump_version_and_create_branch.log 2>&1 &


## F. Finishing up

### F1. Enable push access to new `RELEASE_3_16` branch

This is done by editing the `conf/packages.conf` file in the `gitolite-admin`
repo (`git clone git@git.bioconductor.org:gitolite-admin`).

- If not done already, replace all instances of `RELEASE_3_15` with
  `RELEASE_3_16`.

- Uncomment all `RELEASE_3_16` and `master` lines.

See scripts/sedCommandsForVariousTasks.txt for help on re-enabling access


- If using hooks exclusion file for allowing version bump. Restore original
  hooks file. 

- Run `gitolite setup` from /home/git/repositories to re-enable the hooks.

- Test that a non-super user can push access is enabled onthe dummy package
  BiocGenerics_test.

Check:

    git push
    git checkout RELEASE_3_16
    git pull

### F2. Tell people that committing/pushing to the BioC git server can resume

Announce or ask a core team member to announce on the bioc-devel mailing list
that committing/pushing changes to the BioC git server (git.bioconductor.org)
can resume.

### F3. Switch `BBS_BIOC_GIT_BRANCH` from `master` to `RELEASE_3_16` on main BioC 3.16 builder

DON'T FORGET THIS STEP! Its purpose is to make the BioC 3.16 builds grab the
`RELEASE_3_16` branch of all packages instead of their `master` branch.

Login to the main BioC 3.16 builder as `biocbuild` and replace

    export BBS_BIOC_GIT_BRANCH="master"

with

    export BBS_BIOC_GIT_BRANCH="RELEASE_3_16"

in `~/BBS/3.16/config.sh`

Also replace

    set BBS_BIOC_GIT_BRANCH=master

with

    set BBS_BIOC_GIT_BRANCH=RELEASE_3_16

in `~/BBS/3.16/config.bat`

Then remove the `manifest` and `MEAT0` folders from `~/bbs-3.16-bioc/`,
`~/bbs-3.16-data-annotation/`, `~/bbs-3.16-data-experiment/`,
`~/bbs-3.16-workflows/`, and `~/bbs-3.16-books/`. They'll get automatically
re-created and re-populated when the builds start.

### F4. Update all core Bioconductor packages hosted on GitHub

The Bioconductor organization on GitHub hosts repositories that may also be
packages in Bioconductor. To identify and update these packages with the latest
version bump from a Bioconductor release, use the `ReleaseLaunch` R package at
<https://github.com/Bioconductor/ReleaseLaunch>.

First, create a fine-grained Personal Access Token (PAT) under User >
Settings > Developer Settings > PATs > Fine-grained tokens.

When generating a new token, be sure to select `Bioconductor` as the resource
owner and to select 'All repositories' and then under 'Repository permissions' >
Content > 'Read and Write'.
Add this as the `GITHUB_PAT` variable in the `~/.Renviron` file.
	
This will work only if the user has admin access to the Bioconductor
organization on GitHub.

To update all packages, run the following command:

    update_all_packages(release = "RELEASE_3_16", org = "Bioconductor")
	
Be sure to edit the `release` argument in the function.
	
To update an individual package, run the following function:

    clone_and_push_git_repo(
       package_name = "updateObject", release = "RELEASE_3_16", gh_branch = "master"
    )

Note that the `gh_branch` corresponds to the default branch on GitHub. On some
repositories, the `gh_branch` can be `devel`.

Packages will be cloned into the current working directory.
