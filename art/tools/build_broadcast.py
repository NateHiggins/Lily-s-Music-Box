"""Build the Orison's television broadcast.

    Lily Fern and Erica Cherry's Variety Hour Marathon

The fiction is a building whose aerial picks up more than one station at
once, so this is not a playlist — it is several channels fighting over the
same signal, with the station's own idents and advertising surfacing between
them. Each source clip is a channel; between them the picture tears, rolls,
ghosts or drops out, with the next channel already bleeding through before
the cut lands.

The running order is SHUFFLED per build (`--seed` to reproduce one), so the
marathon is a different night's viewing each time the reel is regenerated.

Output is Ogg Theora, the only video format Godot 4 plays. Audio is stripped
deliberately: this project synthesises every sound at runtime and has no
audio files on disk, and a real audio bed would both break that and fight
the acoustic simulation the game is built on. If the sets should be audible,
the murmur belongs in the procedural mix.

    python art/tools/build_broadcast.py <source_dir> <out.ogv> [seed]
"""
import os
import random
import subprocess
import sys
import glob

# A television in the corner of a room. 384x288 is generous for how large it
# ever gets on screen, and the reel has to stay small enough to ship.
W, H, FPS = 384, 288, 24
## Sources arrive at four different sizes — 704x1280, 576x1048, 480x872 and
## one landscape 1048x576 — so the crop cannot be hardcoded. Scale to cover
## 4:3 and take the centre: correct for any aspect, and on the portrait
## clips it discards the top and bottom bands where the generator's
## watermark usually sits.
FIT = ("scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d"
       % (W, H, W, H))
LOOK = "eq=saturation=0.72:contrast=1.10:brightness=-0.03,noise=alls=7:allf=t+u"
## Shorter than it wants to be, deliberately: a marathon of nearly forty
## channels at six seconds each is a five-minute file, and this reel has to
## live in a repository whose history is already a gigabyte.
SEG = 4.5
GLITCH = 0.5
FONT = "C\\:/Windows/Fonts/arialbd.ttf"

SHOW = "LILY FERN & ERICA CHERRY'S"

## Between-programme idents. Short, and shouted, the way they were.
BUMPERS = [
    ("WE'LL BE", "RIGHT BACK"),
    ("STAY TUNED", ""),
    ("DO NOT ADJUST", "YOUR SET"),
    ("ORISON", "CHANNEL 4"),
    ("ONE MOMENT", "PLEASE"),
    ("WE ARE", "EXPERIENCING", "DIFFICULTY"),
]

## The advertising is the building talking. Every one of these is a line the
## game already owns — the portal rules the residents' cases resolve to, and
## the support line the player works — sold back to them as a slogan between
## programmes. A resolved case's aphorism turning up as an advert is the
## cheapest genuinely unsettling thing in the reel.
ADVERTS = [
    ("PLEASE REMAIN", "ON THE LINE"),
    ("NIGHTLINE REMOTE SUPPORT", "OPERATORS ARE WAITING"),
    ("SILENCE DOES NOT", "REQUIRE ANNOTATION"),
    ("SOME THINGS ARE", "NOT REPAIRABLE"),
    ("GOOD ENOUGH", "CAN HOLD"),
    ("NOT EVERY ALARM", "IS YOURS"),
    ("CONTRADICTION", "IS SURVIVABLE"),
    ("PRESENCE IS NOT", "PRESERVATION"),
    ("A VISIBLE REPAIR", "IS STILL A REPAIR"),
    ("DEPARTURE", "IS A DECISION"),
    ("THE ORISON APARTMENTS", "A GOOD ADDRESS SINCE 1927"),
]


def run(args):
    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0:
        print("FFMPEG FAILED:", " ".join(args[:6]), "...")
        print(proc.stderr[-1200:])
        sys.exit(1)


def esc(text):
    return text.replace("'", "’").replace(":", "\\:")


def card(lines, out, seconds, bg, ink, size, sub=""):
    """A caption card, degraded to match the rest of the transmission.

    Each line is fitted to the frame independently. drawtext will happily
    render past both edges — the show's own title came back as
    "Y FERN & ERICA CHERR" — so the size is capped by the line's length
    rather than trusted from the caller.
    """
    draws = []
    body = [l for l in lines if l]
    # Arial Bold runs about 0.58 em per character; keep to 92% of the frame.
    sizes = [max(11, min(size, int(W * 0.92 / (0.58 * max(1, len(l))))))
             for l in body]
    gap = 12
    total_h = sum(sizes) + gap * (len(body) - 1)
    offset = 0
    for i, line in enumerate(body):
        y = "(h-%d)/2+%d" % (total_h, offset)
        offset += sizes[i] + gap
        draws.append(
            "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=%d:"
            "x=(w-text_w)/2:y=%s" % (FONT, esc(line), ink, sizes[i], y))
    if sub:
        draws.append(
            "drawtext=fontfile='%s':text='%s':fontcolor=%s:fontsize=15:"
            "x=(w-text_w)/2:y=h-42" % (FONT, esc(sub), ink))
    chain = ",".join(draws)
    run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi",
         "-i", "color=c=%s:s=%dx%d:d=%.2f:r=%d" % (bg, W, H, seconds, FPS),
         "-vf", "%s,noise=alls=11:allf=t+u,vignette=PI/4.2,format=yuv420p"
         % chain,
         "-c:v", "libx264", "-crf", "18", out])


