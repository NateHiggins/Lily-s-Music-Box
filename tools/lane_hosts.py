#!/usr/bin/env python3
"""Which host runs a lane batch, and running a recipe there (order w8286ec452a9d, Optimus C).

    python tools/lane_hosts.py choose            < runs.json   -> {"host": ..., "reasons": [...]}
    python tools/lane_hosts.py run --host NAME   < run.json    -> runs one recipe run, exit = its exit

tools/lane.ps1 calls this only for batches that contain a recipe run ({"recipe": name, "commit": sha}); a batch
of Godot scenes or GPU commands never reaches here and stays on this PC exactly as before.

Choosing, by the batch's stated needs:
  - Anything that is not a recipe (a scene, a "gpu" command) needs this PC's GPU and Godot: this PC.
  - A run may name its host ("host": "Optimus" / "this-pc"); every run in a batch must then agree.
  - Otherwise every run is a recipe, and the first remote host in tools/lane_hosts.json that qualifies takes the
    batch: its Omni worker answers /status, is not paused, offers the recipe receipt the host entry names (that is,
    Optimus B is deployed there), every recipe's manifest at its commit says needs.gpu false (or the host has a
    GPU), and every commit is on origin (the remote fetches it from there). Failing that, this PC, with reasons.
  - A busy remote host is still chosen: its lane queue (one job at a time per host, first come first served)
    holds the batch until the host is free.

Running a recipe:
  - On a remote host, through its Omni worker: POST /jobs {kind, recipe, commit, id}, then GET /jobs/<id> until it
    finishes. 409 (busy with a job the lane did not send) and 423 (paused) wait and retry until the wait deadline,
    then exit 73, the lane's "not free" code. A lost POST response is observed, never resubmitted.
  - On this PC: the manifest's argv in this checkout, which must be at the run's commit ({python} = this
    interpreter, {out} = a folder beside the log).
  - Either way the log gets the output and <log>.receipt.json (schema orison.lane-host-run.v1) names the host.
    A remote receipt carries the worker's own receipt (optimus.cpu-precheck.v2) verbatim; outputs stay on the
    remote host, identified there by name, sha256 and size.

Remote addresses and pairing tokens are never stored in the repository: a host's "omni_machine" is looked up in
Omni's machines.json (ORISON_OMNI_MACHINES, else the usual Omni locations).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import re
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

TOOLS = pathlib.Path(__file__).resolve().parent
REPO = TOOLS.parent
HOSTS_FILE = TOOLS / "lane_hosts.json"
RECEIPT_SCHEMA = "orison.lane-host-run.v1"
LOCAL = "this-pc"
EXIT_BUSY, EXIT_USAGE, EXIT_TIMEOUT = 73, 64, 124
POLL_SECONDS = 3.0
CHECKOUT_ALLOWANCE = 1800  # a remote job fetches and checks out its commit before the recipe's own timeout starts


def utc(t: float | None = None) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() if t is None else t))


def load_hosts() -> list[dict]:
    path = pathlib.Path(os.environ.get("ORISON_LANE_HOSTS_FILE") or HOSTS_FILE)
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("schema") != "orison.lane-hosts.v1":
        raise ValueError(f"{path} is not orison.lane-hosts.v1")
    return data["hosts"]


def machines_file() -> pathlib.Path | None:
    candidates = [os.environ.get("ORISON_OMNI_MACHINES"),
                  os.path.join(os.environ.get("LOCALAPPDATA", ""), "Omni", "cluster", "machines.json"),
                  os.path.join(os.path.expanduser("~"), "local-llm", "model_hub", "cluster", "machines.json")]
    for c in candidates:
        if c and os.path.isfile(c):
            return pathlib.Path(c)
    return None


def omni_machine(name: str) -> dict | None:
    """{url, token} for an Omni machine, from Omni's own pairing file; never from the repository."""
    path = machines_file()
    if not path:
        return None
    try:
        rows = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    row = next((r for r in rows if isinstance(r, dict) and r.get("name") == name), None)
    if not row or not row.get("url") or not row.get("token") or row.get("enabled") is False:
        return None
    return {"url": str(row["url"]).rstrip("/"), "token": str(row["token"])}


def call(machine: dict, path: str, body=None, timeout: float = 10.0):
    req = urllib.request.Request(machine["url"] + path, data=None if body is None else json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + machine["token"], "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.status, json.loads(response.read() or b"{}")


def git(*args: str) -> str:
    proc = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True, encoding="utf-8",
                          errors="replace")
    if proc.returncode != 0:
        raise RuntimeError(f"git {args[0]}: {proc.stderr.strip()[-300:]}")
    return proc.stdout


def head_commit() -> str:
    return git("rev-parse", "HEAD").strip()


def on_origin(commit: str) -> bool:
    try:
        return bool(git("for-each-ref", "--contains", commit, "--count=1", "--format=%(refname)", "refs/remotes/origin/").strip())
    except RuntimeError:
        return False


def manifest_at(recipe: str, commit: str) -> dict:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", recipe or ""):
        raise ValueError(f"bad recipe name {recipe!r}")
    return json.loads(git("show", f"{commit}:tools/optimus_recipes/{recipe}.json"))


