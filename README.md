# Zig Binding for ZeroMQ

This Zig library provides a ZeroMQ client.

It is implemented as a wrapper of the "High-level C Binding for ZeroMQ" ([CZMQ](http://czmq.zeromq.org)).

**IMPORTANT: The library is currently still work in progress!!**

## Using the Library

### Minimal Example

Since this library is basically a 1:1 wrapper of CZMQ, please refer to the [CZMQ documentation](http://czmq.zeromq.org) to get a better understanding on how the library works.

```zig
const zzmq = @import("zzmq");

var s = try zzmq.zsocket.ZSocket.init(allocator, zzmq.zsocket.ZSocketType.Pair);
defer s.deinit();

const port = try s.bind("tcp://127.0.0.1:!");
```

Please feel free to also have a look at the various unit tests in this library.

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

| Branch | Zig Version   | Comment |
| --- |---------------| --- |
| `main` | Zig v0.11.x  | The latest unreleased version for Zig 0.11. |

Please use a specific [release tag](https://github.com/nine-lives-later/zzmq/tags) for including the library into your project.

### Testing

The library can be tested locally by running: `zig build test`.

### Contributors

Implementation done by [Felix Kollmann](https://github.com/fkollmann).

Based on the work of [CZMQ](http://czmq.zeromq.org), inspired by [goczmq](https://github.com/zeromq/goczmq).

## License

Published under the [MIT license](LICENSE).

Please keep in mind that this library depends on [CZMQ](http://czmq.zeromq.org) and [libzmq](https://github.com/zeromq/libzmq) which are published under their own respective license.
They are being used as dynamically linked libraries (`libczmq.so`, `libzmq.so`), which should be fine.
