#!/bin/sh
#
# Builds/pushes project container image as `jsks/conflict_onset` with
# the version tag set as the current git tag.
###

set -e

usage() {
    printf "Usage: ./$(basename $0) [-h] [-p]\n"
    exit 127
}

help() {
cat <<EOF
$(usage)

Builds 'jsks/conflict_onset' container image.

Options:
        -h Useless help message.
        -p Push after successful build.
        -t Tag resulting image.
EOF

exit
}

## Main
while getopts 'hpt:' opt; do
    case $opt in
        h)
            help;;
        p)
            PUSH_IMG=1;;
        t)
            TAG="$OPTARG";;
        *)
            usage;;
    esac
done

shift $(($OPTIND - 1))
[ -n "$1" ] && usage

which podman 2>&1 >/dev/null && cmd=podman || cmd=docker

if [ "$cmd" == "podman" ]; then
    $cmd build --cap-add=CAP_SYS_PTRACE --format docker -t jsks/conflict_onset .
else
    $cmd build --cap-add=SYS_PTRACE -t jsks/conflict_onset .
fi

[ -n "$PUSH_IMG" ] && $cmd push jsks/conflict_onset
if [ -n "$TAG" ]; then
    $cmd tag jsks/conflict_onset jsks/conflict_onset:"$TAG"
    [ -n "$PUSH_IMG" ] && $cmd push jsks/conflict_onset:"$TAG"
fi
