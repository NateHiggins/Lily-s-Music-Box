# HARUKIYA NYC — REFERENCE NOTES

The evidence file the brief demands. Every spatial and dressing decision
is filed under one of four headings, and nothing moves between headings
silently:

- **CANONICAL** — visible in the film or surviving production art
- **INFERRED** — extrapolated conservatively from visible geometry and
  ordinary human dimensions
- **NYC ADAPTATION** — the fiction of the transplant: what a New York
  operator added, repaired, or was forced to install
- **GAMEPLAY NECESSITY** — exists because the player needs it

Primary references on file: the stairwell descent frame (litter on the
treads, teal walls, red rug at the bottom) and the Belchí Lorente
interior study (canopy over the long counter, barrels and crowded
pictures on the backbar wall, violet-felt pool table, round tables,
booth seating at right). Secondary: production-background scholarship
confirming the two arcade cabinets immediately left of the entrance and
Otomo's teal-offset-by-red staircase composition.

**LAYOUT REBUILD (2026-08-07).** The owner supplied Belchí Lorente's
full layout doc and interior concept — the same artist this file
already cites as the primary interior study, now with the plan, the
layout-exploration sheet, and his own note that he imagined the room
"a bite more friendly than in the manga". The bar was rebuilt to it.

The room now runs 9.2 m deep instead of 6.8 (the block above is hollow
to 3.55 and the basement had been using two thirds of its footprint)
and reads as the study's three zones: a raised lounge of banquettes
behind a turned-baluster railing where you arrive, a checkerboard
table floor in the middle, and a curtained stage at the far end under
a lit sign. Added with it: the rubble dado, the crowded gallery wall,
exposed ceiling services, seven tables with candles and bentwood
chairs, an upright piano, PA stacks, and palms.

Nothing canonical moved. The teal descent, the red steel door, the two
arcade cabinets immediately left of the entrance, the deep canopy over
the counter, the barrels and pictures behind the backbar, the violet
felt and the low ceiling are all where the evidence ledger puts them —
the cabinets now stand on the raised deck, which is still the first
thing on your left. This is a NYC ADAPTATION entry, not a canon
revision: the film's basement is still the film's basement, and what
changed is what a New York operator did with a bigger cellar.

**Standing integration rulings (2026-08-07):**

