#!/bin/bash

DEBUG=1
VERBOSE=1
INSTALL_DIR=$HOME/testing


die() {
    echo "ERROR: (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*" >&2
    exit 2
}


log() {
    [[ $VERBOSE -ne 1 ]] && return
    echo "INFO (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*" >&2
}


warn() {
    echo "WARN (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*" >&2
}


set_var_in_script() {
    [[ $DEBUG -gt 0 ]] && set -x
    log "$*"
    [[ $# -lt 3 ]] && die "expected >=3 parameters, got '$#'"
    varname="$1"
    value="$2"
    shift 2
    sed -i "/^${varname}=/c\\${varname}=${value}" "$@"
}


[[ $DEBUG -gt 0 ]] && set -x

# Get install directory
BASE="$PUP_DEV_BASE" #environment var is best
[[ -z "$BASE" ]] && BASE=$(readlink -e $( dirname $0 ) ) # $0 is less reliable
[[ -z "$BASE" ]] && die "Empty base. Re-run with PUP_DEV_BASE env var."
# Double check install dir by looking for a known file
[[ -f "$BASE/bin/branches.sh" ]] || die "Unable to determine install dir. Try setting PUP_DEV_BASE env var."

# Find python3
PYTHON=$PY3_PATH #env var is best
[[ -z "$PYTHON" ]] && PYTHON=$(which python3) 2>/dev/null #system search is less reliable
[[ -z "$PYTHON" ]] && PYTHON=$(which python36) 2>/dev/null #system search is less reliable
[[ -z "$PYTHON" ]] && die "Unable to find Python3. Re-run with PY3_PATH env var."

# Verify python version 3
"$PYTHON" "$BASE/require-python-3.py" || die "Python version too low"

# Setup python virtual env
venvdir="$BASE/venv"
[[ -d "$venvdir" ]] || {
    "$PYTHON" -m venv "$venvdir"
    PIP="$BASE/venv/bin/pip"
    "$PIP" install --upgrade pip
    "$PIP" install -r "$BASE/requirements.txt"
}
V_PYTHON="$BASE/venv/bin/python"
[[ -x "$V_PYTHON" ]] || die 'Venv python is missing or not executable'
"$V_PYTHON" "$BASE/require-python-3.py" || die "Venv Python version too low"

# Create symlinks
find "$BASE/bin" -name '*.sh' \
| while read ; do
    ltgt=$( readlink -e "$REPLY" )
    fn_base=$( basename "$ltgt" '.sh' )
    lname="$INSTALL_DIR/$fn_base"

    # Update BASE in target shell script
    set_var_in_script BASE "$BASE" "$ltgt"

    # Create symlink
    ln -s "$ltgt" "$lname"
done
