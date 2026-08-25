# ORISON SERVICE ROUND — maintenance micro-activities

Owner direction, 2026-08-24. This is the waking maintenance expansion: one
third of active play in short physical service interactions, one third with
residents / travel / search, and one third observing, avoiding and eventually
communicating with the Dream organism. It extends the complete loop in
`game/docs/core_loop.md`; it does not claim another waking case is complete.

## Ruling

The Orison's period machinery is one distributed nervous system, not a shelf of
unrelated puzzles. Steam, water, electrical call circuits, speaking tubes,
elevator and dumbwaiter shafts, mail chutes and the watchman's physical round
all join distant rooms through hidden structure. The player first learns each
ordinary rule, then notices an impossible result, then recognizes that the
contradiction is an attempt at communication.

“WarioWare-style” means **a chain of 3–12 second physical verbs**, not a
full-screen game or score attack. The established `PROP_ACTIVITIES` test still
applies: resistance then release, a discrete commit, sound as reward, immediate
reversibility before commit, visible mechanism. The service strip may name the
hand action and its travel; the prop itself must supply the response.

## Historical basis

- The Orison is a one-pipe steam building. Steam and condensate share a pipe;
  radiator air valves let displaced air escape so steam can enter. Period
  witness: Hoffman Specialty Company's one-pipe air-valve advertisement in
  *House & Garden*, October 1920:
  https://www.usmodernist.org/HG/HG-1920-10.pdf
- A 1920 low-water alarm patent couples boiler level, an audible whistle and
  fuel shutoff. The glass is evidence only when its passages communicate:
  https://patents.google.com/patent/US1364287A/en
- A 1915 apartment annunciator fixture combines electric bell, speaking tube,
  pushbutton and electromagnetic street-door release:
  https://patents.google.com/patent/US1149973A/en
- Otis's 1924 mechanical landing interlock makes the car itself release a door
  only at a safe landing: https://patents.google.com/patent/US1493069A
- A New York inventor's 1910 dumbwaiter uses a counterweight, lift sheave and
  automatic holding brake: https://patents.google.com/patent/US950828A/en
- A 1923 New York apartment-house mail chute isolates oversized mail in a
  floor-local choke compartment: https://patents.google.com/patent/US1450139
- Watchman's clocks use different station keys to mark a clock-driven paper
  dial and make the worker's route physical:
  https://patents.google.com/patent/US1351056A/en

## The active-time braid

Balance over a rolling 40–50 minutes, not every minute. Attribute each second
to the player's primary attention; a Dream limb merely visible behind a valve
does not turn maintenance into an entity beat.

| lane | target | content |
| --- | ---: | --- |
| Hands-on maintenance | 33% | inspection plus chains of turn, align, hold/release, listen, trace and time verbs |
| People / travel / search | 33% | calls, resident thresholds, 2–3-zone routes, acoustic and physical diagnosis, parts |
| Dream relationship | 33% | observe, misunderstand/avoid, test signals, answer, cooperate |

Avoidance is an early misunderstanding, not the final entity relationship.
Dream organisms seek contact as organelles of one hyperdimensional being;
pressure, sound, light, heat and electrical pulses are waking-world translations
of their electrochemical and secretory communication.

## Activity contract

`MaintenanceActivityLibrary` is the strict data boundary. An activity owns
apparatus copy, historical source, material/human/Orison story layers, and an
ordered sequence of micro-verbs. It owns no job, resident, case or Dream fact.

`MaintenanceActivityDirector` admits one run and routes input. A run withholds
its proposed `mechanism_patch` until the final verb succeeds. The director
cannot apply that patch and has no `WorkOrders` method. The physical prop may
consume a completed result through its existing setters; `WorkOrders` remains
the only job-stage owner. Aborting before commit restores the prop snapshot.

The first shared vocabulary is `turn`, `align`, `hold_release`. Precision and
hold assists widen access without changing the authored sequence or its story.
No diagnosis may rely on sound alone.

Each profile also carries exactly one controlled `transferable_verb`. This is
the physical principle the hands-on job teaches, not another input verb or a
supernatural explanation. The first round maps radiator venting to `flow`, the
annunciator's squared electrical faces to `contact`, and the communicating
boiler column to `pressure`. Validation admits only pressure, continuity,
timing, regulation, contact and flow; the tag owns no Dream, case or save fact.

