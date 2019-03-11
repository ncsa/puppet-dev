#!/bin/bash

### Show current branch for each of multiple repos

REPONAMES=( control hiera legacy )
REPOCOLORS=( 7 6 208 )
PUPDIR="$HOME/puppet"


die() {
    echo "ERROR: (${BASH_SOURCE[1]} [${BASH_LINENO[0]}] ${FUNCNAME[1]}) $*" 1>&2
    exit 1
}


get_max_length() {
    declare -a ary=($"${!1}")
    for x in "${ary[@]}"; do echo "$x"; done | wc -L
}


pr_hdr() {
    text="$1"
    clr=$2
    [[ -z "$clr" ]] && clr=7
    printf "\e[30;48;5;${clr}m%s\e[0m" "$text"
}

center() {
    text="$1"
    width=$2
    char="$3"
    [[ -z "$char" ]] && char=' '
    filler="$(printf '%0.1s' "$char"{1..20})"
    fill_len=$(bc <<< "($width-${#text})/2")
    xtra_len=$(bc <<< "($width-${#text})%2")
    fill="$(printf '%0.*s' $fill_len "$filler" )"
    xtra="$(printf '%0.*s' $xtra_len "$filler" )"
    echo "$xtra$fill$text$fill"
}


pr_state() {
    clr=39
    case "$1" in
        clean)
            clr=32
            ;;
        dirty)
            clr=31
            ;;
        * )
            die "unknown state"
            ;;
    esac
    printf "\e[${clr}m${1}\e[0m"
}


# Get current branch names
branches=()
for repo in "${REPONAMES[@]}"; do
    branches+=( $( git --git-dir "$PUPDIR/$repo/.git" branches \
    | sed -ne 's/^* // p' ) )
done
#for b in "${branches[@]}"; do echo "$b"; done
#exit 1

# Get clean/dirty status
clean_dirty=()
for repo in "${REPONAMES[@]}"; do
    pushd "$PUPDIR/$repo" &>/dev/null
    state=clean
    dirty_count=$( git status --porcelain \
    | grep -E '^( ?[M\?])' \
    | wc -l )
    [[ $dirty_count -gt 0 ]] && state=dirty
    clean_dirty+=( "$state" )
    popd &>/dev/null
done
#for x in "${clean_dirty[@]}"; do echo $x; done
#exit 1

longest_hdr=$( get_max_length REPONAMES[@] )
let "hdr_len=$longest_hdr + 2"
br_len=$( get_max_length branches[@] )
let end="${#REPONAMES[*]}-1"
for i in $(seq 0 $end); do

    # get parts
    reponame=${REPONAMES[$i]}
    br_name="${branches[$i]}"
    color=${REPOCOLORS[$i]}

    # uppercase reponame
    repo=$( echo "$reponame" | tr [a-z] [A-Z] )

    # get centered hdr text
    h_txt="$(center "$repo" $hdr_len)"

    # print parts
    printf " "
    pr_state "${clean_dirty[$i]}"
    printf "  "
    pr_hdr "$h_txt" $color
    printf "  %-${br_len}s" "${br_name}"
    echo
done
echo

# https://misc.flogisoft.com/bash/tip_colors_and_formatting
