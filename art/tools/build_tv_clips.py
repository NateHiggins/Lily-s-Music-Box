"""Process each source video into its own clip for the broadcast director.

One source, one clip, CLEAN — no baked grading, noise or interference.
Whatever the transmission does to the picture is done live by the
director's shader, so the same clip can play pristine one night and
possessed the next. The single pre-baked reel this replaces could only
ever fail the same way in the same places.

Output: game/assets/video/clips/ch_NN.ogv (portrait 320x576 Theora q5,
Vorbis audio kept — the programmes sound like programmes) plus
clips.json naming each clip and its duration for the director's shuffle.

    python art/tools/build_tv_clips.py <source_dir>
"""
import glob
import json
import os
import subprocess
import sys

W, H, FPS = 320, 576, 24
OUT_DIR = r"C:\PleaseRemainOnTheLine\game\assets\video\clips"
## NOT the ffmpeg on PATH. The Gyan 8.1.2 build writes MALFORMED Theora —
## its own decoder fails with "error in unpack_block_qpis" on its own
## output, in both quality and bitrate mode. Every corrupt picture this
## project ever showed on a television traces to that encoder. 7.1 is the
## newest build that encodes valid streams; keep it pinned until a fixed
## 8.x exists (verify by encoding then self-decoding a frame).
FFMPEG = os.path.expandvars(
    r"%LOCALAPPDATA%\claude\ffmpeg71\ffmpeg.exe")
import shutil as _sh
if not os.path.exists(FFMPEG):
    _alt = _sh.which("ffmpeg")
    print("WARNING: pinned ffmpeg 7.1 missing, falling back to PATH (%s) — "
          "VERIFY output self-decodes before trusting it" % _alt)
    FFMPEG = _alt
FIT = ("scale=%d:%d:force_original_aspect_ratio=increase,"
       "crop=%d:%d" % (W, H, W, H))


def main():
    src_dir = sys.argv[1]
    os.makedirs(OUT_DIR, exist_ok=True)
    sources = sorted(glob.glob(os.path.join(src_dir, "*.mp4")))
    manifest = []
    for i, src in enumerate(sources):
        name = "ch_%02d" % (i + 1)
        out = os.path.join(OUT_DIR, name + ".ogv")
        proc = subprocess.run(
            [FFMPEG, "-v", "error", "-y", "-i", src,
             "-vf", "%s,format=yuv420p" % FIT,
             "-r", str(FPS), "-c:v", "libtheora", "-q:v", "5",
             "-pix_fmt", "yuv420p",
             "-c:a", "libvorbis", "-q:a", "1", "-ar", "44100", "-ac", "2",
             # Source-chain metadata carries Latin-1 bytes that Godot's
             # demuxer warns about on every station boot. Ship none of it.
             "-map_metadata", "-1", "-map_metadata:s", "-1",
             out], capture_output=True, text=True)
        if proc.returncode != 0:
            print("FAILED %s: %s" % (name, proc.stderr[-400:]))
            sys.exit(1)
        dur = float(subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", out], capture_output=True,
            text=True).stdout.strip())
        manifest.append({"id": name, "duration": round(dur, 2)})
        print("  %s  %5.1f s  %4.1f MB" % (name, dur,
              os.path.getsize(out) / 1048576.0))
    with open(os.path.join(OUT_DIR, "clips.json"), "w") as handle:
        json.dump({"clips": manifest}, handle, indent=1)
    total = sum(os.path.getsize(os.path.join(OUT_DIR, f))
                for f in os.listdir(OUT_DIR))
    print("%d clips, %.1f MB total" % (len(manifest), total / 1048576.0))


if __name__ == "__main__":
    main()
