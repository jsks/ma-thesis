#!/bin/sh

rsync -vrue ssh --delete --partial --progress \
      --exclude-from $(dirname $0)/exclude.txt \
      ./ nki:/home/jsks/inv/
