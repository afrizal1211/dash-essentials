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
  mode selector with OEM Reset. Per-App Controls can now also select an MI
  thermal mode per app: a profile's choice is written on focus, ownership
  blocks global `SET thermal.sconfig` writes, the guard pauses reassertion
  while owned, and leave/restore puts the saved global selection (or the
  journaled OEM value when none exists) back.
- The module log is fresh on every boot and every new daemon run. The
  previous contents rotate to `backend.log.1` (one generation) instead of
  appending across reboots and only rotating at one megabyte.
- Per-app CPU profiles now apply to parked clusters. When the prime core
  (or a whole cluster) is offline, cpufreq hides its scaling nodes, which
  used to fail the profile with `unsupported per-app control:
  CpuGovernor(7)` / `CpuRange(7)`. A parked cluster's governor is now
  accepted (live sysfs verifies the write), the capability probe borrows
  the shared governor set, applying or restoring a range/governor brings
  the cluster's cores back online, and release parks them back to the
  captured mask. Per-app GPU controls were audited for the same parked
  resource class: the Mali devfreq nodes persist through power collapse and
  GPU profile writes fail soft. Extreme Beast (profile 3) additionally
  checks its accepted state by configuration (1612/1612 devfreq bounds,
  performance governor, GED boost pipeline, always_on policy) and no
  longer requires the live OPP clock to already read 1612, which an idle,
  clock-gated GPU cannot report at toggle time; the clock check stays in
  the strict verified path for diagnostics.
- Waking edge cases from device testing: a cluster that just left park
  briefly reports EBUSY on its cpufreq nodes, so per-app apply/restore now
  wait for the policy to finish waking instead of rolling the profile
  back; and while the GPU sleeps, MediaTek's power service re-clamps the
  devfreq floor to its stock idle value (1 MHz). A below-target Beast
  floor and DVFS are only accepted together with a below-target clock
  committed, so GPU waking must still show the full locked state; the
  background GPU guard reasserts the floor until the ladder commits 1612.
- A fresh sakura launcher icon replaces the inherited upstream emblem:
  an original pink-gradient squircle with the Dash monogram, redrawn at
  every launcher density (nothing from ArchiveTune is reused).
- In-app updates. The app fetches the latest GitHub release, downloads the
  APK or driver-module zip into its cache, and verifies it against the
  release's `*.sha256` asset (a pure-Dart SHA-256 that the root daemon
  re-verifies independently before acting). Commands `SET update.install_apk
  <path> <sha256>` install through `cmd package install -r`, and
  `SET update.flash_module <path> <sha256>` stages the zip under
  `/data/adb/dash-essential/update` and flashes it via `ksud` or Magisk;
  both refuse any path outside the app cache allowlist and refuse missing
  or malformed checksums. CI now publishes `Dash-Essential.apk.sha256`
  alongside the zip and APK so the updater never has to trust a bare
  download.

## 1.18.19

Codename: Nihal. **Pre-release.** The Gaming Dynamic profile, which was the
one profile that never worked on this device.

- Gaming Dynamic's clock is no longer left where the vendor put it. The load
  ramp compared its target against its own cache instead of against the live
  node, so once the MediaTek power service reclaimed the floor -- which it
  does every couple of hundred milliseconds -- the ramp never wrote again and
  the clock stayed at the 338 MHz floor. The ramp compares against the live
  node now, so a reclaim is corrected on the next tick. This is why Balanced
  and Extreme Beast worked while only Gaming failed: Balanced's governor is the
  vendor's own, so the vendor drives the clock there, and Beast freezes DVFS
  at the target, but Gaming depends on the ramp's write actually landing.
- The floor is published as a pair, the ladder index on the GED node and the
  frequency on the `gpu_bottom_freq` / `gpu_cust_boost_freq` module
  parameters, and both are written together. The driver resolves the floor from
  both, so a ramp that moved the index while the frequency still named the
  minimum would have kept the clock on the floor.
