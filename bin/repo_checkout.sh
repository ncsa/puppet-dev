#!/bin/bash

### Checkout the specified branch in each repo (control, hiera, legacy)
### For each repo without a matching branch, checkout "production" instead.

REPONAMES=( control hiera legacy )
PUPDIR="$HOME/puppet"

die() {
    echo "ERROR: (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*" 1>&2
    exit 1
}


[[ $# -ne 1 ]] && die "Expected 1 argument, got '$#'"
topic="$1"

for repo in "${REPONAMES[@]}"; do
    repodir="$PUPDIR/$repo"
    branch=production
    git --git-dir "$repodir/.git" branches -a \
    | grep -q -- "$topic" \
    && branch="$topic"
    pushd "$repodir"
    git checkout "$branch" \
    && git pull \
    || die "failed to checkout branch '$branch' in repo '$repo'"
    popd
done
