#!/bin/bash
# ReleaseLaunch/inst/scripts/sync_release.sh
# Synchronizes a Bioconductor package's GitHub repository with the Bioconductor git server.
#
# Usage: ./sync_release.sh <release_tag> <org> <package_name> [bioc_branch] [gh_branch]

set -e

RELEASE=$1
ORG=${2:-Bioconductor}
PKG=$3
BIOC_BRANCH=${4:-devel}
GH_BRANCH=${5:-devel}

if [ -z "$RELEASE" ] || [ -z "$PKG" ]; then
    echo "Usage: $0 <release_tag> <org> <package_name> [bioc_branch] [gh_branch]"
    exit 1
fi

echo "=========================================================="
echo "Working on: $PKG (Release: $RELEASE)"
echo "=========================================================="

# 1. Check if branch exists on GitHub
if gh api "repos/$ORG/$PKG/branches/$RELEASE" --silent 2>/dev/null; then
    echo "  Branch $RELEASE already exists on GitHub for $ORG/$PKG. Proceeding to sync..."
else
    echo "  Branch $RELEASE does not exist on GitHub for $ORG/$PKG. Will create..."
fi

# 2. Clone if needed
if [ ! -d "$PKG" ]; then
    echo "  Cloning git@github.com:$ORG/$PKG.git..."
    git clone "git@github.com:$ORG/$PKG.git"
fi

cd "$PKG"

# 3. Ensure we are on the correct GitHub branch
echo "  Checking out $GH_BRANCH..."
git checkout "$GH_BRANCH" || git checkout -b "$GH_BRANCH"

# 4. Pull origin
echo "  Pulling from origin..."
git pull --ff-only origin "$GH_BRANCH"

# 5. Add upstream if missing
if ! git remote | grep -q "upstream"; then
    echo "  Adding upstream remote..."
    git remote add upstream "git@git.bioconductor.org:packages/$PKG.git"
fi

# 6. Fetch specific branches from upstream
echo "  Fetching from upstream..."
git fetch upstream "$BIOC_BRANCH"
git fetch upstream "$RELEASE"

# 7. Merge upstream/devel into local devel (Fast-Forward only)
echo "  Merging upstream/$BIOC_BRANCH..."
git merge --ff-only "upstream/$BIOC_BRANCH"

# 8. Push devel to origin
echo "  Pushing $GH_BRANCH to origin..."
git push origin "$GH_BRANCH"

# 9. Sync or create release branch
if git show-ref --verify --quiet "refs/heads/$RELEASE"; then
    echo "  Syncing existing local release branch $RELEASE..."
    git checkout "$RELEASE"
    git merge --ff-only "upstream/$RELEASE"
else
    echo "  Creating local release branch $RELEASE..."
    git checkout -b "$RELEASE" "upstream/$RELEASE"
fi

echo "  Pushing $RELEASE to origin..."
git push -u origin "$RELEASE"

# 10. Restore default branch
git checkout "$GH_BRANCH"

echo "  Successfully processed $PKG"
echo ""
