# N7 — hazards, endings, and the fairness numbers

*Recorded 2026-08-16. Reproduce with the two harnesses named below; both are
deterministic at seed `f123456789abcdef` and neither needs a display.*

```bash
godot --headless --path game res://tests/DreamHazardTest.tscn
```

```bash
godot --headless --path game res://tests/DreamPerceptionTest.tscn
```

## What N7 added

The run can now end, three ways, through one latched funnel in
`DreamMazeRoot._commit_outcome()`. It refuses rather than half-succeeding when
no `CampaignShell` owns the transaction, and a capture and a contact arriving
in the same frame commit once.

| Ending | Owner | Proof |
|---|---|---|
| capture | `DreamPursuer` (N6) | DreamPursuitTest, 39 checks |
| expiry | the slot's authored 28 s ceiling | DreamHazardTest block B |
| contact | `DreamHazard` condition `lamp_on` | DreamHazardTest block D |
| fall | real gravity through real missing floor | DreamHazardTest block E |

`DreamHazardTest` passes 30/30 across five blocks. `DreamPerceptionTest`
passes 15/15. `DreamPursuitTest` 39/39 and `DreamBoundaryTest` 36/36 are
unchanged by this work.

## The fairness sweep

Sixty approaches, twenty bearings per hazard, each walked at the 4.6 m/s run
speed from the previous room, in through the chain door, to the sill.

| Hazard | Approaches | Warned | Fair | Bearing correct | Worst warning | Owed |
|---|---|---|---|---|---|---|
| `vantry_signal_trunk` | 20 | 20 | 20 | 20 | 1.12 s | 0.90 s |
| `open_lift_void` | 20 | 20 | 20 | 20 | 1.58 s | 0.90 s |
| `hollow_runner` | 20 | 20 | 20 | 20 | 0.92 s | 0.75 s |

No bearing was skipped. The harness names every skip it makes, because a
silently dropped bearing reads as coverage we do not have.

## Three things the sweep found that were not visible by inspection

**1. The sector table named left as right.** `Vector3.signed_angle_to` about
+Y is positive counter-clockwise seen from above, which is a turn to the
player's *left*, while the sector table reads clockwise from AHEAD. Every
directional caption was mirrored. An accessibility caption that says RIGHT for
a danger on the left is worse than no caption, so this is the single most
important thing N7 fixed, and it was found by measuring rather than by
reading. `DreamHazardField._bearing_to()` now negates, and
`DreamPerceptionTest._true_sector()` derives ground truth by a deliberately
different formulation so the two cannot share a sign error again.

**2. The authored tell radii are larger than the rooms that hold them.** The
sockets carry 4.6–5.5 m tells; the modules are 3.5–4.1 m deep. The tell is
therefore a room-entry event, not a proximity event. That is arguably the
better feel — you cross a threshold and the room tells you what is in it — but
it means a warning can only be measured as time actually walked, never as
radius arithmetic.

**3. Which makes the through-wall tell load-bearing, not a leak.** At a dead
run, 0.90 s of warning needs 4.14 m of runway, and no room is that deep. The
trunk and the void were first heard from an adjacent room in **20 of 20**
approaches each. They are fair *because* the sound crosses the wall. Only the
hollow runner, which sits in the long hall, earns its margin inside its own
room.

> **Binding constraint on the dream acoustic graph.** The brief calls for a
> dream-scoped graph with the waking network's delay and damping schema. When
> it is built it must **attenuate** hazard tells across a wall and must not
> **silence** them. Occluding the trunk and the void would take their worst
> warning from 1.12 s and 1.58 s to well under the 0.90 s their sockets owe,
> and would break Gate C at the moment the graph landed. Re-run
> `DreamPerceptionTest` as the acceptance check for that work.

## What is measured but not claimed

Forty of sixty first tells arrived from outside the hazard's own room. Sound
through a wall is honest; a *bearing* through a wall points at plaster. The
caption is still directionally correct — it names where the danger is, and the
player walks toward the door rather than the wall — but the graph above is the
principled fix and it does not exist yet. Recorded here rather than quietly
passed.

## Gate C status — the honest reading

Gate C has three bullets. Two are closed by this work; one cannot be closed by
a script at all.

- ~~Every impact log includes tell start, player distance, light state and
  causal hazard id.~~ **Closed.** `DreamHazard.impact_record()` carries
  `tell_start_s`, `tell_distance_m`, `contact_s`, `realised_warning_s`,
  `minimum_warning_s`, `lamp_on`, `hazard_id`, `kind`, `module` and `outcome`.
  `DreamHazardField.unfair_impacts()` reduces the whole question to one list
  that must stay empty.
- ~~Directional-caption mode conveys the same information without revealing
  hidden geometry.~~ **Closed at the data layer.** Perception rows carry an
  eight-sector bearing and a cue, never a distance, a module id or a position,
  and the direction is restated whenever the sector it names stops being true.
  The on-screen presentation and its settings key are still to build.
- **In blinded tests, each of Mina's three hazards is identified by bearing
  and type before contact in at least 80% of trials. — NOT CLOSED, and not
  closeable here.** This is a human playtest. `DreamPerceptionTest` proves the
  *precondition*: that from every approach there was something honest to
  identify, correctly aimed, in time. It holds itself to 100%, not to 80%,
  because if the machine side is imperfect the human number measures our bugs
  instead of their perception. The three cues are mutually distinguishable —
  `TRUNK HISS`, `CHAIN BELOW`, `DRY CREAK` — which is the identification
  channel, but whether players *do* identify them is theirs to answer.

## Still open in N7

- The hollow runner's effect. Its socket, allowlist entry and `running`
  condition all exist and it warns correctly; what a broken board *does* is
  unimplemented, and the brief and catalog disagree on which module it sits in
  (catalog `D01_F04_LONG_HALL`; the §"MINA'S FIRST RUN" script says D04, which
  has no sockets at all). Moving the socket changes the catalog SHA and
  invalidates Gate A, so the engineering read is to amend the script. That is
  a fiction change and belongs to the owner.
- The trunk's lit beam-splash confirmation.
- Caption presentation and its settings key under `GameBoot.settings`.
- The production dream `WorldEnvironment` and receding practical.
- Frames. This README records numbers only; no beauty pass has been shot of
  the hazards, and Gate E's A/B work is untouched.
