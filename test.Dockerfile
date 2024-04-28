FROM alpine:3.19 as builder

# Install necessary tools for building musl
RUN apk add --no-cache clang make

# Download musl source code
RUN wget https://musl.libc.org/releases/musl-1.2.4.tar.gz

# Extract the source code
RUN tar -xzvf musl-1.2.4.tar.gz

# Navigate into the musl directory
WORKDIR /musl-1.2.4

# Configure, build, and install musl
RUN ./configure && make && make install

# Cleanup
WORKDIR /
RUN rm -rf /musl-1.2.4 musl-1.2.4.tar.gz

# install Zig 0.12 from Alpine edge repo: https://pkgs.alpinelinux.org/package/edge/testing/x86_64/zig
RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache zig@testing~=0.12.0

# install dependencies
RUN apk add --no-cache zeromq-dev

COPY . /build/

WORKDIR /build

RUN zig build test -Doptimize=ReleaseFast --summary all

RUN touch /var/touched # dummy build output

# empty result image
FROM scratch

COPY --from=builder /var/touched /tmp/touched
