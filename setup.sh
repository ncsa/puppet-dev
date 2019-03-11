#!/bin/bash

DEBUG=1
VERBOSE=1
BIN=/usr/local/bin


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
BASE="$BR_INSTALL_DIR" #environment var is best
[[ -z "$BASE" ]] && BASE=$(readlink -e $( dirname $0 ) ) # $0 is less reliable
[[ -z "$BASE" ]] && die "Empty base. Re-run with BR_INSTALL_DIR env var."
# Double check install dir by looking for a known file
[[ -f "$BASE/branches.sh" ]] || die "Unable to determine install dir. Try setting BR_INSTALL_DIR env var."

# Find python3
PYTHON=$BR_PY3_PATH #env var is best
[[ -z "$PYTHON" ]] && PYTHON=$(which python3) 2>/dev/null #system search is less reliable
[[ -z "$PYTHON" ]] && die "Unable to find Python3. Re-run with BR_PY3_PATH env var."

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

# Update path in bash wrapper script
set_var_in_script BASE "$BASE" "$BASE/branches.sh"

# Create symlinks
ltgt="$BASE/branches.sh"
lname="$BIN/branches"
if [[ $EUID -eq 0 ]] ; then
    ln -s "$ltgt" "$lname"
else
    warn "Non-root user: skipping create symlink '$lname'"
fi
