#!/bin/sh

set -e

zig build test --summary all
#zig test src/zzmq.zig -lc -lzmq

zig fmt . > /dev/null
