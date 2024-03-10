#!/bin/sh

set -e

IMAGE=zzmq_libzmq_345345345

DOCKER_BUILDKIT=1 docker build . -t $IMAGE

if [ -d output ]; then
  rm -rf output
fi

mkdir -p output

docker run -v "$PWD/output:/mnt" $IMAGE sh -c "cp -rf /build/output/* /mnt/ && chown $(id -u):$(id -g) -R /mnt/"
