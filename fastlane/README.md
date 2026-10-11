fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios bootstrap_signing

```sh
[bundle exec] fastlane ios bootstrap_signing
```

Create or repair the encrypted App Store signing assets in Match

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit and UI tests on an available iPhone simulator

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build, sign, and upload the next build to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build, submit for App Review, and release automatically after approval

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
