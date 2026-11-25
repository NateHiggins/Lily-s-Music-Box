"""The host-aware lane (order w8286ec452a9d): host choice by stated needs, recipe runs on a remote Omni worker, one
job at a time per host, first come first served, and receipts that name the host. The remote host is a fake Omni
worker on 127.0.0.1, so nothing depends on Optimus or on its recipe runner being deployed."""
from __future__ import annotations

import http.server
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

TOOLS = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("lane_hosts", TOOLS / "lane_hosts.py")
H = importlib.util.module_from_spec(spec)
spec.loader.exec_module(H)


def recipe_commit() -> str:
    """A commit that has tools/optimus_recipes and is on origin (the one that added the recipes)."""
    out = subprocess.run(["git", "-C", str(TOOLS.parent), "log", "--format=%H", "--diff-filter=A", "-1", "--",
                          "tools/optimus_recipes/cpu-design-lint-tests.json"], capture_output=True, text=True).stdout.strip()
    return out


class FakeWorker:
    """Just enough of an Omni worker: /status, POST /jobs, GET /jobs/<id>."""

    def __init__(self, status=None, busy_posts=0, polls_to_finish=1, exit_code=0, drop_first_post_response=False,
                 job_seconds=0.0):
        self.status = status or {"paused": False, "busy": None, "cpu_recipe": {"receipt": "optimus.cpu-precheck.v2"}}
        self.busy_posts, self.polls_to_finish, self.exit_code = busy_posts, polls_to_finish, exit_code
        self.drop_first_post_response, self.job_seconds = drop_first_post_response, job_seconds
        self.posts, self.jobs, self.lock = [], {}, threading.Lock()
        self.running, self.max_running = 0, 0
        worker = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, code, body):
                data = json.dumps(body).encode()
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_GET(self):
                if self.headers.get("Authorization") != "Bearer TEST_ONLY":
                    return self.reply(403, {"error": "not paired"})
                if self.path == "/status":
                    return self.reply(200, worker.status)
                if self.path.startswith("/jobs/"):
                    jid = self.path[6:]
                    with worker.lock:
                        job = worker.jobs.get(jid)
                        if not job:
                            return self.reply(404, {"error": "no such job"})
                        job["polls"] += 1
                        done = job["polls"] >= worker.polls_to_finish and time.time() - job["at"] >= worker.job_seconds
                        if done and job["state"] == "running":
                            job["state"] = "done" if worker.exit_code == 0 else "failed"
                            worker.running -= 1
                    if job["state"] == "running":
                        return self.reply(200, {"id": jid, "state": "running", "phase": "running"})
                    return self.reply(200, {"id": jid, "state": job["state"], "output": f"ran {job['recipe']}\n",
                                            "exit_code": worker.exit_code, "receipt_sha256": "ab" * 32,
                                            "receipt": {"schema": "optimus.cpu-precheck.v2", "host": "FAKE-OPTIMUS",
                                                        "recipe": job["recipe"], "commit": job["commit"],
                                                        "exit_code": worker.exit_code, "outputs": []}})
                return self.reply(404, {})

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers.get("Content-Length") or 0)) or b"{}")
                if self.path != "/jobs":
                    return self.reply(404, {})
                with worker.lock:
                    worker.posts.append(body)
                    if len(worker.posts) <= worker.busy_posts:
                        return self.reply(409, {"error": "busy", "job": "someone-else"})
                    if worker.running:
                        return self.reply(409, {"error": "busy", "job": "lane"})
                    worker.jobs[body["id"]] = dict(body, state="running", polls=0, at=time.time())
                    worker.running += 1
                    worker.max_running = max(worker.max_running, worker.running)
                    drop = worker.drop_first_post_response and len(worker.posts) == 1
                if drop:
                    self.connection.close()  # accepted, but the response is lost
                    return
                return self.reply(202, {"id": body["id"], "state": "running"})

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self):
        self.server.shutdown()
        self.server.server_close()


