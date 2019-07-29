#!/bin/sh

docker run -d -v $PWD:/proj jsks/conflict_onset make $@
container=$(docker ps -l --format "{{.Names}}")

echo "Launched: $container"
docker logs -f $container
