# Building and verification

## Host requirements

- Linux x86_64 (or macOS/Windows x86_64 for the Flutter and Android toolchains)
- Flutter SDK on `PATH`, pinned to the engine revision
- A release-mode Flutter engine prebuilt
- Rust and the `aarch64-linux-android` target
- Android SDK with platform 36, current build-tools, and an NDK
- JDK 17 or newer
- `readelf`, `file`, `zip`, and `unzip`

Set `ANDROID_SDK_ROOT` when the SDK is not at `$HOME/Android/Sdk`.

A phone cannot build the project. The Android NDK ships a `linux-x86_64` host
toolchain only, and `flutter assemble` AOT-compiles `libapp.so` with a host
`gen_snapshot` that Flutter publishes for x86_64 hosts only.

## Pinned Flutter runtime

The custom embedder links `libflutter_engine.so` and loads `icudtl.dat`, so the
engine, the engine header, and the `gen_snapshot` that writes `libapp.so` must
all belong to one Flutter release. This tree is pinned to:

| Component | Value |
| --- | --- |
| Flutter | 3.44.8 stable |
| Framework revision | `058e0af2c2b57e369d905a03ac9748b0ebf543c6` |
| Engine revision | `0cd610717bde95fd88343c64f81c11ba4e5c0010` |
| Dart | 3.12.2 (`e9ed4fc9f1544c58d8a9347c1fc9471d8dd7c465`) |

Flutter publishes release-mode embedder libraries from an engine checkout, not
from the SDK artifact service (the SDK serves the debug embedder only), so the
default path reuses the exact release engine the v1.18.5 module shipped and
verifies it by digest:

```bash
./tools/fetch-flutter-engine-prebuilt.sh
```

The script installs ignored local artifacts and fails unless the engine still
carries the pinned framework and Dart revisions and
`runtime/flutter-engine/include/embedder.h` still matches the engine ABI:

```text
runtime/flutter-engine/prebuilt/android-arm64/libflutter_engine.so
runtime/flutter-engine/prebuilt/android-arm64/icudtl.dat
```

Building the engine from source remains supported when the pin has to move.
It needs a full engine checkout (~25 GB) and `ninja`:

```bash
DASH_FLUTTER_ENGINE_SRC=/absolute/path/to/engine/src \
  ./tools/build-flutter-engine.sh
```

Whichever path fills the prebuilt directory, build the UI with the matching
Flutter SDK.

## Prepare Rust and Flutter

```bash
rustup target add aarch64-linux-android
./tools/fetch-flutter-engine-prebuilt.sh
flutter pub get --directory ui/flutter
```

## Build the application and daemon

```bash
DASH_BUILD_ONLY=1 ./build-and-install.sh
```

The output directory contains:

```text
Dash-Essential.apk
host-cargo/aarch64-linux-android/release/dash_daemon
host-cargo/aarch64-linux-android/release/dash_ctl
apk-files.txt
```

Without `DASH_BUILD_ONLY=1`, the script installs the APK on the connected
device and updates the development root-module backend. ROM release automation
should always use build-only mode or `tools/export-aosp-bundle.sh`.

## Signing

An omitted `DASH_KEYSTORE` creates a stable local development key at
`out/signing/dash-essential-development.jks`. The ignored key is generated
once and reused so repeated local builds remain update-compatible. Nothing
under `android/package` contains private signing material.

Supply release credentials through environment variables:

```bash
DASH_KEYSTORE=/absolute/path/release.jks \
DASH_KEY_ALIAS=release \
DASH_KEYSTORE_PASS='store-password' \
DASH_KEY_PASS='key-password' \
DASH_BUILD_ONLY=1 ./build-and-install.sh
```

AOSP exports require an explicit persistent key. The imported APK remains
presigned with that certificate, and the exported public PEM binds its exact
package name to the dedicated `dash_app` domain. The private key remains with
the ROM maintainer.

## Local checks

Run before committing:

```bash
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test -p dash-essential-daemon
dart format --output=none --set-exit-if-changed ui/flutter/lib
(cd ui/flutter && flutter analyze)
bash -n build-and-install.sh
bash -n tools/build-flutter-engine.sh
bash -n tools/fetch-flutter-engine-prebuilt.sh
bash -n tools/build-kernelsu-next-module.sh
bash -n tools/export-aosp-bundle.sh
bash -n tools/integrate-aosp-rom.sh
./tools/test-kernelsu-watchdog-lock.sh
./tools/test-root-module-contract.sh
./tools/test-aosp-integration.sh
git diff --check
```

The NativeActivity host intentionally links Android system libraries and is not
linked as a Linux test executable. `build-and-install.sh` cross-compiles it with
the Android NDK and verifies the resulting ARM64 shared object.

Build verification additionally checks:

- `classes*.dex` is absent.
- APK signature verification succeeds.
- ZIP entries satisfy 16 KB page alignment.
- Every native ELF LOAD segment has at least 16 KB alignment.
- Every Dart FFI lookup resolves to an exported ARM64 host symbol.
- Daemon and control binaries target ARM64 Android.
- The packaged runtime stamp covers every Flutter asset and `icudtl.dat`, so
  application updates cannot reuse an incompatible extraction cache.

