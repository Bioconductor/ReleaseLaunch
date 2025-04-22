---
name: Bioconductor Release
about: Create a release checklist
title: ''
labels: 'release'
assignees: ''
---

Some important operations that need to happen before a BioC release,
in _this_ order

## 6-8 weeks before

- [ ] Draft and Announce Release Schedule

- [ ] Announce new package submission deadline and last day to pass submission process

- [ ] Start building annotations (db0, orgDb, TxDb) and announce when available
  in devel

- [ ] Update AnnotationForge and inst/exdata/viableIds.rda (needed for hub
  nonstandard org generation)

- [ ] Update GenomeInfoDbData data/specData.rda (needed for hub
  nonstandard org generation)

- [ ] Update GenomeInfoDb mapping table between UCSC and ensembl
      http://useast.ensembl.org/info/website/archives/assembly.html
      

- [ ] Identify and warn people with bad NEWS files

- [ ] Warn people of package ERRORs/Deprecation

- [ ] Consider more frequent devel BBS auto notifications

- [ ] Send reminder that contributed annotations are due by api feature freeze
  date and absolute latest new package submission process deadline

- [ ] After OrgDb and TxDb are in devel repo, add to annotationhub

- [ ] Add NonStandard OrgDbs to AnnotationHub

- [ ] Announce new package submission deadline has been reached


## 4-5 weeks before

- [ ] Announce to community a reminder for packages to pass build/check without
  error, devel feature freeze, and current release freeze 

## Three weeks before

- [ ] Announce deprecated packages

- [ ] Announce feature api freeze and remind about release freeze

- [ ] **Flush to-be-release repo**


## 2 weeks before

- [ ] Announce last build of Bioc release and repo is frozen.

- [ ] Update remove-packages.md on website

- [ ] Update packages.conf in gito-lite for removed packages

- [ ] Disable commits to old release branch. See scripts/sedCommandsForVariousTasks.txt

- [ ] After the last build report for old relase is online, stop the old
release builds.

- [ ] Update <https://bioconductor.org/checkResults/> by moving the old release
to the top of the "Archived results for past release" section.

- [ ] Create the manifest files for new devel and remove the deprecated packages
BEFORE the first build. (reminder any newly accepted packages need to get added
to both manifests)

- [ ] Ensure to-be-release machine uses new RELEASE_X_Y manifest

* As part of the bump and branch process, the
`BBS_BIOC_MANIFEST_GIT_BRANCH` variable on the release builder will be modified
to point to the correct manifest. This variable is defined in the `config.sh`
and `config.bat` files located in the `~biocbuild/BBS/3.6/bioc/` and
`~biocbuild/BBS/3.6/data-experiment/` folders. For now, packages must still be
built off their devel branch so do **NOT** touch the `BBS_BIOC_GIT_BRANCH`
variable!

- [ ] Install latest biocViews on biocpush account on to-be-release master
builder. 

- [ ] Start setting up new devel builders and repositories. coordinate that
  manifest has been updated to have deprecated packages removed before devel
  builders start propagting any products.

- [ ] Make sure that the R that runs as biocpush is current, has the
  most current biocViews and that 'knitcitations' is installed.
  
  **Note**: Simlinks to old devel:
  
  Until the next devel builds are running, we want symlinks pointing to the old
  devel builds so that the BiocManager package will work. This includes the
  software, data/annotation, and data/experiment repositories.  Remove these
  symlinks when the builds start running.

- [ ] Add links to checkResults page for new devel builds

- [ ] Confirm build report for new devel builds is intact

- [ ] Update NEWS files

- [ ] Announce release candidate no large changes to repos

## 1 week before

- [ ] Remind community of upcoming deadlines of last day to commit changes and freeze
  before branching. If NEWS is not updated it will not be included in release
  announcement

- [ ] Reminder last day for packages to pass build/check

- [ ] Last Day for new packages to be added to the release manifest

- [ ] Identify and fix packages with bad DESCRIPTION

- [ ] Identify and fix packages with easily fixable bad NEWS 

- [ ] Update BBS doc for version bump and branch to reflect new RELEASE_X_Y in
  the document.

- [ ] Refer to document to find out more preliminary steps (e.g set up account
  on builders for bump and branch)


## Day before we branch (D-2):

- [ ] Announce last day to commit changes before branching

## Day we branch (D-1):

- [ ] Send mail to bioc-devel to ask people to stop commits until
further notice so we can create the devel branches (software and data
experiment). The bump and branch took about 2 hours.

- [ ] Add bump and branch executers to admin group on gitolite.conf

- [ ] Block commits using gitolite/admin/conf/gitlite.conf. (see
  scripts/sedCommandsForVariousTasks.txt)
 
- [ ] Disable hooks to allow bump and branch (see
  scripts/sedCommandsForVariousTasks.txt)
  
- [ ] Bump versions and create BioC release branch
https://github.com/Bioconductor/ReleaseLaunch/blob/devel/vignettes/Version-bump-and-branch-creation-HOWTO.Rmd

