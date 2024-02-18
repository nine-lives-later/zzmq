#!/bin/bash

printf "\e]2;Hello World Server\a"

set -e

zig build
zig fmt . > /dev/null

./zig-out/bin/hello_world_server