def kind_of(run: dict) -> str:
    if run.get("recipe"):
        return "recipe"
    return "gpu" if run.get("gpu") else "scene"


def normalize(run: dict) -> dict:
    if kind_of(run) == "recipe":
        run = dict(run)
        run["commit"] = run.get("commit") or head_commit()
        if not re.fullmatch(r"[0-9a-f]{40}", run["commit"]):
            raise ValueError("a recipe run's commit must be the full 40-hex sha")
    return run


def choose(runs: list[dict], hosts: list[dict] | None = None, status_of=None) -> dict:
    """{"host": name, "reasons": [...]} for a whole batch."""
    hosts = hosts if hosts is not None else load_hosts()
    names = {h["name"] for h in hosts}
    runs = [normalize(r) for r in runs if not r.get("skip")]
    forced = {r["host"] for r in runs if r.get("host")}
    if len(forced) > 1:
        raise ValueError(f"runs in one batch name different hosts: {sorted(forced)}")
    if forced:
        name = forced.pop()
        if name not in names:
            raise ValueError(f"unknown host {name!r}")
        kinds = {kind_of(r) for r in runs}
        host = next(h for h in hosts if h["name"] == name)
        if not kinds <= set(host.get("runs", [])):
            raise ValueError(f"{name} cannot run {sorted(kinds - set(host.get('runs', [])))}")
        return {"host": name, "reasons": ["named by the batch"]}
    if any(kind_of(r) != "recipe" for r in runs):
        return {"host": LOCAL, "reasons": ["Godot scenes and GPU commands run only on this PC"]}
    if not runs:
        return {"host": LOCAL, "reasons": ["nothing to run"]}
    reasons = []
    status_of = status_of or remote_status
    for host in hosts:
        if host.get("local") or "recipe" not in host.get("runs", []):
            continue
        why = remote_refusal(host, runs, status_of)
        if not why:
            return {"host": host["name"], "reasons": [f"{host['name']} has the recipe receipt and every commit is on origin"]}
        reasons.append(f"{host['name']}: {why}")
    return {"host": LOCAL, "reasons": reasons or ["no remote host is configured"]}


def remote_status(host: dict) -> dict | None:
    machine = omni_machine(host.get("omni_machine", host["name"]))
    if not machine:
        return None
    try:
        return call(machine, "/status", timeout=float(host.get("status_timeout_seconds", 5)))[1]
    except (OSError, ValueError, urllib.error.URLError):
        return {"error": "unreachable"}


def remote_refusal(host: dict, runs: list[dict], status_of) -> str:
    status = status_of(host)
    if status is None:
        return "not paired in Omni's machines.json"
    if status.get("error"):
        return f"status {status['error']}"
    if status.get("paused"):
        return "paused"
    offered = (status.get("cpu_recipe") or {}).get("receipt")
    if offered != host.get("receipt"):
        return f"offers receipt {offered!r}, not {host.get('receipt')!r} (recipes not deployed there)"
    for run in runs:
        if not on_origin(run["commit"]):
            return f"{run['commit'][:12]} is not on origin, so {host['name']} cannot fetch it"
        try:
            needs = manifest_at(run["recipe"], run["commit"]).get("needs", {})
        except (RuntimeError, ValueError) as error:
            return f"no manifest for {run['recipe']} at {run['commit'][:12]} ({error})"
        if needs.get("gpu") and not host.get("gpu"):
            return f"{run['recipe']} needs a GPU"
    return ""


# Running.

def write_receipt(log: pathlib.Path, record: dict) -> None:
    receipt = log.with_name(log.name + ".receipt.json")
    receipt.write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8")


def run_remote(host: dict, run: dict, wait_minutes: float, log: pathlib.Path) -> int:
    machine = omni_machine(host.get("omni_machine", host["name"]))
    if not machine:
        log.write_text(f"{host['name']} is not paired in Omni's machines.json\n", encoding="utf-8")
        return EXIT_USAGE
    manifest = manifest_at(run["recipe"], run["commit"])
    job_id = f"lane-{socket.gethostname()}-{os.getpid()}-{int(time.time())}"[:80]
    job = {"kind": "recipe", "recipe": run["recipe"], "commit": run["commit"], "id": job_id}
    started = time.time()
    deadline = started + wait_minutes * 60
    accepted = False
    while not accepted:
        try:
            call(machine, "/jobs", job, timeout=20)
            accepted = True
        except urllib.error.HTTPError as error:
            if error.code in (409, 423) and time.time() < deadline:
                time.sleep(POLL_SECONDS * 2)
                continue
            text = error.read().decode("utf-8", "replace")[:400]
            log.write_text(f"{host['name']} refused the job ({error.code}): {text}\n", encoding="utf-8")
            write_receipt(log, receipt_record(host, run, job_id, started, None, {"error": f"refused {error.code}"}))
            return EXIT_BUSY if error.code in (409, 423) else EXIT_USAGE
        except (OSError, ValueError):
            accepted = True  # the response was lost; the job may exist: observe it, never resubmit
    ceiling = time.time() + int(manifest.get("timeout_seconds", 3600)) + CHECKOUT_ALLOWANCE
    record = None
    while time.time() < ceiling:
        time.sleep(POLL_SECONDS)
        try:
            record = call(machine, "/jobs/" + job_id, timeout=10)[1]
        except urllib.error.HTTPError as error:
            if error.code == 404 and time.time() - started > 60:
                break
            continue
        except (OSError, ValueError):
            continue
        if record.get("state") in ("done", "failed", "lost", "cancelled"):
            break
        record = None
    if record is None:
        log.write_text(f"{host['name']} job {job_id} did not finish within its ceiling\n", encoding="utf-8")
        write_receipt(log, receipt_record(host, run, job_id, started, EXIT_TIMEOUT, {"error": "ceiling"}))
        return EXIT_TIMEOUT
    output = record.get("output") or ""
    if record.get("error"):
        output += ("\n" if output else "") + str(record["error"])
    log.write_text(output, encoding="utf-8")
    exit_code = record.get("exit_code")
    if not isinstance(exit_code, int):
        exit_code = 0 if record.get("state") == "done" else 1
    write_receipt(log, receipt_record(host, run, job_id, started, exit_code, record))
    return exit_code