def channel(src, out, seconds):
    run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % seconds, "-i", src,
         "-an", "-vf", "%s,%s,format=yuv420p" % (FIT, LOOK),
         "-r", str(FPS), "-c:v", "libx264", "-crf", "19", out])


def interference(kind, outgoing, incoming, out):
    """The signal failing, always with a real picture underneath it —
    interference that carries no image reads as a file ending, not as a
    transmission being lost."""
    common = FIT
    if kind == "static":
        run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % GLITCH,
             "-i", incoming, "-an", "-vf",
             "%s,eq=saturation=0.10:contrast=1.5:brightness=0.05,"
             "noise=alls=95:allf=t+u,format=yuv420p" % common,
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20", out])
    elif kind == "roll":
        run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % GLITCH,
             "-i", incoming, "-an", "-vf",
             "%s,scroll=vertical=0.34,eq=saturation=0.35:contrast=1.25,"
             "noise=alls=45:allf=t+u,format=yuv420p" % common,
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20", out])
    elif kind == "ghost":
        run(["ffmpeg", "-v", "error", "-y",
             "-t", "%.2f" % GLITCH, "-i", outgoing,
             "-t", "%.2f" % GLITCH, "-i", incoming, "-an",
             "-filter_complex",
             "[0:v]%s,eq=saturation=0.45:contrast=1.15[a];"
             "[1:v]%s,eq=saturation=0.45:brightness=0.04,"
             "crop=%d:%d:11:5,pad=%d:%d:0:0[b];"
             "[a][b]blend=all_mode=average:all_opacity=0.55,"
             "eq=saturation=0.30:contrast=1.25,"
             "noise=alls=42:allf=t+u,format=yuv420p"
             % (common, common, W - 11, H - 5, W, H),
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20", out])
    else:
        run(["ffmpeg", "-v", "error", "-y", "-t", "%.2f" % GLITCH,
             "-i", outgoing, "-an", "-vf",
             "%s,eq=brightness=-0.62:saturation=0.05:contrast=1.8,"
             "noise=alls=70:allf=t+u,format=yuv420p" % common,
             "-r", str(FPS), "-c:v", "libx264", "-crf", "20", out])


def main():
    src_dir, out_path = sys.argv[1], sys.argv[2]
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else random.randrange(99999)
    rng = random.Random(seed)
    work = os.path.join(os.path.dirname(out_path), "_broadcast_work")
    os.makedirs(work, exist_ok=True)

    sources = sorted(glob.glob(os.path.join(src_dir, "*.mp4")))
    if not sources:
        sys.exit("no sources in %s" % src_dir)
    rng.shuffle(sources)
    print("%d channels, seed %d" % (len(sources), seed))

    parts = []
    n = [0]

    def add(path):
        parts.append(path)

    def tmp(tag):
        n[0] += 1
        return os.path.join(work, "%03d_%s.mp4" % (n[0], tag))

    # Opening title, then the marathon.
    title = tmp("title")
    card([SHOW, "VARIETY HOUR", "MARATHON"], title, 3.2,
         "0x0b1a2a", "0xf2e4c0", 34, sub="ORISON CHANNEL 4")
    add(title)

    kinds = ["static", "ghost", "roll", "dropout"]
    bumpers = BUMPERS[:]
    adverts = ADVERTS[:]
    rng.shuffle(bumpers)
    rng.shuffle(adverts)

    for i, src in enumerate(sources):
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", src], capture_output=True, text=True)
        span = min(SEG, float(probe.stdout.strip()) - 0.2)
        seg = tmp("ch")
        channel(src, seg, span)
        add(seg)
        nxt = sources[(i + 1) % len(sources)]
        glitch = tmp("gl")
        interference(rng.choice(kinds), src, nxt, glitch)
        add(glitch)
        # Roughly every third break goes to an ident or the advertising.
        roll = rng.random()
        if roll < 0.22 and bumpers:
            b = tmp("bump")
            card(list(bumpers.pop()), b, 1.6, "0x101418", "0xe8d9a8", 28)
            add(b)
            add(glitch)
        elif roll < 0.44 and adverts:
            a = tmp("ad")
            card(list(adverts.pop()), a, 2.4, "0x1a1208", "0xf0d99a", 24,
                 sub="A PUBLIC SERVICE ANNOUNCEMENT")
            add(a)
            add(glitch)

    listing = os.path.join(work, "reel.txt")
    with open(listing, "w") as handle:
        for part in parts:
            handle.write("file '%s'\n" % part.replace("\\", "/"))

    print("encoding Theora from %d segments..." % len(parts))
    run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0",
         "-i", listing, "-an", "-c:v", "libtheora", "-q:v", "4",
         "-r", str(FPS), out_path])
    size = os.path.getsize(out_path) / 1048576.0
    dur = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", out_path], capture_output=True, text=True)
    print("BROADCAST %s\n  %.1f s  %.1f MB  %dx%d  seed %d"
          % (out_path, float(dur.stdout.strip()), size, W, H, seed))


if __name__ == "__main__":
    main()
