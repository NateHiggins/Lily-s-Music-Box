# The sanity system

An invisible pressure model, eighteen poltergeists built from the residents'
own traumas, a meta layer that breaks the frame, and a director that decides
who speaks and when.

There is no sanity meter and there is never going to be one. A meter turns
dread into a resource: players learn its rate, learn what refills it, and
the horror becomes budgeting. The only readout is the building.

## Files

| File | What |
|---|---|
| `scripts/reality/sanity_director.gd` | Pressure model, player telemetry, the who/where/what/when decision |
| `scripts/reality/poltergeist_library.gd` | 18 personalities as data, one per resident case |
| `scripts/reality/intrusions.gd` | In-world acts: possession, lights, sound, annotation, distortion |
| `scripts/ui/fourth_wall.gd` | Meta effects that pretend to be outside the game |
| `scripts/player/safety_net.gd` | Catches a player the world has dropped |

## The design rule

**An intrusion is only allowed if it is a sentence about the person whose
apartment it happens in.**

Every personality is derived from that resident's case in
`data/reality_cases.json` — its `manifestation`, its `resolution_flags`, its
`portal_rule`. Nothing is invented. Mina's case says captions escalate from
nouns to false claims about thoughts and intentions, so her poltergeist
annotates, and what it eventually annotates is the player. Omar's says every
repaired object returns with another impossible fault, so his breaks what you
have just watched work. Noel preserved his family into a museum, so his
accessions the game itself.

That rule is what separates this from a jump-scare generator, and it is what
makes the system's stated goal — insight into the trauma — reachable rather
than decorative.

## The ladder

Each poltergeist has four rungs. The escalation is the same argument made
more plainly each time.

1. **tell** — an anomaly small enough to dismiss
2. **pattern** — the same anomaly, repeating, no longer dismissible
3. **reenact** — the trauma staged in the room, using the room
4. **address** — it stops performing and speaks to the player directly

Rung four is the point of the whole system and deliberately the rarest. It is
where the haunting says the thing the resident cannot. A poltergeist that
explains itself every ten minutes is a chatterbox, not a wound.

## Pressure

Hidden, 0–1, recomputed every 1.4 s. Sources:

- the building's own `Conductor.infection` — the floor of the mood
- live cases (`active`, `reopened`) push it up
- **resolved cases push it down** — understanding is the only thing in the
  system that lowers pressure, which is the argument the game is making
- working a call adds a lot: the desk is where the player is most committed
  and least able to walk away, so that is when the building leans on them
- behaviour: standing still (attention), running (flight — pushed briefly,
  then backed off, because chasing a fleeing player reads as unfair), and
  whipping the camera around, which means the last one landed
- **attention**: holding a gaze on one object says the player has found
  something and is working out what it means, which is the moment an
  intrusion is worth spending
- **being ignored**: see below
- **campaign memory**: how many addresses this player has already been
  given, persisted, so escalation runs across the whole game and not just
  the session

## Attention

The director raycasts from the camera every tick and knows what the player
is looking at and for how long. That does three things.

**It picks the room.** A held gaze names a place more precisely than a
position does — you can stand in a corridor and be looking into somebody's
kitchen, and the poltergeist who speaks should be the one whose things you
are staring at.

**It aims the act.** `_nearby_props()` sorts unseen props ahead of visible
ones by default, because the strongest version of nearly every act here is
the one the player did not watch happen. A chair that turns while you watch
is a special effect; a chair that has turned when you look back is a fact
about the room you are standing in. `prop_vanish` goes further and will
*only* take things currently out of view — watching an object blink out is a
glitch, finding the shelf empty is a memory you now distrust.

**It closes the loop.** Every act records what it touched. If the player's
gaze lands on any of it within 14 seconds, the building concludes it was
heard: the insistence counter resets, pressure drops slightly, and it buys
some quiet. If the window expires untouched, the intrusion was unwitnessed
and pressure climbs. This is the one place the building deliberately gets
louder, and it is why a player who blunders through with the camera on the
floor ends up somewhere worse than one who stops and looks.

Annotation acts mark their anchor props too, even though a label hung over a
chair does not move the chair — a player who looks at the labelled chair has
still noticed, and notice is what is being measured.

## Pacing

