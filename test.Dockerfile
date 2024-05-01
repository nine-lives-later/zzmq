FROM alpine:3.19 as builder

# install Zig 0.11 from the original source (it is no longer available via Alpine edge repos)
ADD https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz /tmp/zig.tar.xz

WORKDIR /opt/zig

RUN tar xf /tmp/zig.tar.xz --strip-components 1
RUN ln -s /opt/zig/zig /usr/local/bin/zig

# install dependencies
RUN apk add --no-cache zeromq-dev

COPY . /build/

WORKDIR /build

RUN zig build test -Doptimize=ReleaseFast --summary all

RUN touch /var/touched # dummy build output



# empty result image
FROM scratch

COPY --from=builder /var/touched /tmp/touched
