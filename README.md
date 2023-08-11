# LargeBrowser

A minimal, yet self-sufficient WebKit-based browser for macOS.

## Building

1. Build WebKit (see [building-webkit](docs/building-webkit.md) for details)
2. Run make with `WEBKIT_FRAMEWORK_PATH` set to path containing the built WebKit artifacts (see [build.txt](build.txt) for an example)
3. Copy, move or run `LargeBrowser.app`

## Documentation

- [Manual](docs/manual.md)
- [Using Content Blockers](docs/content-blockers.md)

## Origin

This is a fork of the macOS version of [MiniBrowser](https://github.com/WebKit/WebKit/tree/main/Tools/MiniBrowser/mac).

## License

[MIT](LICENSE.txt), unless otherwise specified.
