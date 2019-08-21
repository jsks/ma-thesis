#!/bin/sh

rsync -vrtue ssh --delete --partial --progress \
      --exclude-from $(dirname $0)/exclude.txt \
      ./ gce:/home/cloud/thesis/
