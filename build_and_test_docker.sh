#!/bin/sh

set -e

IMAGE=zzmq_test_347563478

DOCKER_BUILDKIT=1 docker build . -t $IMAGE -f test.Dockerfile
