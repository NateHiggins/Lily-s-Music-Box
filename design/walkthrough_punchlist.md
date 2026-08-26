# Walkthrough punchlist

**Milestone intake (2026-08-26):** this file is the visual evidence ledger, not
a parallel roadmap. `design/MILESTONE_RECONCILIATION_2026-08-26.md` defines how
rows enter the large plan: blockers immediately; uglies only when golden-route
visible or systemic; wishes only after playtest or owner promotion. Resolved and
info rows remain evidence and are not open-task counts. The current triage below
reports no open blocker, so the next pass begins with stable cameras on M2's
fresh-save route rather than a building-wide beauty sweep.

Live log for the room-by-room pass. One line per finding:
`room | symptom | severity` — severity is `blocker` (breaks play),
`ugly` (wrong but survivable), or `wish` (make it better).

Placement and rendering findings from any session land here, one line each,
with the instrument that produced the finding named in the symptom.

## 2026-08-25 SR7-A lobby wall-run

| room | symptom | severity |
|---|---|---|
| F01 lobby, dumbwaiter wall run | FACING: `LobbyPorterBoard` and `LobbyMailBank` use `rotation.y = +PI/2` and present their featureless backs to the corridor; the adjacent dumbwaiter's corrected `-PI/2` working face makes the error legible. Instrument: `MaintenanceDumbwaiterShot.tscn`, `art/renders/dumbwaiter_brake_sr7a/06_wall_run.png` | ugly |

## 2026-08-21 generator watermark in the material sources

| room | symptom | severity |
|---|---|---|
| every surface built from a Gemini source (2A bedroom brick first, owner-reported) | ~~A four-point sparkle glyph, ~96 px of 40 % white, sits ~190 px in from the bottom-right of 61 AI source photos; the ingest's seamless crossfade rolls it onto every tile and derives height/normal/roughness from it, so it repeats across whole walls in all four maps~~ FIXED 2026-08-21: `art/tools/scrub_source_watermarks.py` finds the glyph (synthetic star, band-passed NCC at the fixed inset, measured-alpha shape gate: 124 hits, 61 real, 63 ChatGPT false positives rejected by alpha ~ 0) and unblends it — recovers the texture underneath from a ring-fitted background, then matches the coarse level — on the SOURCES; 147 material sets re-ingested, GLBs/textures rebuilt. A hairline edge can remain on dark grounds (sub-3 mm on a wall); the 10 cm star is gone | resolved |

## 2026-08-21 WK-1 — the encroachment found the perimeter plaster facing the brick

| room | symptom | severity |
|---|---|---|
| every storey, east / north / south perimeter walls | ~~FINISH FACING: `build_baked_wall_finish` emitted every finish quad with one winding per orientation regardless of `in_side` (x-walls +x, y-walls +z), so the alpha-masked plaster on the east and the north/south perimeter back-face-culled from its own room — only west-wall finishes had ever rendered (probed on `floor_02.gltf`: `f02_w01` at z 9.644 facing +z into the brick)~~ FIXED 2026-08-21: the quad now flips with side and orientation; GLBs rebuilt. Before/after at `art/renders/apartment_encroachment_wk1/` | resolved |

## 2026-08-21 live presentation audit — first run of `PresentationAudit.tscn` (H13)

Live-scene findings from `art/renders/presentation_audit_h13/README.md`
(`presentation_audit.json` carries every row). Instrument: the named pass of
`res://tests/PresentationAudit.tscn`. These supersede the 2026-08-20 data-sweep
hypotheses they answer; generator fixes still wait for contended-file scheduling.

