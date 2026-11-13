# Loop punch-up and first source integration

Evidence class: **INERT**. November 12, 2026. Implemented in source, **not run in
Godot, played or artistically accepted**. Lily requested integration with no time
for testing now. No engine, capture, voice or animation batch was launched.

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

The actual playable lines are the selected single-speaker replies in that JSON.
The longer multi-person script exchanges and complex prop handling remain direction
for later implementation; they have **not** all been converted into runtime scenes.
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
  A thin route subclass yields before approaching another walking resident during
  visits; the original motor still owns every actual step. Mae/Cal move to the
  kitchen while their visitor comes through, then resume their phase after the
  guest arrives. There is no new sidestep or collision exemption. Narrow two-way
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
  A same-minute rerun is distinct; an object-order fault is not. Home/real rerun
  clears this owner's transient replies, attitudes and dedicated conversation.
  Phase changes cancel its dedicated line. Nothing rewinds knowledge or extends
  a visit. Existing mystery heard-at-entry semantics are unchanged.

## Honest limits and next verification

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
