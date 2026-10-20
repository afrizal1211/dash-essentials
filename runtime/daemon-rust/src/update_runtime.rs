//! In-app update support: the root daemon verifies a release asset hashed by
//! the app, then either installs the APK with `cmd package install` or hands
//! the module zip to the KernelSU/Magisk/Apatch installer. GitHub access and
//! file transfer stay in the unprivileged UI process.

use serde_json::{Value, json};
use std::path::{Path, PathBuf};

const MODULE_DIR: &str = "/data/adb/modules/nees_dash_essential_backend";
const MODULE_ZIP_STAGING: &str = "/data/adb/dash-essential/update";
const APK_CACHE_PREFIX: &str = "/data/user/0/io.github.neeschal.dashessential/cache/dash-update";
const APK_TMP_PREFIX: &str = "/data/local/tmp/dash-update";

pub(super) fn is_command(cmd: &str) -> bool {
    cmd == "GET update.status"
        || cmd.starts_with("SET update.install_apk ")
        || cmd.starts_with("SET update.flash_module ")
}

fn module_version() -> String {
    std::fs::read_to_string(format!("{MODULE_DIR}/module.prop"))
        .map(|raw| {
            raw.lines()
                .find(|line| line.trim_start().starts_with("version="))
                .and_then(|line| line.strip_prefix("version="))
                .map(|value| value.trim().trim_start_matches('v').to_owned())
                .filter(|value| !value.is_empty())
                .unwrap_or_else(|| "unknown".into())
        })
        .unwrap_or_else(|_| "not installed".into())
}

fn verified_path(path: &str, expect: &str, what: &str) -> Result<PathBuf, String> {
    if !path.starts_with(APK_CACHE_PREFIX) && !path.starts_with(APK_TMP_PREFIX)
        || path.contains("..")
        || !Path::new(path).is_file()
    {
        return Err("update asset path is not an accepted staging location".into());
    }
    let expected = expect.trim();
    if expected.len() != 64
        || expected.as_bytes()[..64]
            .iter()
            .any(|b| !b.is_ascii_hexdigit())
    {
        return Err("checksum must be a 64-character SHA-256 hex digest".into());
    }
    let bytes = std::fs::read(path).map_err(|e| format!("read {path}: {e}"))?;
    let actual = crate::sha256::hex(&bytes);
    if actual != expected.to_ascii_lowercase() {
        return Err(format!(
            "{what} checksum mismatch: expected {expected}, got {actual}"
        ));
    }
    Ok(PathBuf::from(path))
}

fn install_apk(path: &str, expect: &str) -> Result<Value, String> {
    let path = verified_path(path, expect, "APK")?;
    let location = path.to_string_lossy().into_owned();
    let result = crate::run_process_with_timeout(
        "/system/bin/cmd",
        &["package", "install", "-r", &location],
        std::time::Duration::from_secs(300),
    )?;
    let stdout = String::from_utf8_lossy(&result.stdout).trim().to_owned();
    let stderr = String::from_utf8_lossy(&result.stderr).trim().to_owned();
    // The installer kills our own app mid-command; the reply may not reach it.
    if !result.status.success() || !stdout.contains("Success") {
        return Err(format!(
            "APK install rejected: code={} stdout={stdout} stderr={stderr}",
            result.status
        ));
    }
    Ok(
        json!({"installed":"apk","note":"The updated APK is active; the interface reconnects automatically."}),
    )
}

fn flash_module(path: &str, expect: &str) -> Result<Value, String> {
    let source = verified_path(path, expect, "module zip")?;
    std::fs::create_dir_all(MODULE_ZIP_STAGING).map_err(|e| e.to_string())?;
    let staged = format!("{MODULE_ZIP_STAGING}/dash-update.zip");
    std::fs::remove_file(&staged).ok();
    std::fs::copy(&source, &staged).map_err(|e| format!("stage zip: {e}"))?;
    let mut attempts = Vec::<String>::new();
    for (flasher, base_args) in [
        ("/data/adb/ks/bin/ksud", vec!["module", "install"]),
        ("/data/adb/ap/bin/ksud", vec!["module", "install"]),
        ("/data/adb/magisk/magisk", vec!["--install-module"]),
    ] {
        if !Path::new(flasher).exists() {
            continue;
        }
        attempts.push(flasher.to_owned());
        let result = crate::run_process_with_timeout(
            flasher,
            &{
                let mut argv = base_args.clone();
                argv.push(&staged);
                argv
            },
            std::time::Duration::from_secs(600),
        )?;
        let stdout = String::from_utf8_lossy(&result.stdout);
        let stderr = String::from_utf8_lossy(&result.stderr);
        if result.status.success() {
            return Ok(json!(
                {"installed":"module","note":"Module flashed; reboot to activate it."}
            ));
        }
        return Err(format!(
            "{flasher} refused the module: code={} {}{}",
            result.status,
            stdout.trim(),
            stderr.trim()
        ));
    }
    Err(format!(
        "no module flasher found (looked at {})",
        attempts.join(", ")
    ))
}

pub(super) fn command(cmd: &str) -> Result<Value, String> {
    if cmd == "GET update.status" {
        return Ok(json!({"module": module_version()}));
    }
    let (what, rest) = if let Some(rest) = cmd.strip_prefix("SET update.install_apk ") {
        ("apk", rest)
    } else if let Some(rest) = cmd.strip_prefix("SET update.flash_module ") {
        ("module", rest)
    } else {
        return Err("unknown update command".into());
    };
    let (path, expect) = rest
        .split_once(' ')
        .ok_or("update command requires a staging path and checksum")?;
    if what == "apk" {
        install_apk(path, expect)
    } else {
        flash_module(path, expect)
    }
}

#[cfg(test)]
mod tests {
    use super::is_command;
    use crate::update_runtime::{APK_CACHE_PREFIX, APK_TMP_PREFIX};

    #[test]
    fn command_surface_is_exactly_the_update_group() {
        assert!(is_command("GET update.status"));
        assert!(is_command(&format!(
            "SET update.install_apk {APK_CACHE_PREFIX}/x 64-digest-placeholder"
        )));
        assert!(is_command(&format!(
            "SET update.flash_module {APK_TMP_PREFIX}/x 64-digest-placeholder"
        )));
        assert!(!is_command("GET update.asset"));
        assert!(!is_command("SET update.apk"));
        assert!(!is_command("GET app.controls"));
    }
}
