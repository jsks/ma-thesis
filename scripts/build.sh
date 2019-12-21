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
EOF

exit
}

## Main
[ -n "$1" ] && usage

while getopts 'hpt' opt; do
    case $opt in
        h)
            help;;
        p)
            PUSH_IMG=1;;
        *)
            usage;;
    esac
done

tag=$(git describe --tags --abbrev=0 2>/dev/null | cut -c 2-)
: ${tag:="latest"}

img_name="jsks/conflict_onset:$tag"
printf "Building $img_name\n"

if which podman 2>&1 >/dev/null; then
    podman build --format docker -t "$img_name" .
    [ -n "$PUSH_IMG" ] && podman push "$img_name" "docker.io/$img_name"
else
    docker build -t "$img_name" .
    [ -n "$PUSH_IMG" ] && docker push "$img_name"
fi
