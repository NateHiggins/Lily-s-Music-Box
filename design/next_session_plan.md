# Next session — walkthrough, then Mina finds her voice

Written at the close of 2026-07-31. Tree clean at `b99860f`, both sessions
merged, WalkTest 218 checks green. This is the brief for tomorrow.

## Part 1 — the room-by-room walkthrough

The user walks every room and calls out placement and functionality bugs by
eye; nothing beats a human standing in the space. Protocol:

- **Order:** B1 → F01 → F02 … ROOF, unit by unit, commons last per floor.
- **Log everything** to `design/walkthrough_punchlist.md` as
  `room | symptom | severity (blocker/ugly/wish)`. Do not fix while
  walking — momentum is worth more than any single fix. Trivial fixes
  (a yaw, an offset) may be batched per floor.
- **Tools:** F1 → GO teleports per floor; "Show all floors"; SUBJECT picker
  to summon any resident's state; `4B desk` and `F03 utility door`
  shortcuts; sanity director stand-down if intrusions muddy the read.
- After the walk: triage the punchlist into tomorrow's fixes vs backlog,
  fix blockers first, re-render doc shots, WalkTest before every commit.

### Known defects going in (don't re-discover these)

1. **TV shows ~3/4 of the picture** — `screen` UVs span ~0..1.33; almost
   certainly `buf()` caching `uv_mode` per buffer from the first material,
   so the UV_MODE_BY_MAT entry for `screen` never lands. Dump a
   `*_furnish_screen` UV range from the glTF to confirm. Theora block noise
   in the first half-second of a card is keyframe warm-up, separate issue,
   cosmetic.
2. **Two Evelyns** — the lobby test figure and the real 1A resident.
   Retire the lobby one; move its test assertions to 1A.
3. **Evelyn's clips are UUID-named** — roles are positional guesses until
   the user supplies the prompt→clip mapping or names them by eye
   (F1 → CAST cycles them on the lobby figure while it still exists).
4. **Sora watermarks** visible in broadcast frames since the crop change.
   Illegible at in-world size; decide whether to care.
5. **Mobile light budgets** still unvalidated on a real phone.
6. **Routine walk clip** — residents pace using whatever clip ROLES guesses;
   only Evelyn has a mesh, the other 17 still billboard until models arrive.

## Part 2 — Case 01, voiced, with a real dialogue tree

Goal: replace Mina's click-through insight buttons with a conversation that
*earns* the case's two recognition flags, then voice it.

### Why Mina's tree is the template

Her case rule: captions escalate from nouns to false claims about thoughts.
Her trauma: **everything must be annotated or it does not count** — care
that became control of the record. The resolution the game already encodes:
`assumptions_are_not_facts`, `silence_can_be_blank`, closing rule
*"silence does not require annotation."*

### Tree design principles (from the case doc's own rule)

- **A case is weak if solved by the obviously compassionate option.** Every
  branch must be defensible; wrong turns cost trust, not progress.
- **The trap is agreeing with her.** Mina wants the player to confirm her
  transcripts are accurate — they are. Accuracy is not the wound. Branches
  that validate the *record* feel kind and go nowhere; branches that ask
  what the record is *for* advance.
- **Silence is a first-class dialogue option.** The button that says
  nothing. Early, it reads as rude and she fills it with annotation
  ("[CALLER DECLINES TO STATE]"). At the heart of the tree, the same
  silence — held after she asks "what am I supposed to put here?" — is the
  answer. The mechanic IS the insight: silence can be blank.
- **Three layers to the heart:** (1) the complaint — captions on objects;
  (2) the pattern — she annotates people, including the player, live;
  (3) the wound — a moment she failed to transcribe (what was said in a
  courtroom the day she stopped being able to hear it fully) and has been
  compensating for ever since. Layer 3 is only reachable after both
  practical repairs, matching the existing stage gates.
- **Recoverable failure:** unhelpful lines drop trust and she retreats one
  layer; nothing dead-ends. Matches the existing trust/recurrence model.

### Build plan

1. `game/data/case01_dialogue.json` — nodes: {id, speaker, line, choices:
   [{label, goto, flag?, trust±}], silence_goto}. Author ~40 nodes.
2. Extend `CaseDialoguePanel` to walk the tree; keep the current API so
   `mina_case_gameplay.gd` stage gates still fire `record_conversation`.
3. WalkTest: drive the tree end-to-end — the earned path sets both flags,
   the flattering path sets none, silence resolves differently by depth.
4. **Voice**: every node ID is the take ID (`mina_c01_<node>.ogg`). Export
   a recording script from the JSON (one command), user generates/records,
   importer matches by filename. Playback on an AudioStreamPlayer3D at
   Mina's position; subtitles from the same JSON so text and voice cannot
   drift. Sources land in `game/assets/audio/voice/source/` (gdignored,
   like music/); processed .ogg beside them, committed.
5. Her `strained`/`recognition` animation roles swap in at layer 2/3 —
   first place the animation prompt sheet and the case system meet.

## Aspirational backlog (post-Mina, in rough order of pull)

- **Cases 04–07 + convergence** authored as data — engineering is done.
- **Case 02 field journey**: contact-mic listening on the way down, not
  just the destination window.
- **Poltergeist ↔ broadcast**: `tv_infect` exists; give Cal's address rung
  a bespoke possessed reel segment (the manifest makes it addressable).
- **17 more character meshes + animation sets** via the prompt sheets;
  routine clip roles firm up per resident as models land.
- **Lightmap bake / GI fallback** — the last named phase-5 remainder.
- **Elevator interior as a room** — riders currently teleport; the cab is
  the natural stage for overheard-resident vignettes.
- **Mail as a system**: Evelyn already haunts the mail bank; letters as
  case breadcrumbs (Mina's PROVISIONAL TESTIMONY slid under the door).
- **Save/load of building state** beyond the reality campaign — door
  states, case doors revealed, broadcast position.
- **Mid-range GPU + phone validation pass** with the Perf stations.

## Invariants (unchanged, sworn again)

gen_layout authors all coordinates; b2g() is the only conversion; never
hand-edit generated JSON/glTF; WalkTest green before every commit; fetch
before push; audio stays procedural except catalogued, attributed assets
with gdignored sources.
