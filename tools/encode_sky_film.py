"""CPU-only bounded raw-video encoder relay. Godot uses execute_with_pipe.
No screenshots, no GPU, no network, no shell. Never overwrite an existing film.
The independent watchdog kills this relay's ffmpeg if stdin/write/drain stalls.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffmpeg", required=True)
    ap.add_argument("--out", type=Path, required=True)
    for name, default in (("width", 1920), ("height", 1080), ("fps", 24), ("frames", 576),
                          ("deadline", 1050), ("drain", 60)):
        ap.add_argument("--" + name, type=int, default=default)
    a = ap.parse_args()
    a.out.mkdir(parents=True, exist_ok=True)
    pending = a.out / "sky_day_night.partial.mp4"
    final = a.out / "sky_day_night.mp4"
    receipt = a.out / "encoder.json"
    if any(p.exists() for p in (pending, final, receipt)):
        raise FileExistsError("Use a new output directory; preserve previous evidence.")
    expected = a.width * a.height * 3 * a.frames
    state = {"status": "running", "relay_pid": os.getpid(), "expected_bytes": expected,
             "received_bytes": 0, "frames": a.frames, "fps": a.fps,
             "dimensions": [a.width, a.height], "deadline_seconds": a.deadline,
             "drain_seconds": a.drain, "started_unix": time.time()}
    lock = threading.Lock()
    def record():
        with lock:
            receipt.write_text(json.dumps(state, indent=2), encoding="utf-8")
    args = [a.ffmpeg, "-hide_banner", "-loglevel", "error", "-nostats", "-nostdin", "-n",
            "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", f"{a.width}x{a.height}",
            "-framerate", str(a.fps), "-i", "pipe:0", "-frames:v", str(a.frames),
            "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-threads", "4",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(pending)]
    state["ffmpeg_args"] = args
    with (a.out / "ffmpeg.stderr.log").open("wb") as errors:
        child = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                 stderr=errors, bufsize=0, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        state["ffmpeg_pid"] = child.pid
        record()
        complete = threading.Event()
        def watchdog():
            if complete.wait(a.deadline):
                return
            state.update(status="deadline_exceeded", error="Encoder relay real-time deadline")
            if child.poll() is None:
                child.kill()
            record()
            # Also closes the relay stdin read handle, unblocking Godot's store_buffer.
            os._exit(3)
        threading.Thread(target=watchdog, daemon=True, name="film-encoder-deadline").start()
        try:
            remaining = expected
            while remaining:
                chunk = sys.stdin.buffer.read(min(1024 * 1024, remaining))
                if not chunk:
                    raise EOFError(f"Input ended after {state['received_bytes']} of {expected} bytes")
                view = memoryview(chunk)
                while view:
                    written = child.stdin.write(view)
                    if not written:
                        raise BrokenPipeError("ffmpeg input did not accept bytes")
                    view = view[written:]
                remaining -= len(chunk)
                state["received_bytes"] += len(chunk)
            child.stdin.close()
            code = child.wait(timeout=a.drain)
            if code:
                raise RuntimeError(f"ffmpeg exited {code}; see ffmpeg.stderr.log")
            pending.replace(final)
            with final.open("rb") as finished:
                digest = hashlib.file_digest(finished, "sha256").hexdigest()
            state.update(status="pass", ffmpeg_exit_code=code, final_file=str(final),
                         sha256=digest, bytes=final.stat().st_size)
        except BaseException as exc:
            state.update(status="fail", error=f"{type(exc).__name__}: {exc}")
            if child.stdin and not child.stdin.closed:
                try:
                    child.stdin.close()
                except (OSError, BrokenPipeError):
                    pass
            try:
                child.wait(timeout=a.drain)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=10)
            state["ffmpeg_exit_code"] = child.returncode
        finally:
            complete.set()
            state["finished_unix"] = time.time()
            state["wall_seconds"] = state["finished_unix"] - state["started_unix"]
            record()
    return 0 if state["status"] == "pass" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"encoder relay setup failed: {exc}", file=sys.stderr)
        raise SystemExit(2)
