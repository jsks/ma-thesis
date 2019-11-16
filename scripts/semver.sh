#!/bin/sh
#
# Release script bumping current project version including git tag,
# thesis.utils version, and container image according to semantic 
# versioning.
###

## Utility functions
usage() {
    printf "Usage: ./$(basename $0) [-h] [-m <msg>] [-s <semver>]\n"
    exit 127
}

help() {
cat <<EOF
$(usage)

Sets the project-wide version number. If not specified, default to
bumping the current patch version.

Options:
        -h Useless help message
        -m Git tagging message
        -s Specify version number in the form of MAJOR.MINOR.PATCH
EOF

exit
}

confirm() {
    printf "$*. Continue (y/n)? "
    read ans

    case $ans in
        [Yy] | Yes | yes)
            return 0;;
        *)
            return 1;;
    esac
}

validate() {
    if ! grep -E '^[0-9]+[.][0-9]+[.][0-9]+$' <<< "$1" >/dev/null; then
        printf "Invalid semver: %s\n" "$1"
        exit 127
    fi

    IFS=.
    read major minor patch <<< "$tag"
    read next_major next_minor next_patch <<< "$1"
    IFS=""

    if (( next_major < major )) ||
           (( next_minor < minor )) ||
           (( next_patch <= patch )); then
        printf "Current version %s >= %s\n" "$tag" "$1"
        exit 127
    fi
}

## Main
if [ -n "$(git diff --name-only --staged)" ]; then
    printf "Finish commit before updating version number\n"
    exit 127
fi

root=$(git rev-parse --show-toplevel)
tag=$(git describe --tags --abbrev=0 2>/dev/null | cut -c 2-)
: ${tag:="0.0.0"}

next_version="${tag%.*}.$(( ${tag##*.} + 1 ))"

while getopts 'hs:' opt; do
    case $opt in
        h)
            help;;
        m)
            msg=$OPTARG;;
        s)
            validate $OPTARG
            next_version=$OPTARG;;
        *)
            usage;;
    esac
done

set -e

[ -n "$(git status -s)" ] && confirm "Uncommitted changes"
confirm "Bumping version to v$next_version"

sed -i "s/Version:.*/Version: $next_version/" $root/R/thesis.utils/DESCRIPTION
git add $root/R/thesis.utils/DESCRIPTION
git commit -m "Prepare release v$next_version"

git tag -a "v$next_version" -m $msg

sh $root/scripts/build.sh "$next_version"
