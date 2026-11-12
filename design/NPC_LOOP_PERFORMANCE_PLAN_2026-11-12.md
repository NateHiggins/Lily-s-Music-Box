# Every NPC through the loops: writing and performance plan

Evidence class: **INERT**. Implementation proposal, not new canon or runtime proof.

Owner request, November 12: after the music video, plan how its production skill
can fully script the cast through each loop. Source inspection: canonical checkout
at **c22794ceb2ee4dac83ae951e376c382f6544217b**, including the explicitly unqualified
Harukiya route/seat work in progress. No gameplay changes or tests were made for
this plan. Read-only cast and temporal audits informed it.

## Scope and existing authority

Give every character a coherent life: an intention, a place, physical business,
conversation and listening behavior, and a response when the player interferes.
Cover the ordinary repeating year and every available historical visit. Fully
scripted means no unexplained gaps in those states; it does not require constant
speech or eleven copies of each person's entire day.

Use [the machinima skill](../.agents/skills/machinima-production/SKILL.md) for
authored acting, selected voice takes, facial timing, contacts and rendered review.
Keep the [Bible](ORISON_BIBLE.md), especially RUL-015/016 and VIII.2/VIII.5, above
the performance plan. All shipped text and voices are authored offline. The
Neo-Noir Neon 1929 style still applies, with readable faces and practical lighting.
Ordinary encounters retain the player's camera, movement and interaction.

The active mystery is an earned eleven-anchor lead tree, not unrestricted date
travel. [anchors.json](../game/data/temporal/anchors.json) and its generated
[tree reference](TEMPORAL_LOOP_TREE_2026-11-10.md) own dates, prerequisites, fares,
steps and clues. **TemporalLoop** owns visits; **CoreLoopDirector** remains Mina's
separate golden-shift owner. Preserve both. Earlier treatment/task language about
unbuilt date travel and free-order jumps is superseded by the installed tree.

## What is already there, and what is missing

These are source findings, not claims of played or accepted behavior.

| Area | Current source | Work needed before cast-wide production |
|---|---|---|
| Schedule | 18 residents, 393 ordinary blocks, 27 special-day records; Stacy has 13 staff blocks | Account for every actor at every anchor; give Lily her own attendance contract |
| Walking | 15 general route owners plus Mina | Rhea and transient guests lack live routes; reconcile body positions on temporal reset |
| Dialogue | 18 ordinary trees/511 nodes, Mina's separate 34 nodes, 324 dated opinion entries | Preserve existing grafts, choices and case ownership; add normal encounter delivery where absent |
| Mystery | 25 speaker files, 148 threads/452 nodes; all marked PROPOSED/draft_unvoiced | Review drafts as drafts; one Mina thread remains held; do not multiply text before coverage is clear |
| Models | Ordinary residents: 17 older 24-joint rigs plus Mina's 28; Lily/Stacy: 76 joints | Coordinate Fable's cast installation; old clips cannot be assumed compatible with new bodies |
| Voice | 34 Mina source WAVs; no actual runtime Ogg files in the audited voice directory | Restore reproducible runtime audio; recover approved cast references before generating new takes |
| Playback | General dialogue has no shared selected-take/cue hookup; bar uses untimed mouth fallback | Expose stable line identity and actual audio time to the single face/pose pipeline |

Roster coverage starts with the union of schedules, motives, dialogue, mystery,
installed actors and service roles. The resident set is Evelyn, Teresa, Mina,
Lena, Juno, Malcolm, Omar, Rhea, Peter, Cam, Noel, transient guests, Nadia, Cal,
Iris, Sacha, Jonah and Mae. Add Stacy, Lily, historical Adela, Emil Voss, Mr Ewald,
H Vantry and the patrolman. Track **the_party** as an encounter; transient guests
currently combine speakers under one identity. Do not invent additional named
actors to make an audit count convenient. Include the companion's authored
responses in the same dependency review without transferring its state owner.

Lily and Stacy currently share Stacy's shift visibility. Stacy has a counter
encounter; Lily has no independent ordinary conversation or route. Adela's
debug preview follower is not historical attendance. Adela, Lily and the other
mystery-only speakers need ordinary-world access; an F9 menu is not that access.

