#!/bin/bash

printf "\e]2;Dealer-Reply Client\a"

set -e

zig build
zig fmt . > /dev/null

./zig-out/bin/dealer_rep_client
