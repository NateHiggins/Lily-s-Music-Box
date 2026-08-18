"""Cut the concept turnaround into projection plates for the piano truck.

Owner, 2026-08-18: "can you strip that current texture and like projection map
a good texture for the whole truck from this?"

Yes, and it is the right call. The Meshy albedo is a shattered photogrammetry
atlas whose lettering is gibberish at EVERY triangle budget -- tested at 12 k,
120 k and 400 k, and the text reads "...UN A O" in all three. No amount of
mesh fidelity recovers text that was never written. Meanwhile the concept
sheet has the truck drawn properly from two near-orthographic angles, which is
exactly what a planar projection wants.

So the baked atlas is dropped entirely and the body is projected from the art:

  SIDE   art/concept/vehicles/we_tuna_pianos_truck_turnaround_v1.png, the
         small elevation on the lower left. Chosen over the big hero view
         because the hero is a three-quarter and would shear when flattened.
         Projected along Y onto every face whose normal is mostly sideways.
  REAR   the elevation on the lower right, projected along X onto the tail.
  PAINT  everything else -- roof, underside, the nose -- takes a flat coach
         colour sampled from the art itself rather than invented, so the
         surfaces the projection cannot see still belong to the same truck.

The art has its nose to the RIGHT and the mesh has its nose at -X, so the side
projection runs backwards along X. That is handled at the UV, not by flipping
the image, because the rear plate must not flip with it.

Run:  python art/tools/build_piano_truck_projection.py
"""
import os

import numpy as np
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SHEET = os.path.join(ROOT, "art", "concept", "vehicles",
                     "we_tuna_pianos_truck_turnaround_v1.png")
OUT = os.path.join(ROOT, "game", "assets", "building", "textures", "traffic")

# Boxes read off the sheet. Kept as literals with the sheet size beside them so
# a regenerated sheet fails visibly rather than silently projecting the
# background onto the truck.
SHEET_SIZE = (1536, 1024)
SIDE_BOX = (84, 615, 1000, 965)
REAR_BOX = (1045, 625, 1370, 960)


def _tighten(img, tol=34):
    """Trim to the drawn vehicle.

    The projection maps the mesh's bounding box onto the plate's bounding box,
    so any background left in the crop shifts the whole truck's paintwork
    along the body. The trim is by hue: the coachwork is blue against a warm
    grey ground.
    """
    a = np.asarray(img.convert("RGB"), dtype=float)
    r, b = a[:, :, 0], a[:, :, 2]
    lum = a.mean(axis=2)
    mask = (b > r + 5) | (lum < 78)
    ys = np.where(mask.any(axis=1))[0]
    xs = np.where(mask.any(axis=0))[0]
    if len(ys) == 0 or len(xs) == 0:
        return img
    return img.crop((int(xs.min()), int(ys.min()),
                     int(xs.max()) + 1, int(ys.max()) + 1))


def build() -> None:
    sheet = Image.open(SHEET).convert("RGB")
    if sheet.size != SHEET_SIZE:
        raise SystemExit("turnaround is %s, expected %s -- re-read the boxes"
                         % (sheet.size, SHEET_SIZE))
    os.makedirs(OUT, exist_ok=True)

    side = _tighten(sheet.crop(SIDE_BOX))
    # MIRRORED ONCE, AT SOURCE. The elevation is drawn nose-right, which is the
    # truck's FAR side; the mesh's nose is at -X so the near side sees it
    # nose-left. Flipping the plate here means the UV code only has to say
    # which end is which, and the two errors -- alignment and handedness --
    # stop being able to cancel each other and look almost right.
    side = side.transpose(Image.FLIP_LEFT_RIGHT)
    rear = _tighten(sheet.crop(REAR_BOX))
    side.save(os.path.join(OUT, "T_piano_truck_side.png"))
    rear.save(os.path.join(OUT, "T_piano_truck_rear.png"))

    # The coach colour, sampled rather than invented: the median of the bluest
    # third of the side plate, which is body paint and not sign, shadow or tyre.
    a = np.asarray(side, dtype=float).reshape(-1, 3)
    blueness = a[:, 2] - a[:, 0]
    keep = a[blueness > np.percentile(blueness, 66)]
    coach = np.median(keep, axis=0)
    paint = Image.new("RGB", (64, 64), tuple(int(v) for v in coach))
    paint.save(os.path.join(OUT, "T_piano_truck_paint.png"))

    print("projection plates -> %s" % os.path.relpath(OUT, ROOT))
    print("  side %s  rear %s" % (side.size, rear.size))
    print("  coach colour sampled from the art: rgb%s"
          % (tuple(int(v) for v in coach),))


if __name__ == "__main__":
    build()
