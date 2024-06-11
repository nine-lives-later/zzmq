FROM alpine:3.20 as zig

ARG ZIG_VERSION=0.13

# install Zig 0.13 from Alpine edge community repo: https://pkgs.alpinelinux.org/package/edge/community/x86_64/zig
RUN echo "@edge-community https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN echo "@edge-main https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

RUN apk add --no-cache zig@edge-community~=${ZIG_VERSION}.0 clang18@edge-main lld-libs@edge-main



FROM zig as builder

# install dependencies
RUN apk add --no-cache zeromq-dev



COPY . /build/

WORKDIR /build

RUN zig build test -Doptimize=ReleaseFast --summary all

RUN touch /var/touched # dummy build output

# empty result image
FROM scratch

COPY --from=builder /var/touched /tmp/touched