class Base(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.state = pathlib.Path(self._dir.name)
        self.commit = recipe_commit()
        self.assertRegex(self.commit, r"^[0-9a-f]{40}$")
        self.hosts_file = self.state / "lane_hosts.json"
        self.hosts_file.write_text(json.dumps({"schema": "orison.lane-hosts.v1", "hosts": [
            {"name": "this-pc", "local": True, "runs": ["scene", "gpu", "recipe"]},
            {"name": "Optimus", "omni_machine": "Optimus", "runs": ["recipe"], "gpu": False,
             "receipt": "optimus.cpu-precheck.v2", "status_timeout_seconds": 2}]}), encoding="utf-8")
        self.machines = self.state / "machines.json"
        self.patch_env = mock.patch.dict(os.environ, {"ORISON_LANE_HOSTS_FILE": str(self.hosts_file),
                                                      "ORISON_OMNI_MACHINES": str(self.machines)})
        self.patch_env.start()
        self.addCleanup(self.patch_env.stop)
        self.poll = mock.patch.object(H, "POLL_SECONDS", 0.05)
        self.poll.start()
        self.addCleanup(self.poll.stop)

    def worker(self, **kw) -> FakeWorker:
        fake = FakeWorker(**kw)
        self.addCleanup(fake.close)
        self.machines.write_text(json.dumps([{"name": "Optimus", "url": fake.url, "token": "TEST_ONLY", "enabled": True}]),
                                 encoding="utf-8")
        return fake

    def recipe(self, **kw):
        return dict({"recipe": "cpu-design-lint-tests", "commit": self.commit}, **kw)


class Choice(Base):
    def test_scenes_and_gpu_commands_stay_on_this_pc(self):
        self.worker()
        for runs in ([{"scene": "res://tests/X.tscn"}], [{"gpu": ["python", "x.py"]}], [self.recipe(), {"scene": "res://t.tscn"}]):
            with self.subTest(runs=runs):
                self.assertEqual(H.choose(runs)["host"], "this-pc")

    def test_all_recipe_batch_goes_to_a_ready_remote(self):
        self.worker()
        choice = H.choose([self.recipe(), self.recipe(recipe="gate-board-static")])
        self.assertEqual(choice["host"], "Optimus")

    def test_a_busy_remote_is_still_chosen(self):
        self.worker(status={"paused": False, "busy": "other", "cpu_recipe": {"receipt": "optimus.cpu-precheck.v2"}})
        self.assertEqual(H.choose([self.recipe()])["host"], "Optimus")

    def test_remote_not_ready_falls_back_with_a_reason(self):
        cases = {"paused": {"paused": True, "cpu_recipe": {"receipt": "optimus.cpu-precheck.v2"}},
                 "not deployed": {"paused": False, "cpu_recipe": {"kind": "recipe"}},  # Optimus B not deployed: v1 only
                 "error": {"error": "boom"}}
        for name, status in cases.items():
            with self.subTest(name):
                self.worker(status=status)
                choice = H.choose([self.recipe()])
                self.assertEqual(choice["host"], "this-pc")
                self.assertTrue(choice["reasons"][0].startswith("Optimus: "))

    def test_unpaired_or_unreachable_remote_falls_back(self):
        self.machines.write_text("[]", encoding="utf-8")
        self.assertIn("not paired", H.choose([self.recipe()])["reasons"][0])
        self.machines.write_text(json.dumps([{"name": "Optimus", "url": "http://127.0.0.1:9", "token": "T"}]), encoding="utf-8")
        self.assertIn("unreachable", H.choose([self.recipe()])["reasons"][0])

    def test_commit_not_on_origin_falls_back(self):
        self.worker()
        with mock.patch.object(H, "on_origin", return_value=False):
            choice = H.choose([self.recipe()])
        self.assertEqual(choice["host"], "this-pc")
        self.assertIn("not on origin", choice["reasons"][0])

    def test_recipe_needing_a_gpu_stays_off_a_cpu_host(self):
        self.worker()
        with mock.patch.object(H, "manifest_at", return_value={"needs": {"gpu": True}}):
            self.assertIn("needs a GPU", H.choose([self.recipe()])["reasons"][0])

    def test_named_hosts(self):
        self.worker()
        self.assertEqual(H.choose([self.recipe(host="this-pc")])["host"], "this-pc")
        self.assertEqual(H.choose([self.recipe(host="Optimus")])["host"], "Optimus")
        with self.assertRaises(ValueError):
            H.choose([self.recipe(host="Optimus"), self.recipe(host="this-pc")])
        with self.assertRaises(ValueError):
            H.choose([{"scene": "res://t.tscn", "host": "Optimus"}])
        with self.assertRaises(ValueError):
            H.choose([self.recipe(host="Nowhere")])


class RemoteRun(Base):
    def host(self):
        return next(h for h in H.load_hosts() if h["name"] == "Optimus")

    def test_receipt_names_the_host_and_carries_the_workers_receipt(self):
        fake = self.worker(polls_to_finish=3)
        log = self.state / "lint.log"
        code = H.run_remote(self.host(), self.recipe(), 1, log)
        self.assertEqual(code, 0)
        receipt = json.loads((self.state / "lint.log.receipt.json").read_text(encoding="utf-8"))
        self.assertEqual((receipt["schema"], receipt["host"], receipt["machine"]), ("orison.lane-host-run.v1", "Optimus", "FAKE-OPTIMUS"))
        self.assertEqual((receipt["recipe"], receipt["commit"], receipt["exit"]), ("cpu-design-lint-tests", self.commit, 0))
        self.assertEqual(receipt["worker_receipt"]["schema"], "optimus.cpu-precheck.v2")
        self.assertFalse(receipt["canonical_gate"])
        self.assertIn("ran cpu-design-lint-tests", log.read_text(encoding="utf-8"))
        self.assertEqual([set(p) for p in fake.posts], [{"kind", "recipe", "commit", "id"}])

    def test_failed_recipe_returns_its_exit(self):
        self.worker(exit_code=3)
        self.assertEqual(H.run_remote(self.host(), self.recipe(), 1, self.state / "f.log"), 3)

    def test_busy_with_someone_elses_job_waits_then_runs(self):
        fake = self.worker(busy_posts=2)
        self.assertEqual(H.run_remote(self.host(), self.recipe(), 1, self.state / "b.log"), 0)
        self.assertEqual(len(fake.posts), 3)

    def test_busy_past_the_deadline_is_lane_busy(self):
        self.worker(busy_posts=10**6)
        with mock.patch.object(H, "POLL_SECONDS", 0.01):
            self.assertEqual(H.run_remote(self.host(), self.recipe(), 0.002, self.state / "d.log"), 73)

    def test_lost_post_response_is_observed_never_resubmitted(self):
        fake = self.worker(drop_first_post_response=True)
        self.assertEqual(H.run_remote(self.host(), self.recipe(), 1, self.state / "l.log"), 0)
        self.assertEqual(len(fake.posts), 1)


class LaneScript(Base):
    """lane.ps1 end to end, on a private mutex and state dir, with the fake remote."""

    def env(self):
        env = dict(os.environ, LOCALAPPDATA=str(self.state),
                   ORISON_LANE_TEST_MUTEX=f"Local\\OrisonLaneHostTest{os.getpid()}")
        env.pop("ORISON_LANE_BROKER", None)
        return env

    def batch(self, name, runs, *extra, wait=True):
        path = self.state / f"{name}.json"
        path.write_text(json.dumps(runs), encoding="utf-8")
        cmd = ["pwsh", "-NoProfile", "-File", str(TOOLS / "lane.ps1"), "batch", "-BatchFile", str(path), "-WaitMinutes", "2", *extra]
        if wait:
            return subprocess.run(cmd, env=self.env(), capture_output=True, text=True, timeout=180)
        return subprocess.Popen(cmd, env=self.env(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def test_remote_batch_runs_there_without_taking_this_pcs_lane(self):
        self.worker()
        # Hold this PC's lane for the whole run: a remote batch must not need it.
        holder = subprocess.Popen(["pwsh", "-NoProfile", "-Command",
                                   f"$m=[Threading.Mutex]::new($false,'{self.env()['ORISON_LANE_TEST_MUTEX']}'); "
                                   "$null=$m.WaitOne(); Start-Sleep 60"], env=self.env())
        self.addCleanup(lambda: (holder.kill(), holder.wait(10)))
        time.sleep(2)
        result = self.batch("remote", [self.recipe(log=str(self.state / "remote.log"))])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("[LANE] host Optimus", result.stdout)
        receipt = json.loads((self.state / "remote.log.receipt.json").read_text(encoding="utf-8"))
        self.assertEqual(receipt["host"], "Optimus")
        history = json.loads((self.state / "Orison/run_history.jsonl").read_text(encoding="utf-8-sig").splitlines()[-1])
        self.assertEqual((history["host"], history["scene"], history["exit"]), ("Optimus", "recipe:cpu-design-lint-tests", 0))

    def test_one_job_at_a_time_per_host_in_queue_order(self):
        fake = self.worker(job_seconds=3)
        first = self.batch("first", [self.recipe(log=str(self.state / "first.log"))], wait=False)
        deadline = time.monotonic() + 60
        while not fake.posts:
            self.assertLess(time.monotonic(), deadline)
            time.sleep(0.05)
        second = self.batch("second", [self.recipe(recipe="gate-board-static", log=str(self.state / "second.log"))], wait=False)
        self.assertEqual(first.wait(120), 0)
        self.assertEqual(second.wait(120), 0)
        self.assertEqual([p["recipe"] for p in fake.posts], ["cpu-design-lint-tests", "gate-board-static"])  # FIFO, no 409s
        self.assertEqual(fake.max_running, 1)

    def test_mixed_batch_stays_on_this_pc_and_runs_the_recipe_here(self):
        self.worker()
        head = subprocess.run(["git", "-C", str(TOOLS.parent), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
        order = self.state / "order.txt"
        runs = [{"gpu": [sys.executable, "-c", "import sys;open(sys.argv[1],'a').write('gpu\\n')", str(order)],
                 "scene": "gpu step", "log": str(self.state / "gpu.log"), "timeout": 30},
                {"recipe": "cpu-design-lint-tests", "commit": head, "log": str(self.state / "local.log")}]
        result = self.batch("mixed", runs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt = json.loads((self.state / "local.log.receipt.json").read_text(encoding="utf-8"))
        self.assertEqual((receipt["host"], receipt["local"], receipt["exit"]), ("this-pc", True, 0))

    def test_a_scene_batch_cannot_be_sent_to_a_remote_host(self):
        result = self.batch("scene", [{"scene": "res://tests/X.tscn", "log": str(self.state / "x.log")}], "-TargetHost", "Optimus")
        self.assertEqual(result.returncode, 64, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
