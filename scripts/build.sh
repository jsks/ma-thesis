#!/bin/sh

set -e

if which podman 2>&1 >/dev/null; then
    podman build -t docker.io/jsks/conflict_onset .
    podman push docker.io/jsks/conflict_onset
else
    docker build -t jsks/conflict_onset:latest .
    docker push jsks/conflict_onset
fi
