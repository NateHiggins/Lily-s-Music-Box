# Loop punch-up and first source integration

Evidence class: **INERT**. Updated November 13, 2026. Source integration and
qualification in progress at Lily's request. Focused owner tests have run;
native world qualification, main merge, play and artistic acceptance remain open.

## What changed

The four script packets now cover entry, sustained work/listening, breaks, late
arrival, departure and expiry. The ordinary-year packet distinguishes early,
middle and late-year behavior; sleep, absence and quiet work count as deliberate
states. Existing source quotations and evidence gates remain intact. New lines
favor different character habits over everyone delivering the same kind of joke.

[performances.json](../../../game/data/temporal/performances.json) is consumed
runtime data, not another unconnected brief: nineteen profiles, including Mina's
deliberately empty speech profile, and all eleven anchors. Forty-seven timed
phases cover twelve actor/anchor assignments. The drain is deliberately silent.
Nadia and Juno each share a visit with its host; other residents retain their
existing agendas, appointments, rest and work rather than joining every scene.

The selected single-speaker replies in that JSON now have seven additional
ordinary exchanges (33 lines) in
[ordinary_performances.json](../../../game/data/temporal/ordinary_performances.json).
The shared conversation owner plays these authored sequences with their exact
speaker/text and optional player reply; every line also permits departure.
All participants must have physically arrived, be available, share a floor,
stand 0.65–2.8m apart and have an unobstructed sightline. A participant leaving,
becoming unavailable, or losing that sightline cancels the exchange. This consumer
does not create an overlap in the residents' schedules or invent a shared prop.
The other multi-person scripts and complex prop handling remain direction for
later implementation; the whole packet has **not** become playable choreography.
Lily's spoken placeholders remain owner-reviewed, not newly generated dialogue.

## Existing owners and new connections

- **orison_v2_runtime_root.resident_whereabouts** asks **LoopPerformances** for
  an active phase before falling back to ResidentAgenda/ScheduleDirector. An
  empty phase place explicitly retains the agenda during arrivals/appointments.
  Phase endpoints derive from the existing visit clock, not frame counts or a
  second campaign clock. All physical clues remain independent of the acting.
- The existing V2 route motor walks the destinations, with its capsule/floor,
  door, key and passage checks. No forced destination, new key, unlock or actor
  teleport was added. Nadia's existing **visit:6C** and Juno's **visit:5B** can
  use copied host route geometry: shared vertices match positions, private vertices
  are namespaced. Their arrival vertices are existing **studio** in Mae's route
  and **alcove** in Cal's route, away from the host's main/kitchen travel. These
  visitor mappings also make the existing weekly timetable destinations reachable
  in principle; they are not limited to an anchor's hours.
  A thin route subclass yields before approaching the authored host/guest partner
  during that pair's visit; the original motor still owns every actual step.
  Unrelated corridor traffic retains its existing owner: blanket symmetric
  yielding could stop two approaching residents forever. Mae/Cal move to the
  kitchen while their visitor comes through, then resume their phase after the
  guest arrives, or resume their own work after30seconds of movement opportunity
  if a lock/obstruction prevents arrival. Conversation and scene-tree pause do
  not consume that opportunity. There is no new sidestep or collision exemption. Narrow two-way
  passages can still require a later passing policy; this is not crowd qualification.
- Actors offer the authored question only once they reach their actual destination.
  A deliberate interaction uses ResidentConversations' consequence-free performance
  entry. It does not count as a case visit, grant knowledge/trust, print a first
  conversation note, activate a case or move evidence. Rhea/guests can receive the
  same bounded line after existing door entry admits the interaction; Stacy uses
  her existing staff/counter entry. After this visit's reply, later interactions
  fall through to their ordinary conversation and its pre-existing consequences.
  No timed line is copied into an ordinary tree that could outlive its phase.
- Arrived bodies use their existing presentation adapter and clips for restrained
  standing attention/rest. Walking, conversation, seating, private washing/sleep
  and the bar's seat owner take priority. No generic reach is described as a
  verified grip. Complex sewing, nursing, tea, photograph, cup and tool work still
  require actual contacts and appropriate models/clips.
