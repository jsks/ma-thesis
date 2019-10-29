#!/bin/sh
#
# CLI arguments are passed directly to make in the spawned
# container. If the environmental variable CLEANUP is defined and set
# to 1, then the container will be automatically removed following
# completion.
###

set -e

which podman 2>&1 >/dev/null && CMD=podman || CMD=docker
echo "Running with $CMD"

# No arrays in posix sh...
mount_opts="-v $PWD:/proj"
if [ -d /mnt/data/posteriors ]; then
    echo "Mounting posterior map from /mnt/data"
    mount_opts="$mount_opts -v /mnt/data/posteriors:/proj/posteriors"
fi

$CMD run -d $mount_opts jsks/conflict_onset make $@
container=$($CMD ps -l --format "{{.Names}}")

echo "Launched: $container"
$CMD logs -f $container

if [ "${CLEANUP:-0}" = 1 ]; then
    docker container rm $container
fi
