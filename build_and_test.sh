#!/bin/sh

set -e

zig build test --summary all
zig fmt . > /dev/null
