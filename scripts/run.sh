#!/bin/sh
#
# Convenience script to launch project image. Note: CLI args besides
# the listed options are passed directly to Make, so no usage
# function.
#
# By default, the latest tag will be used unless the IMG_TAG env variable is
# set.
#
# If the env variable CLEANUP is defined and set to 1, then the container will
# be automatically cleaned up after exit.
###

set -e

which podman 2>&1 >/dev/null && CMD=podman || CMD=docker

# No arrays in posix sh...
mount_opts="-v $(cd ./`dirname $0`/../ && pwd):/proj"
if [ -d /mnt/data/posteriors ]; then
    echo "Mounting posterior map from /mnt/data"
    mount_opts="$mount_opts -v /mnt/data/posteriors:/proj/posteriors"
fi

if [ "${CLEANUP:-0}" = 1 ]; then
    rm_opts="--rm"
fi

$CMD run -it $mount_opts $rm_opts \
     -e cmdstan=/cmdstan -e extract=/root/bin/extract \
     --cap-add=CAP_SYS_PTRACE \
     "jsks/conflict_onset:${IMG_TAG:-latest}" make -j4 $@
