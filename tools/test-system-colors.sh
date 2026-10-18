#!/usr/bin/env bash
set -euo pipefail

DASH_PALETTE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cargo test --manifest-path "$DASH_PALETTE_ROOT/Cargo.toml" \
    -p dash-essential-daemon system_colors::tests

# backend_bridge.rs resolves `crate::dash_host_open_url_jni` against the stub in
# tools/tests/system-colors-host.rs and uses serde_json, so it cannot be built
# with a bare `rustc --test`; run it through the manifest beside that harness.
cargo test --manifest-path "$DASH_PALETTE_ROOT/tools/tests/Cargo.toml"

cd "$DASH_PALETTE_ROOT/ui/flutter"
flutter test test/system_colors_test.dart test/system_colors_preview_test.dart \
    test/system_colors_monitor_test.dart test/backend_connection_test.dart
