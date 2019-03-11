#!/usr/bin/bash

BASE=/usr/local/src/branches
PYTHON="${BASE}/venv/bin/python"

# git repos names (ie: r10k sources)
# Format is space separated words in a string
# If set here, this value overrides any others
# If unset here, attempt to get sources from r10k
#export REPO_NAMES='control hiera legacy'

# branch names that topics merge into
# Show merge status reletive to these "reference" branches
# Format is space separated words in a string
export REFERENCE_NAMES='production test'

# Topic branches are identified by looking for this keyword in the topic name
# If branch name does not have this keyword it it, that branch will be excluded
# from the report
export TOPIC_KEYWORD='topic'

"$PYTHON" "$BASE/bin/branches.py"
