# “The House Heard Big” orchestration contract

Status: pre-wiring owner audit. This document specifies the smallest honest
story owner that can turn one mechanical answer into a building-wide comic
burden without teaching the fortune prop, telephone, register, keys or work
orders a second lifecycle.

## Audit result

This should not be another resident case and should not be folded into the
opening `FirstShiftDirector`.

- `RealityCaseManager` owns resident manifestations, repair recurrence,
  conversation flags and portal-rule resolution. “The big job” has no resident
  whose psyche should be diagnosed or repaired.
- `FirstShiftDirector` owns the one-time arrival-to-clock-out tutorial. Making
  its completion depend on a novelty would turn an optional comic promise into
  a tutorial gate and make old saves ambiguous.
- `WorkOrders` owns job stages. The fortune event must not author a synthetic
  omnibus job or advance existing ones.
- The physical prop can prove only coin path and head motion.

The correct owner is a small campaign vignette director, tentatively
`HouseHeardBigDirector`, activated only after first shift is complete. Its saved
state describes the vignette boundary—not the state of any instrument.

## Durable state

One additive dictionary, `RealityState.data.house_heard_big`:

| field | values | meaning |
| --- | --- | --- |
| `phase` | `dormant`, `answered`, `burden`, `narrowed`, `complete` | Vignette boundary only |
| `first_answer_sequence` | integer | Rejects duplicate observation after reload |
| `owners_presented` | array of closed owner ids | Which requested presentations were accepted |

Do not persist question text, a “wish granted” boolean, instrument snapshots,
new jobs, invented callers or a second custody record. The causal ambiguity is
the point: the save says the vignette advanced after an observed answer, never
that the machine understood or caused it.

## Phase transitions

### Dormant → answered

Eligibility: first shift is `complete`; fortune prop emits its first accepted
answer. The director records sequence and schedules the burden for the next
ordinary shift boundary. A NO answer is still eligible: comedy comes from the
house behaving as though it heard what the player wanted, not from rigging the
machine into prophecy.

### Answered → burden

At next shift presentation, request at most one legal state from each owner:

| Owner | Legal request | Capacity rule |
| --- | --- | --- |
| House telephone network | One already-authored endpoint asks | Only while `IDLE`; no queue fabricated |
| Night register | Present the first already-issued supported report | One pinned slip; never duplicate or replace it mid-round |
| Tour-key guard | Remain readable in its actual custody state | Observation only; do not take the key for the player |
| Watch register | Show an indication only if a real station signal arrives | Never call `receive_signal` as theatrical dressing |
| WorkOrders | Supply title/objective for existing work | Read only; never issue, acknowledge or close |
| Objective presenter | Compose “THE HOUSE HEARD BIG” from accepted requests | Presentation, not lifecycle authority |

The scene is simultaneous across owners, never multiplied inside one owner.
One call plus one report plus one custody fact is a building chorus; five fake
telephone callers and a stack of duplicate slips is a lie.

If an owner is busy, unavailable or has no honest presentation, record no
acceptance for it. The vignette must remain playable with only two distinct
owners answering. It may retry idle presentation seams later, but it must not
reset, interrupt or expire someone else’s live state.

### Burden → narrowed

This is not “finish every task.” It observes a quieting boundary composed from
public owner facts:

- telephone returns to `IDLE` through its rightful answering hand;
- tour key is on its hook;
- night register has no report in hand and no keys out;
- exactly one currently presented report is selected as the player’s focus.

The last clause prevents tidiness from becoming the moral. The player becomes
“small enough” by choosing whom to hear, not by making the house empty.

### Narrowed → complete

The player may work the fortune machine again. Its answer closes only the
vignette. It does not certify that custody is morally correct or undo any owner
state. Final copy may note the head’s motion and the house’s quiet separately;
it must never state that one caused the other.

## Signals and adapter boundary

The director may consume:

- `FortuneAnswerProp.answer_given(record)` (answer, path,
  powered-at-actuation and sequence only);
- first-shift phase changes;
- telephone `line_changed(snapshot)`;
- tour-key taken/returned observations;
- night-register presentation/custody reads.

It should depend on injected callables or a thin adapter, not search the scene
tree. Production root wiring resolves concrete owners once. A focused harness
can then prove the director with typed doubles without instantiating the whole
building.

## Required refusal and reload proofs

1. Answer before first-shift completion is inert.
2. Duplicate answer sequence cannot open the vignette twice.
3. Busy telephone is never reset or overwritten.
4. No issued supported report means no fabricated slip or job.
5. Key already carried remains carried; the director neither returns nor takes it.
6. A station register changes only from a delivered station signal.
7. Reload in `burden` reconstructs copy from owners and does not replay requests.
8. Narrowing refuses while a cord or key remains out.
9. Completing the vignette changes no job stage, case stage or instrument-owned
   persistence.

## Cheap visual and audio escalation

Use existing geometry and bounded owner sounds. The new cost should be one
oversized paper tongue temporarily presented by the vignette adapter and one
composed objective card. Everything else is an existing bell, drop, hook,
cord, slip or lamp responding through its normal owner. Avoid new dynamic
lights, viewports, physics bodies and a second notification UI.

The oversized strip is comedy, not a ledger. It lists owner titles already
accepted for presentation, disappears on narrowing, and stores no job data.
If it cannot remain legible without blocking the wall or player route, cut it;
the chorus of real instruments is the stronger effect.