- The comment that described the boost node as the frequency the GPU runs at
  is gone; it is the floor, and it was the wrong reading that the last few
  releases were built on.

## 1.18.18

Codename: Mizar. **Pre-release.** The dashboard's GPU monitor stops showing a
dash for a clock that is really there, and the GPU controls stop quoting a
frequency this device does not have.

- The live GPU clock on the Home dashboard and in the Live overview now shows
  the reading whenever there is one. The Mali driver gates the GPU into a
  26 MHz deep-idle clock when it is not doing any work, and the dashboard
  treated anything under 260 MHz as "no reading" and showed a dash, while the
  Mali screen showed the clock. 260 MHz was the lowest clock upstream's device
  ever reported, so the floor doubled as the "is the GPU working" test; on
  this one it is not. The Home tile now says "GPU idle" for a gated GPU and
  "Live clock" when the GPU is running.
- Every GPU frequency the app quotes is the device's own ladder. Dash's Mali
  ladder starts at 338 MHz and has no 260 MHz point at all, so the Gaming
  Dynamic, Stock Balanced and Battery Saver presets, the profile descriptions
  and the readback fallbacks were all naming a frequency that does not exist
  and a minimum the daemon rejects.

## 1.18.17

Codename: Merak. **Pre-release.** Rebased onto upstream Rodin Essential's
GPU actuation model, which this port had replaced with an inverted reading of
the same nodes.

- The GPU boost node is a **floor**, not the clock the GPU runs at. Upstream
  writes the ladder position of the requested minimum to
  `custom_boost_gpu_freq` and the frequency itself to the
  `gpu_bottom_freq` / `gpu_cust_boost_freq` module parameters; the ceiling
  gets the same treatment on `custom_upbound_gpu_freq` and
  `gpu_cust_upbound_freq`. The port had concluded the opposite -- that the
  boost node named the frequency the GPU runs at -- and wrote the fastest OPP
  there for every profile, with the frequency parameters left untouched as
  "reporting only". The field logs show why that reading was wrong: the
  MediaTek power service publishes index 51 there, which is exactly the
  338 MHz floor a profile asks for. Under the floor reading the vendor's own
  write is a benign floor, and under the target reading it looked like a
  hostile pin, which is what the last few releases were built to fight.
- Every profile now publishes the floor and the ceiling the way MediaTek's own
  tooling does it: the ladder index on the GED node and the frequency on the
  module parameter. The ladder is Dash's own 52-entry table, so the indices
  are resolved from the live table rather than from the historic 26 MHz
  formula.
- The Gaming Dynamic load ramp moves the **floor** with the load again, the
  way upstream does it, instead of moving the ceiling and leaving the floor
  pinned. The ramp still compares against the live node, so the vendor's
  reclaim of the floor is corrected on the next tick.
- Extreme Beast pins the floor to the fastest OPP, publishes 1612 MHz on the
  module parameters and freezes DVFS once the live clock reaches the target,
  which is upstream's lock condition. The port's stricter "the boost node must
  name the fastest OPP" check is gone with the model it belonged to.
- Stock Balanced's devfreq ceiling is restored when the MediaTek power HAL
  lowers it while the display idles. The governor and the power policy stay
  untouched there: the vendor owns them, and the platform's own `dummy`
  governor is still accepted as a valid reading rather than reported as a
  fault.
- The port's diagnostics are kept: the measured clock from the GPUFREQ status
  dump, the limit-table readback, the verified thermal ceiling and the
  per-app override handling all stay as they were.

## 1.18.16

Codename: Alcyone. **Pre-release.** Fixes the Per-App Controls GPU profiles
and removes the code that the earlier GPU work left behind.

- A per-app GPU profile is now actually maintained while the app is in the
  foreground. The background guard skipped the GPU entirely during an
  override, which left the override's boost target to the MediaTek power
  service -- and that service rewrites the node to the slowest OPP every
  couple of hundred milliseconds. Since the boost target is the frequency the
  GPU runs at on this firmware, the app's profile silently ran at the 338 MHz
  floor from the moment the vendor service touched it. The guard now maintains
  the override's own profile instead of the global one, and the profile the
  override applied is reconciled at every ownership boundary.
