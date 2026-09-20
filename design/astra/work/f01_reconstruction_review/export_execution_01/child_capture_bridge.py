"""Run exact installed C1 controller with a narrowly bound raw-child capture seam.

Preparation only until an explicit execution handoff. This does not install
sources, choose geometry providers, clean outputs, or rewrite controller bytes.
"""
from pathlib import Path
import argparse
import hashlib
import json
import runpy
import subprocess
import sys
import time


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""): h.update(chunk)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    root = Path(config["root"]).resolve()
    output = Path(config["output"]).resolve()
    evidence = Path(config["evidence"]).resolve()
    assert not output.exists(), "fresh nonexistent external export required"
    assert output != root and not output.is_relative_to(root) and not root.is_relative_to(output)
    assert evidence.is_dir() and evidence != output and not evidence.is_relative_to(output)
    controller = root / "tools/m11c1_floor01_owner_first/run_disposable_export.py"
    for relative, fingerprint in config["exact_source_hashes"].items():
        assert sha(root / relative) == fingerprint, "installed C1 source drift: " + relative
    blender = Path(config["blender"]).resolve()
    assert sha(blender) == config["blender_sha256"]
    expected_command = [str(blender), "--background", "--factory-startup", "--python",
        str(root / "tools/m11c1_floor01_owner_first/generate_owner_first_candidate.py"), "--",
        "--generator", str(root / "art/blender/scripts/build_orison.py"),
        "--layout", str(root / "art/data/building_layout.json"),
        "--ownership-sidecar", str(root / "art/data/m11c1/floor01_source_ownership.json"),
        "--output", str(output)]
    real_run, real_popen = subprocess.run, subprocess.Popen
    calls = []

    def capture_once(command, **kwargs):
        assert not calls and list(command) == expected_command, "unexpected/duplicate child invocation"
        assert kwargs == {"cwd":str(root), "capture_output":True, "text":True,
            "encoding":"utf-8", "errors":"replace", "check":False}, "C1 subprocess contract drift"
        stdout_path, stderr_path = evidence / "blender.stdout.raw", evidence / "blender.stderr.raw"
        started = time.monotonic()
        row = {"command":list(command), "cwd":str(root), "status":"STARTING",
            "timeout_seconds":config["blender_timeout_seconds"], "pid":None,
            "actual_blender_exit":None, "forced_timeout_termination":False}
        calls.append(row)
        receipt = evidence / "blender_child.json"
        def record(): receipt.write_text(json.dumps(row,indent=2)+"\n")
        record()
        with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
            child = real_popen(command, cwd=str(root), stdout=stdout, stderr=stderr)
            row.update(pid=child.pid,status="RUNNING");record()
            try:
                child.wait(timeout=config["blender_timeout_seconds"])
            except subprocess.TimeoutExpired:
                row["forced_timeout_termination"] = True
                child.terminate()  # Only this exact owned Blender process.
                try: child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill();child.wait()
            finally:
                row.update(actual_blender_exit=child.returncode,status="EXITED",
                    elapsed_seconds=time.monotonic()-started)
                record()
        raw_out,raw_err = stdout_path.read_bytes(),stderr_path.read_bytes()
        # Preserve the controller's existing UTF-8/replacement semantics exactly;
        # raw bytes are independently retained, not reconstructed from this text.
        def controller_text(data):
            return data.decode("utf-8",errors="replace").replace("\r\n","\n").replace("\r","\n")
        decoded_out,decoded_err = controller_text(raw_out),controller_text(raw_err)
        row.update(stdout_raw_sha256=hashlib.sha256(raw_out).hexdigest(),stderr_raw_sha256=hashlib.sha256(raw_err).hexdigest(),
            stdout_decoded_utf8_sha256=hashlib.sha256(decoded_out.encode()).hexdigest(),
            stderr_decoded_utf8_sha256=hashlib.sha256(decoded_err.encode()).hexdigest())
        record()
        return subprocess.CompletedProcess(command,child.returncode,decoded_out,decoded_err)

    subprocess.run = capture_once
    sys.argv = [str(controller),"--output",str(output),"--blender",str(blender)]
    sys.dont_write_bytecode = True
    controller_exit = 1
    try:
        try:
            runpy.run_path(str(controller),run_name="__main__")
            controller_exit = 0
        except SystemExit as error:
            controller_exit = error.code if type(error.code) is int else 1
    finally:
        subprocess.run = real_run
        receipt={"actual_controller_exit":controller_exit,"intercepted_blender_calls":len(calls),
            "controller_source_sha256":sha(controller),"no_controller_source_rewrite":True,
            "scope":"Exact C1 controller with one explicitly instrumented process boundary; no Blender result is implied by bridge preparation."}
        (evidence/"controller_bridge.json").write_text(json.dumps(receipt,indent=2)+"\n")
    if len(calls) != 1 or any(x["forced_timeout_termination"] for x in calls): return 1
    return controller_exit


if __name__ == "__main__": raise SystemExit(main())
