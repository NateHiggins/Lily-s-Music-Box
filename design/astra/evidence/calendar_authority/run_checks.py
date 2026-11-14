"""Capture synthetic calendar red/green controls and current static audits."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
sys.path.insert(0, str(ROOT / "tools/tests"))
import test_period_dates as period
import test_systemic_situation_authority as systemic


def main():
    phase = sys.argv[1] if len(sys.argv) > 1 else "integrated"
    if phase not in {"pre_migration", "integrated"}:
        raise ValueError("phase must be pre_migration or integrated")
    output = HERE / phase
    output.mkdir(parents=True, exist_ok=True)
    receipt = {"phase": phase, "runs": {}}
    inputs = ["tools/audit_period_dates.py", "tools/audit_systemic_situation_authority.py",
              "tools/tests/test_period_dates.py", "tools/tests/test_systemic_situation_authority.py",
              "game/data/orison_v2_shared_frames.json", "game/scripts/building/orison_v2_frame_contract.gd",
              "game/tests/admin_prereq_contract_test.gd", "game/data/campaign_calendar.json",
              "game/scripts/game/campaign_clock.gd", "game/scripts/phoneos/phone_camera.gd",
              "game/scripts/phoneos/phone_os.gd", "game/scripts/songbook/songbook_store.gd",
              "game/scripts/game/historical_radio_notice.gd", "game/data/historical_radio_reallocation.json",
              "game/scripts/props/lobby_bulletin_board.gd",
              "game/scripts/reality/organism_incidents.gd"]
    def hashes():
        return {path: hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
                for path in inputs if (ROOT / path).is_file()}
    receipt["input_sha256_before"] = hashes()
    baseline = ROOT / "tools/systemic_situation_authority_baseline.json"
    before = hashlib.sha256(baseline.read_bytes()).hexdigest()

    def save(name, code, stdout, stderr, command):
        (output / (name + ".stdout.txt")).write_text(stdout, encoding="utf-8")
        (output / (name + ".stderr.txt")).write_text(stderr, encoding="utf-8")
        receipt["runs"][name] = {"exit_code": code, "command": command}

    def run(name, args):
        command = [sys.executable, *args]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        save(name, result.returncode, result.stdout, result.stderr, command)
        return result.returncode

    with tempfile.TemporaryDirectory(prefix="calendar_period_control_") as tmp:
        fixture = Path(tmp)
        period.make_repo(fixture)
        source = fixture / period.CLOCK
        source.write_text(period.HOST, encoding="utf-8")
        args = ["tools/audit_period_dates.py", str(fixture)]
        assert run("period_fixture_host_red", args) == 1
        source.write_text(period.AUTHORED, encoding="utf-8")
        assert run("period_fixture_authored_green", args) == 0
        period.write_json(fixture, "game/data/campaign_calendar.json",
                          dict(period.CALENDAR, year=2026))
        assert run("period_fixture_calendar_drift_red", args) == 1

    with systemic.TempRepo() as fixture:
        fixture_baseline = systemic.write_baseline(fixture)
        source = fixture / systemic.HostCalendarTests.CLOCK
        source.write_text(period.HOST, encoding="utf-8")
        args = ("--root", str(fixture), "--baseline", str(fixture_baseline),
                "--domain", "host-clock", "--json")
        code, stdout, stderr = systemic.run_main(*args)
        save("systemic_fixture_host_red", code, stdout, stderr, list(args))
        assert code == 1
        source.write_text(period.AUTHORED, encoding="utf-8")
        code, stdout, stderr = systemic.run_main(*args)
        save("systemic_fixture_authored_green", code, stdout, stderr, list(args))
        assert code == 0

    assert run("host_calendar_selftests", ["tools/tests/test_systemic_situation_authority.py",
                                           "HostCalendarTests"]) == 0
    assert run("period_selftests", ["tools/tests/test_period_dates.py"]) == 0
    run("systemic_full_selftests", ["tools/tests/test_systemic_situation_authority.py"])
    run("systemic_audit", ["tools/audit_systemic_situation_authority.py", "--json"])
    run("period_audit", ["tools/audit_period_dates.py"])
    after = hashlib.sha256(baseline.read_bytes()).hexdigest()
    assert before == after
    receipt["production_baseline_sha256_unchanged"] = after
    receipt["input_sha256_after"] = hashes()
    receipt["inputs_unchanged_during_run"] = receipt["input_sha256_before"] == receipt["input_sha256_after"]
    assert receipt["inputs_unchanged_during_run"], "audited source inputs changed during capture"
    receipt["frame_runtime_execution"] = "not run by this agent; root owns Godot lane"
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({name: data["exit_code"] for name, data in receipt["runs"].items()}, indent=2))


if __name__ == "__main__":
    main()