- Releasing a per-app GPU override no longer rewrites the user's global
  profile. The restore called the persisting global apply, which wrote the
  profile choice, its frequency bounds and the thermal-ceiling flag back into
  the persisted state, so letting go of an app's override silently changed the
  global choice and dropped the user's own GPU preferences. It now uses the
  hardware-only apply.
- The override is released before the global profile is restored, so the
  guard cannot reassert the app's profile over the global one in the window
  between the two writes.
- Obsolete code removed. The boost target used to be written as a frequency
  floor, which needed a "slowest OPP at or above the request" bound that no
  production path has used since the boost target became the frequency the GPU
  runs at; the bound and its dead branch are gone. A dead write helper, two
  unused NDK bindings and the orphaned buffer type behind them are gone too.
  The app's nested-detail back stack was removed with it: the method that
  populated it was never called, so the field was always null and the branch
  that read it could never run.

## 1.18.15

Codename: Spica. **Pre-release.** The GPU frequency reporting and the thermal
ceiling are now measured rather than assumed, and the daemon stops claiming a
ceiling it cannot lift. The clock behaviour itself is not yet settled: this
release exists to get a field log that shows the real clock next to the
requested one.

- The live GPU clock now comes from the GPUFREQ status dump's measured clock
  (`[GPU   REALOPP]`) instead of GED's `current_freqency` node. That node
  reports the nominal frequency of the OPP the vendor's power HAL last
  requested, not the clock the hardware ended up at: with the daemon holding
  the devfreq floor at 338 MHz the node kept reading `51 338000` while the
  status dump showed `OutFreq: 583882`, so the dashboard reported 338 MHz for a
  GPU that was running at 583 MHz. The field log now prints the measured
  clock, GED's nominal reading and the requested OPP side by side, so a "stuck
  at 338 MHz" report can be checked against what the GPU really did.
- The thermal ceiling is verified instead of assumed. `/proc/gpufreqv2/limit_table`
  accepts the write -- the driver returns the byte count -- but on this ROM the
  row never changes: fifteen write formats were tried on the device, including
  the short `<id> <up_enable> <low_enable>` form the community MTK GPUEB unlock
  uses for every row, and the readback was byte-identical afterwards. The table
  is owned by the vendor's power HAL. The daemon now checks the enforced
  ceiling before and after the write, refuses to record an unlock that did not
  happen, and the app says the vendor service owns the table instead of
  claiming a ceiling was raised.
- The limit table is read back and reported in the field log, naming every row
  that carries a limit, the index it caps at and the frequency that index
  resolves to. The enforced ceiling is taken from the live `[PPM Ceiling]`
  line, which names the row that is actually holding the clock down.

## 1.18.14

Codename: Rigel.

- The thermal ceiling write now actually takes effect. The limit table prints
  seven columns (`id`, `name`, `priority`, `ceiling`, `floor`, `c_enable`,
  `f_enable`) but the write was sent in the short three-field form, which the
  firmware parses as `id`, `ceiling` and `floor`: `c_enable` was never
  changed, the row stayed enforced at its stored index, and the GPU kept
  running at the 1430 MHz plateau while every other readback said the profile
  was configured. The full column form is written now, and the write is
  confirmed by reading the table back, so a firmware that wants the other
  layout is still handled.
- The limit table is read back and reported in the field log, naming the row
  that is actually holding the clock down together with the index it caps at
  and the frequency that index resolves to. The enforced ceiling now comes
  from the live `[PPM Ceiling]` line, which sits at offset 581 of the
  GPUFREQ status dump and was being cut off by the small node buffer, so the
  diagnostics always reported an unknown ceiling.
