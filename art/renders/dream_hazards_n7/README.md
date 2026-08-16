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
| capture | `DreamPursuer` (N6) | DreamPursuitTest 39, GateDJoinTest 69 |
| expiry | the slot's authored 28 s ceiling | DreamHazardTest block B |
| contact | `DreamHazard` condition `lamp_on` | DreamHazardTest block D |
| fall | real gravity through real missing floor | DreamHazardTest block E |

`DreamHazardTest` passes 31/31 across five blocks. `DreamPerceptionTest`
passes 20/20. `DreamPursuitTest` 39/39 and `DreamBoundaryTest` 36/36 are
unchanged by this work.

## The fairness sweep

*Corrected 2026-08-16 after an adversarial review of this file. The first
version claimed "sixty approaches, twenty bearings per hazard". That was
wrong. The correction is recorded below rather than quietly swapped.*

Three measurements per hazard, because they answer three different questions.

**1. The routed approach** - the walk a player actually makes, from the
previous room, in through the chain door, to the sill at 4.6 m/s.

| Hazard | Warned | Fair | Bearing correct | Margin | Owed |
|---|---|---|---|---|---|
| `vantry_signal_trunk` | yes | yes | yes | 1.12 s | 0.90 s |
| `open_lift_void` | yes | yes | yes | 1.58 s | 0.90 s |
| `hollow_runner` | yes | yes | yes | 0.92 s | 0.75 s |

**2. Ten in-room bearings per hazard**, which is the only place a bearing can
vary for a hazard whose tell fires before its door. Best in-room margin
1.12 s / 1.09 s / 0.92 s - each exactly `(tell_radius - clearance) / 4.6`,
meaning the longest axis of each room is long enough to spend the whole tell
radius. Fair on 1, 1 and 2 of 10 sampled bearings: the long axis earns it, the
short ones do not.

**3. The doorway margin** - what a player would get if the tell were inaudible
until they crossed the threshold. **This is the number that decides whether
the future acoustic graph may occlude a tell.**

| Hazard | From its own doorway | Owed | Occlusion safe? |
|---|---|---|---|
| `vantry_signal_trunk` | 0.52 s | 0.90 s | **no** |
| `open_lift_void` | 0.19 s | 0.90 s | **no** |
| `hollow_runner` | 0.92 s | 0.75 s | yes |

## What the first version of this table got wrong

**The sweep was one approach replayed twenty times.** `_approach_route` took
the bearing-derived start point as an argument and used it only in two
fallback returns that slot 1 never reaches, so the route carried no trace of
the bearing. Twenty trials walked an identical path, and `worst_margin` was
that single path's margin rather than a worst case over anything. The one
check written to prevent a lucky-bearing proof - `tested >= 12` - counted loop
iterations and therefore could not fail.

The route now ends on the bearing's own entry point, and the coverage check
counts **distinct positions where the tell actually fired**. That check
immediately reported `1` for the trunk and the void - which turned out not to
be a bug either: their tells fire while the player is still crossing the
previous room, so the routed approach genuinely cannot vary by bearing.
Per-direction variation lives in measurement 2, where it can.

**"No room is that deep" was false.** That claim described `D03_LIFT_VOID`
(4.10 x 3.50) and silently generalised. `D05_SERVICE_RISER` is
**6.50 x 2.08** and `D01_F04_LONG_HALL` is **19.30 x 2.08**. Every room here
is long enough on its long axis to earn its own margin, which is exactly why
the in-room bests above come out at the full tell-radius figures.

## Three things the sweep found that were not visible by inspection

**1. The sector table named left as right.** `Vector3.signed_angle_to` about
+Y is positive counter-clockwise seen from above, which is a turn to the
player's *left*, while the sector table reads clockwise from AHEAD. Every
directional caption was mirrored. An accessibility caption that says RIGHT for
a danger on the left is worse than no caption, so this is the single most
important thing N7 fixed, and it was found by measuring rather than by
reading. `DreamHazardField._bearing_to()` now negates.

Two corrections to how this was first written up here. The mirroring affected
**every caption naming a side** - AHEAD and BEHIND are symmetric about the
axis and were always right. And `_true_sector()` in the harness is *not* an
independent derivation: `atan2(t.r, t.f)` is identically
`-signed_angle_to(f, t, UP)`, and it calls the same `bearing_sector` table, so
it cannot catch a shared sign error. The real external anchor for handedness
is block G, which pins four hardcoded sector names against four cardinal
facings. That check is what holds the convention.