## AOSP export

```bash
DASH_KEYSTORE=/absolute/path/rom-app.jks \
DASH_KEY_ALIAS=dash-essential \
DASH_KEYSTORE_PASS='store-password' \
DASH_KEY_PASS='key-password' \
  ./tools/export-aosp-bundle.sh
```

The export fails rather than replacing an existing destination. Pass a new
absolute or relative destination as its first argument when required.

To build, stage, and wire the integration directly in an AOSP checkout:

```bash
DASH_KEYSTORE=/absolute/path/rom-app.jks \
DASH_KEY_ALIAS=dash-essential \
DASH_KEYSTORE_PASS='store-password' \
DASH_KEY_PASS='key-password' \
  ./tools/integrate-aosp-rom.sh /absolute/path/to/aosp \
    device/xiaomi/dash/device.mk \
    device/xiaomi/dash/BoardConfig.mk
```

The helper adds the exact product and BoardConfig includes idempotently and
refuses files outside the selected tree. Pass only the AOSP root for stage-only
operation with no device-tree edits.

## KernelSU Next and Magisk module

```bash
DASH_KEYSTORE=/absolute/path/release.jks \
DASH_KEY_ALIAS=release \
DASH_KEYSTORE_PASS='store-password' \
DASH_KEY_PASS='key-password' \
  ./tools/build-kernelsu-next-module.sh
```

This builds the application and daemon together, then creates one ZIP for
KernelSU Next Manager and the Magisk app. The build validates module metadata,
shell syntax, the authenticated Unix/loopback IPC contract, the official APK signing
certificate, package/version/zero-DEX/16 KB alignment, ARM64 daemon binaries,
Android dynamic linker, archive contents, and checksum. It also rejects any
SELinux patch payload or system overlay in the resulting ZIP.

The module installs the bundled APK through Android's package manager as a
normal user application. It does not mount an APK into a system partition, so
KernelSU does not need a metamodule. Policies that block cross-domain Unix
sockets use the root-privileged localhost fallback, whose accepted client is
mapped to the installed package UID through the kernel TCP table. The module
neither patches live SELinux policy nor converts the APK into a privileged
application. A policy that already permits the direct connection may use it.
Installation from recovery is not supported.

On a ROM with native Dash Essential integration, the module becomes an update
layer only when Android accepts the bundled APK as a signature-compatible
system-app update. At boot it stops the native init service, shares the native
state directory, and then starts the module daemon. Module removal uses
Android's targeted `uninstall-system-updates` command and restarts native init.
No partition file is replaced. Cross-signature native updates remain rejected
because bypassing Android's package identity would either fail package scanning
or require destructive app removal.

The builder requires a persistent `DASH_KEYSTORE`; it never creates a
disposable module signing identity. Reuse the same key for all published module
versions so Android can update the bundled application without removing user
data. For the one signing-identity reset, the module installer first attempts a
normal update. If Android reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE` for a
user-installed copy, it removes that package and installs the bundled APK while
leaving `/data/adb/dash-essential` untouched. This resets application-local
preferences once. A cross-signed ROM-native system package is still rejected;
only its ROM maintainer can replace it safely.

### Development builds

The published release keystore is not in this repository, so a test build has
to opt out of the release-certificate gate explicitly:

```bash
DASH_KEYSTORE=/absolute/path/dev.jks \
DASH_KEY_ALIAS=dash-essential-development \
DASH_KEYSTORE_PASS=android \
DASH_KEY_PASS=android \
DASH_ALLOW_UNOFFICIAL_SIGNING=1 \
  ./tools/build-kernelsu-next-module.sh
```

Development builds still pass every packaging check, but they are named
`...-dev.zip`, they print `SIGNING=development`, and they never overwrite
`out/Dash-Essential-KernelSU-Next-Magisk.zip`. They cannot update a device that
carries a release-signed copy without first removing that application.

## CI build

`.github/workflows/build-dash-essential-module.yml` runs the same sequence on an
Ubuntu x86_64 runner: Flutter 3.44.8, Android platform 36 with build-tools and
an NDK, `aarch64-linux-android` Rust, the pinned engine prebuilt, then
`tools/build-kernelsu-next-module.sh` with a development key. It uploads the
module ZIP, its checksum, and the APK as workflow artifacts, and can be started
from a tag push or by hand.

To keep one stable development signature across runs, create a JKS with alias
`dash-essential-development` and store and key password `android`, base64-encode
it, and save it as the `DASH_DEV_KEYSTORE_BASE64` repository secret. Without the
secret each run generates a fresh key, so installs replace each other.

Version 1.18.4 introduces the replacement signing identity. Its public fingerprint
is recorded in `android/package/release-cert.sha256`. Keep the corresponding
private keystore outside the repository and retain it for subsequent releases.
The certificate subject retains its original development name; the fingerprint,
not that display name, determines Android update compatibility.