- A published thermal ceiling below the lowest OPP is the deep-idle marker the
  framework emits for a clock-gated GPU, not a one megahertz cap. It is
  ignored now, which stops the diagnostics from reporting an idle GPU as
  thermally capped.
- The MediaTek power service's own `dummy` governor is no longer treated as a
  profile fault. Requiring a profile's own governor name made the guard
  reassert every 500 ms against a vendor it could not win, reported a working
  profile as failed in the diagnostics, and wrote the same field log line
  twice a second. The governor name is inert on this SoC, so the boost target
  and the ceiling are what the profile is judged on. Extreme Beast keeps the
  strict check: it freezes DVFS, so the governor is part of the locked state.
- The profile drift log is rate limited to one line every 30 seconds. The
  reassert keeps its own cadence, so a node the vendor keeps reclaiming can no
  longer bury every other event in the field log.

## 1.18.13

Codename: Lyra.

- The GPU now reaches its 1612 MHz OPP. Two separate firmware clamps were
  holding it back and neither was fully lifted before.
  - The MediaTek GPUFREQ limit table carries **two** thermal ceiling rows, and
    the firmware enforces the strictest enabled one. `THERMAL_EB` caps at
    1430 MHz and `THERMAL_AP` at 1196 MHz, and the live status line named
    `THERMAL_AP` (`LimitIndex: 35, Limiter: 4`) as the row actually in force.
    The unlock lifted `THERMAL_EB` only and then re-armed `THERMAL_AP`, so a
    1196 MHz cap stayed in place and the GPU ramped but never reached 1612 MHz.
    Both rows are now lifted together, and the stock ceilings come back with
    Battery Saver, the conservative profile.
  - The MediaTek power service continuously rewrites GED's boost target
    (`custom_boost_gpu_freq`) to index 51, the 338 MHz floor, and on this
    firmware that node is the clock the GPU actually runs at. The background
    guard now watches the boost target on its own and restores it to the
    fastest OPP as soon as the vendor reclaims it. Stock Balanced is included:
    the vendor power HAL owns the governor and the power policy there, but the
    boost target belongs to the profile, and without the check Balanced could
    never recover from a reclaim. Extreme Beast also refuses to freeze DVFS
    while the target names a slow OPP, because freezing it there would pin the
    GPU to that OPP.
- The thermal ceiling readback now reports the ceiling the firmware is really
  enforcing. The live `[PPM Ceiling]` limit index is resolved through the
  firmware OPP ladder and combined with the platform's published ceiling, so
  the diagnostics screen and the "thermally capped" notice name the real cap
  (1196 MHz or 1430 MHz) instead of a value that does not match what the GPU
  is held to.
- The daemon no longer rewrites its state file ten times a second. The GPU
  guard re-applied its state on every tick, and each write did two `fsync`
  calls, which put twenty flash syncs per second on the device's storage for
  no change at all. A state mutation that changes nothing is now skipped, and
  the thermal unlock is logged only when it actually transitions.
- The in-app thermal ceiling notice and toast now describe what the unlock
  really does: both GPU thermal ceiling rows are lifted, so the clock is only
  limited by the cooling available.

## 1.18.12

Codename: Astraea.

- Module flasher now searches additional common paths (KernelSU `/data/adb/ks/ksud`,
  APatch `/data/adb/ap/ksud`, Magisk `/sbin/magisk`, `/system/bin/magisk`,
  `magisk64`) and the "no module flasher found" error now lists all checked
  locations instead of an empty list.

## 1.18.11

Codename: Tsuki.

- Per-app GPU controls no longer follow or rewrite the global profile. A per-app
  GPU choice was applied through the global `SET perf` path, which persisted it
  as the user's global profile: a stock global profile dragged an app's gaming
  clocks back down, and changing the global profile rewrote every app. Per-app
  GPU now drives the hardware through a dedicated path that never touches the
  persisted global choice and holds the background drift guard off the Mali
  nodes while the override is in force.
