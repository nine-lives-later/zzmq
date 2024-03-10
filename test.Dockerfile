FROM alpine:3.19 as cpp_base

RUN apk add --no-cache g++ gcc cmake make musl-dev



FROM cpp_base as libzmq_builder

ARG LIBZMQ_VERSION=4.3.5

# add the pre-processed source package (note: this is not the raw source code from Git!)
ADD https://github.com/zeromq/libzmq/releases/download/v${LIBZMQ_VERSION}/zeromq-${LIBZMQ_VERSION}.tar.gz /tmp/source.tgz

WORKDIR /build

RUN tar -xzf /tmp/source.tgz --strip-components=1

RUN ./configure --prefix=/build/output
RUN make install




FROM alpine:3.19 as builder

# install Zig 0.11 from Alpine edge repo: https://pkgs.alpinelinux.org/package/edge/testing/x86_64/zig
RUN echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
RUN apk add --no-cache zig@testing~=0.11.0

# install dependencies (keep in sync with other images above)
COPY --from=libzmq_builder /build/output/ /usr/

COPY . /build/

WORKDIR /build

RUN zig build test -Doptimize=ReleaseFast --summary all

RUN touch /var/touched # dummy build output



# empty result image
FROM scratch

COPY --from=builder /var/touched /tmp/touched
