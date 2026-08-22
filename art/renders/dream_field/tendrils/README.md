# DF-13 — SURFACE TENDRILS

> *"lets shelve the procedural tentacle and maybe use it as the grist for
> many small tentacles we can spawn across a surface or something"*
> — owner, 2026-08-22

Where the Dream Field's cross-section meets matter, small limbs push through,
nose at whatever is nearest, and withdraw. One mesh, one draw, twenty-four at
a time; they wear the **same material stack as the hero creature**, because
they are the same organism.

All frames below are the review harness (`SWEEP_MODE=tendrils`) carrying the
**actual player lamp on the camera**, in 2A with the room's own fixtures lit,
exactly as in play. The harness aims itself: it waits for a patch to surface
on a **wall inside the lit flat** and photographs *that*, rather than
photographing whatever exists at an arbitrary second.

| frame | what it shows |
| --- | --- |
| `01_before__scattered_thorns.png` | **Rejected.** 5–16 cm, one per wall, unlit: two black specks on a floor. Invisible at room distance. |
| `02_clustered__straight_horns.png` | **Rejected.** Clustering and size fixed the visibility — and exposed the next fault: straight spikes read as *brass horns nailed to the wall*. |
| `05_hex_boot_fault.png` | **Rejected.** Close up, the root flare was a hexagonal boot: six-sided rings, and only one ring inside the flare, so the skirt was a step. |
| `03_ACCEPTED__room_distance.png` | Legible from across the room: curling limbs with molten-gold interiors coming out of the wall beside the door. |
| `04_ACCEPTED__close.png` | Close: wet, beaded, gold-flecked, curving. The hero material at a tenth the scale. |

## What the photographs changed

1. **Size** — 5–16 cm → 16–40 cm, radius 11 mm → 19 mm. A limb has to be a
   hand's length to read as a limb.
2. **Clustering** — each tendril mostly joins the last one's patch (7–13 per
   patch, within ~0.45 m). One body meeting our space *here*, not litter.
3. **Root** — 6 segments → 11, 9 evenly spaced rings → 13 bunched at the root
   (`v = t^1.7`), flare 1.9× → 0.62×. A swelling, not a bell.
4. **Curl** — normal-dominant at the root, aim-dominant (squared) along the
   shaft, plus a per-tendril lateral arc. This is the single change that
   turned horns into limbs.
5. **Emission ×2.4** — the hero is looked at from 30 cm; these are looked at
   from four metres, and at that range only the emission survives.

## Two real bugs the photographs found

Neither was visible in the contract, which passed 14/14 throughout.

**The receding horizon.** `spawned` froze at 26 and never moved again.
`_reseed_absent` re-seeded every lobe that was not *currently* present —
including the ones still on their way in — pushing each one further ahead of
the slice every three seconds, faster than the slice drifts. The field
surfaced once at startup and then went silent for the rest of the session.
It now recycles only lobes the slice has already **passed**.

**The wandering body.** Over sixty seconds not one lobe surfaced in the case
flat: the field drifted across the whole building. The body is here *for
someone*, so the controller now keeps a `home` — the case flat — and prefers
the organism's own nodes within `HOME_R` of it.

`DreamFieldTest` is now **16/16**; the two checks added for these bugs would
have caught both.

## Known, not yet fixed

- At room distance they are near-silhouette: the gold interior reads, the
  purple flesh does not. Correct for a dim flat, worth revisiting under the
  DF-4 tiers.
- Tendrils intersect furniture (they grow through shelves). No clearance test
  yet.
- A harness fault, not a game one: standing off from a *floor* patch means
  standing off along the floor's normal, i.e. two metres straight up into the
  slab above, which photographs as a featureless dark disc. I first wrote this
  up as an opaque dream volume; it is nothing of the kind. The harness now
  prefers wall patches.
