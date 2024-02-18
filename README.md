# Zig Binding for ZeroMQ

This Zig library provides a ZeroMQ client.

It is implemented as a wrapper of the "High-level C Binding for ZeroMQ" ([CZMQ](http://czmq.zeromq.org)).

**IMPORTANT: The library is currently still work in progress!!**

[![Unit Tests](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml)

## Using the Library

### Minimal Example

Since this library is basically a 1:1 wrapper of CZMQ, please refer to the [CZMQ documentation](http://czmq.zeromq.org) to get a better understanding on how the library works.
Please feel free to also have a look at the various unit tests in this library (esp. [ZSocket](src/classes/zsocket.zig)).

Running the server (also see [full example](https://github.com/nine-lives-later/zzmq/tree/main/examples/hello_world_server)):

```zig
const zzmq = @import("zzmq");

var socket = try zzmq.ZSocket.init(allocator, zzmq.ZSocketType.Pair);
defer socket.deinit();

const port = try socket.bind("tcp://127.0.0.1:!");

// send a message
var frame = try zzmq.ZFrame.init(data);
defer frame.deinit();

try socket.send(&frame, .{});
```
Running the client (also see [full example](https://github.com/nine-lives-later/zzmq/tree/main/examples/hello_world_client)):

```zig
const zzmq = @import("zzmq");

var socket = try zzmq.ZSocket.init(allocator, zzmq.ZSocketType.Pair);
defer socket.deinit();

const endpoint = try std.fmt.allocPrint(allocator, "tcp://127.0.0.1:{}", .{port});
defer allocator.free(endpoint);

try socket.connect(endpoint);

// receive a message
var frame = try socket.receive();
defer frame.deinit();

const data = try frame.data();
```


### Adding to build process

Determine the specific [release tag](https://github.com/nine-lives-later/zzmq/tags) of the library to use in the project.

Add to the `build.zig.zon` file, e.g. for Zig 0.11:

```zig
.{
    .dependencies = .{
        .clap = .{
            .url = "https://github.com/nine-lives-later/zzmq/archive/refs/tags/0.1.0-zig.tar.gz",
        },
    },
}
```

Note: When adding the URL only, the compiler will generate an error regarding the missing `.hash` field, and will also provide the correct value for it. Starting with Zig 0.12 you can also use `zig fetch`.

It is also required to add it to the `build.zig` file:

```zig
const zzmq = b.dependency("zzmq", .{
    .target = target,
    .optimize = optimize,
});

// Note: starting with zig 0.12 the function will be 
//       `exe.root_module.addImport` instead of `exe.addModule`
exe.addModule("zzmq", zzmq.module("zzmq"));

exe.linkSystemLibrary("czmq");
exe.linkLibC();
```

### Installing local dependencies

Installing [CZMQ](http://czmq.zeromq.org) development library version 4.0 or higher is also required:

```sh
# Building on Ubuntu, PoP_OS, ZorinOS, etc.
sudo apt install libczmq-dev

# Running on Ubuntu, PoP_OS, ZorinOS, etc.
sudo apt install libczmq
```

## Contributing

### Zig Version Branches

There are branches for the supported Zig versions:

| Branch | Zig Version   | Status | Comment |
| --- |---------------| --- | --- |
| `main` | Zig v0.11.x  | [![Unit Tests](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/nine-lives-later/zzmq/actions/workflows/test.yml) | The latest unreleased version for Zig 0.11. |

Please use a specific [release tag](https://github.com/nine-lives-later/zzmq/tags) for including the library into your project.

### Testing

The library can be tested locally by running: `zig build test`.

### Contributors

Implementation done by [Felix Kollmann](https://github.com/fkollmann).

Based on the work of [CZMQ](http://czmq.zeromq.org), inspired by [goczmq](https://github.com/zeromq/goczmq).

## License

Published under the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/).

- Static linking is allowed.
- Safe for use in close-source applications.
- You do not need a commercial license.

Feel free to also see the [ZeroMQ licensing terms](https://zeromq.org/license/).