- [ ] Modify BBS_BIOC_GIT_BRANCH to point the 3.21 builds (software, data
  experiment, workflows, and books) to the RELEASE_3_21 branch in git.

- [ ] Confirm MEAT0 is pointed at the correct manifest for the release and devel
branches.

- [ ] Update gitolite authorization files to give maintainers R/W
access to their package in the new branch. see
scripts/sedCommandsForVariousTasks.txt)

- [ ] Confirm new branch can be checkout from a location other than
  the machine used to create the branch (i.e., your local system).

- [ ] Announce the creation of the new branch and that commits can
  resume. Clarify the difference between the new branch and devel.

- [ ] Confirm defunct packages have been removed from manifest.

- [ ] BiocManager: Update R version dependency in devel version of BiocVersion.

- [ ] Run the builds ...

- [ ] Sync bioc github packages with git.bioconductor.org

- [ ] Send email to mirrors to adjust their rsyncs within 2 weeks when we will
  move to archive on OSN

## Release day

- [ ] Start generating release announcement 

- [ ] bioconductor.org/config.yaml

Update config.yaml in the root of the bioconductor.org working copy and
change values as indicated in the comments. This will (among other things),
automatically update the website symlinks ("release" and "devel") under
/packages.
  
**Note**

If there is no annotation branch, that line under 'devel_repos' must be
commented out; if any of annotation, experiment data or software are not
available (and a simlink makes them unavailable) the script will break and
landing pages will not be generated. If using symlinks, mark as unavailable or
else will destroy symlinked directory!

After a release you should let the no-longer-release version build one last
time so package landing pages won't say "release version".

- [ ] rsync on devel

  UPDATE the /etc/rsyncd.conf on master.bioconductor.org and
  restart rsync.

  ```sh
      sudo systemctl restart rsync
  ```

  Test rsync is still working as expected with commands from:
  http://www.bioconductor.org/about/mirrors/mirror-how-to/.

- [ ] mirrors/enable archiving for bioc in apache config

  The mirror instructions on the website will be updated
  automatically when config.yaml is updated.

  The apache config files need to updated by hand. Add a new
  (copy-paste) section at the top for the new release number in
  these 2 files:

  ```sh
      /etc/apache2/sites-available/000-default.conf
      /etc/apache2/sites-available/default-ssl.conf
  ```

**Note** 

It couldn't hurt to restart the Apache server:
  
```sh
    sudo service apache2 restart
```

  Test the mirrors with commands from:
  http://www.bioconductor.org/about/mirrors/mirror-how-to/.
  In a test directory the following should produce correct results
  
  ```sh
      rsync -zrtlv --delete master.bioconductor.org::devel/bioc . 
      rsync -zrtlv --delete master.bioconductor.org::release/bioc . 
  ```

- [ ] Enable archiving in Apache config

- [ ] Update checkResults page and symlinks ("release" and "devel") under
  checkResults/.

Website updates:

- [ ] Update build report index page and symlinks; remove "devel"
  background image from report.css (if there is one).

- [ ] Put release announcement on web and add to pages which contain
  links to all release announcements (/about/release-announcements
  and **/layouts/_release_announcements.html**). Put today's
  date at the top of the web version of the release
  announcement.

- [ ] Add the last release version to the list of 'Previous Versions'
  (layouts/_bioc_older_packages.html). **DON'T FORGET THIS!**

- [ ] Update link to release announcement on main index page

- [ ] Update number of packages on main index page

- [ ] Add "Disallow: /packages/XX/" to the web site's robots.txt file
  where XX is the new devel version (one higher than the version)
  that was just released.  (on master)

- [ ] `BiocManager::install()` sanity check

  Was BiocManager installed / updated properly? With a fresh R devel and
  release

  ```r
      install.packages("BiocManager")
  ```

- [ ] Once builds post and products are pushed to master, check new landing
  pages for updated versions

- [ ] Compare number of packages in announcement with manifest file

- [ ] Finalize release announcement

- [ ] Announce the release

- [ ] Social media posts with link to the release announcement

- [ ] Update Wikipedia page for Bioconductor

- [ ] Go for a beer.

## Post-release

### Week after the Release (D+):

- [ ] Confirm Archive/ folder is working for new release.
  The relevant script is BBS/utils/list.old.packages.R
  which depends on BiocManager to determine if
  archiving should happen. Example location to look:

  ```sh
      biocpush@nebbiolo1:~$ ls PACKAGES/3.15/bioc/src/contrib/Archive/
  ```

- [ ] Branch Annotations and put backup into S3 bucket

- [ ] Build dockers for new release and devel for Bioc and AnVIL

- [ ] Update SPB and clean sqlite file

- [ ] ID packages for deprecation

- [ ] Follow up on Hub submissions to ensure packages submitted/accepted

- [ ] Move legacy release build products off master and into AWS/OSN. Only
active release and devel on master

- [ ] Update books/release/index.md
