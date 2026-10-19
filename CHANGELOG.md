# Changelog

All notable changes are documented here.

## Dash Essential port for MT6991 (`dash`)

Device-port edition of Rodin Essential, based on upstream release `v1.18.5`.
See [NOTICE](NOTICE) and
[Source and credits](README.md#source-and-credits) for attribution to the
original project and its author, NEESCHAL-3.

The sections below describe upstream Rodin Essential releases and keep their
original wording.

### Changed in this port

- Hardware handling rebuilt against the shipped `dash` kernel, device tree
  and ROM dump: CPU and GPU frequency tables, thermal zones and cooling
  devices, MediaTek GED boost/ceiling OPP indices, UFS and DVFSRC memory
  nodes, touch and display interfaces, and the resolution and density
  baseline.
- Application package renamed to `io.github.neeschal.dashessential`, root
  module id to `nees_dash_essential_backend`, SELinux names moved into the
  `dash_*` namespace, and application, module and binary strings renamed.
- The KernelSU Next / Magisk root module is the only integration built and
  supported; upstream's AOSP ROM integration is not built here.
- Releases are signed with this port's own key, which is never committed, and CI
  verifies the signer against `android/package/release-cert.sha256` before
  anything can be called a release. Builds without those secrets fall back to a
  throwaway development key and a `-dev` suffix. The upstream release signing
  key is not held by this derivative;
  `android/package/UPSTREAM_RELEASE_CERT.sha256` records its fingerprint for
  provenance only.
- The Touch Bridge failure is diagnosed instead of silent. The daemon records
  why the touch profile could not be applied, exposes it as `touch_error` and
  `touch_error_code` in the snapshot, and the application and the module action
  show the cause rather than a bare "Failed".
- The in-memory touch timing patch is best-effort on `dash`. The shipped
  `libtouchreport_hal.so` does not carry the upstream timing block, so a missing
  block is reported and skipped instead of aborting the whole touch apply; the
  vendor touch HAL path stays authoritative.
- The settings audit reports a GPU performance profile only when the platform
  actually refused it. The readback compared the acceptance instead of its
  absence, so a profile that was in force was logged as `not in force` while a
  profile that really had failed was reported only by the apply error.
- Application links point at `https://github.com/afrizal1211/dash-essentials`,
  the `POCOX8ProMaxID` Telegram community, and the upstream Rodin Essential
  source repository.
- The upstream Flutter embedder engine release `v1.18.5` (Flutter 3.44.8) is
  pinned as the Dart/AOT runtime by `tools/fetch-flutter-engine-prebuilt.sh`.
- Per-app CPU ranges apply even when a cluster is booted with its core
  offline. The capability check no longer rejects `CpuRange(policy)` just
  because the online kernel exposes no frequency table for that policy; the
  range is validated by the live apply path, which verifies writes and rolls
  back on failure.
- The MI thermal config mode (sconfig) is directly controllable. New daemon
  commands `SET thermal.sconfig <mode>`, `ACTION thermal.sconfig.reset` and
  `GET thermal.sconfig`, a persisted consumer choice (`thermal_mode`, -1 =
  follow mi_thermald) that survives reboots and control enable/disable, and
  drift reassertion by the CPU frequency guard while no custom CPU range owns
  the thermal configuration. Reset and disable restore the journaled OEM
  value. The host bridge exposes the live mode and the app CPU screen gains a
  mode selector with OEM Reset.


## 1.18.6

Codename: Aurora.

### Fixed

- Changing the GPU performance profile could fail permanently and name a cause
  that did not exist. The per-app ownership map also carries recovery tokens
  written when a daemon restart or a failed restore left an override half
  applied, and the global-command gate treated any key in that map as a
  foreground profile holding the control. `SET perf` was therefore rejected
  with a message blaming an app that was not running, and nothing ever cleared
  the key. The gate now asks who actually owns the control: only an applied
  foreground profile blocks a global change, a pending restore says so, and a
  stale recovery token no longer locks the GPU out for the rest of the
  session. Per-app recovery also restores every control instead of aborting at
  the first failure, which is what stranded those tokens.
- The diagnostics screen marked "System Optimizations" as failed for a live GPU
  profile. The apply path accepted a profile under a vendor thermal ceiling but
  published `perf_verify_ok` from the stricter check, so the screen read
  `0 / 1 active` for a profile that was correctly in force. The apply and the
  background guard now publish the same verdict.
- A transient servicemanager miss was reported as a missing controller. The
  touch apply fell through to a fallback that can only fail on a non-Goodix
  panel, and the health screen could show Touch Controller and Display Engine
  as Unavailable while the HAL was fine. Both the apply and the snapshot now
  retry briefly before concluding that a HAL is gone.
- The touch fallback message no longer implies that the panel cannot do
  240/480. Dash's Novatek driver can; what was missing is the vendor HAL, the
  only route to it, and the panel has no generic report-rate node. The error
  code the application displays is unchanged.
- The in-memory touch timing notice no longer repeats on every keepalive
  apply. It is logged when the reason changes and cleared after a successful
  patch, which turns 124 identical lines per boot into one.

### Added

- Settings changes that fail, or that answer `OK` without the hardware
  actually moving, are recorded as `DASH_SETTING_PROBLEM` in the module log,
  beside the touch diagnostics. GPU profile, governor, power policy, min and
  max frequency and uncap requests are read back after the write, so "the app
  says it changed" and "it changed" are no longer the same claim. Each problem
  is logged once when it appears and again only after it clears.
- Uninstalling the module from KernelSU Manager removes
  `/data/adb/dash-essential`: the settings file, the service intent, the clock
  originals, the per-app profiles and their recovery journal, the watchdog lock
  and the log. ROM-native installs keep the ROM's own state in
  `/data/system/dash-essential` and drop only module-owned artifacts. A
  contract test keeps the cleanup from regressing.


## 1.18.5

Codename: Aurora.

### Added

- Per-App Controls for individual touch response, refresh rate, CPU core/range/
  governor and GPU settings. Profiles default to Follow global; the master
  switch starts off. Saved profiles work independently of the app and restore
  previous global/ROM controls when leaving the foreground app or disabling
  overrides. Includes app icons, search, optional system-app visibility and
  individual/reset-all actions.
- Memory DVFS & UFS hub with LPDDR5X/UFS 4.0 driver readings, Dynamic Range,
  Exact Lock, supported-frequency sliders and OEM Reset. Session controls
  survive app closure but restore originals on daemon restart or reboot.
- Bypass Charging Quick Settings/Control Center tile with matching icon,
  on/off state feedback and long-press access to Charging Control.
- Connected page transitions, predictive Back previews on supported Android,
  touch-following lighting, spring press feedback and consistent haptics.
- Rotating colour-accented Control Hubs headlines.

### Improved

- Home/Control Hubs layout, glass headers, light-mode card boundaries, dividers,
  icons, typography and readable descriptions throughout the interface.
- Dock dragging/tab switching, page opening/Back motion, gesture cancellation,
  slider value indicators, feedback-card clearance and keyboard/navigation insets.
- Per-app foreground ownership and global/ROM restoration, transient CPU core
  write handling, bounded asynchronous control requests and Android rendering
  surface lifecycle handling.
- AOSP and unpacked-ROM integration with scoped charging-parent traversal,
  Per-App Controls and subsystem policy, current framework-adapter validation
  and updated porter instructions.

### Removed

- Double Tap to Wake controls and daemon handling. ROM ownership is unchanged.

Full user-facing release notes: [v1.18.5 — Aurora](docs/releases/v1.18.5.md).

## 1.18.4

Released on 4 October 2026.

### Added

- Kernel-supported bypass charging with Immediate and 20/40/80/90% threshold
  choices, persisted independently of the app, and measured status reporting.
- Whole-app hardware-control pause and reset controls.
- OEM Control choices for touch sampling, display colour and temperature.
  Fresh or missing settings leave those features under ROM ownership; existing
  explicit choices remain saved.
- System Colors: system-wide Material You palettes with custom seed colours,
  wallpaper-based colours, palette styles, fine-tuning and reset controls.
- An unpacked-ROM integration package with partition copy destinations,
  filesystem metadata, certificate-bound application policy and a full porter
  guide. It contains Rodin-only policy additions and a merge tool using the
  porter's own target ROM policies, not whole-ROM replacement policies.
- AOSP integration instructions and a scoped platform-policy preparation helper
  for the native touch timing interface.

### Fixed

- Touch ownership release is serialized with wake and boot restoration so an
  older queued restore cannot resurrect a fixed profile after selecting OEM.
- Display OEM Control stops future overrides without forcing a guessed stock
  colour mode. The current appearance may remain until the ROM reapplies it.
- Hardware reset invalidates applied-state caches, and bypass verification is
  retained across page changes without redundant unchanged kernel requests.
- Dock clearance and card text wrapping improve readability. App-facing
  descriptions use the full Rodin Essential name.
- Refined Home, Control Hubs, Support, charging cards, confirmation dialogs and
  haptics, including a continuous bypass-threshold selector.
- Root-module migration handles the signing-key rotation for user-installed
  copies while preserving daemon settings. Application-local preferences reset
  during this one-time migration; differently signed ROM-native updates remain
  rejected rather than bypassing Android package identity.
- ROM application policy uses certificate-bound IPC, normal application MCS
  isolation and scoped daemon hardware permissions. Policy tests no longer
  treat a runtime-mode compile as a strict neverallow pass.
- App, daemon/host packages, module metadata and About label are synchronized
  at 1.18.4 / code 11804. The matching IPC protocol remains 13.6.
- System Colors now writes the version-correct Android Monet contract: the
  legacy palette/accent pair on Android 12 and palette/style fields on Android
  13 and newer.
- Wallpaper mode now restores Android's explicit `home_wallpaper` source so
  the palette follows later wallpaper changes.
- Custom palette changes require verified native resource regeneration.
  Settings-only changes on incomplete OEM implementations are rolled back and
  reported as unsupported instead of being presented as applied.
- Palette readback uses a longer bounded settle window for slower OEM overlay
  transactions while preserving conflict detection and rollback safety.

## 1.18.3

### Fixed

- Restored the complete v1.18.0 Touch Response pipeline: native 240/480 Hz
  timing for the 250/500 profiles and the verified one-millisecond Android
  output scheduler for the 1000 profile.
- Preserved the authenticated reverse and privileged-loopback transports,
  bounded framework startup, transactional persistence, and daemon-first boot
  ordering that prevent a healthy KernelSU Next or Magisk backend from
  appearing Offline.
- ROM-native 1000 Hz output now opens the dedicated Rodin input device directly
  and no longer requests `SYS_PTRACE`, `DAC_OVERRIDE`, or `DAC_READ_SEARCH`.
  This removes the Android 17 platform-neverallow conflicts without granting
  the application root or privileged Android identity.
- AOSP policy validation now distinguishes pre-existing OEM platform-policy
  diagnostics from violations introduced by the Rodin integration while still
  rejecting any Rodin neverallow failure.
- Application, Rust workspace, KernelSU/Magisk module, manifest, interface, and
  release metadata are synchronized at version 1.18.3 / code 11803.
- The KernelSU/Magisk installer now supports signature-compatible ROM-native
  installations as a reversible update layer. It preserves native state, stops
  the init-owned daemon before module takeover, and restores the ROM APK and
  native service when the module is removed. Cross-signature updates still fail
  safely without deleting application data.

## 1.18.2

### Fixed

- KernelSU Next and Magisk communication no longer depends on an
  `untrusted_app` process connecting into a root-manager SELinux domain. The
  daemon now initiates an authenticated reverse socket to the normal APK, and
  both sides verify the peer UID with `SO_PEERCRED`.
- Module Action distinguishes root-only daemon health from a connection that
  was successfully completed by the Android app.
- Root modules now provide an authenticated privileged-loopback transport for
  ROMs whose SELinux policy blocks Unix `connectto` in either direction. The
  app proves the privileged-port boundary from its own sandbox, and the daemon
  resolves the accepted client's exact package UID from `/proc/net/tcp` before
  serving hardware commands. Cached transports and a temporarily occupied
  listener port recover automatically without relaunching the app or rebooting.
- Root-module installation no longer modifies live SELinux policy or depends on
  root-manager domain names. The script-only package uses no system overlay and
  therefore requires no KernelSU metamodule.
- Root-module updates verify the APK version and official signing certificate.
  A differently signed installed copy is reported clearly and is never removed
  automatically.
- Persisted state is committed transactionally with file and directory sync, so
  an applied command cannot be reported as durable when the state write failed.
- The native daemon binds its socket and enters the accept loop before any
  framework telemetry or restore command can wait on `system_server`. Framework
  command execution is bounded, and SELinux permits only the required reply-pipe
  direction, preventing a healthy native service from appearing Offline.
- Display, GPU, CPU, UFS, charging, and ZRAM commands now reject failed or
  mismatched live readback instead of saving a false success. Touch commands
  require an accepted vendor transaction before persistence is committed.
- TouchFeature setter replies now parse both the AIDL status header and vendor
  result instead of mistaking a delivered Binder transaction for an accepted
  panel command.
- Touch Response retains the proven v1.18.0 250, 500, and 1000 profiles. Native
  modes use the 240/480 Hz timing blocks, while 1000 keeps the 480 Hz source and
  restores the verified one-millisecond Android output scheduler.
- The unused per-application profile subsystem and its package-query surface
  have been removed from the daemon, host, manifest, and interface.
- AOSP integration now preserves an explicit APK signing identity, maps that
  certificate and package to the dedicated `rodin_app` domain, labels only the
  required exact generic Mali and Goodix sysfs paths, and keeps the v1.18.0
  touch permissions isolated to the daemon policy for device-tree review.
- ROM-native policy again includes the narrowly scoped touch-HAL process and
  input access required by the v1.18.0 1000 Hz output path.
- Application, module, daemon protocol, documentation, and release metadata
  are synchronized under a new version so different payloads are no longer
  distributed under the same release identity.

## 1.18.0

### Added

- CPU Core & Frequency hub with independent frequency control for the efficiency,
  performance, and prime policies.
- Dynamic minimum/maximum ranges and exact `min = max` locks at any frequency
  exposed by the active kernel OPP table.
- Separate saved-target and live-effective readback, per-policy drift status,
  verified writes, and an OEM range reset.
- ROM-native logical-density detection and automatically scaled resolution
  presets instead of a fixed 520 DPI baseline.
- Live/selected refresh-rate telemetry and persisted custom resolution state.

### Changed

- CPU frequency requests are validated against the live driver table instead of
  accepting arbitrary values that the kernel may silently round.
- Frequency targets remain fully independent from CPU governors and GPU modes.
- CPU topology labels now identify the Dimensity 8400's three all-Cortex-A725
  groups instead of the previous generic A520/A720/X4 labels.
- Native host/daemon protocol updated to 13.3 for CPU, display, and touch-path
  telemetry.

### Fixed

- KernelSU Next and Magisk installations now generate an app-to-daemon socket
  rule for the root manager's live SELinux domain (`su`, `ksu`, or `magisk`).
  This prevents a healthy daemon from appearing Offline on ROMs that omit the
  corresponding `connectto` allowance.
- Root-module startup now reapplies the detected socket rule to the live policy
  after boot through KernelSU's `ksud` or Magisk's `magiskpolicy`. This covers
  manager builds that skip or race the early `sepolicy.rule` loader, and Module
  Action reports the result and patch engine used.
- The root-module daemon validates every socket peer with `SO_PEERCRED` and
  accepts hardware commands only from UID 0 or the exact Android UID assigned
  to the bundled Rodin Essential package.
- CPU range application now selects Rodin's OEM `thermal-nolimits` policy before
  updating the per-policy Xiaomi thermal ceiling, MediaTek PowerHAL request, and
  cpufreq limits. Exact locks remain at the full 2100/3000/3250 MHz policy
  maxima without changing a governor, and requests fail instead of being saved
  when live verification does not match.
- The previous Xiaomi thermal configuration is saved before the first custom
  CPU range and restored when the last range is reset. `mi_thermald`, AOSP
  `thermald`, and the MediaTek thermal HAL remain running throughout; the boot
  restore and drift guard also verify the live OEM configuration.
- Xiaomi's fresh-boot `sconfig=-1` sentinel is treated as the normal thermal
  configuration, allowing persisted exact CPU locks to restore before any
  explicit vendor mode has been published.
- Frequency cards show the live governor selected elsewhere in the app, provide
  clearer apply/reset guidance, and emit discrete haptic ticks while sliding.
- KernelSU Next and Magisk startup now waits for Android boot completion, then
  repeats the complete persisted-state transaction across the vendor settling
  window. Saved controls remain daemon-owned when the app is force-stopped.
- Touch persistence verifies the active THP timing instead of trusting cached
  state, so late vendor defaults are detected and corrected automatically.
- Native 250 mode now applies Rodin's dedicated TouchFeature sensitivity latch
  instead of sharing the 500-mode calibration that could silently fall back to
  roughly 135 Hz while the HAL still reported 240 Hz.
- The 1000 Hz output scheduler now discovers the actual multitouch event among
  every TouchFeature service descriptor and can attach directly to the panel
  event when FocalTech firmware does not retain a compatible service handle.
- Repeated boot and watchdog restores no longer reset an already-correct ZRAM
  device; compression, size, and swappiness changes are now idempotent.
- Resolution telemetry refreshes after framework startup, distinguishes live
  adaptive refresh from the ROM-selected rate, and no longer reports a false
  hardcoded 60/120 Hz value.
- Cold launches now present a plain application surface instead of exposing an
  oversized launcher-icon transition, while appearance loading and daemon
  startup no longer block the first application frame.
- Extracted Flutter assets and ICU data now use a deterministic content stamp.
  Unchanged runtime files are reused on later cold starts, while APK updates or
  incomplete cache files force a verified refresh before Flutter starts.

## 1.17.1

### Fixed

- GPU performance modes no longer change CPU governors or CPU frequency
  ranges. Existing CPU settings remain independent when switching GPU modes.
- Legacy CPU values written by earlier GPU profiles are migrated once without
  overwriting separately customized CPU settings.
- Vendor CPU and platform thermal services remain running in every GPU mode;
  Gaming Dynamic and Extreme Beast retain ownership only of the Mali cooling
  constraint required by their GPU policy.
- GPU profile transitions are serialized with the maintenance and dynamic
  guards, preventing the previous mode from reasserting stale values during a
  rapid mode switch.

## 1.17.0

### Added

- Complete Rust privileged daemon and command-line health client.
- Persistent CPU, GPU, touch, display, charging, ZRAM, and UFS state.
- Extreme Beast, Gaming Dynamic, Stock Balanced, and Battery Saver transactions.
- Live Mali frequency/load readback, GED state, governor, and power-policy UI.
- Native 240/480 Hz touch timing and 1 ms Android output mode.
- Goodix and FocalTech detection through the Rodin touch vendor stack.
- UFS scheduler application and verification across detected logical units.
- Motion-feel control and refined application transitions.
- Combined KernelSU Next and Magisk module with bundled unprivileged APK.
- AOSP `/product` integration bundle, init service, and split SELinux policy.

### Changed

- The APK remains an ordinary app UID; all privileged operations are isolated in
  the daemon.
- GED is profile-owned: enabled only for Gaming Dynamic and Extreme Beast.
- Profile, touch, storage, CPU, and memory settings are reapplied after boot and
  guarded against vendor drift.
- Persisted GPU profiles recover from late MediaTek power-service overrides;
  fixed-frequency restoration verifies the live target OPP before locking DVFS.
- Build output is zero-DEX, release-mode, ARM64-only, and verified for 16 KB APK
  and ELF alignment.

### Removed

- Direct live-partition mutation scripts.
- Empty privileged-permission allowlist packaging.
- Obsolete migration audits, phase markers, and proof-only build scripts.
