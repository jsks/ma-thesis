#!/bin/sh

set -e

docker build -t jsks/conflict_onset:latest .
docker push jsks/conflict_onset
