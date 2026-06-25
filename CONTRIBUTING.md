# Contributing to containerr

Thanks for your interest in improving `containerr`! This document outlines how to get set up and the conventions the project follows.

## Getting started

1. Fork and clone the repository.
2. Open `containerr.xcodeproj` in Xcode 16 or later.
3. Make sure Apple's [`container` CLI](https://github.com/apple/container) is installed so the app has something to talk to.
4. Build and run (`⌘R`).

## Development workflow

- Create a topic branch off `develop` (e.g. `feat/my-feature` or `fix/some-bug`).
- Keep changes focused — one logical change per pull request.
- Add or update tests in `containerrTests` / `containerrUITests` where it makes sense.
- Run the test suite before opening a PR:

  ```sh
  xcodebuild test -project containerr.xcodeproj -scheme containerr -destination 'platform=macOS'
  ```

## Code style

- Follow the existing SwiftUI and Swift conventions in the codebase.
- Keep blocking work off the main actor, matching the pattern in `ContainerCLI`.
- Prefer clear, self-documenting names over comments, but document non-obvious behavior.

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add SettingsView for advanced resource management
fix: handle daemon-down state in container list
docs: clarify build requirements in README
```

## Pull requests

- Describe what the change does and why.
- Reference any related issues.
- Make sure the project builds and tests pass.

## Reporting issues

Open an issue with clear reproduction steps, your macOS version, and the `container` CLI version (`container --version`).

## License

By contributing, you agree that your contributions will be licensed under the [GNU Affero General Public License v3.0](LICENSE).
