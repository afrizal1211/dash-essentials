# Flutter runtime pin

Dash Essential ships its own custom Flutter embedder runtime and does not load
Flutter libraries from the ROM.

The framework engine revision is read from the active Flutter SDK at:

```text
bin/internal/engine.version
```

`tools/build-flutter-engine.sh` compares that value with the engine checkout
before building. A mismatch is a hard failure because the AOT snapshot,
`embedder.h`, and `libflutter_engine.so` must share an ABI revision.

## Current pin

| Component | Value |
| --- | --- |
| Flutter | 3.44.8 stable |
| Framework revision | `058e0af2c2b57e369d905a03ac9748b0ebf543c6` |
| Engine revision | `0cd610717bde95fd88343c64f81c11ba4e5c0010` |
| Dart | 3.12.2 (`e9ed4fc9f1544c58d8a9347c1fc9471d8dd7c465`) |
| `libflutter_engine.so` | `3a8950c7c2f722a4971b418b7328fd6c44c517e62e9473ff3daca43b3c01f704`, 13239712 bytes |
| `icudtl.dat` | `e4133e09a6a24c3c3ba33aec770713418c19133314dd93309ae1538f649d678b`, 9242032 bytes |
| `embedder.h` | `166626fb689d4e77e720c925f18e814a3cd55280999a443d9d1cc244384e37af`, 168433 bytes |

The engine is a release build, so it exports the embedder entry points the host
links against. The published `android-arm64-embedder.zip` is a debug engine and
must not be used as this prebuilt.

Flutter does not publish release-mode embedder libraries to the SDK artifact
service, so `tools/fetch-flutter-engine-prebuilt.sh` installs the v1.18.5
release engine and verifies the digests above plus the revisions compiled into
the binary. `tools/build-flutter-engine.sh` remains the source-build path.

Local engine artifacts are deliberately ignored by Git:

```text
runtime/flutter-engine/prebuilt/android-arm64/libflutter_engine.so
runtime/flutter-engine/prebuilt/android-arm64/icudtl.dat
```

An engine update is complete only after rebuilding the APK and validating zero
DEX, ARM64 loading, 16 KB alignment, first frame, EGL lifecycle, input,
choreographer pacing, foreground/background transitions, and all backend FFI
entry points on Dash hardware.
