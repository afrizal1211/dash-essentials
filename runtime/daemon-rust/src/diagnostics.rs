//! Field diagnostics. Users report GPU profiles that "do nothing" while the
//! only evidence lives in a root-only log nobody can attach. Every profile
//! transition, rejected command and guard reassert lands here: a bounded
//! in-memory ring the app can read over the authenticated socket, mirrored
//! into a size-capped file under the state directory for post-reboot review.

use std::collections::VecDeque;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::sync::{Mutex, OnceLock};
use std::time::{SystemTime, UNIX_EPOCH};

const RING_LINES: usize = 512;
const FILE_BYTES: u64 = 512 * 1024;

struct Diagnostics {
    ring: Mutex<VecDeque<String>>,
}

static DIAGNOSTICS: OnceLock<Diagnostics> = OnceLock::new();

fn diagnostics() -> &'static Diagnostics {
    DIAGNOSTICS.get_or_init(|| Diagnostics {
        ring: Mutex::new(VecDeque::with_capacity(RING_LINES)),
    })
}

pub(crate) fn log_path() -> PathBuf {
    super::state_dir().join("logs").join("perapp.log")
}

fn append_file(line: &str) {
    let path = log_path();
    let Some(dir) = path.parent() else {
        return;
    };
    if fs::create_dir_all(dir).is_err() {
        return;
    }
    let size = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    if size > FILE_BYTES {
        let _ = fs::rename(&path, path.with_extension("log.1"));
    }
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(&path) {
        let _ = writeln!(file, "{line}");
    }
}

pub(crate) fn log_event(message: impl AsRef<str>) {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let line = format!("{stamp} {}", message.as_ref());
    if let Ok(mut ring) = diagnostics().ring.lock() {
        if ring.len() == RING_LINES {
            ring.pop_front();
        }
        ring.push_back(line.clone());
    }
    append_file(&line);
}

pub(crate) fn lines() -> Vec<String> {
    diagnostics()
        .ring
        .lock()
        .map(|ring| ring.iter().cloned().collect())
        .unwrap_or_default()
}

pub(crate) fn is_command(cmd: &str) -> bool {
    cmd == "GET diagnostics.log"
}

pub(crate) fn command(cmd: &str) -> Result<serde_json::Value, String> {
    if cmd == "GET diagnostics.log" {
        return Ok(serde_json::json!({
            "lines": lines(),
            "path": log_path().display().to_string(),
        }));
    }
    Err(format!("unknown diagnostics command: {cmd}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ring_keeps_only_the_newest_lines() {
        let diag = Diagnostics {
            ring: Mutex::new(VecDeque::new()),
        };
        for index in 0..(RING_LINES + 10) {
            let mut ring = diag.ring.lock().unwrap();
            if ring.len() == RING_LINES {
                ring.pop_front();
            }
            ring.push_back(format!("line-{index}"));
        }
        let ring = diag.ring.lock().unwrap();
        assert_eq!(ring.len(), RING_LINES);
        assert_eq!(ring.front().map(String::as_str), Some("line-10"));
        assert_eq!(ring.back().map(String::as_str), Some("line-521"));
    }

    #[test]
    fn only_the_log_command_is_recognised() {
        assert!(is_command("GET diagnostics.log"));
        assert!(!is_command("GET app.controls"));
        assert!(!is_command("SET diagnostics.log x"));
    }
}
