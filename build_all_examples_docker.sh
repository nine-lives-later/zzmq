#!/bin/sh

set -e

IMAGE=zzmq_examples_347563478

DOCKER_BUILDKIT=1 docker build . -t $IMAGE -f examples.Dockerfile
