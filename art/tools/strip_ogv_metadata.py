"""Strip container metadata from every shipped .ogv, in place.

The broadcast clips carried source-chain metadata (vid_md5 comments and
friends) whose bytes are not valid UTF-8; Godot's Theora demuxer warns
`Invalid UTF-8 leading byte (a9)` on every station boot — one of the
execution plan's Phase 0 baseline blockers. Nothing in the game reads
stream comments, so the fix is a pure remux: no re-encode, metadata
dropped, every output self-decode verified before it replaces the
original.

    python art/tools/strip_ogv_metadata.py
"""
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Same pin as build_tv_clips.py — a verified toolchain beats a probably-fine
# one, even for a copy remux.
FFMPEG = os.path.expandvars(r"%LOCALAPPDATA%\claude\ffmpeg71\ffmpeg.exe")
if not os.path.exists(FFMPEG):
    FFMPEG = shutil.which("ffmpeg")


def main() -> None:
    pattern = os.path.join(ROOT, "game", "assets", "video", "**", "*.ogv")
    cleaned = 0
    for path in sorted(glob.glob(pattern, recursive=True)):
        tmp = path + ".strip.ogv"
        subprocess.run(
            [FFMPEG, "-y", "-v", "error", "-i", path, "-c", "copy",
             "-map_metadata", "-1", "-map_metadata:s", "-1", tmp],
            check=True)
        verify = subprocess.run(
            [FFMPEG, "-v", "error", "-i", tmp, "-f", "null", "-"],
            capture_output=True, text=True)
        if verify.returncode != 0 or verify.stderr.strip():
            os.remove(tmp)
            sys.exit("SELF-DECODE FAILED for %s:\n%s" % (path, verify.stderr))
        os.replace(tmp, path)
        cleaned += 1
        print("stripped %s" % os.path.relpath(path, ROOT))
    print("%d files remuxed clean" % cleaned)


if __name__ == "__main__":
    main()