**2. The authored tell radii are larger than the rooms that hold them.** The
sockets carry 4.6–5.5 m tells; the modules are 3.5–4.1 m deep. The tell is
therefore a room-entry event, not a proximity event. That is arguably the
better feel — you cross a threshold and the room tells you what is in it — but
it means a warning can only be measured as time actually walked, never as
radius arithmetic.

**3. The through-wall tell is load-bearing - but not for the reason first
given here.** The original reasoning was that no room is deep enough to hold a
4.14 m runway. That is false, as above. The real reason is that **the sockets
sit mid-room**, so the walk from a doorway to the socket is short however long
the room is: 0.52 s for the trunk and 0.19 s for the void, against 0.90 s
owed. Only the hollow runner, whose socket sits 12 m down the long hall,
clears its own bar from its own threshold.

> **Binding constraint on the dream acoustic graph.** When the dream-scoped
> graph is built it must **attenuate** hazard tells across a wall and must not
> **silence** them. This is now measured rather than inferred: with the tell
> occluded to the room, the trunk gives 0.52 s and the void 0.19 s against the
> 0.90 s their sockets owe. `DreamPerceptionTest` recomputes both figures on
> every run and prints an OCCLUSION VERDICT line. Re-run it as the acceptance
> check for that work.

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
  hidden geometry.~~ **Closed.** Perception rows carry an eight-sector bearing
  and a cue, never a distance, a module id or a position, and the direction is
  restated whenever the sector it names stops being true. `DreamCaptionLayer`
  renders each tell as exactly the cue and the sector, capped at three
  readable lines, under the `dream_directional_captions` setting — off by
  default, because the mix already carries this and the dream's grammar is
  listening. `DreamPerceptionTest` block I proves the setting defaults off,
  the layer is wired to the field's signal, and no rendered line contains a
  digit, a module id or a distance.
- **In blinded tests, each of Mina's three hazards is identified by bearing
  and type before contact in at least 80% of trials. — NOT CLOSED, and not
  closeable here.** This is a human playtest. `DreamPerceptionTest` proves the
  *precondition*: that from every approach there was something honest to
  identify, correctly aimed, in time. It holds itself to 100%, not to 80%,
  because if the machine side is imperfect the human number measures our bugs
  instead of their perception. The three cues are mutually distinguishable —
  `TRUNK HISS`, `CHAIN BELOW`, `DRY CREAK` — which is the identification
  channel, but whether players *do* identify them is theirs to answer.

## A flake this work exposed, and the worse thing the first fix did

`DreamPursuitTest`'s restore check allowed the Tenant 0.35 m of drift after a
reload, which was a race against how long the reload took. It lost once under
the extra build work.

**The first fix turned it into a tautology.** Bounding the drift by
`elapsed_s * top_speed` sounds principled and is not: that product is exactly
the pursuer's own displacement bound, because `advance_fixed` adds `delta` to
the clock and moves at most `speed * delta` in the same call. With 0.35 m of
slack on top and a strict `<`, the check could not fail - and a coherently
serialized chase frame, precisely the regression it is named for, would have
passed silently. It was written up as "the invariant the check was named for".
It was not.

It now establishes its premise and then tests the falsifiable thing. Real
physics runs until the Tenant is demonstrably mid-pursuit - measured at
**2.02 s of clock and 6.74 m of drift** - *that* is saved, and after the
reload it asserts a fresh run: clock under 0.20 s, nobody acquired, no capture
time, and drift under a flat 1.60 m constant rather than a clock-derived one.
Observed across three runs: clock 0.100-0.150 s, drift 0.334-0.502 m. A
resumed chase frame fails on the clock alone.

## Still open in N7

- The hollow runner's effect. Its socket, allowlist entry and `running`
  condition all exist and it warns correctly; what a broken board *does* is
  unimplemented, and the brief and catalog disagree on which module it sits in
  (catalog `D01_F04_LONG_HALL`; the §"MINA'S FIRST RUN" script says D04, which
  has no sockets at all). Moving the socket changes the catalog SHA and
  invalidates Gate A, so the engineering read is to amend the script. That is
  a fiction change and belongs to the owner.
- The trunk's lit beam-splash confirmation.
- The production dream `WorldEnvironment` and receding practical.
- Frames. This README records numbers only; no beauty pass has been shot of
  the hazards, and Gate E's A/B work is untouched.
