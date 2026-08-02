# Next session — punchlist blockers, then Mina speaks out loud

Written at the close of 2026-08-01. This session completed both halves of
the previous brief: the room-by-room walkthrough (193 generated stills, all
8 floors reviewed, `design/walkthrough_punchlist.md` fully populated with a
systemic triage) and Case 01's dialogue tree (34 nodes, live in play,
31-check gameplay test green). A parallel session is mid-flight on the
lived-in/decal/lighting work — several punchlist items are theirs.

## Part 1 — punchlist blockers and systemic fixes

Work from `design/walkthrough_punchlist.md`, top section first. The two
blockers look like single data-side fixes in gen_layout's furnishing pass:

1. **Blinds decoupled from windows** — slats on bare brick / overshooting
   frames on ~15 rooms across every floor. One placement offset.
2. **WSTOR white slab + cube** — untextured placeholder filling the west
   storage room on F02–F06 (F04's covers the walkable floor).

Then the batchable per-floor trivia (towel bars over trim, floating
faucets, pendant-in-duct, ceiling-height sticky notes) — each is one
asm/socket offset. **Coordinate before touching:** white decal quads,
F06 ceiling scuffs, socket prop labels, elevator WalkTest failures — all
in the parallel session's working set. Re-shoot D_MAIN/C_BED2/UTILITY_b
cameras after fixes (nested-rect artifact, see punchlist caveats).

Verify fixes by re-rendering: `WalkthroughShots.tscn` takes `WALK_FLOOR=F0x`
to re-shoot one floor.

## Part 2 — Case 01 voice

The tree is authored, tested, and wired: `game/data/case01_dialogue.json`
(node id = take id), `CaseDialoguePanel.run_tree` with silence as a
first-class button, trust-costing traps, layer retreats, and the earned
paths proven by `MinaCaseGameplayTest` (earned path sets both flags,
flattering path sets none, silence resolves differently by depth).

Remaining is the voice itself:

1. Generate/record the 34 takes from `design/case01_recording_script.md`
   (regenerate any time: `python art/tools/export_voice_script.py`).
2. Drop raw takes in `game/assets/audio/voice/source/` (gdignored), run
   `python art/tools/import_voice_takes.py` (pinned ffmpeg, self-decode
   verified, loudnorm to -19 LUFS mono).
3. Playback already works: `MinaCaseGameplay` plays `mina_c01_<node>.ogg`
   from an AudioStreamPlayer3D in 2A when the take exists, stays silent
   when it doesn't. Subtitles are the panel text — same JSON, cannot drift.
4. Listen in-game at conversational distance; check the AudioStreamPlayer3D
   position against Mina's actual standing spot and tune unit_size.
5. Her `strained`/`recognition` roles are requested at rt_court_door /
   rt_heart+rt_earned via `AnimatedResident.play_case_role` — they no-op
   until clips with those names ship from the prompt sheet, so cutting the
   two clips is the natural companion task.

## Aspirational backlog (unchanged order)

- **Cases 04–07 + convergence** authored as data — engineering is done.
  Mina's tree is now the template: entries keyed by stage gate, silence
  routing per node, trust-only bookkeeping flags for traps.
- **Case 02 field journey**: contact-mic listening on the way down.
- **Poltergeist ↔ broadcast**: bespoke possessed reel for Cal's rung.
- **17 more character meshes + animation sets** via the prompt sheets.
- **Lightmap bake / GI fallback** — last named phase-5 remainder.
- **Elevator interior as a room.**
- **Mail as a system** (Mina's PROVISIONAL TESTIMONY under the door).
- **Save/load of building state** beyond the reality campaign.
- **Mid-range GPU + phone validation pass.**

## Invariants (unchanged, sworn again)

gen_layout authors all coordinates; b2g() is the only conversion; never
hand-edit generated JSON/glTF; WalkTest green before every commit (checked
in an isolated worktree when the parallel session's tree is red); fetch
before push; audio stays procedural except catalogued, attributed assets
with gdignored sources.
