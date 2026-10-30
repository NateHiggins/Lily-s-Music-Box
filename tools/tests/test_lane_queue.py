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

    def test_a_direct_runner_refuses_while_anyone_is_queued(self):
        me = os.getpid()
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 60))
        self.queue_of({"me": {"pid": me, "scene": "x", "worktree": "", "since_utc": now}})
        script = (f". '{TOOLS / 'lane_common.ps1'}'; Test-OrisonLaneQueueAhead; "
                  "$env:ORISON_LANE_BROKER = \"$PID\"; Test-OrisonLaneQueueAhead")
        out = subprocess.run(["pwsh", "-NoProfile", "-Command", script], env=self.env, capture_output=True,
                             text=True, check=True).stdout.split()
        self.assertEqual(out, ["True", "False"])


if __name__ == "__main__":
    unittest.main()