def receipt_record(host: dict, run: dict, job_id: str, started: float, exit_code, record: dict) -> dict:
    worker_receipt = record.get("receipt") if isinstance(record.get("receipt"), dict) else None
    return {"schema": RECEIPT_SCHEMA, "host": host["name"], "local": bool(host.get("local")),
            "machine": (worker_receipt or {}).get("host") or (socket.gethostname() if host.get("local") else None),
            "kind": "recipe", "recipe": run["recipe"], "commit": run["commit"], "job_id": job_id,
            "started_utc": utc(started), "finished_utc": utc(), "exit": exit_code, "state": record.get("state"),
            "error": record.get("error") or "", "worker_receipt": worker_receipt,
            "worker_receipt_sha256": record.get("receipt_sha256"), "canonical_gate": False}


def run_local(run: dict, log: pathlib.Path) -> int:
    host = {"name": LOCAL, "local": True}
    head = head_commit()
    started = time.time()
    if run["commit"] != head:
        log.write_text(f"this checkout is at {head[:12]}, not the run's commit {run['commit'][:12]}\n", encoding="utf-8")
        write_receipt(log, receipt_record(host, run, "local", started, EXIT_USAGE, {"error": "commit mismatch"}))
        return EXIT_USAGE
    manifest = manifest_at(run["recipe"], run["commit"])
    if set(manifest.get("tools", [])) - {"python"}:
        log.write_text(f"this PC runs recipes that need only python, not {manifest.get('tools')}\n", encoding="utf-8")
        return EXIT_USAGE
    out = log.with_name(log.stem + ".out")
    out.mkdir(parents=True, exist_ok=True)
    argv = [a.replace("{python}", sys.executable).replace("{out}", str(out)) for a in manifest["argv"]]
    env = dict(os.environ, **manifest.get("env", {}))
    try:
        proc = subprocess.run(argv, cwd=REPO, env=env, capture_output=True, text=True, encoding="utf-8",
                              errors="replace", timeout=int(manifest["timeout_seconds"]))
        exit_code, text = proc.returncode, proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as error:
        exit_code, text = EXIT_TIMEOUT, f"timed out after {manifest['timeout_seconds']} s\n{error.stdout or ''}"
    log.write_text(text, encoding="utf-8")
    outputs = []
    for name in manifest.get("outputs", []):
        path = out / name
        outputs.append({"name": name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size}
                       if path.is_file() else {"name": name, "missing": True})
    record = {"state": "done" if exit_code == 0 else "failed", "receipt": {"host": socket.gethostname(), "outputs": outputs}}
    write_receipt(log, receipt_record(host, run, "local", started, exit_code, record))
    return exit_code


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("command", choices=["choose", "run"])
    parser.add_argument("--host", default="")
    parser.add_argument("--wait-minutes", type=float, default=30)
    args = parser.parse_args(argv)
    try:
        payload = json.loads(sys.stdin.read() or "null")
        if args.command == "choose":
            runs = payload if isinstance(payload, list) else [payload]
            print(json.dumps(choose(runs)))
            return 0
        run = normalize(payload)
        if not run.get("log"):
            raise ValueError("a recipe run needs a log")
        log = pathlib.Path(run["log"])
        log.parent.mkdir(parents=True, exist_ok=True)
        if not args.host or args.host == LOCAL:
            return run_local(run, log)
        host = next((h for h in load_hosts() if h["name"] == args.host), None)
        if not host:
            raise ValueError(f"unknown host {args.host!r}")
        return run_remote(host, run, args.wait_minutes, log)
    except (ValueError, RuntimeError, OSError) as error:
        print(f"lane_hosts: {error}", file=sys.stderr)
        return EXIT_USAGE


if __name__ == "__main__":
    raise SystemExit(main())