Source entry points: **game/data/resident_schedules.json**, **resident_motives.json**,
**game/data/dialogue/**, **game/data/mystery/**, **game/data/opinions/**;
**game/scripts/characters/resident_agenda.gd**, **orison_v2_resident_route.gd**,
**orison_v2_mina_routine.gd**, **harukiya_cast.gd**;
**game/scripts/game/resident_conversations.gd** and
**game/scripts/cases/mina_case_gameplay.gd**.

## Write one baseline, then dated differences

First deliver an inspectable cast-by-anchor matrix. Every cell explicitly says
**inherits baseline**, **dated override**, **conditional encounter**, or
**absent with reason**. An inherited cell points to the actual applicable schedule
and date rules. Empty cells fail coverage. Add ordinary-year special dates and
pre/post-murder availability; the eleven visits do not cover the whole year.

For each person, write a compact performance sheet from their existing character
notes: what they want, what they know at that date, what they will conceal, verbal
rhythm, habitual work, gesture limits, personal space, and how they listen. Avoid
making everyone a clue dispenser. Quiet tasks, friendships, jokes, irritation,
unfinished conversations and work interruptions provide the connective life.

Each scene/beat package should contain:

- Stable actor, encounter, beat and line IDs; source dialogue nodes and exact text.
- Date/anchor and local time window; prerequisites, absence and repeat conditions.
- Where participants start/end, reachable paths, seat/prop reservations and exits.
- Each participant's intention and historically available knowledge, including
  who can hear or see the action. Player knowledge is a separate input.
- Physical action before/during/after each line; gaze, listening, expression,
  gesture, prop contact and a readable silent alternative when offscreen.
- Interrupt, leave, return, blocked-path, busy-prop, missed-window and loop-expiry
  behavior; which lines resume, restart, summarize or remain unavailable.
- Existing owner of every consequence: knowledge flag, clue, trust, case event,
  inventory transfer or none. An animation finishing must not invent a reward.
- Selected take/hash, actual playback duration, mouth cues and subtitle source;
  independent states for drafted, text reviewed, voiced, integrated, technically
  verified, played and artistically accepted.

Keep proposed fields in design until their consumer and validation land together.
Do not add unconsumed runtime data merely to show writing progress. Reuse existing
node IDs and dialogue grafts for weather, gifts, music, errands and opinions.

## Preserve chronology, memory and missed moments

The year repeats from November 10, 1928 through November 9, 1929. Historical civil
time, visit time and monotonic player elapsed time have different jobs. The audio
playback cursor drives lips; the campaign clock drives appointment eligibility.
CampaignPace holds mean ordinary rate 1, not a frozen calendar. Acting cannot
pause time or extend a visit by itself. Handle a line that reaches visit expiry.

The murder is approximately July 19 at 21:03. The July 19 21:01–July 20 03:02
blackout applies to every transition and advance. Reconstruct the crime; never
stage a witnessed murder replay. Adela's living attendance ends on the correct
historical boundary. No future-self recognition, invented biography for Lily,
new confession from Mae or explanation of the unresolved larger conspiracy.
Preserve Mina's held **mv_struck** thread and Emil's non-comic grief scene.
Keep **WR-03** property-law details, including the proposed reversion clause and
August receipt, pending their existing review. Lily's self-insert dialogue remains
owner-review placeholders; do not turn it into final voice batches by inference.

**TemporalLoop** rewinds caretaker economy, inventories, door keys, shop stock,
conversation visits and resident trust. Player knowledge, specified collected
evidence, bank/wall/deductions and elapsed-time obligations retain their existing
owners. **m_** and **mt:** flags describe player knowledge, not what every resident
knows. **loop:** evidence does not automatically stand in for an **m_** flag.
Audit unreachable carrier dependencies, including **m_trade_log**,
**m_boiler_sheet**, **m_o1_print** and **m_receipt_seen**, before adding branches.

Current mystery entry marks a thread heard immediately. Do not silently move that
grant to audio completion. First preserve it and explicitly test interrupted
entry. If a resumable presentation is needed, design a separate bounded playback
cursor that neither repeats grants nor makes gated threads universally replayable.
Any change to narrative availability needs review with the existing owner.

At an authorized temporal reset, propose one population reconstruction transaction:
stop/cancel speech and contact actions; release seats, props and passage reservations;
restore the existing snapshot domains; reconstruct historical presence, agenda and
route position; then resume normal movement. **ResidentAgenda** already rebuilds
after jumps, but the audited walking bodies lack this reset hook. No live
teleporting to repair ordinary attendance. Save/load and repeated visits must
restore the same valid state without duplicated evidence or ghost reservations.

## Transfer the film process into interactive performance

Use a small presentation adapter under the existing conversation/schedule owners.
They decide whether an event happens; the adapter plays the selected performance.
Expose stable node/line identity rather than guessing from the panel's displayed
text. Subtitle, voice and mouth timing must refer to the same selected take.
Use **cast_model_presentation.gd**, **pose_pipeline.gd**, **resident_attention.gd**
and **face_controller.gd** with one ordered skeleton writer and one morph writer.
Missing audio gets a declared fallback and remains a delivery gap, not a fake pass.

The film's useful methods are seated-root-before-gaze, measured reach, correctly
oriented palms, anticipation/contact/release, silent listening, held vowels and
absolute-time presentation evaluation. Its private disabling of autonomous actors,
garment workarounds and music-derived approximate fingerings are not production
fixes. Ordinary actors must retain navigation, clothing behavior and interruption.
Re-evaluating a pose or seeking audio must never replay gameplay side effects.

Recover official approved voice profiles and selected takes through Omni. The
temporary pilot voice is not Lily's permanent voice authorization. Batch generation
by character/model after text review; review a short exchange before whole-cast
generation. Use **export_voice_script.py**, **import_voice_takes.py** and
**audit_authored_voice.py** where their current contracts fit. Add general-cast
support deliberately rather than assuming Mina's exporter already covers everyone.

Offscreen actors keep deterministic logical schedules without full voice/IK work.
Nearby visible actors receive detailed performance, with distance/visibility
budgets measured in a populated room. Preserve existing acoustic routing; prioritize
the engaged conversation over background chatter. Door obstruction, competing
speakers and a full bar need tests, not twenty simultaneous foreground monologues.

## Delivery order

| Batch | Work | Exit requirement |
|---|---|---|
| 0: reconcile | Recover Fable's latest cast ownership; complete roster/anchor matrix, line and carrier audit, voice-source custody | No unknown coverage cell; distinguish missing asset, missing encounter and held writing |
| 1: one playable visit | **tea**, Mae in 6C: existing radiator reason, tray action and order slip; background roster coverage; coordinate one qualified Mae body/face first | Actual normal entry, authored exchange/listening, interruption, save/load and rerun; clue only from its existing physical owner |
| 2: cast compatibility | Apply the same contract to one walking resident and Lily/Stacy's normal bar encounters; historical Adela only where allowed | Routes, reservations, mixed/current rigs and actual voice/face playback work together; coordinate dependency on Fable's qualified bodies |
| 3: immediate chronology | **friday** (Cam), **stairs** (Teresa), **button** (Lena) | Correct pre/post-murder presence and tone; blackout and missed-window checks |
| 4: parallel investigation | **notebook** (Jonah), **drain** (existing carrier), **drama** (Cal/Juno), **bench** (Omar) | Existing prerequisites, strict steps and clue owners preserved; no invented speaker for the drain |
| 5: convergence | **duplicate**, **plate** (Sacha), **box** (Mae) | Cross-branch knowledge gates, late-year behavior and deduction resolution without requiring a confession |
| 6: full ensemble | All remaining resident/service/support encounters, ordinary-year routines and anchor overlays | No unwritten required state, unreachable encounter or untested reset path; full-cast cost and artistic review |

Every batch updates the same full coverage matrix; supporting actors are accounted
for from batch 0 rather than becoming an untracked final backlog. Write and review
all required outlines before expensive voice batches. Implement/qualify one slice
before expanding adapters or rendering every scene. Reuse unchanged sources and
proofs. Keep **B-DESTINATION** gameplay qualification separate and finish its route,
seat and service gates before relying on the rebuilt bar as an accepted venue.

## Coordination and verification

Codex remains integration owner. These are proposed bounded assignments, not new
claims on files currently owned by Fable or another agent:

| Work package | Named-path boundary | Dependency / deliverable |
|---|---|---|
| Fable cast integration | Her claimed wardrobe/export/cast files; agree exact paths on bridge before edits | Qualified body/clip/face interfaces and a frozen manifest; no competing rebuild |
| Writing review | Assigned speaker files in **game/data/mystery/**, **dialogue/**, **opinions/** plus one design coverage matrix | Canon/current-line audit first; changes with exact node IDs and no held revelations |
| Codex runtime | **temporal_loop.gd**, **orison_v2_loop_stage.gd**, route/attendance files, **resident_conversations.gd**, **case_dialogue_panel.gd** and adapter/tests | One reset/event contract; sequential dependent edits; Mina case owner reviewed separately |
| Offline audio | Assigned selected-take manifests, voice outputs and cue files only | Text/profile freeze first; measured durations, hashes, pronunciation review and runtime import proof |
| Read-only QA | Coverage report, affected fixtures and case-local receipts | No source changes during another owner's frozen proof |

First merges: coverage/consumer contract and tests; one playable slice including
its selected voice take, mouth cues and audio-clock hookup; reviewed dated text;
remaining cast audio/performance batches; then composed candidate. Use named
staging and one clear integration order. Freeze shared inputs before rendered
evidence; all Godot/GPU work uses the patched engine, FIFO lane, receipts and hidden
desktop. CPU writing/audits can overlap; dependent fixes stay sequential.

Reuse **TemporalLoopTest**, **V2LoopStageTest**, **MysteryWiringTest**,
**MysteryPlaytestRouteTest**, **ResidentConversationTest**, **ScheduleTest**,
**ResidentAgendaTest**, resident walk/key fixtures, cast/pose/face benches and
affected Harukiya tests. Add meaningful coverage for interrupted/reentered lines,
audio cancellation, actor reconstruction, busy props, missed windows, save/load,
accelerated waits and repeat visits. Include negative controls for future knowledge,
held threads, absent/dead characters and duplicate rewards. Verify a fresh checkout
has playable audio rather than relying on stale import metadata/cache.

Review a short actual-input encounter before expensive composed runs. Render faces,
hands, seats, props and listener reactions under native venue lighting; sample
unchanged combinations and target the exceptions. Measure a populated scene's
frame tails and voice/animation cost. Reader audit admits zero new unread fields;
candidate verification uses the real baseline and preserves original failures.

Completion means every required matrix cell and line has an accountable state;
normal-play encounters work, clocks/saves/knowledge remain correct, and performance
is readable. **Implemented**, **technically verified**, **played** and
**artistically accepted by Lily** remain separate. This document completes the
planning request only; no cast-wide scripting or runtime acceptance is claimed.
