FROM alpine:3.19 as builder

RUN apk add --no-cache g++ gcc cmake make musl-dev

# add the pre-processed source package (note: this is not the raw source code from Git!)
ADD https://github.com/zeromq/libzmq/releases/download/v4.3.5/zeromq-4.3.5.tar.gz /tmp/source.tgz

WORKDIR /build

RUN tar -xzf /tmp/source.tgz --strip-components=1

RUN ./configure --prefix=/build/output
RUN make install



# copy the build output
FROM alpine:3.19

COPY --from=builder /build/output /build/output
