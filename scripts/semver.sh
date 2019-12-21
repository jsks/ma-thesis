#!/bin/sh
#
# Release script bumping current project version including git tag,
# thesis.utils version, and container image according to semantic
# versioning.
###

set -e

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

compare() {
    IFS=.
    read major minor patch <<< "$tag"
    read next_major next_minor next_patch <<< "$1"
    IFS=""

    (( next_major > major )) && return 0
    (( next_major < major )) && return 1

    (( next_minor > minor )) && return 0
    (( next_minor < minor )) && return 1

    (( next_patch > patch )) && return 0
    (( next_patch <= patch )) && return 1
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

while getopts 'hs:m:' opt; do
    case $opt in
        h)
            help;;
        m)
            msg=$OPTARG;;
        s)
            if ! grep -E '^[0-9]+[.][0-9]+[.][0-9]+$' <<< "$OPTARG" >/dev/null; then
                printf "Invalid semver: %s\n" "$OPTARG"
                exit 127
            fi

            if ! compare $OPTARG; then
                printf "Current version %s >= %s\n" "$tag" "$OPTARG"
                exit 127
            fi

            next_version=$OPTARG;;
        *)
            usage;;
    esac
done

shift $(($OPTIND - 1))
[ -n "$1" ] && usage

[ -n "$(git status -s)" ] && confirm "Uncommitted changes"
confirm "Bumping version to v$next_version"

sed -i "s/Version:.*/Version: $next_version/" $root/R/thesis.utils/DESCRIPTION
git add $root/R/thesis.utils/DESCRIPTION
git commit -m "Prepare release v$next_version"

git tag -a "v$next_version" -m "$msg"
git push --follow-tags

sh $root/scripts/build.sh -p
