"""The lane is first come, first served: real brokers, on a private mutex and state dir."""
from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest

TOOLS = pathlib.Path(__file__).resolve().parents[1]
BROKERS = 5


class LaneQueueTests(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.state = pathlib.Path(self._dir.name)
        self.env = dict(os.environ, LOCALAPPDATA=str(self.state),
                        ORISON_LANE_TEST_MUTEX=f"Local\\OrisonLaneQueueTest{os.getpid()}")
        self.env.pop("ORISON_LANE_BROKER", None)

    def tearDown(self):
        self._dir.cleanup()

    def broker(self, name: str, order: pathlib.Path, hold: float, wait_minutes: float = 2) -> subprocess.Popen:
        code = f"import time,sys;open(sys.argv[1],'a').write({name!r}+chr(10));time.sleep({hold})"
        runs = self.state / f"{name}.json"
        runs.write_text(json.dumps([{"gpu": [sys.executable, "-c", code, str(order)], "scene": name,
                                     "log": str(self.state / f"{name}.log"), "timeout": 60}]), encoding="utf8")
        return subprocess.Popen(["pwsh", "-NoProfile", "-File", str(TOOLS / "lane.ps1"), "batch", "-BatchFile", str(runs),
                                 "-WaitMinutes", str(wait_minutes)], env=self.env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def has_started(self, name: str, order: pathlib.Path) -> bool:
        if order.exists() and name in order.read_text():
            return True
        for record in (self.state / "Orison/waiters").glob("*.json"):
            try:
                if json.loads(record.read_text(encoding="utf-8-sig"))["scene"] == name:
                    return True
            except (ValueError, OSError):
                pass
        return False

    def test_brokers_run_in_the_order_they_queued(self):
        order = self.state / "order.txt"
        names = [f"run{i}" for i in range(BROKERS)]
        brokers = []
        for i, name in enumerate(names):
            brokers.append(self.broker(name, order, hold=12 if i == 0 else 0.5))
            deadline = time.monotonic() + 30
            # Each one is running or on the queue, and the next stamps a later second.
            while not self.has_started(name, order):
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.05)
            time.sleep(1.1)
        for broker in brokers:
            self.assertEqual(broker.wait(120), 0)
        self.assertEqual(order.read_text().split(), names)

    def queue_of(self, records: dict[str, dict]) -> list[int]:
        folder = self.state / "Orison/waiters"
        folder.mkdir(parents=True, exist_ok=True)
        for name, record in records.items():
            (folder / f"{name}.json").write_text(json.dumps(record), encoding="utf8")
        script = (f". '{TOOLS / 'lane_common.ps1'}'; "
                  "@(Get-OrisonLaneQueue) | ForEach-Object { $_.pid }")
        out = subprocess.run(["pwsh", "-NoProfile", "-Command", script], env=self.env, capture_output=True,
                             text=True, check=True).stdout
        return [int(line) for line in out.split()]

    def test_dead_brokers_and_reused_pids_do_not_block_the_queue(self):
        me = os.getpid()
        records = {
            "dead": {"pid": 4194300, "scene": "gone", "worktree": "", "since_utc": "2026-10-01T00:00:00Z"},
            # A live process that started after this stamp cannot be the broker that wrote it.
            "reused": {"pid": me, "scene": "old", "worktree": "", "since_utc": "2020-01-01T00:00:00Z"},
        }
        self.assertEqual(self.queue_of(records), [])

    def test_a_live_older_broker_stands_first(self):
        me = os.getpid()
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 60))
        self.assertEqual(self.queue_of({"me": {"pid": me, "scene": "x", "worktree": "", "since_utc": now}}), [me])

    def test_a_departing_waiter_can_disappear_after_enumeration(self):
        me = os.getpid()
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 60))
        self.queue_of({"live": {"pid": me, "scene": "live", "worktree": "", "since_utc": now}})
        folder = self.state / "Orison/waiters"
        # Return an enumerated entry whose broker has already removed it.
        # A deterministic snapshot avoids relying on a filesystem timing race.
        script = (f". '{TOOLS / 'lane_common.ps1'}'; "
                  "function Get-ChildItem { "
                  f"[System.IO.FileInfo]::new('{folder / 'departed.json'}'); "
                  f"[System.IO.FileInfo]::new('{folder / 'live.json'}') }}; "
                  "@(Get-OrisonLaneQueue) | ForEach-Object { $_.pid }")
        result = subprocess.run(["pwsh", "-NoProfile", "-Command", script], env=self.env,
                                capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.split(), [str(me)])
        self.assertEqual(result.stderr, "")

    def test_a_direct_runner_refuses_while_anyone_is_queued(self):
        me = os.getpid()
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 60))
        self.queue_of({"me": {"pid": me, "scene": "x", "worktree": "", "since_utc": now}})
        script = (f". '{TOOLS / 'lane_common.ps1'}'; Test-OrisonLaneQueueAhead; "
                  "$env:ORISON_LANE_BROKER = \"$PID\"; Test-OrisonLaneQueueAhead")
        out = subprocess.run(["pwsh", "-NoProfile", "-Command", script], env=self.env, capture_output=True,
                             text=True, check=True).stdout.split()
        self.assertEqual(out, ["True", "False"])

    def environment_run(self, name, overrides=None, exit_code=0):
        output = self.state / f"{name}.out.json"
        code = ("import json,os,sys; "
                "open(sys.argv[1],'w').write(json.dumps([os.getenv('ORISON_TEST_ENV'),"
                "os.getenv('ORISON_TEST_NEW')])); sys.exit(int(sys.argv[2]))")
        spec = {"gpu": [sys.executable, "-c", code, str(output), str(exit_code)],
                "scene": name, "log": str(self.state / f"{name}.log"), "timeout": 30}
        if overrides is not None:
            spec["environment"] = overrides
        return spec, output

    def run_environment_batch(self, specs, *extra, parent_value="outer"):
        batch = self.state / "environment.json"
        batch.write_text(json.dumps(specs), encoding="utf8")
        env = dict(self.env, ORISON_TEST_ENV=parent_value)
        env.pop("ORISON_TEST_NEW", None)
        return subprocess.run(["pwsh", "-NoProfile", "-File", str(TOOLS / "lane.ps1"),
                               "batch", "-BatchFile", str(batch), "-WaitMinutes", "1", *extra],
                              env=env, capture_output=True, text=True, timeout=45)

    def test_batch_environment_is_scoped_and_null_unsets(self):
        first, a = self.environment_run("set", {"ORISON_TEST_ENV": "inner", "ORISON_TEST_NEW": "new"})
        second, b = self.environment_run("unset", {"ORISON_TEST_ENV": None})
        third, c = self.environment_run("restored")
        result = self.run_environment_batch([first, second, third])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(a.read_text()), ["inner", "new"])
        self.assertEqual(json.loads(b.read_text()), [None, None])
        self.assertEqual(json.loads(c.read_text()), ["outer", None])

    def test_failed_run_restores_environment_before_continuing(self):
        first, _ = self.environment_run("failed", {"ORISON_TEST_ENV": "inner"}, exit_code=7)
        second, output = self.environment_run("after_failure")
        result = self.run_environment_batch([first, second], "-ContinueOnFailure")
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertEqual(json.loads(output.read_text()), ["outer", None])

    def test_empty_inherited_value_is_restored_exactly(self):
        first, _ = self.environment_run("override_empty", {"ORISON_TEST_ENV": "inner"})
        second, output = self.environment_run("restored_empty")
        result = self.run_environment_batch([first, second], parent_value="")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(output.read_text()), ["", None])

    def test_launch_exception_restores_environment_and_releases_lane(self):
        batch = self.state / "launch_exception.json"
        output = self.state / "exception_restoration.json"
        batch.write_text(json.dumps([{
            "gpu": [str(self.state / "missing-executable.exe"), "unused"],
            "scene": "launch failure", "log": str(self.state / "never.log"),
            "environment": {"ORISON_TEST_ENV": "inner", "ORISON_TEST_NEW": "new"},
        }]), encoding="utf8")
        script = ("$ErrorActionPreference='Stop'; $caught=$false; "
                  f"try {{ & '{TOOLS / 'lane.ps1'}' batch -BatchFile '{batch}' -WaitMinutes 1 }} "
                  "catch { $caught=$true }; "
                  "$m=[Threading.Mutex]::new($false,$env:ORISON_LANE_TEST_MUTEX); "
                  "$free=$m.WaitOne(0); if($free){$m.ReleaseMutex()};$m.Dispose(); "
                  "@{caught=$caught;free=$free;old=[Environment]::GetEnvironmentVariable('ORISON_TEST_ENV');"
                  "added=[Environment]::GetEnvironmentVariable('ORISON_TEST_NEW')} | "
                  f"ConvertTo-Json | Set-Content -Encoding utf8 -LiteralPath '{output}'")
        env = dict(self.env, ORISON_TEST_ENV="outer")
        env.pop("ORISON_TEST_NEW", None)
        result = subprocess.run(["pwsh", "-NoProfile", "-Command", script], env=env,
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8-sig")),
                         {"caught": True, "free": True, "old": "outer", "added": None})

    def test_invalid_environment_is_rejected_before_any_run(self):
        for overrides in [[], {"bad=name": "x"}, {"ORISON_TEST_ENV": 3},
                          {"ORISON_LANE_BROKER": "x"}, {"orison_lane_test_mutex": "x"},
                          {"localappdata": "elsewhere"}]:
            with self.subTest(overrides=overrides):
                spec, output = self.environment_run("must_not_start", overrides)
                result = self.run_environment_batch([spec])
                self.assertEqual(result.returncode, 64, result.stdout + result.stderr)
                self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