1. **Renderer stays `gl_compatibility`.** The brief specifies Forward+;
   the Orison targets mobile and the entire lighting doctrine
   (per-object light budgets, the LightRig rationing, lesson #48) is
   built on gl_compatibility. The brief's lighting *principles* —
   practical sources only, localized emission, no giant fill omnis —
   transfer intact; its renderer choice does not. Flagged to the owner
   rather than switched silently.
2. **The Harukiya is a room in the Orison's block**, not a standalone
   project. It sits under the south block (nbr_s2), across the new
   30 ft street. The brief's street-threshold requirement is satisfied
   by the block itself.
3. **The brief's component and phase architecture maps onto the
   existing pipeline** (gen_layout → Blender buffers → marker-spawned
   props) rather than the proposed fresh res:// tree. Its `docs/`
   deliverables are honored at the paths it names.

---

## 0. AMENDMENTS FOR THE 1928 REBUILD (owner authority, 2026-08-16)

*The owner commissioned an expansion of this room and then instructed:
"please edit the canon to meet our practical needs." A ten-agent audit
found the commission's first objective physically unmeetable in plan and
found four ledger claims blocking the rest. These amendments answer them.
The ledger's method is unchanged — every entry still files under one of
the four headings, and nothing moves between headings silently. Full
audit and blocker list: `design/HARUKIYA_RECONSTRUCTION_BRIEF.md`.*

### A0.1 THE LOW CEILING IS A CONDITION OVER THE COUNTER, NOT A CONSTANT

The ledger already files "~2.65 m floor-to-structural-ceiling" under
**INFERRED**, and separately files the **canonical** low element as the
huge canopy/soffit over the counter with its continuous light strip —
1.76 m clear in the built room. Those are different claims, and the
identity list's "the low ceiling" has been read as the first when the
evidence only supports the second.

**Ruled: the canopy is canon; the 2.65 m field is not.** The low ceiling
is a *condition you feel where you drink* — over the counter, the raised
lounge, the west bay and the stage, where it stays exactly 2.65 m clear
and the canopy stays exactly 1.76 m. The **middle of the room may open**.

This is what makes the commission possible at all. The room's footprint
is locked inside a fixed canon mass and can gain **+2.7%**; the section
can gain **+47%** by reclaiming brick above the room that is the bar's
own generated fabric. You stay under a low lid at the bar and the room
goes up two storeys three paces out — compression and release, which is
the film's own instinct rather than a departure from it.

### A0.2 THE STAIR WIDENS; THE DESCENT STAYS MEAN

The ledger's "circulation: minimum ~850 mm, generally 950–1200 mm. Never
generous" is **retained as the room's character** and struck as a
dimensional rule for the stair alone. Owner ruling: the shaft widens from
1.15 m to **approximately 1.6 m** — enough that two people pass, which
reads generous *relative to the film* while remaining tight by any other
standard. Everything else about the descent gets denser, not roomier:
this is NYC ADAPTATION, with the same precedent the 2026-08-07 rebuild
used when it took the room from 6.8 to 9.2 m deep.

### A0.3 THE FIT-OUT IS SECOND-HAND, AND THAT IS THE WHOLE TRICK

The commission wants 1928 metropolitan grandeur — mahogany, a leaded
mirror, a brass foot rail, a coved plaster ceiling — in a Queens cellar,
without retro cosplay. **Ruled: the grand fabric is inherited, not
commissioned.** The tenant fitted this room out from a closed hotel bar:
everything twenty years old when it arrived, cut down to fit, repaired by
four different people, and none of it originally drawn for this room. The
block's own pawnbroker "sells what the building needs".

This buys the grandeur honestly *and* solves A0.4, because it makes the
two aesthetics legible **as two** instead of blending them into mush.

### A0.4 WHOSE ROOM THIS IS, AND THE FLOOR UNDER ITS JAPANESE CONTENT

No document stated it, so it is stated here. **The Harukiya is
Japanese-run.** The grand fabric is second-hand American and inherited
(A0.3); the things that are *theirs* are the things they brought and the
things they maintain — the signboard, the lantern, the barrels, the
service at the counter, what gets sung and when.

**The floor, which exists because the audit predicted the failure
exactly:** the room's Japanese content is three objects today, and adding
178 m³ of coffered ceiling and mirrored backbar would drive that share
toward zero *without anyone deciding to remove anything* — identity
erased by arithmetic. So:

> **Japanese content scales with the room.** Any phase that adds volume
> or fabric must state what it adds on this side of the ledger in the
> same breath. A phase that adds only inherited American fabric is
> incomplete, not neutral.

Nothing existing may be removed to make room for grandeur. If a proposed
object would displace the barrels, the signboard or the lantern, the
object loses.

### A0.5 HELD PENDING A CONSUMER SWEEP

Two amendments are drafted but **not applied**, because a repo-wide sweep
for dependants is still running and a canon edit that silently breaks a
test is the failure mode this ledger exists to prevent:

- **The NYC ADAPTATION timeline is stale.** Its sprinkler line, smoke
  detector, GFCI outlets, modern POS, security camera and "35 years of
  American operation" were written for a contemporary-set fiction that
  the 1928 ruling silently overwrote. The signal machines — karaoke,
  receivers, jukebox — are expected to survive intact under the Bible's
  existing rule that signal-reproducing technology is native here rather
  than anachronistic; the building-code retrofits need re-dating.
- **In-world dates that cannot exist**: the bar describes "this block in
  1948" and "the bar under its first name, 1962", and three jukebox
  tracks are dated 1999–2008. Either re-date them or file them under the
  same undated-arrival phenomenon as the receivers. The sweep decides
  which is consistent.

---

## I. EVIDENCE LEDGER

### CANONICAL
- Basement bar beneath a rundown building; entered by descending an
  enclosed stairwell from the street.
- Stairwell: institutional teal/green, peeling, littered — cans and
  refuse on the treads; a **soiled red rug**; graffiti and stickers.
- Entrance door: battered painted **red steel**.
- Immediately **left** on entering: **two upright arcade cabinets**.
- Long bar counter, dark top with **aggressive red trim**; bartender
  zone behind with shelving, bottles, refrigeration, clutter.
- **Wall barrels** and crowded framed pictures behind the backbar.
- A huge low **canopy/soffit over the counter** with a continuous
  light strip at its rim; dark ceiling above it.
- Overstuffed **couch seating**, mismatched, adapted into booths.
- **Pool table with violet/purple felt.**
- Round tables, bentwood-ish chairs, bottles left standing.
- Tall indoor **palms/tropical plants**, improbably alive.
- A glowing, overdesigned **jukebox-like music machine**.
- Red-orange floor tile in the interior study.
- Palette law: dirty warm light, poisoned green walls, bruised red
  accents, localized cyan/green/pink electronics. Teal offset by red
  is Otomo's own staircase composition.

### INFERRED (conservative, provisional dimensions from the brief)
- Main room **~10.8 × 6.8 m**, floor-to-structural-ceiling **~2.65 m**.
- Stair: clear width **~1.15 m**, **16 risers × 175 mm** (2.80 m drop),
  treads **270 mm** (4.05 m run + landings).
- Door **900 × 2050 mm**, heavy closer, imperfect frame.
- Counter **~5.2 m × 0.68 m**, top at **1080 mm**.
- Circulation: minimum ~850 mm, generally 950–1200 mm. Never generous.
- Masonry/plaster walls, layered repairs; low ugly ceiling with beams,
  pipes and conduit — every run supported and terminated.

### NYC ADAPTATION (the transplant fiction, reads as a timeline)
- The karaoke system, installed cheaply ON TOP of the room: tiny
  plywood stage (~2.6 × 1.8 m, 200 mm high, chipped black edge),
  wall-bracketed karaoke display with imperfectly hidden cabling, two
  wired mics + one cheap wireless, cheap stands, two modest PA
  speakers, compact mixer, battered song terminal, the obsolete
  printed binder, a grimy remote.
- Code retrofits: EXIT sign, emergency light, extinguisher, sprinkler
  line, smoke detector, GFCI outlets at wet service, modern POS,
  security camera, capacity sign, handwash sign.
- 35 years of American operation: NYC tap handles, quarters not yen in
  the dead arcade token, English graffiti strata over older layers.
- Restroom: one tiny customer WC (door, commercial lock, toilet, sink,
  exposed plumbing, mirror, exhaust, floor drain, mismatched repairs).

### GAMEPLAY NECESSITY
- Playable arcade minigames (≥2 cabinets), original 20–60 s games.
- Karaoke loop: terminal → queue → stage → timed lyrics (SongData /
  LyricEvent resources, original songs only).
- Seats the player can occupy; drink order with physical preparation.
- ≥50 inspectable objects; interaction reach 1.5–2.0 m.
- Debug: teleports, collision view, forced song, reference-angle
  screenshot stations for film-composition comparison.

---

## II. ROOM INVENTORY (by zone)

**Stairwell + vestibule** — teal peeling walls · treads with litter
(cans, paper, a crate) · red rug · sticker/graffiti strata · fluorescent
on a ballast hum · red steel door, closer, kick plate · EXIT sign
(retrofit) · capacity sign.

**Entrance zone / arcade corner (SE)** — two upright cabinets (01
traditional, 02 flamboyant) hard against the south wall, screens angled
away from the door glare · power to a real receptacle · dead token under
cabinet 01 · worn floor arc where players stand.

**South side, continuing west** — jukebox (hero, glowing) · couch bank:
four distinct modules (dark moss, faded brown-maroon, near-black green,
dirty burgundy), low laminate tables, underside stickers · cabinet 03
(music-adjacent amusement) deeper in · plant cluster.

**North side (the bar)** — counter ~5.2 m, dark top, red trim, canopy
over with rim light strip · stools · foot rail · service opening · back
bar: mixed shelving, bottle population (varied fill/dust/tilt), barrels
on the wall above, crowded pictures · sink, drainboards, ice bin,
under-counter cooler, soda gun · rubber mats · POS (modern) · tip jar,
towel, opener, spike, forgotten pen · fuse box · handwash sign.

**NE corner** — second couch/booth bank facing the bar · round tables ·
plant · security camera high in the corner (retrofit).

**West end** — the karaoke stage (plywood, low) · display on aftermarket
bracket · PA pair · mixer · mic stands · song terminal + binder at the
bar's west end · pool table mid-west under its own pendant · restroom
door SW with its whole small room behind it.

**Everywhere** — conduit with dated paint layers · patched penetrations
· moisture line near the floor · the microdetail pass quotas (§18 of
the brief), concentrated at entrance, table edges, stool zone, arcade
bases, couch crevices, corners, behind the bar.

---

## III. DIMENSIONED PLAN (top-down, north up, 1 char ≈ 0.4 m)

```
            STREET (y=-28.32)                          N
   ═══════╗ door ╔══════ roll-gate relief ══════       ^
          ║  ▼   ║                                     |
          ║ LOBBY║          (ground storey:      W <---+---> E
          ║ stair║           solid infill)             |
          ║  16R ║                                     S
          ║ down ║   drop 2.80 m @ 175 mm
          ║ 1.15w║
          ╚═▓════╝  ▓ = red rug, then RED STEEL DOOR (west into room)
 ─ BASEMENT (floor −2.80, ceiling −0.15) ──────────────────────
 ┌──────────────────────────────────────────────┬───────┐
 │  BACKBAR: shelves·bottles·barrels·pictures    │ COUCH │
 │ ┌──────────── COUNTER 5.2m ────────────┐ svc  │ BANK  │
 │ │        (canopy over, light rim)      │ gap  │  NE   │
 │ │  o    o    o    o    o   ← stools    │      │ tables│
 │ STAGE                                         └───┐   │
 │ 2.6x1.8      POOL TABLE                        ▼  │   │
 │ ▐███▌        ┌──────┐                        RED  │   │
 │ mic·PA·scrn  │violet│                        DOOR │   │
 │┌────┐        └──────┘                             │   │
 ││ WC │  COUCH BANK S      JUKE  CAB CAB ← arcades  │   │
 │└────┘  (4 modules+tables) BOX  03│ 02  01 (E, left│   │
 └───────────────────────────────────┴───────────────┘   │
   x: −5.1 ←──────────── 10.8 m ────────────→ 5.7
   y: −35.5 (S wall) ← 6.8 m → −28.7 (N wall)
```

Composition check (canonical): standing behind the counter looking
south-east you see counter → seating → arcade cabinets → entrance —
the compressed rectangular sightline of the film.

## IV. SCENES / MODULES TO BUILD

Within the existing pipeline (not a fresh tree):
- `retail_pass` v3: shell to the dimensions above — room, stair,
  vestibule, restroom cell, all collision-bearing.
- Blender assemblies (new): `arcade_cab` (4 silhouettes), `jukebox`,
  `couch_module` (4 variants), `low_table`, `karaoke_rig` (stage,
  bracket screen, PA, mixer, stands), `wc_set`.
- Godot props (new/extended): `ArcadeMachineProp` (attract + playable
  minigame takeover), `JukeboxProp`, `KaraokeTerminalProp` (queue),
  `MicrophoneProp`, `SeatProp`, `InspectableProp` (component),
  `BartenderController` (anchor-based task loops).
- Data: `data/songs/*.tres` (SongData: title, fictional artist, stream,
  duration, lyric_events[], mood, bpm, crowd profile; LyricEvent:
  timestamp, text, end).
- Docs owed later (not yet written, deliberately): an asset manifest and
  an interaction manifest for this room.

## V. REUSABLE COMPONENTS (map to existing systems)

| Brief component | Existing | Gap |
|---|---|---|
| Interactable | `FunctionalProp.interact()` | none |
| Inspectable | — | new component: pickup, rotate, mass class |
| Seat | — | new: sit/exit transforms, occupied |
| Door | `DoorProp` (lock, rattle, tween) | none |
| ArcadeMachine | `MonitorProp` (emissive screens) | playable takeover |
| KaraokeTerminal | — | new (queue UI) |
| Microphone | `micstand` asm | prop + karaoke state |
| Drink | — | new (fill, type) |
| NPC schedules | `resident_routines` + nav graph | bar anchors; folds into task #50's 24 h schedules — the bar's patrons ARE residents |

## VI. ACCEPTANCE

The brief's §35 checklist is adopted verbatim as the completion gate,
with two amendments: renderer criteria are read against
gl_compatibility, and NPC counts draw from the eighteen residents
(whose Jungian schedule pass, task #50, supplies the regulars —
Regular 02's spectacular confidence is a scheduled resident, not a new
body).
