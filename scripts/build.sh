#!/bin/sh

set -e

if [ -n "$1" ]; then
    printf "Attaching tag: %s\n" "$1"
    tag=":$1"
fi

if which podman 2>&1 >/dev/null; then
    podman build --format docker -t "docker.io/jsks/conflict_onset$tag" .
    podman push "docker.io/jsks/conflict_onset$tag"
else
    docker build -t "jsks/conflict_onset$tag" .
    docker push "jsks/conflict_onset$tag"
fi
