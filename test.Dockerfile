FROM alpine:3.19 as builder

# install Zig 0.11 from Alpine edge repo: https://pkgs.alpinelinux.org/package/edge/testing/x86_64/zig
RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache zig@testing~=0.11.0

# install dependencies
RUN apk add --no-cache zeromq-dev

COPY . /build/

WORKDIR /build

RUN zig build test -Doptimize=ReleaseFast --summary all

RUN touch /var/touched # dummy build output



# empty result image
FROM scratch

COPY --from=builder /var/touched /tmp/touched