| room | symptom | severity |
|---|---|---|
| kitchens 1A/1D/2A/3A/3D/4A/4C/5A/6A/6C | ~~SUPPORT RAY: every `TOASTER_01` base 215 mm inside `furnish_hull`; OVERLAP: toaster × kettle 133–152 mm~~ FIXED 2026-08-21: `_toaster_marker`'s offset was rotated by facing yaw while the clutter was not, so every yaw-180/−90 run stood the toaster on the dishrack (inside its hull — the 215 mm). Offset now in the run frame; `_validate_kitchen_worktops` guards it (fails the old layout 21×). Re-audit: toaster rows 0, support faults 16 → 6. Before/after at `art/renders/presentation_audit_h13/toaster_1A_*.png` | resolved |
| ROOF | ~~OVERLAP: `ROOF_VENT_FAN_B` stands 420 mm inside planter `roof_bed1`~~ FIXED 2026-08-21: the garden pass had laid the east bed and a geranium over the 1928 ventilator; the fan now stands at (−3.6, 6.75) on open roof south of the bed (marker move, no rebuild). Before/after at `art/renders/presentation_audit_h13/roof_fan_*.png` | resolved |
| F01 bar (SITE) | SUPPORT RAY: `F01_KARAOKE_SPK_0` and `F01_BAR_SONGBOOK` have no collider within 0.5 m below their base (wall/stage-mounted by intent — confirm in the frame); `F01_KARAOKE_SPK_1` base is 230 mm inside the hull. OVERLAP: the songbook terminal cuts 45–60 mm into the bar dado and two gallery frames. (The bodega radio row moved to its own FIXED line) | wish |
| 6A | OVERLAP: three monitors cut 50–120 mm into `6A_deskwall` and its legs — the monitor prop's stand/cable mesh reaches 222 mm below its base through a 50 mm desk top; the bases sit 10 mm above the top. Prop-mesh question, not placement | wish |
| 4B | ~~SUPPORT: `F04_B_STOVE_01` base 100 mm low~~ FIXED 2026-08-21: the range was authored at floor level under its own 0.10 m plinth; it sits on the plinth now (marker z only). Before/after at `art/renders/presentation_audit_h13/stove_4B_*.png` | resolved |
| F01 bodega | ~~SUPPORT: `F01_BODEGA_RADIO` base 50 mm into `retail_bod_floor`~~ FIXED 2026-08-21: authored at 0.0 under the 50 mm lino finish; now at 0.05 | resolved |
| 2A / 2C / 4B | OVERLAP + SUPPORT: `F02_A_MONITOR_01` × `F02_A_LAMP_01` 56 mm and the lamp base 75 mm into `Service_2A_papers`; `F02_C_MONITOR_01` 50 mm into `2C_bench`; `F02_2C_STOVE_01` 55 mm into three hob-tape strips; `F04_B_LAMP_01` 50 mm into `desk_legs` | wish |
| 6D / 3D | OVERLAP: `F06_6D_SHOWER_01` × `6D_rolledrug` 154 mm; `F03_D_SPEAKER_01` recessed 50 mm into `3D_booth_n` (the booth/mirror residue family) | wish |
| F02_D_BED, F02_D_OFFICE, F05_D_OFFICE | ~~DENSITY CENSUS: zero dressing records~~ BY DESIGN 2026-08-21: 2D is "sealed since 1927: nobody dresses a tomb" and 5D is "vacant (fire damage)" in `gen_layout.py`; the census now reads as the fiction | resolved |
| F04_B_CLOSET, F04_B_VESTIBULE | DENSITY CENSUS: the only undressed rooms (2.1 / 2.8 m²) with no authored vacancy rule; the player's own flat. Median is 0.54 records/m²; corridors F02–F06 sit at 0.08 | wish |
| corridors F02–F06 | ~~DATA COVERAGE SWEEP: 22% without a ceiling rect~~ CEILING RAYS 2026-08-21: the uncovered area is the atrium light well (by design) plus ONE grid point per floor that belongs to no room and finds nothing within 3.6 m — that single point is what remains to inspect. Every other ray meets the slab above at ceiling height, visible at standing eye | wish |
| all floors | ~~1.4 m perimeter wall-gap rays~~ CLOSED 2026-08-21: 5,783 rays across every authored wall, 0 see-through samples | resolved |
| F0x_C_BED2 (every floor) | CEILING RAYS: data covers 96%; the slab above closes the rest and is visible at standing eye — reads as bare ceiling, not a hole | info |
| named OrbitSweep stations | ~~RUNTIME LEAD: lights reportedly disappear with view direction~~ ORBITSWEEP 2026-08-21, 8 stations × 36 frames: granted set is direction-blind (only `F01_STREETLAMP_04` flickers across the 0.05 energy line); granted lights with centre in view dropped by the culler: 0/288. Not gating, not rank churn, not culling. Remaining suspects are per-object light assignment on merged meshes and fixture flicker — look with `LightingDebugTest` room by room | ugly |
| all rooms | STILLS: `WalkthroughShots` rerun wrote 182 frames (established count 183) — one diagonal fewer from the current layout; frames in the session scratchpad | info |

## 2026-08-21 dream fauna inspection (FA-V4)

| room | symptom | severity |
|---|---|---|
| dream (all pockets) | DREAMWALK F PROBE: Compatibility stores MultiMesh `INSTANCE_CUSTOM` as truncated half-floats; record `(0.5033, 16448, 1024, 45276)` reads back `(0.5029, 16448, 1024, 45248)`. Packed high bytes (nutrient, flags, hue) exact; low bytes (emergence, activity, pattern_jitter) quantized to 8–32 steps. Presentation only; modelled by `DreamFaunaChannels.compatibility_half` and asserted in DreamFaunaTest. Repacking is an FA-V1 contract change, not licensed here | wish |
| dream (all pockets) | DREAMWALK CENSUS: ~~`_class_of` errored `int(null)` 20× per census on the five fauna material bindings~~ FIXED 2026-08-21; bindings now classify as `FAUNA (<family>)` | resolved |

## 2026-08-20 presentation sweep — data findings and runtime leads

Read-only sweep of `game/data/building_layout.json` at `8806f99`. These lines
separate facts the generated records prove from live-scene hypotheses that
still require the named instrument. Raw interpenetration totals are not bug
counts: overlap-jointed construction is this builder's joinery idiom, so only
unrelated classes should be compared.

| room | symptom | severity |
|---|---|---|
| kitchens 1A/2A/3A/4A/5A/6A/1D/3D | ~~DATA SWEEP: `TOASTER_01` centre overlaps the dishrack footprint on the same counter run~~ FIXED 2026-08-21 (see the H13 row above: one yaw-rotation fault, not a missing allocator). 4B's hand-placed NW corner keeps its authored 200 mm kettle spacing and its own clearance check | resolved |
| corridors F02–F06 | DATA COVERAGE SWEEP: each corridor has the same 22% area without a ceiling rect. Orbit/up-ray + `show_all_floors` must distinguish a hidden floor-above slab from a genuine generator omission | ugly |
| all non-shaft rooms | DATA SWEEP: zero empty rooms; perceived emptiness is a density/dressing question. Run a records-per-square-metre census and walk the bottom decile | info |
| building-wide free-standing props | DATA SWEEP: zero unsupported baked-record candidates. Run live-scene support rays because marker-spawned mesh origins can still hover or clip | info |
| 3D | DATA CROSS-CLASS RESIDUE: `3D_booth_n` and `3D_mirror` overlap about 5 cm through 1.8 m of height; inspect in the live AABB pass | wish |
| named OrbitSweep stations | RUNTIME LEAD: lights reportedly disappear with view direction. Log RenderingServer visible-light census, LightRig granted set and per-screen-sixth luma over 360° yaw × three pitches to distinguish visibility gating, nearest-16 rank churn, and merged-mesh light selection | blocker |
| reported ceiling gaps | RUNTIME LEAD: upward ray plus `show_all_floors` toggle must distinguish ceiling ownership/visibility gating from the systematic corridor generator gap above | blocker |

