#!/bin/sh
#
# Launches an interactive container instances with CLI arguments
# passed directly to `make`. If the env variable CLEANUP is defined
# and set to 1, then the container will be automatically removed
# following completion.
###

set -e

tag=$(git describe --tags --abbrev=0 2>/dev/null | cut -c 2-)
: ${tag:="latest"}

which podman 2>&1 >/dev/null && CMD=podman || CMD=docker

# No arrays in posix sh...
mount_opts="-v $(git rev-parse --show-toplevel):/proj"
if [ -d /mnt/data/posteriors ]; then
    echo "Mounting posterior map from /mnt/data"
    mount_opts="$mount_opts -v /mnt/data/posteriors:/proj/posteriors"
fi

if [ "${CLEANUP:-0}" = 1 ]; then
    rm_opts="--rm"
fi

$CMD run -it $mount_opts $rm_opts "jsks/conflict_onset:$tag" make $@
