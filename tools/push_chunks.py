"""Push main's outstanding objects to origin in small bites.

The HTTPS transport drops large packs mid-sideband, so: synthetic
commits on tmp-push-chunks, each carrying ~15 MB of blobs from the
target commit, pushed one at a time with retries. Once the blobs are
remote, pushing main itself is a small pack. Progress in
chunk_push.log; safe to re-run (skips what the remote already has).
"""
import os
import subprocess
import time

ROOT = os.path.dirname(os.path.abspath(__file__))
WT = os.path.join(os.environ["LOCALAPPDATA"], "Temp", "claude",
                  "C--PleaseRemainOnTheLine",
                  "f674abaa-22c3-46a4-bcaa-0773d29fbc8d", "scratchpad",
                  "push_chunks")
LOG = os.path.join(ROOT, "chunk_push.log")
TARGET = "main"
BASE = "282a4d0"
CHUNK_BYTES = 15 * 1024 * 1024


def log(msg):
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(msg + "\n")


def git(args, cwd=ROOT, timeout=1800):
    return subprocess.run(["git"] + args, cwd=cwd, capture_output=True,
                          text=True, timeout=timeout)


def main():
    log("=== chunk push start %s" % time.strftime("%H:%M:%S"))
    files = git(["diff-tree", "-r", "--name-only", "--diff-filter=ACM",
                 BASE, TARGET]).stdout.split()
    sized = []
    for f in files:
        blob = git(["rev-parse", "%s:%s" % (TARGET, f)])
        if blob.returncode != 0:
            continue
        size = int(git(["cat-file", "-s", blob.stdout.strip()]).stdout or 0)
        sized.append((f, size))
    batches = []
    batch, total = [], 0
    for f, size in sized:
        if batch and total + size > CHUNK_BYTES:
            batches.append(batch)
            batch, total = [], 0
        batch.append(f)
        total += size
    if batch:
        batches.append(batch)
    log("%d files -> %d chunks" % (len(sized), len(batches)))

    for i, chunk in enumerate(batches):
        git(["checkout", TARGET, "--"] + chunk, cwd=WT)
        git(["commit", "-q", "-m", "chunk %d/%d" % (i + 1, len(batches))],
            cwd=WT)
        ok = False
        for attempt in range(4):
            push = git(["push", "-q", "origin", "tmp-push-chunks"],
                       cwd=WT, timeout=1800)
            if push.returncode == 0:
                ok = True
                break
            log("chunk %d attempt %d failed: %s"
                % (i + 1, attempt + 1, push.stderr.strip()[-120:]))
            time.sleep(10)
        log("chunk %d/%d %s" % (i + 1, len(batches),
                                "pushed" if ok else "FAILED"))
        if not ok:
            log("aborting at chunk %d" % (i + 1))
            return
    # The blobs are up; main's own pack is now small. Keep the remote
    # chunk branch alive until main actually lands - deleting it on
    # failure orphans every pushed blob and the next attempt starts
    # from zero (learned 2026-08-07, 226 chunks lost to four 500s).
    for attempt in range(12):
        push = git(["push", "-q", "origin", "main"], timeout=1800)
        if push.returncode == 0:
            log("MAIN PUSHED")
            git(["push", "-q", "origin", "--delete", "tmp-push-chunks"])
            break
        log("main push attempt %d failed: %s"
            % (attempt + 1, push.stderr.strip()[-120:]))
        time.sleep(30)
    log("=== done %s" % time.strftime("%H:%M:%S"))


if __name__ == "__main__":
    main()
