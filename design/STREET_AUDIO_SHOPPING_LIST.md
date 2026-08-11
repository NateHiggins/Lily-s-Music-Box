# Street audio — what to download

*2026-08-11. For T2b. The forged loops in `StreetTraffic._forge()` are a
placeholder and should be deleted the moment real recordings land.*

## Licensing — read this first, it eliminates most search results

**CC0 only, or CC-BY with the author recorded.** `ATTRIBUTION.md` already
excludes noncommercial-licensed files as incompatible with a potentially
commercial release, so anything marked NC is a waste of a download. On
Freesound, filter by license before listening.

## Where files go

- Untouched download → `game/assets/audio/freesound/source/` (engine-ignored)
- Game-ready derivative → `game/assets/audio/freesound/processed/mechanical/`
- Add a line to `ATTRIBUTION.md` under CC0 or CC-BY
- Register the key in `PropAudio.RECORDED`

**Mono, .ogg, 22–44 kHz.** Stereo on a positional 3D source is wasted and Godot
will fold it anyway.

---

## The six that matter

Ordered by how much each buys. **1 and 2 alone get the brief's acceptance test
passing** — a player crossing by ear with the camera facing a door.

### 1. Vintage car engine, loopable — `traffic_motor_loop`
A 1920s–30s four-cylinder at steady low revs. **Uneven firing is the point**:
a period engine putters and occasionally misses, and that irregularity is what
makes distance and speed readable. A smooth modern idle will not work.
*Search: "vintage car engine idle", "model T engine", "1920s car".*
**8–20 s, seamless loop.**

### 2. Horse and cart, loopable — `traffic_hooves_loop`
Shod hooves at a walk **plus iron-rimmed wheels on stone**. The wheels matter
as much as the hooves — a horse on its own sounds like a field, and this is a
street. *Search: "horse cart cobblestone", "horse drawn carriage", "hooves
walking street".*
**6–15 s, seamless loop.**

### 3. Bulb horn, one-shot — `traffic_horn`
The "ah-oo-gah" klaxon. **This is the entire feedback for being hit** — no
damage, no screen, no fail sound, just a horn and a stumble — so it has to read
as *annoyed*, not as an alarm. *Search: "klaxon horn", "ahooga", "antique car
horn".*
**0.5–1.5 s.**

### 4. Heavy lorry, loopable — `traffic_lorry_loop`
Slower and deeper than #1, with some load rattle. Distinguishing a lorry from a
car by ear is what lets a player judge how long a gap will take to clear.
*Search: "old truck engine", "vintage lorry", "diesel idle slow".*
**8–20 s, seamless loop.**

### 5. Streetcar, loopable + bell one-shot — `traffic_tram_loop`, `tram_bell`
Electric whine over rail clatter, and the bell separately. The tram is the
largest thing on the road and should be audible before it is visible.
*Search: "tram passing", "streetcar rails", "trolley bell".*
**Loop 8–20 s; bell 1–2 s.**

### 6. Distant traffic bed, loopable — `traffic_bed_loop`
Low continuous city rumble with no identifiable individual vehicle. **This
stops the street being silent between vehicles**, which is currently its worst
quality — silence between passes reads as a bug rather than as a lull.
Should sit well under everything else.
*Search: "distant city traffic", "urban rumble", "traffic ambience far".*
**30 s+, seamless loop.**

---

## Nice to have, not blocking

- **Wet tyres / wheels through water** — the street already has authored
  puddles, and this is the cheapest way to make it feel rained-on.
- **Cart creak / harness jingle** — one-shots to scatter over #2.
- **Distant single horn** — used rarely and far off, so the street sounds like
  it continues past the tears.

## Not wanted

Modern engines, squealing tyres, sirens, car alarms, anything with a radio in
it, and anything recorded close enough to hear a fuel-injection whine. The
street should sound like it is 1928 and slightly too empty.
