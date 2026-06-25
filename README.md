# Containerr

A native SwiftUI macOS app that provides a graphical interface for [Apple's `container` CLI](https://github.com/apple/container).

`Containerr` is a thin, native front-end over the `container` command-line tool. It lets you browse, inspect, and launch Linux containers on macOS without touching the terminal, with sensible resource defaults that respect your host's CPU and memory reserves.

## Features

- **Container list** — view running and stopped containers at a glance with live status badges.
- **Container details** — inspect a container's configuration and current state.
- **Launch new containers** — configure image, run options, and resource limits from a simple sheet.
- **Resource policy** — automatic CPU and memory allocation that reserves headroom for the host, with an advanced override for power users.
- **Daemon awareness** — clear messaging when the `container` system service isn't running.

## Requirements

- macOS (Apple Silicon or Intel)
- [Apple's `container` CLI](https://github.com/apple/container) installed at `/usr/local/bin/container`, `/opt/homebrew/bin/container`, or anywhere on your `PATH`
- Xcode 16 or later to build from source

## Building

```sh
git clone https://github.com/nedanwr/containerr.git
cd containerr
open containerr.xcodeproj
```

Then build and run (`⌘R`) from Xcode.

## How it works

`Containerr` shells out to the `container` CLI via `Process`, decoding its `--format json` output. All blocking work runs off the main actor to keep the UI responsive.

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

`Containerr` is licensed under the [GNU Affero General Public License v3.0](LICENSE).