- Visit identity includes the anchor, departure/start stamps and paid/rerun counts.
  A same-minute rerun is distinct; an object-order fault is not. Numeric identity
  fields are normalized across validated JSON save/load. Home/real rerun/load
  clears this owner's transient replies and attitudes; obsolete owned ordinary,
  mystery and dedicated dialogue is cancelled without effects in the new context.
  An unrelated successor panel is not closed. The household stage uses the same
  paid/rerun identity so immediate AGAIN restores its snapshot even when civil
  time has not advanced. Ordinary replies renew on a new civil day.
  Phase changes cancel its dedicated line. Nothing rewinds knowledge or extends
  a visit. Existing mystery heard-at-entry semantics are unchanged.

## Honest limits and next verification

Private evidence case: **C:/ov/reports/npc_loop_integration_20261112/**.
**preflight01** passes the existing temporal169checks, conversation and agenda
programmes. **contract04/shots/runtime_contract.json** passes624checks across
all11anchors/47phases and seven ordinary exchanges/33lines, including real clock,
dialogue and validated-save owners, foreign panel custody, transitions and a real
physics sightline blocker. Its route endpoints are deliberately synthetic and
the receipt says **production_runtime:false**. It proves the consumer/lifecycle,
not native attendance, clearance, full journeys or clue earning. **contract03**
retains the original JSON numeric-identity failure;01/02 retain parse failures.

**stage01** reports202/0 assertions in the actual building, including same-minute
household AGAIN, but its stderr contains AStar self-edge errors. Coincident graph
vertices are now guarded; do not call that original run a clean world pass.
Fresh **contract05** and **world01** qualify the later scoped-yield and
interrupted-wait repairs; their result must be read before claiming success.
The reader gate has no new findings for either loop data file;30tool tests pass
after registering the precise dynamic identity maps, with value fields still
audited. The shared checkout retains unrelated bar/bass reader debt.

Ordinary attendance has specific unimplemented cases: **OY02** currently selects
Teresa/Cam corridors on different floors; **OY05** selects Malcolm/Sacha's
different homes; **OY04** has Juno5.49m from Cal's main mark. Shared mail endpoints
also need qualified spacing. These fail closed and leave solo authored business
available; their synthetic positive controls are not natural encounters. Add
qualified meeting routes/marks before claiming those sequences can occur.

Read-only review caught and corrected three issues before this checkpoint: guest
arrival vertices were on the hosts' kitchen paths; a proposed ordinary-tree graft
could outlive its phase; baseline topics needed the same private/sleep exclusions
as acting. The graft was removed in favor of the bounded entry. These are source
repairs, not observed runtime passes. A follow-up read identified the shared
approach through the host's original stance; host yielding and the route step
guard address that in source, also without runtime proof.

This pass is source integration. It does **not** establish that an NPC is at the
proposed mark at a particular minute. Bodies still walk in real time while a WAIT
can accelerate civil/visit time. Arrival gates prevent distant speech and acting;
missed performance never blocks evidence. On loading or changing dates, existing
bodies walk from their actual positions toward current phase targets. Exact
historical body reconstruction under a transition is still owed; no visible warp
was introduced to disguise it.

Rhea and transient guests retain existing door dialogue and logical schedules but
still lack walking routes. Stacy retains her counter/staff contract. Lily retains
her current bar presentation; independent attendance and her own spoken entry are
still owed. Historical Adela, Emil, Ewald, Vantry, patrolman and party scripts keep
their existing mystery source/access limitations; this pass creates no extra bodies
or new historical encounter doors. Mina's case/golden-shift presentation is untouched.

Teresa's yard-to-1D attendance, Nadia/Juno's real locked-door access, host/guest
clearance, timing contradictions, unsupported carrier flags and legal-text holds
remain listed in [the packet](README.md). Refusing a locked door is correct until
the access owner legitimately admits the visitor; do not bypass it for staging.
The observer's reusable source lines do not approve WR-03 or resolve the conspiracy.

Before qualification: engine parse/startup; reader gate; actual route/door and
arrival proof; same-minute rerun, strict fault, interrupted dedicated and ordinary
dialogue, WAIT, home and load; native two-person clearance, safe attitude release
and populated-frame cost. Reuse the established temporal, loop-stage, conversation,
agenda, route and pose fixtures. Keep the original failures. No main merge or
runtime receipt is claimed. Fable's body/outfit work and the film capture hold
remain separate dependencies.
