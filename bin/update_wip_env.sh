#!/bin/bash

### Create the puppet environment
### /etc/puppetlabs/code/environments/wip_<USERNAME> using contents of current
### working directories for each repo (control, hiera, legacy) for testing live
### changes without commit-push-deploy cycle.
###
### Note: <USERNAME> must be passed as a parameter on the cmdline

set -x 

PUPPET=/opt/puppetlabs/bin/puppet
ENVPATH=$( $PUPPET config print environmentpath )
R10K=/opt/puppetlabs/puppet/bin/r10k
# TODO this should come from "r10k deploy display"
declare -A REPO_TARGETS=( ['hiera']='data'
                          ['legacy']='legacy'
                        )

die() {
    echo "ERROR (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
    exit 2
}

log() {
    [[ $VERBOSE -ne 1 ]] && return
    echo "INFO (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*"
}


[[ $# -ne 1 ]] && die 'Missing username'
user=$1

base=$( getent passwd $user | cut -d: -f6 )/puppet
[[ -d "$base" ]] || die "Not a directory: '$base'"

# Copy control working contents
env="$ENVPATH/wip_${user}"
[[ -d "$env" ]] || mkdir -p "$env"
[[ -d "$env" ]] || die "Failed at 'mkdir -p $env'"
rsync -rlt "$base/control/" "$env/"

# Copy contents for remaining repos
for repo in "${!REPO_TARGETS[@]}"; do
    srcdir="$base/$repo"
    tgtdir="$env/${REPO_TARGETS[$repo]}"
    [[ -d "$tgtdir" ]] || mkdir -p "$tgtdir"
    [[ -d "$tgtdir" ]] || die "Failed at 'mkdir -p $tgtdir'"
    rsync -rlt "$srcdir/" "$tgtdir/"
done

# Install modules
pushd "$env"
"$R10K" puppetfile install -v notice
popd
