FROM alpine:3.19 as builder

# install Zig 0.12 from Alpine edge community repo: https://pkgs.alpinelinux.org/package/edge/community/x86_64/zig
RUN echo "@edge-community https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN apk add --no-cache zig@edge-community~=0.12.0

# install dependencies
RUN apk add --no-cache zeromq-dev clang

COPY . /build/

WORKDIR /build

RUN zig build test -Doptimize=ReleaseFast --summary all

RUN touch /var/touched # dummy build output

# empty result image
FROM scratch

COPY --from=builder /var/touched /tmp/touched
