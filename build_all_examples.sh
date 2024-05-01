#!/bin/bash

set -e

for x in ./examples/*/build.zig; do
  EXAMPLEDIR=$(dirname "$x")

  echo "Building example: $EXAMPLEDIR ..."

  pushd $EXAMPLEDIR > /dev/null

  zig build

  popd > /dev/null
done