Most ticks deliberately do nothing. Three rules make escalation read as
intent rather than as a random event generator:

1. **Refractory periods** after every intrusion, longer for higher rungs.
   Two hauntings back to back are one haunting with a stutter.
2. **Mercy.** After a rung-four address the building goes quiet for a long
   beat and pressure drops. The silence is where the player does the
   thinking, and the thinking is the entire point.
3. **Anti-repetition.** No poltergeist plays the same rung twice running, and
   the director will not pick the same resident twice while another has
   something to say.

## Who speaks

Proximity usually wins, because an act has to land on props the player has
already looked at. Competing claims: whose apartment the player is standing
in, whose case is live, who the player has been dwelling near, and who spoke
last (penalised). Resolved residents fall silent.

## The fourth wall

Eternal Darkness worked because it attacked things players believe are
outside the fiction. Two rules keep that from being a cheap trick:

- every effect is a sentence about a specific wound, not a generic prank
- **nothing here touches anything real.** No file is written, no setting is
  changed, no input is rebound, nothing is deleted. Every effect is a
  *picture* of a catastrophe. All of them self-clear on a wall-clock timer
  with a hard ceiling, because an effect that can strand a player is a bug
  wearing a costume.

Effects never overlap — two at once reads as a rendering fault rather than a
haunting, and the illusion depends on each looking like the only thing that
has gone wrong.

## The safety net

The world is allowed to lie about its own floor: chaos mode folds the storey
you are standing on, reality thresholds teleport you through paired doorways,
room-local gravity points sideways, and a poltergeist may be moving furniture
out from under you. All of those are supported states and any of them can
drop a capsule out of the world.

`SafetyNet` records the last position where the player was genuinely standing
on real floor — never mid-air, never mid-fall, and never during or just after
a distortion — and silently restores it if the player leaves the world:
below −12 m, beyond ±240 m, or at a non-finite position. Non-finite is
checked first and separately, because a NaN transform fails every range
comparison silently and would otherwise fall forever with all the checks
politely returning false.

No message, no fade. A visible safety net is an admission that the floor
cannot be trusted, and the floor not being trustworthy is the horror.

## Testing

WalkTest stands the director down for the deterministic pass — it moves
furniture and rewrites light energies, which is exactly what the lighting and
prop assertions measure — then drives it explicitly at the end. It proves:
the net catches both a fall and a NaN transform; all 18 poltergeists map to
real cases with complete ladders; possessed props restore exactly; every meta
effect named by a rung-four address actually exists; and standing down leaves
the building clean.

Use `SanityDirector.force(case_id, tier)` to fire a specific rung, and
`stats()` for the hidden values. Neither may ever be wired to shipped UI.

By hand: F1 opens the debug panel, whose SANITY section is open by default.
Pick a resident in the shared SUBJECT dropdown, then fire any of the four
rungs on them, restore the props, stand the director down or re-arm it, play
any fourth-wall effect by name, and drop yourself out of the world to watch
the net catch you. The status block at the top is the only place pressure is
ever displayed.

## Not done yet

- No per-resident audio. Whispers are text; the sound acts borrow the
  building's own library (radiator knocks, boiler hum) so a poltergeist
  sounds like the building rather than like a different game, but a resident
  speaking in their own voice would be much stronger.
- Rungs one to three are strong for the residents whose trauma is spatial or
  object-based, and thinner for the ones whose trauma is linguistic. Jonah
  and Mae in particular want acts that do not exist yet.
- Gaze is a single ray from the camera centre. It answers "what are you
  looking at" but not "what is in your peripheral vision", so an act placed
  just off-centre counts as unseen when the player would plainly notice it.

## A trap worth knowing about

The campaign persists to a user save, and the test suite was silently
inheriting it. On a machine that had ever opened Mina's case, her evidence
interactables came up with collision enabled — and one of them, the redaction
pencil, stands in 2A's living room on the exact line the bedroom walk takes.
A fresh clone passed; this machine failed. Environment-dependent and
invisible in the diff.

WalkTest now resets the campaign **before** the building is built, because
case gameplay reads the state once in `_ready()`. And it *seeds* every case
rather than merely emptying the table: `_refresh()` early-returns on an empty
state, leaving interactables at their default enabled, which is worse than
the save it was escaping. Emptying is not the same as a first launch.
