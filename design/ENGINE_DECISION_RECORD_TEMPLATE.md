# Engine decision record — EDR-___: [decision title]

**Status:** proposed | accepted | superseded | rejected
**Date:** YYYY-MM-DD
**Owner:** [system/fact owner, not merely the implementor]
**Milestone / task:** [for example K0-ENGINE, K3, AU-2]
**Decision commit:** [SHA once accepted]
**Supersedes / superseded by:** none | EDR-___

> Delete this instruction block when copying the template. Use an EDR only for
> a systemic decision: authority ownership, cross-subsystem contract, generated
> data/schema boundary, save/migration rule, release-proof protocol, or a seam
> proposed as reusable. Ordinary prop content, local tuning, bug fixes that do
> not change a contract, and accepted render sheets do not need one.

## Decision

[One paragraph stating what is decided, what owns the fact, and what other
components may observe or present. Write in the present tense after acceptance.]

## Production problem

[Describe the observed game/release failure or constraint. Name the player,
authoring or verification consequence. Do not begin from a desired abstraction.]

## Context and constraints

- Product authority: [brief/task/design ruling]
- Existing owner(s): [classes, data files, scripts]
- Consumers: [runtime, generator, tests, tools]
- Must preserve: [save compatibility, input, performance, privacy, etc.]
- Explicitly out of scope: [adjacent work this decision does not license]

## Contract

### Inputs

| Name | Type / shape | Authority | Valid range / precondition |
| --- | --- | --- | --- |
| | | | |

### Outputs and effects

| Output / effect | Owner | Consumer | Guarantee |
| --- | --- | --- | --- |
| | | | |

### Failure and refusal behavior

| Condition | Observable result | State mutation allowed? | Recovery / retry |
| --- | --- | --- | --- |
| | | | |

### Persistence and migration

[State what is saved, derived on reconstruction, versioned, deliberately
transient, or not applicable. Name compatibility consequences.]

## Alternatives considered

| Alternative | Evidence for/against | Why not selected |
| --- | --- | --- |
| | | |

Include “leave the current system alone” when it is a real option. Record failed
approaches and the evidence that rejected them; do not rewrite history into an
inevitable solution.

## Evidence

| Claim | Test / measurement / capture / commit | Result | Machine/context |
| --- | --- | --- | --- |
| | | | |

### Evidence level

Select the strongest level actually earned under
`design/ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` §G:

- [ ] L1 — observation
- [ ] L2 — local invariant
- [ ] L3 — reusable contract with names, inputs, outputs and failure modes
- [ ] L4 — second-consumer proof importing no Orison state
- [ ] L5 — product claim with docs, versioning, support and compliance answers

**Ceiling / unsupported claim:** [State why the next level is not earned. Mark
any claim above the checked level `UNSUPPORTED`.]

## Godot and platform constraints

[Engine lifecycle, renderer, autoload, resource/import, threading, filesystem,
PowerShell/Python/Blender, operating-system or hardware constraints.]

## Orison-specific content and candidate reusable seam

**Keep game-specific:** [case ids, residents, floors, vocabulary, art, data]

**Candidate seam:** [pattern or contract only; write “none” if the decision is
product-specific]

**Extraction caution:** [couplings, rewrite cost, second-consumer evidence
still required, licence/support questions]

## Consequences

### Positive

-

### Costs and risks

-

### Follow-ups

- [task, owner, gate; do not hide unfinished acceptance here]

## Falsification and rollback

**This decision is wrong if:** [a measurable repository/player fact]

**Detection:** [test, audit, playtest or metric]

**Rollback / supersession path:** [how authority returns to a valid state;
never prescribe destructive Git commands]

## Ledger update

[Name the exact section in `design/ENGINE_KNOWLEDGE_LEDGER.md` updated by the
accepted decision, or explain why this is a product-only decision with no
reusable lesson.]