Queued instrument: one `PresentationAudit.tscn` with headless live cross-class
AABBs (assembly whitelist), >3 cm prop support rays, WalkTest's existing
`[ART]` sweep, dressing density, and 1.4 m perimeter wall-gap rays; windowed
mode owns the OrbitSweep and the established 183-still WalkthroughShots rerun.
Fresh-worktree import, single-Godot, real-window, 60-second, and A/A noise-floor
rules remain mandatory.

## 2026-08-15 walk — method and caveats

Two full WalkthroughShots passes (183 stills each): one in production
lighting (mood truth) and one with `SCREENSHOT_TEST_CAMERA_LIGHT=1`
(placement truth). **The camera-light pass was only partially effective**:
the merged per-floor meshes kept 16 lights by AABB overlap, so on busy
floors the camera omni was dropped and F02_D/F05_D unit interiors rendered
black in BOTH passes — those rooms needed an in-engine look with their own
switches on (RoomLumaAudit's method) before trusting them.

> **CLOSED 2026-08-16 — RE-MEASURED, AND THE ROOMS ARE FINE.** The
> paragraph above was correct about the mechanism and was simply never
> re-run after the mechanism was removed. `max_lights_per_object` went
> 16 → 128, so the camera omni can no longer be evicted by AABB overlap
> on a busy floor.
>
> `RoomLumaAudit` measured both floors rather than eyeballing stills,
> which is the right instrument — it reads pixels back and reports mean
> luma and the share below near-black, against thresholds set from
> measurement (a lit room fails above 55% near-black or below mean 9.0):
>
> | room | mean luma | near-black |
> |---|---:|---:|
> | F02_D_BED | 20.0 | 39.8% |
> | F02_D_OFFICE | 27.8 | 6.4% |
> | F02_D_MAIN | 33.1 | 0.2% |
> | F02_D_BATH | 58.9 | 0.2% |
> | F05_D_BED | 19.2 | 42.8% |
> | F05_D_OFFICE | 28.4 | 6.2% |
> | F05_D_MAIN | 37.3 | 0.2% |
> | F05_D_BATH | 53.1 | 0.2% |
>
> Both floors report **PASS** (20 rooms, 4 exempt). The D units are
> readable; the bedrooms sit highest on near-black at ~40% but are well
> inside the bar and are the dimmest rooms by design rather than by
> defect. Nothing was hiding behind the cap explanation.
>
> One observation left rather than a defect: three of the four D rooms
> per floor report *no fixture* and are readable on spill and window glow
> alone. Both audits accept that, so it is recorded and not chased.
Build was verified current against `building_layout.json` (fcaaf64 is
marker-attribute-only). Stills in session scratchpad `walkthrough/` and
`walkthrough_lit/`.

**Resolved since 08-01, verified by render:** blinds/window offset
(spot-checked clean everywhere reviewed); WSTOR white slab+cube — F05/F06
now shelved and crated; F04_D giant white mass and F04_B white box —
both units furnished (photo, radio desk, grandfather clock); F01_HALL
white rectangle over the stair opening gone; "OUR QUEENS" poster sits on
its pier; bathrooms rebuilt (pedestal sinks, tile, mirrors, sconces);
F05_A_MAIN reads as a lived room (kitchen, Marian print, desk lamp);
B1_LAUNDRY wringer bank + airer read correctly; F03_A_BATH restructured
(no toilet-in-shower at the reviewed angle).

**Shot-rig gaps found this walk (fix in walkthrough_shots.gd, not the map):**
broadcast/radio caption overlay ("THE BUILDING SELECTED — …") burns into
frames — a caption owner added since 08-01 that the rig's CanvasLayer
hide + fourth_wall/sanity silencing doesn't cover; resident nameplates
render in shots; the F04_ATRIUM camera stands inside the shaft wall
(black wedge fills a third of the frame). The F04/F06 atrium
"translucent smears" are NOT defects — authored shadow-figures plus real
baluster shadows, confirmed in the lit pass.

### Persisting from 08-01

| room | symptom | severity |
|---|---|---|
| ROOF | ~~black monolith + angled arm~~ FIXED 2026-08-16: the "monolith" was the near clothespost — authored `metal` (metallic 0.9) reflects the night away and renders 0,0,0 (the flat-metal lesson). Clotheposts, line and tank legs now `cast_iron`; the billboard's 0.055 soot-black backing lifted to weathered timber in `found_art_pass.gd`. Re-render shows speckled iron catching the skyline | resolved |
| B1_ATRIUM | IDENTIFIED 2026-08-16: the "chase tube" is the commissioned light-tree trunk (gen_layout tree pass; the reading nook is authored at its base and WalkTest stations there). Remaining question is narrow and owner-taste: whether the trunk's curve may physically touch the balustrade/nook furniture, or must clear them. Not a defect to move unilaterally | owner |
| F01_A_BED, F06_D_BED | ~~window frames glazed with brick~~ FIXED 2026-08-16: the middle-band street/rear walls in `exterior()` spanned the full face and ran a second windowless wall coincident with the stack end walls — 23 apertures bricked over building-wide. Clamped to ±XAW (their own comment's intent); the B1 areaway door pass re-anchored to the shorter wall; layout sweep now finds 0 blocked apertures and the rebuilt F06_D_BED shows city light through glass | resolved |
| F06_D unit | ~~unfinished set~~ IDENTIFIED 2026-08-16: 6D is authored "landlord storage" (unit status table) — the pale masses are its crate grid, which wore `trim` (painted-woodwork cream) and read as placeholders. Crates now `timber`; racks/rolled rug unchanged. The window was the double-wall fix, already landed | resolved |
| F01_LOBBY | ~~second mail rack~~ IDENTIFIED 2026-08-16 by probe: the lattice under the lobby clock is the elevator's CarGate scissor grille — correct furniture. The old generated mailbank was already removed at the generator (its comment survives at gen_layout ~:2704) | resolved |
| B1_COAL | improved (whitewash, hopper mass has form) but the bin is an untextured gray primitive and there is still no coal or grime | wish |
| B1_STORAGE_CAGES | near-void in production light with its switch state as-is — this is the open L9 owner call, logged here only as walk confirmation | — |

### New findings 2026-08-16 (surfaced while fixing the blinds)

| room | symptom | severity |
|---|---|---|
| C_BED1 / C_BED2, F02–F06 | ~~Ten bedrooms with no exterior aperture at all~~ FIXED 2026-08-16. `remove_partition_crossing_windows()` deleted any facade opening a perpendicular partition cut through and stopped there — but the partition is what is wrong for the window, not the room's need of daylight, and C's bedroom partition lands squarely on its rear aperture. A crossed window now SLIDES along its own facade, in 0.05 m steps outward from where it was authored, to the nearest slot that clears every partition, every other opening and both wall ends; only a window with no legal slot within 2.60 m is removed. Facade audit now reports **removed 0** where it used to delete 16, exterior windows go 80 -> 96, and the blinds pass dresses 66 where it dressed 50. New `_validate_daylight()` asserts the rule that actually matters — no habitable room owning a piece of facade is left dark — and reports 0 | resolved |
| F01 1B / 1C | Neither unit receives a single blind, i.e. neither has a dressed aperture. Likely the same cause as the C-stack row above, or ground-floor shopfront geometry; unverified | wish |

### New findings 2026-08-15

| room | symptom | severity |
|---|---|---|
| several floors | ~~recurring small unlit black blob prop~~ IDENTIFIED 2026-08-15 by probe: `DomesticAnomaly_player_smart_speaker` and siblings — authored case-anomaly props (impossible modern objects, meant to be dismissable per X1). A black cylinder is the correct read; not a defect. Legibility tuning is an owner-taste call | resolved |
| corridors/units | ~~residents read as pure-black cutouts~~ FIXED 2026-08-16: every Meshy hero GLTF omits `metallicFactor` and glTF defaults it to **1.0** — fully metallic people reflect the room light away. Both spawn paths (AnimatedResident presence-glow walk, routines `_upgrade`) now clamp metallic>0.5 to dielectric; probe confirms all residents at metallic 0.00 in the live tree | resolved |
| baths | ~~mirror faces render as black voids~~ FIXED 2026-08-16 at the material's true author (gen_layout MATERIAL_CATALOG → material_catalog.json → runtime manifest → material_sets.gd): `mirror_aged` retuned 0.78/0.18 metallic/rough → 0.35/0.45 — worn mercury glass reads by its haze. Chain regenerated end to end | resolved |
| F02/F06_ATRIUM | empty "frame" at skirting level — DOWNGRADED 2026-08-16: a runtime probe at both sighting spots found no prop within 1.6 m, and no art data places anything low; the rectangle is most likely baked wainscot panel molding reading as a frame in raking light. Revisit only if it bothers the eye in play | wish |
| F03_A_BATH | small black chip/box floats at the ceiling corner over the doorway | wish |
| F01_OFFICE | ~~photographic print floats under the desk shelf edge~~ FIXED 2026-08-15: `FoundPrint_office_magazine` in `found_art_catalog.json` was anchored at (-11.8, 4.4, 0.845) — open air 0.75 m off the desk; moved onto the desk top at (-12.45, 3.55, 0.742) | resolved |
| F04_D_MAIN | tan cabinet panel above the TV juts diagonally off the wall face | wish |
| F04_B_MAIN | ~~dark blue slab by the shelf~~ IDENTIFIED 2026-08-16 by probe: `DomesticMark_4B_0/1` — authored haunting wall-marks, working as designed | resolved |
| F02_D unit | ~~confirm vacancy is intentional~~ ANSWERED 2026-08-16: the unit status table rules 2D "sealed" — the emptiness is canon, question closed | resolved |
| F05_D_MAIN, F06_C_MAIN | ~~unjudgeable (light-budget caveat)~~ CLOSED 2026-08-16: the rig now flips each room's own switch (RoomLumaAudit's method) instead of leaning on the capped camera omni. F05_D stays dark **by design** — "vacant (fire damage)", and fire-gutted 5D hangs no fixture; F06_C re-shot judgeable and clean | resolved |

## 2026-08-01 walk — method and caveats

Walked by rendered evidence: `res://tests/WalkthroughShots.tscn` (new,
generated from building_layout.json room rects) produced 193 eye-height
stills — every room, two diagonals for rooms ≥ 20 m² — reviewed floor by
floor. `SCREENSHOT_TEST_CAMERA_LIGHT=1` was on, so lighting mood was NOT
judged (that stays LightingAudit's job); this pass is placement, geometry
and function only. Stills in the session scratchpad `walkthrough/` dir.

**Tool artifacts, not bugs (excluded below):** bath/office rects are carved
out of MAIN rects, so a MAIN corner camera can stand inside the nested
bathroom (every "D_MAIN renders a bathroom" frame: F01/F02/F03/F06). Corner
cameras also don't dodge furniture, so a wardrobe parked at the shot corner
fills the frame (C_BED2 on F02/F04/F05/F06 — the wardrobe-in-corner itself
may still deserve a look in-engine). Re-aim those cameras before trusting
those rooms as "clean".

**WalkTest baseline at walk time:** FAIL (5), elevator checks only — since
resolved: the NPC-elevator work landed and the opening lockdown ended the
car contention. WalkTest has been fully green since 2026-08-02 morning.

**Hypothesis for the white-rectangle family** (hall voids, corridor boxes,
roof sign, above the B1 poster): these look like story/atmospheric decal
quads with no texture assigned — `story_decal.gd` and the new
`atmospheric_decal_pass.gd` are both mid-edit in the parallel session, so
coordinate before fixing.

## User-reported 2026-08-02 (lobby pass)

| room | symptom | severity |
|---|---|---|
| lobby | ~~old generated wood mailbank on the south wall~~ STALE: the generated mailbank was already removed at the generator (its comment survives near gen_layout ~:2704). The lattice under the lobby clock is the elevator CarGate scissor grille, correct furniture; the remaining brass bank is placed at runtime by `orison_detail_pass.gd` on the EAST wall, not the south | resolved |
| F01 office | title-image plaque (maintenance_headquarters._build_plaque) — remove from world, retool the concept | ugly |
| foyer | bench is decorative and on the wrong side of the entry door — move across, add sit affordance, move Teresa's haunt with it | ugly |
| all floors | ~~wall art misplacement family~~ FIXED 2026-08-16. Same class as the blinds: `legal_spot` inset a flat 0.105 m from a `room.rect` edge, but STACK_RECTS are interior FACES while partition rects sit on CENTRELINES, so one constant could not mean one thing. The law now finds the backing wall first and seats the hook off its real face. Four more defects fell out with it: `wall_backs` applied its thickness pad ALONG the run as well as across, endorsing hooks past a wall's own end and never testing the piece's own width; it had no orientation gate, so a perpendicular wall could validate a hook and the frame hung at right angles to its backing; `RAIL_TOP` was 1.56 against a dado the builder tops at 1.32 with a bead at 1.355, i.e. 0.20 m of invented height pushing hall pieces into the ceiling trim and the elevator surround; and `furniture_blocks` saw only `rect` and `p0/p1` records, missing all 702 `asm` assemblies (1 in 10 of the building's furniture). The wainscot refusal also ignored `wains_side`, refusing the plaster face of every tiled partition. New `WallArtLawTest.tscn` drives the real law over every room and judges what it accepted using build_orison's numbers, not the law's own: **125 violations before (89 buried, 14 overhang, 11 furniture, 6 orientation, 5 opening), 0 after**. Counts unchanged at 20/20/8; found-art walls 18 -> 17, the one loss being a piece now correctly refused rather than hung illegally | resolved |
| stairway | half-landings share/lack art — each of the seven landings needs a unique piece | wish |
| 1A / cast | Evelyn's original Meshy model stands 1.80 m while the height-baked hero cast bases at 1.70 m — canon 0.96 says ~1.63. She reads tall against her neighbors; bake her too (she is also the biped move-library donor, so update DONOR_HIPS when rescaling her file) | wish |

## Systemic (one fix, many floors)

| room | symptom | severity |
|---|---|---|
| all bedrooms/kitchens | ~~Blinds decoupled from windows~~ FIXED 2026-08-16. The row's stated cause was wrong, which is why it survived one fix already: `unit_windows()` reports a wall CENTRELINE, and `blinds_for_unit()` inset a flat 0.10 m from it as though it were the plaster face, so all 50 generic blinds stood inside the brick (F01 1A_bl0_head spanned x[-13.695,-13.635] against an interior face at -13.590, t=0.41 - 0.045 m buried). An earlier rewrite had corrected the ALONG-wall axis and introduced this cross-axis fault in the same change, and its verification measured only the axis it had fixed. Thickness now travels out of `unit_windows`; `_mount()` places off the face; the head rail hangs under the aperture head instead of level with it (z0 2.55 -> 2.50); the drop clamp reads the window's own sill instead of `WIN_COURT["sill"]`, a constant describing a court window this building does not contain. New `_validate_blinds()` in gen_layout asserts adoption, side, clearance, head height and uniqueness from the wall and opening records rather than from literals: **112 violations before, 0 after** | resolved |
| several bedrooms | ~~Windows glazed with brick~~ SUPERSEDED by 9acc1d6, the same `exterior()` +/-XAW clamp that closed the F01_A_BED / F06_D_BED row above: the second windowless wall running coincident with the stack end walls bricked over 23 apertures building-wide, and the layout sweep now reports 0 blocked. Re-walk before reopening | resolved |
| several bedrooms | ~~Wardrobe parked directly in front of a window / crowding a doorway~~ D-STACK FIXED 2026-08-16 (1D/3D/4D: 1.105 m of a 1.35 m window, 82%, moved 1.80 m west, overlap now 0.000). THE REST ARE NOT REPRODUCIBLE in the current layout: A-stack wardrobes measure **0.000 m** window overlap on all six floors (they sit at y[-6.89,-6.59], an interior position, not against a facade at all), and 2B / 3B / 6B measure **0.000 m** door overlap. LIMIT OF THAT MEASUREMENT, stated so nobody reads it as more than it is: it tests geometric OVERLAP, not clearance — a wardrobe can crowd a doorway from 0.3 m away and read badly in play while overlapping nothing. These rows came from a visual walk, so they want a re-walk to close rather than a probe. Note also that the 2026-08-16 daylight fix moved 16 windows, so any pre-dating window sighting should be re-checked rather than trusted | wish |
| WSTOR F02–F06 | ~~untextured white slab + bare cube~~ FIXED by a534c7c/f7963af, verified 2026-08-16: F04 WSTOR now emits 55 `crate` assemblies plus materialed linen/rug/cast-iron pieces, and no large-footprint unmaterialed box survives anywhere in the WSTOR set. (The crates report no `mat` in the layout because assemblies carry their material in build_orison, not in the record — that is not the white-surface signature it resembles) | resolved |
| HALL F01–F05 | Blank pure-white rectangle floating in/above the stair opening (also corridor-wall white boxes F02/F03, ROOF sign face, B1 above the exit poster) — see decal hypothesis above | ugly |
| all UTILITY | Duct/chase column freestanding mid-room, stops short of floor and/or ceiling, pendant lamp clipping into its face (B1, F02–F06) | ugly |
| A/B BATH all floors | ~~Faucet hardware detached, floating above/behind the basin~~ FIXED 2026-08-16, and in all 24 lavatories rather than the 6 listed. `tap_prop.gd` mounted the wall valves at a literal z of 0.105 while the integral porcelain back's front face sits at 0.1825, so both valves, the bridge, the union and the spout origin hung **64 mm out in the air** in front of the thing they are supposed to pierce. The rule was already proven 30 lines away: the kitchen sink seats its valves at `d*0.5 - 0.035` against a face at `d*0.5 - 0.0215`, exactly -0.0135. That is now the shared `VALVE_SEAT_DZ` and both fixtures derive their mount from their OWN splashback, so they cannot drift apart again. Root cause of the survival, not just of the bug: `walk_test.gd` asserted `_handle_wall_mounted == [true, true]` — a BOOLEAN, where the defect was a DISTANCE — so when 3b04597 corrected the flag and left the coordinate, the suite went green. The guard now measures the seat gap on all 43 wall-valve fixtures and requires them to agree: **spread 0.0640 m before, 0.0000 m after** | resolved |
| C/D BATH F02–F05 | ~~Towel bar runs past its bracket across the door trim/switch plates~~ FIXED 2026-08-16, and in 13 rooms rather than the 8 listed. Third instance of the same anti-pattern: `bath_fixtures()` derived the rail from the ROOM RECT (`x0 + 0.10` / `x1 - 0.10`), and a room rect edge is not a wall face — measured, that produced THREE different standoffs (0.04 / 0.14 / 0.19 m) depending on which wall family the room sat in, and left **13 rails crossing a door or window reveal**. bath_fixtures cannot fix it itself: it is handed the furniture list and never the walls. New `reseat_bath_rails()` runs after the walls exist, the way the facade pass does, seats every bar 0.075 m off its own wall face and slides the run clear of every reveal. 4B—the player's own bathroom—had no legal 0.62 m slot at all (2.20 m wall, 0.81 m door, 0.575 m clear) and was overhanging its wall end by 20 mm; it now shrinks to a 0.55 m bar, which is what a joiner would do. Result: **projection 0.075 on all 23, uniform; reveal crossings 13 -> 0** | resolved |
| several BATH | Sticky-note/plaque decals at ceiling height, detached from their boards (F01_A, F03_B, F04_A, F06_A/B) | wish |
| unit MAINs | Lived-in socket prop labels ("Mysterious Hotel Towel", "Unfinished Manuscript", "Self-Appending Forms"…) float mid-air detached from props and render mirrored from behind (F01 lobby, F04, F06; F03 reviewer read them as intentional) — if they're meant as look-prompts they shouldn't be world-space always-on | ugly |

## Pre-seeded

| room | symptom | severity |
|---|---|---|
| all units | ~~TV picture bugs~~ FIXED: root cause was ffmpeg 8.1.2 writing malformed Theora; station rebuilt live (per-clip shuffle, E toggles sets, NPC watching, glow, 9-fault shader) | done |
| lobby | ~~duplicate Evelyn (test figure)~~ FIXED: lobby figure retired, assertions moved to the real 1A resident, UUID clips named by eye (ClipSheet.tscn) and ROLES re-pointed | done |
| all units | ~~17 residents still billboard sprites~~ FIXED: the generated `_rigged.glb` cast upgrades in place, and Evelyn's Meshy set is retargeted once onto their shared skeleton (`resident_moves.glb`) — every resident sits, works, reaches and glances; bespoke gaits still win where they exist. Hero models per the execution plan replace these as they land | done |
| broadcast | Sora watermark visible in some frames at close range — DECIDED 2026-08-01: don't care for now; illegible at play distance in every walkthrough still, and clips get re-cut when new broadcast footage lands. Revisit only if a marketing capture frames a TV close up | wish |
| B1 hall | ~~"KNOW YOUR EXIT" poster~~ VERIFIED in the walk: poster reads fine; only remaining issue is the white rectangle above it (decal family, parallel session's) | done |
| corridors | ~~door spill bars~~ VERIFIED 2026-08-02 unlit at play height: warm bar under 4A's door plus jamb slivers read clearly (b_40 re-render); only 9 doors leak by design (circulation/asleep gating) | done |

## B1

| room | symptom | severity |
|---|---|---|
| B1_STORAGE_CAGES | Cage partitions are solid opaque metal (no chain-link read), no cage doors or stored contents | ugly |
| B1_LAUNDRY | ~~Washer/dryer units freestanding mid-floor~~ Resolved: two wall-fed wringers, paired rinse tubs and ceiling airer; automatic dryer removed | resolved |
| B1_LAUNDRY | Empty white window-style frame embedded at ceiling height in the brick wall, top edge clipped | wish |
| B1_ATRIUM | Light-well tube intersected mid-height by a white rail/stringer; its lower run passes through the reading-nook furniture | ugly |
| B1_COAL | Only a bare untextured white block on clean brick — no coal, chute, or grime | ugly |
| B1_UTILITY | Pendant bulb overlapping the chase column (systemic, logged above) | — |
| B1_BOILER, B1_ELECTRICAL, B1_HALL | clean beyond systemic items | — |

## F01

| room | symptom | severity |
|---|---|---|
| F01_LOBBY | Order Board renders as three overlapping teal slabs at different depths; a stray label fragment clips the wall corner by the front desk | wish |
| F01_LOBBY | "Ontological Inspection Clipboard" / "Impossible Tape Measure" nameplates float ~1 m above their table props | wish |
| F01_COMMON_B | Unframed door-sized slab leans flat against the back wall — reads as a loose door leaf | ugly |
| F01_STORAGE_C | One shelf rack is rails-only (no boards) while its twin has full planks | wish |
| F01_HALL | "OUR QUEENS" poster overhangs the wall edge into the stairwell void | wish |
| F01_ATRIUM | Handrail stub protrudes from brick at rail height, attached to nothing; pale pink blotch decal on atrium brick | wish |
| F01_OFFICE | Framed print clips diagonally through the desk side panel; teal cup mounted on a vertical board face | ugly |
| F01_RESTROOM | Dotted diagonal seam across the upper wall — geometry gap or z-fight | wish |
| F01_A_BED | Window partially buried in brick (slats/frame fragments show through wall); grass-green patch on floor at wardrobe base | ugly |
| F01_A_BATH | Tan mat/caddy floats off the tiled shower wall | wish |
| F01_A_MAIN | Family photo frame overlaps the abstract canvas on the same wall | ugly |
| F01_D_BATH | Bath mat propped vertically against the door face — will clip on open | wish |
| F01_D_MAIN | Tall stepped untextured white mass near the right wall — identify the prop | wish |
| F01_D_OFFICE | Thin dark rod floats under the desk top, attached at neither end | wish |

## F02

| room | symptom | severity |
|---|---|---|
| F02_A_MAIN | TV wedged between sofa back and window, overlapping sill/blinds, no stand | ugly |
| F02_A_BATH | Gold sconce/decal at ceiling height | wish |
| F02_B_BATH | Wooden shelf above toilet broken apart — board and dowels hanging diagonally over the mirror | ugly |
| F02_B_KITCHEN | Door trim outlines bare brick (door panel missing) beside a live light switch | ugly |
| F02_C_MAIN | TV overlaps window blinds; blank tan canvas hangs tilted off the brick wall | ugly |
| F02_C_BED1 | Picture frame wedged between wardrobe top and ceiling | ugly |
| F02_D_MAIN | ~~Unit 2D entirely unfurnished~~ ANSWERED: the unit status table rules 2D "sealed", so the emptiness is canon. Duplicate of the row answered under the 08-15 walk | resolved |
| F02_D_OFFICE | Dark geometry pokes through the right wall edge; floor sliver past the baseboard in the corner | wish |
| F02_HALL | Bridge painting hangs into the stair opening, overlapping the interior brick window | ugly |
| F02_ATRIUM | Beige lamp shade floats mid-air with no cord/arm to the brass pole | ugly |

## F03

| room | symptom | severity |
|---|---|---|
| F03_A_BATH / F03_B_BATH | Toilet sits half inside the shower enclosure — glass plane cuts the bowl | ugly |
| F03_B_ALCOVE | Wardrobe faces the main room with its unfinished back panel | wish |
| F03_C_BED2 | Counter/platform top pokes through the doorway wall plane, visible both sides | ugly |
| F03_C_MAIN | Gray squiggle prop clipped to the window frame edge at mid-height | wish |
| F03_D_BED | Floor-to-lintel sliver of blue fabric texture embedded in the wall beside the closet door, visible from both sides | ugly |
| F03_D_BATH | Magenta hamper intersects the tan box behind it | wish |
| F03_D_MAIN | Denim screen/fort walls clip through the glass coffee table; angled plank protrudes through their base | ugly |

## F04

| room | symptom | severity |
|---|---|---|
| F04_D_MAIN | Giant lumpy untextured white mass, floor to near ceiling, jagged silhouette, against the right wall | ugly |
| F04_B_MAIN | Tall featureless white box standing in the room (both angles) | ugly |
| F04_A_BATH / F04_B_BATH | Toilet-paper holder mounted inside the shower enclosure | ugly |
| F04_B_VESTIBULE / F04_B_CLOSET | Brass lever handle floats off the door face at an angle with a visible gap | ugly |
| F04_C_MAIN | Maroon ovoid embedded halfway into the partition-wall edge at ~1.2 m | ugly |
| F04_C_BATH | Tall brown plank floats on the wall above the towel rail | ugly |
| F04_D_OFFICE | Wooden post descends from the ceiling above the desk and ends mid-air | ugly |
| F04_B_ALCOVE | Pitch-black vertical void strip at the wall junction left of the bed; white block intersecting the mattress edge | ugly |
| F04_ATRIUM | Resident sprite stands outside the guardrail line over the atrium opening | ugly |
| F04_A_BED | Wardrobe crowds the bed's foot, sitting on its rug, covering the far window | wish |
| F04_D_MAIN | Small teal panel clipped into the rear door frame top | wish |
| F04_B_KITCHEN | Fridge silhouette has jagged alpha-cutout outline (also from B_MAIN) | wish |

## F05

| room | symptom | severity |
|---|---|---|
| F05_A_MAIN | Appliance text decal renders mirrored; black oval on rear wall is a featureless blob | ugly |
| F05_B_MAIN | Abstract painting rotated off its partition wall, floating in front of wardrobe edge; untextured teal box on the floor | ugly |
| F05_B_ALCOVE | Rod/bracket from the doorway header clips the wardrobe top | wish |
| F05_B_KITCHEN | Trim-outlined bricked-over doorway | wish |
| F05_C_MAIN | Drafting table leans at an unstable angle, legs off the floor, sinking into the wall | wish |
| F05_C_MAIN | Stray white streaks across the couch back cushions (seam/z-fight) | wish |
| F05_D_BED | Black headboard overlaps half the window frame | ugly |
| F05_D_MAIN | Dark untextured slab across a ceiling patch; lone concrete block mid-floor of an empty room | ugly |
| F05_D_OFFICE | Dark speckled object sunk into the right wall at mid-height | wish |
| F05_WSTOR | Full-width pitch-black void where the far wall should render | ugly |
| F05_HALL | Artwork clipped behind/into the elevator door surround at ceiling height | wish |
| F05_ATRIUM | Stair handrail overshoots its run; end cap penetrates the newel post | wish |

## F06

| room | symptom | severity |
|---|---|---|
| F06_A_MAIN | Floor-type scuff decals projected onto the CEILING near the wall corner (also C_MAIN) — atmospheric decal pass landing on the wrong face; coordinate with parallel session | ugly |
| F06_A_MAIN | Glowing art/TV panel overlaps window blinds | ugly |
| F06_C_BATH | Vertical brown strip above the towel rail — looks like a mis-rotated duplicate rail | ugly |
| F06_C_MAIN | "PROVENANCE UNKNOWN" sign overlaps the abstract painting; portrait painting sits in front of the fridge/cabinet face, clipping the counter | ugly |
| F06_D_BED | Bed and dressers are featureless pure-white boxes; both windows brick-filled | ugly |
| F06_D_BATH | Orange bench/tabletop clips ~0.6 m of geometry through the closed bathroom door | ugly |
| F06_WSTOR | Floor is two mismatched slabs with a visible ledge drop | ugly |
| F06_HALL | Painting mounted flush against ceiling trim, clipped by the soffit | wish |
| F06_ATRIUM | Chandelier arm curves through the stair balusters; glowing blob on brick with no fixture mesh; hard black rectangle high on the atrium wall between rail flights | ugly |

## ROOF

| room | symptom | severity |
|---|---|---|
| ROOF | Freestanding sign board blank on both faces (white front, untextured gray back) — story decal/text missing | ugly |
| ROOF | Billboard/screen and HVAC-scale boxes render 100%-black on all faces while adjacent props at the same distance catch light — missing/unlit materials | ugly |
| ROOF | Verified clean: parapet/planter coverage continuous, no walk-off gaps; posts/plinths all grounded | — |

## Triage (proposed, not yet actioned)

**Fix-first (blockers):** ~~the blinds/window offset, WSTOR white
slab+cube~~ BOTH CLOSED 2026-08-16 (see their rows). The remaining blocker
families are:

1. ~~Wall art misplacement~~ **CLOSED 2026-08-16** — see its row. Every
   suspicion listed here was confirmed, and the centreline-versus-face
   prediction was the largest single family (89 of 125).
2. ~~Ten windowless C-stack bedrooms~~ **CLOSED 2026-08-16** — see its row.

**No blockers remain open.** What is left is 50 "ugly" and 36 "wish" rows.
Several look like families rather than individual bugs, and the three fixed
today all turned out to be exactly that — worth diagnosing before touching:
the faucet-detachment set (F01_A, F03_A/B, F04_A/B, F05_A/B), the towel-bar
overrun set (F02–F05 C/D baths), the sticky-note/plaque decals sitting at
ceiling height, and the wardrobe-in-front-of-window set.

The lesson from the blinds, worth applying to the wall art before touching
it: **a centreline is not a face.** Both owners committed that same mistake
independently, and the blinds version survived a previous fix because the
verification measured only the axis that had been repaired.

**Coordinate with parallel session before touching:** white decal quads
(hall/corridor/roof/B1), ceiling scuff decals (F06), socket prop labels,
elevator WalkTest failures — all in their working set.

**Batchable per-floor trivia:** towel bars, sticky notes, faucet floats,
pendant-in-duct — each is one asm/socket offset in gen_layout.

**Re-shoot after fixes:** D_MAIN and C_BED2 cameras (nested-rect/furniture
artifacts), UTILITY/WSTOR _b corners.
