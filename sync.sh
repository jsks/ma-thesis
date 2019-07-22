#!/bin/sh

rsync -vrue ssh --partial --progress \
      --exclude=docs --exclude=plots --exclude=replications \
      --exclude=Rmd --exclude=refs --exclude=md \
      --exclude='\#*' --exclude=posteriors --exclude=data/*.rds \
      ./ nki:/home/jsks/inv/
