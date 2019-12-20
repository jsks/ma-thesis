#!/bin/sh

set -e

tag=$(git describe --tags --abbrev=0 2>/dev/null | cut -c 2-)
: ${tag:="latest"}

img_name="jsks/conflict_onset:$tag"

if which podman 2>&1 >/dev/null; then
    podman build --format docker -t "docker.io/$img_name"
    podman push "docker.io/$img_name"
else
    docker build -t "$img_name" .
    docker push "$img_name"
fi
