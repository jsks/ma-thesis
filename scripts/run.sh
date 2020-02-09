#!/bin/sh
#
# Convenience script to launch project image. Note: CLI args besides
# the listed options are passed directly to Make, so no usage
# function.
###

set -e

help() {
    cat <<EOF
$(usage)

Launches an attached instance of 'jsks/conflict_onset'. Any
commandline arguments beside the listed options are passed directly to
'make -j4' in the container.

If the env variable CLEANUP is defined and set to 1, then the
container will be automatically removed following completion.

Options:
        -t Specify container tag [Default: latest;]
EOF
}

while getopts 'ht:' opt; do
    case $opt in
        h)
            help;;
        t)
            TAG="$OPTARG";;
    esac
done

shift $(( $OPTIND - 1 ))
: ${TAG:="latest"}

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
     -e cmdstan=/cmdstan -e select=/root/bin/select \
     "jsks/conflict_onset:$TAG" make -j4 $@