## First Service Round

Three profiles are authored in `game/data/maintenance_activities.json`:

1. **Apartment — radiator vent.** Shut to a detent, hold through the painted
   vent thread's release, clock the replacement, return the one-pipe supply
   fully open. This is the first live consumer.
2. **Lobby — annunciator flag.** Free the armature, square the contact and reset
   the bank. The impossible call may name two apartments at once.
3. **Basement — boiler water column.** Isolate the demonstration column, prove
   its drain, witness the returning level and return it to guarded service.
   The impossible line remains after the glass should be empty.

The target complete slice is call → resident → radiator evidence → lobby
comparison → boiler comparison → Dream interruption → repair → resident return
→ a deliberate reply through the same pressure/sound rhythm.

## Production order

1. Shared data/run/director/presenter contract and live radiator consumer.
2. Lobby annunciator consumer using the same verbs and presenter.
3. Boiler water-column consumer using the same verbs and presenter.
4. One authored service-round work order and resident/search route through the
   existing lifecycle owners.
5. One shared Dream response that observes and answers apparatus events without
   creating a maintenance-owned Dream director.
6. Rolling attention telemetry and tuning against the 1:1:1 target.
7. Vertical expansion: dumbwaiter, elevator interlock, rooftop tank, mail-chute
   choke, fuse panel, watchman clock, sash weights and laundry mechanisms.

## Landed production checkpoints

- **M1 / radiator:** shared activity data, run, router and paper-strip
  presenter; live one-pipe radiator consumer with preview/abort/commit proof.
- **SR2 / lobby annunciator (2026-08-24):** the production porter board exposes
  separate dispatch and call-hardware reaches. Its real call flags, contact
  bridge and common reset enact the authored three-step chain; the older lift
  game is unchanged. Headless proof boots the production building, and frozen
  A/A plus worked-state Forward+ evidence is recorded at
  `art/renders/maintenance_annunciator_sr2/README.md`.
- **SR3 / boiler water column (2026-08-24):** the production basement boiler's
  real glass now owns the shared four-step service reach. Gauge cocks, blow-down
  lever, visible water and witness marker preview isolate/prove/read/return
  without publishing plant state. Completion alone sets the proved honest
  level. Production-root tests and frozen A/A plus four worked Forward+ frames
  are recorded at `art/renders/maintenance_boiler_sr3/README.md`.

- **SR4 / first waking service round (2026-08-24):** Lena Ortiz files Work
  Order 002 through the carried 28-R only after Mina's opening job closes. Her
  threshold conversation acknowledges it; opening the 2B radiator reach earns
  inspection without repair; the production lobby contacts and basement water
  column must then be proved in order. Those three facts alone make the no-part
  job repairable. The 2B activity records the repair, and a deliberate return
  reply—not proximity or a UI close—closes it. `ServiceRoundDirector` translates
  existing signals into public `WorkOrders` calls and stores no lifecycle.
  Production A/A, call and resident frames plus executable proof are at
  `art/renders/maintenance_service_round_sr4/README.md`. SR5 remains the shared
  Dream interruption/answer; SR4 creates no maintenance-owned Dream fact.

## Acceptance

- Each micro-verb authors 3–12 seconds; failure recovers in under four seconds.
- A first attempt is comprehensible 70–85% of the time in playtest.
- No verb family repeats more than twice in ten minutes.
- Most service jobs cross two zones and no empty travel leg exceeds two minutes.
- Timing, precision, holds and audio cues all have alternatives.
- No interaction can close a job, advance a case or create a Dream fact through
  presentation code.
- Visual claims receive windowed production-render proof; animated/shader claims
  also receive an unchanged A/A noise control.

## M1 checkpoint — 2026-08-24

The shared contract, all three data profiles, narrow service strip and live
radiator consumer are implemented. The radiator's preview moves the actual
wheel and vent without publishing heat state; only final completion reaches
`set_vent_grade` and `set_supply_position`. Focused data/run and live-consumer
tests pass. Paired Forward+ proof is at
`art/renders/maintenance_service_round_m1/README.md`.