- Extreme Beast now reaches the 1612 MHz OPP instead of settling at 1430. The
  DVFS freeze previously waited for the live clock to read 1612 first, but an
  idle GPU power-collapses below its floor and the load governor's steady state
  sits on the 1430 MHz plateau, so the lock never armed. Beast now locks once
  the 1612 MHz floor is in force (devfreq floor or GED floor index 0), which the
  guard re-asserts every 100 ms.
- Extreme Beast reports a thermal clamp honestly. On this SoC the MediaTek
  thermal firmware holds a stock 1430 MHz GPU ceiling (`THERMAL_EB`) that no GED
  or devfreq write can beat; Dash now reads the live thermal ceiling and PPM
  limiter, logs `beast thermally capped` with the exact node state, and shows a
  "thermally capped" notice instead of implying 1612 is live.
- New opt-in "unlock ceiling" control raises the stock 1430 MHz GPU ceiling when
  the user chooses to, while the AP thermal safety cap stays armed. It is off by
  default and reverts cleanly.

## 1.18.9

Codename: Hoshi.

- Gaming Dynamic and Battery Saver stop reasserting in a loop. The periodic
  drift guard compared the full profile including the GED boost pipeline, but
  the vendor GED worker owns that master switch and keeps it on, so the check
  never settled and rewrote the profile every 500 ms forever. The guard now
  compares only the nodes the vendor stack actually reclaims — devfreq ceiling
  and floor, governor, power policy, DVFS gate — and logs the GED pipeline
  state alongside the drifted readings so the two can never be confused again.
- A Beast GPU restore that is armed but not yet locked no longer blocks the
  profile controls. When Extreme Beast is applied on an idle GPU the OPP is
  written and persisted but cannot be read back until the GPU wakes; this
  "armed" reply was treated as a hard per-app restore failure, leaving the
  control stuck in a restoring state that rejected every later profile change
  with a phantom "still restoring this control" error. An armed Beast restore
  now counts as complete and locks the moment the GPU becomes active.
- Leaving Extreme Beast for Gaming Dynamic restores the load ramp. The
  performance governor Beast leaves behind is now detected as drift and
  rewritten to `simple_ondemand`, so Gaming Dynamic resumes scaling instead of
  staying pinned.

## 1.18.8

Codename: Sakura.

- Gaming Dynamic and Battery Saver keep their GPU settings. On this SoC the
  vendor GED/power stack quietly reinstates its own ceiling and devfreq ladder
  while the GPU idles, collapsing the Mali clock to the lowest OPP. Only
  Extreme Beast reasserted its configuration every tick, so the other two
  profiles silently lost theirs while still showing as active. The dynamic
  guard now detects the reclamp and rewrites the stable nodes (ceiling, floor,
  governor, GED ceiling index, power policy) on a rate limit, without touching
  the Gaming Dynamic load ramp.
- The Extreme Beast target reads 1.61 GHz everywhere. The preset, the mode
  cards and the live readout said 1.30 GHz while the profile actually locks the
  GPU at 1612 MHz; the copy now matches the hardware ceiling.
- The installed-app chooser resolves display names as you browse. Labels are
  fetched per visible page instead of one all-packages sweep that blocked the
  list and failed silently with no visible names and no hint. A failed batch is
  retried and a `Retry names` action appears when PackageManager cannot be read.
- Dash Essential now keeps a field log. Every profile transition, rejected
  command, per-app apply/restore and GPU drift reassert is recorded in a bounded
  in-memory ring and a size-capped file under the module state directory, and
  exposed to the app as `GET diagnostics.log` so failures can be attached
  instead of guessed at.

## 1.18.7

- The port's releases now carry a codename. `Afuri` is the first one: the
  release tag is `v1.18.7-afuri` and the About screen shows the codename,
  giving the in-app updater an app-build identity instead of relying on
  numeric versions alone.
- The update card says `Your app is up to date.` when the installed module
  version and the app's codename both match the latest release, and only
  offers the component that is actually behind (an APK refresh after a
  module flash, or flashing the module after an APK-only update).

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
