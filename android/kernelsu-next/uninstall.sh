#!/system/bin/sh

MODDIR=${0%/*}
DASH_ROOT=/data/adb/dash-essential
DASH_WATCHDOG_LOCK="$DASH_ROOT/watchdog.lock"
DASH_WATCHDOG_PID="$(cat "$DASH_ROOT/watchdog.pid" 2>/dev/null)"
DASH_PACKAGE=io.github.neeschal.dashessential
DASH_NATIVE_MODE=0
[ -f "$MODDIR/rom-native-mode" ] && DASH_NATIVE_MODE=1

case "$DASH_WATCHDOG_PID" in
    ''|*[!0-9]*) ;;
    *) kill "$DASH_WATCHDOG_PID" 2>/dev/null ;;
esac

for DASH_PROCESS_NAME in dash_daemon dash_essentiald; do
    for DASH_PID in $(pidof "$DASH_PROCESS_NAME" 2>/dev/null); do
        kill "$DASH_PID" 2>/dev/null
    done
done
sleep 1
for DASH_PROCESS_NAME in dash_daemon dash_essentiald; do
    for DASH_PID in $(pidof "$DASH_PROCESS_NAME" 2>/dev/null); do
        kill -9 "$DASH_PID" 2>/dev/null
    done
done

if [ "$DASH_NATIVE_MODE" -eq 1 ]; then
    # The module APK is an Android package-manager update over the matching ROM
    # system app. Revert only that update, keep package data, and return daemon
    # ownership to init. The ROM state directory (/data/system/dash-essential)
    # belongs to the ROM daemon and is never removed.
    DASH_ROLLBACK_RESULT="$(/system/bin/cmd package uninstall-system-updates "$DASH_PACKAGE" 2>&1)"
    case "$DASH_ROLLBACK_RESULT" in
        *Success*|'') ;;
        *)
            # Keep a trace only when the rollback actually failed. A clean
            # rollback has nothing to inspect, and nothing may outlive the
            # module once it is removed from KernelSU Manager.
            printf '%s\n' "$DASH_ROLLBACK_RESULT" \
                >"$DASH_ROOT/native-app-rollback.log" 2>/dev/null || true
            ;;
    esac
    /system/bin/pm enable --user 0 "$DASH_PACKAGE" >/dev/null 2>&1 || true
    for DASH_NATIVE_SERVICE in dash_daemon dash_essentiald; do
        if [ -n "$(getprop "init.svc.$DASH_NATIVE_SERVICE" 2>/dev/null)" ]; then
            /system/bin/setprop ctl.start "$DASH_NATIVE_SERVICE" 2>/dev/null || true
        fi
    done
fi

# Everything the module owns under /data/adb goes with it. KernelSU Manager
# removes the module directory itself, so /data/adb/dash-essential is the only
# place the module would leak: the settings file (state.conf), the service
# intent (service.json), the clock originals, the per-app profiles and their
# recovery journal, the watchdog lock and the log. A leftover watchdog.lock
# also blocks the next install's early-boot guard, and stale recovery tokens
# read as live control ownership to a freshly started daemon.
#
# ROM-native: the daemon and its state belong to the ROM, so only the
# module-owned artifacts are removed and the directory is dropped when empty.
# Standalone: the module owns the daemon, so the whole tree is module data.
# Uninstalling is a deliberate action; updating the module does not run this
# script, so settings still survive an upgrade.
if [ "$DASH_NATIVE_MODE" -eq 1 ]; then
    rm -f "$DASH_ROOT/watchdog.pid" "$DASH_WATCHDOG_LOCK/pid" "$DASH_WATCHDOG_LOCK/boot_id"
    rmdir "$DASH_WATCHDOG_LOCK" 2>/dev/null
    rm -f "$DASH_ROOT/bin/dash_daemon" "$DASH_ROOT/bin/dash_ctl"
    rmdir "$DASH_ROOT/bin" 2>/dev/null
    rm -f "$DASH_ROOT/backend.log" "$DASH_ROOT/backend.log.1"
    rm -f "$DASH_ROOT/state.conf" "$DASH_ROOT/service.json" \
        "$DASH_ROOT/subsystem-clock-originals.json" \
        "$DASH_ROOT/app-profiles.json" "$DASH_ROOT/app-recovery.json"
    [ -f "$DASH_ROOT/native-app-rollback.log" ] || rmdir "$DASH_ROOT" 2>/dev/null
else
    rm -rf "$DASH_ROOT"
fi

exit 0
