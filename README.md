# Zig Binding for ZeroMQ

This Zig library provides a ZeroMQ client.

It is implemented based on the C API of [libzmq](https://libzmq.readthedocs.io/en/latest/).
The interface is highly inspired by [CZMQ](http://czmq.zeromq.org) and [goczmq](https://github.com/zeromq/goczmq).

It was originally based on the "High-level C Binding for ZeroMQ" ([CZMQ](http://czmq.zeromq.org)), 
but later moved to using [libzmq](https://libzmq.readthedocs.io/en/latest/) directly, to provide zero-copy message support.

> [!IMPORTANT]
> The library is currently still work in progress!!
> 
> Please feel free to open pull requests for features needed.

[![Unit Tests](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml) 
[![Examples](https://github.com/nine-lives-later/zzmq/actions/workflows/examples.yml/badge.svg?branch=main)](https://github.com/nine-lives-later/zzmq/actions/workflows/examples.yml)

## Using the Library

### Minimal Example

This repository holds various example within the `examples` folder.
Please feel free to also have a look at the various unit tests in this library (esp. [ZSocket](src/classes/zsocket.zig)).

Running the server (also see [full example](https://github.com/nine-lives-later/zzmq/tree/main/examples/hello_world_server)):

```zig
const zzmq = @import("zzmq");

var context = try zzmq.ZContext.init(allocator);
defer context.deinit();

var socket = try zzmq.ZSocket.init(zzmq.ZSocketType.Pair, &context);
defer socket.deinit();

try socket.bind("tcp://127.0.0.1:*");

std.log.info("Endpoint: {s}", .{try socket.endpoint()});

// send a message
var message = try zzmq.ZMessage.initUnmanaged(data, null);
defer message.deinit();

try socket.send(&message, .{});
```

Running the client (also see [full example](https://github.com/nine-lives-later/zzmq/tree/main/examples/hello_world_client)):

```zig
const zzmq = @import("zzmq");

var context = try zzmq.ZContext.init(allocator);
defer context.deinit();

var socket = try zzmq.ZSocket.init(zzmq.ZSocketType.Pair, &context);
defer socket.deinit();

const endpoint = try std.fmt.allocPrint(allocator, "tcp://127.0.0.1:{}", .{port});
defer allocator.free(endpoint);

try socket.connect(endpoint);

// receive a message
var message = try socket.receive(.{});
defer message.deinit();

const data = try message.data();
```


### Adding to build process

Determine the specific [release tag](https://github.com/nine-lives-later/zzmq/tags) of the library to use in the project.

```sh
zig fetch --save=zzmq 'https://github.com/nine-lives-later/zzmq/archive/refs/tags/v0.2.1-zig0.12.tar.gz'
```

It is also required to add it to the `build.zig` file:

```zig
const zzmq = b.dependency("zzmq", .{
    .target = target,
    .optimize = optimize,
});

// Note: starting with zig 0.12 the function will be 
//       `exe.root_module.addImport` instead of `exe.addModule`
exe.addModule("zzmq", zzmq.module("zzmq"));

exe.linkSystemLibrary("zmq");
exe.linkLibC();
```

### Installing local dependencies

Installing [libzmq](https://zeromq.org/download/) development library version 4.1 or higher is also required:

```sh
# Building on Ubuntu, PoP_OS, ZorinOS, etc.
sudo apt install libzmq5-dev

# Running on Ubuntu, PoP_OS, ZorinOS, etc.
sudo apt install libzmq5
```

See the [unit test Dockerfile](test.Dockerfile) on how to install it into an Alpine Docker image.

To retrieve the version of the libzmq library actually being used, call `ZContext.version()`.

## Contributing

### Zig Version Branches

There are branches for the supported Zig versions:

| Branch     | Zig Version | Status                                                                                                                                                                              | Comment                                     |
|------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| `main`     | Zig v0.12.x | [![Unit Tests](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml)     | The latest unreleased version for Zig 0.12. |
| `zig-0.11` | Zig v0.11.x | [![Unit Tests](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml/badge.svg?branch=zig-0.11)](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml) | The latest unreleased version for Zig 0.11. |

Please use a specific [release tag](https://github.com/nine-lives-later/zzmq/tags) for including the library into your project.

### Testing

The library can be tested locally by running: `zig build test`.

### Contributors

- Implementation done by [Felix Kollmann](https://github.com/fkollmann).
- Update to Zig 0.12 done by [Jacob Green](https://github.com/7Zifle).
- Inspired by [CZMQ](http://czmq.zeromq.org) and [goczmq](https://github.com/zeromq/goczmq).

## License

Published under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/).

- Static linking is allowed.
- Safe for use in close-source applications.
- You do not need a commercial license.

Feel free to also see the [ZeroMQ licensing terms](https://zeromq.org/license/).
