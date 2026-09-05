"""One fresh-profile notice run; only invokes the unchanged serial Godot runner."""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(r"C:\PleaseRemainOnTheLine-astra")
BASE = Path(__file__).resolve().parent
PWSH = r"C:\Users\nate_\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe"
RUNNER = ROOT / "tools/run_godot_serial.ps1"
OWNED = [
    "game/data/historical_radio_reallocation.json",
    "game/scripts/game/historical_radio_notice.gd",
    "game/scripts/props/lobby_bulletin_board.gd",
    "game/tests/historical_radio_notice_test.gd",
    "game/tests/historical_radio_notice_test.tscn",
    "game/tests/historical_radio_lobby_shot.gd",
    "game/tests/HistoricalRadioLobbyShot.tscn",
    "game/scripts/ui/telegram_hud.gd",
    "game/tests/shot_harness.gd",
    "game/scripts/game/campaign_clock.gd",
    "game/scripts/game/campaign_clock_driver.gd",
    "game/scripts/game/reality_game_state.gd",
    "game/data/campaign_calendar.json",
    "game/tests/campaign_calendar_test.gd",
    "game/tests/CampaignCalendarTest.tscn",
    "game/tests/admin_prereq_contract_test.gd",
    "game/tests/AdminPrereqContractTest.tscn",
    "tools/run_godot_serial.ps1",
]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def utc():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], stderr=subprocess.DEVNULL)


def snapshot(out, label):
    files = [ROOT / "game/project.godot"]
    for directory, patterns in [("game/scripts", ["*.gd"]),
                                 ("game/scenes", ["*.tscn", "*.tres"]),
                                 ("game/data", ["*.json"])]:
        for pattern in patterns:
            files.extend((ROOT / directory).rglob(pattern))
    rows = [{"path": p.relative_to(ROOT).as_posix(), "sha256": sha(p.read_bytes())}
            for p in sorted(set(files)) if p.is_file()]
    manifest = sorted([row["path"], row["sha256"]] for row in rows)
    encoded = json.dumps(manifest, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    (out / (label + ".runtime_inputs.json")).write_text(json.dumps(rows, indent=2) + "\n")
    diff = git("diff", "--binary", "HEAD", "--", "game")
    (out / (label + ".game.diff")).write_bytes(diff)
    selected = []
    for relative in OWNED:
        source = ROOT / relative
        target = out / label / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        selected.append({"path": relative, "sha256": sha(source.read_bytes())})
    return {"head": git("rev-parse", "HEAD").decode().strip(),
            "runtime_inputs_digest_encoding": "compact JSON sorted [relative_posix_path, raw_file_sha256] pairs, no trailing newline",
            "runtime_inputs_sha256": sha(encoded), "runtime_input_count": len(rows),
            "tracked_game_diff_sha256": sha(diff), "selected_source_copies": selected,
            "asset_scope": "Texture/audio/other asset files are not covered by this text-input digest."}


parser = argparse.ArgumentParser()
parser.add_argument("run_name")
parser.add_argument("mode", choices=["calendar", "admin", "focused", "capture"])
args = parser.parse_args()
if not re.fullmatch(r"[a-zA-Z0-9_-]+", args.run_name):
    raise SystemExit("Use a plain fresh run name")
out = BASE / args.run_name
out.mkdir(exist_ok=False)
profile = out / "appdata"
profile.mkdir()
env = os.environ.copy()
env["APPDATA"] = str(profile)
for key in ["ORISON_BUILDING_ROOT", "SHOT_DIR", "REALITY_TIME_OVERRIDE", "REALITY_TIME"]:
    env.pop(key, None)
scene = {
    "calendar": "res://tests/CampaignCalendarTest.tscn",
    "admin": "res://tests/AdminPrereqContractTest.tscn",
    "focused": "res://tests/historical_radio_notice_test.tscn",
    "capture": "res://tests/HistoricalRadioLobbyShot.tscn",
}[args.mode]
log = out / "godot.stdout.log"
def ps_quote(value):
    return "'" + str(value).replace("'", "''") + "'"


invocation = ("& " + ps_quote(RUNNER) + " -ProjectPath " + ps_quote(ROOT / "game")
              + " -Scene " + ps_quote(scene) + " -LogPath " + ps_quote(log)
              + " -TimeoutSeconds 60")
if args.mode == "capture":
    shots = out / "shots"
    invocation += " -Windowed -ShotDir " + ps_quote(shots)
    invocation += " -ExtraArgs @('--verbose', '--audio-driver', 'Dummy', '--resolution', '1280x720')"
else:
    invocation += " -ExtraArgs @('--verbose')"
wrapper = out / "command.ps1"
wrapper.write_text(invocation + "\nexit $LASTEXITCODE\n", encoding="utf-8")
command = [PWSH, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(wrapper)]
receipt = {"schema": "astra.historical_notice_run.v1", "mode": args.mode,
           "scene": scene, "started_utc": utc(), "command": command,
           "fresh_appdata": str(profile), "appdata_preexisting": False,
           "runner_sha256": sha(RUNNER.read_bytes()), "source_before": snapshot(out, "source_before"),
           "scope": "Focused component checks" if args.mode != "capture" else "Actual V1 composition and teleported control presentation; no walked route or human acceptance",
           "visual_review": "PENDING" if args.mode == "capture" else "NOT_APPLICABLE"}
receipt_path = out / "run_receipt.json"
receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
started = time.perf_counter()
process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
receipt["elapsed_seconds"] = round(time.perf_counter() - started, 3)
receipt["runner_exit"] = process.returncode
(out / "runner.stdout.log").write_bytes(process.stdout)
(out / "runner.stderr.log").write_bytes(process.stderr)
stdout = log.read_text(encoding="utf-8-sig", errors="replace") if log.exists() else ""
stderr_path = Path(str(log) + ".stderr")
stderr = stderr_path.read_text(encoding="utf-8-sig", errors="replace") if stderr_path.exists() else ""
receipt["diagnostic_lines"] = [line for line in (stdout + "\n" + stderr).splitlines()
    if re.search(r"WARNING:|ERROR:|SCRIPT ERROR:|Parse Error|leaked|resources still in use", line, re.I)]
receipt["summary_lines"] = [line for line in stdout.splitlines()
    if re.search(r"RESULT:|NOTICE OK|NOTICE FAIL|CAPTURE|PASS|FAIL", line)]
receipt["source_after"] = snapshot(out, "source_after")
receipt["source_unchanged"] = receipt["source_before"] == receipt["source_after"]
receipt["finished_utc"] = utc()
receipt["process_verdict"] = "PASS" if process.returncode == 0 else "FAIL_OR_REFUSED"
receipt["artifact_hashes"] = [{"path": p.relative_to(out).as_posix(), "bytes": p.stat().st_size,
    "sha256": sha(p.read_bytes())} for p in sorted(out.rglob("*"))
    if p.is_file() and p != receipt_path and "appdata" not in p.relative_to(out).parts]
receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
compact = {key: receipt[key] for key in ["mode", "runner_exit", "elapsed_seconds", "source_unchanged", "summary_lines"]}
compact["diagnostic_counts"] = dict(Counter(receipt["diagnostic_lines"]))
print(json.dumps(compact, indent=2), flush=True)
raise SystemExit(process.returncode)
