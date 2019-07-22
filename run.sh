#!/bin/sh

docker run -d -v $PWD:/proj conflict_onset make $@ && \
    docker logs -f $(docker ps -l --format "{{.Names}}")
