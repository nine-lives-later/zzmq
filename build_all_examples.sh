#!/bin/bash

set -e

if [ -z "$ZIG_VERSION" ]; then
  ZIG_VERSION="$(zig version | sed -E 's/^([0-9]+\.[0-9]+)\.[0-9]+$/\1/')"
fi

echo "Zig version: $ZIG_VERSION"

for x in ./examples/*/build.zig; do
  EXAMPLEDIR=$(dirname "$x")

  echo "Building example: $EXAMPLEDIR ..."

  pushd $EXAMPLEDIR > /dev/null

  zig fetch --save=zzmq "https://github.com/nine-lives-later/zzmq/archive/refs/tags/v0.2.2-zig${ZIG_VERSION}.tar.gz"
  zig build

  popd > /dev/null
done
