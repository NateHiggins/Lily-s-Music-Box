# V2 roof program spatial access checkpoint — 2026-10-12

Evidence class: **EVIDENCE**. Automated spatial access and scoped machinery checks.
Status: **Nine roof spaces reached; full runtime authority and human acceptance remain separate.**

## Scope actually executed

One production-selected V2 world runs the roof plant circuit followed by the
lift-drive circuit. There is one initial F06 placement. The first circuit
returns to F06 and the second continues from that actual position. All 80
walked targets use the normal controller and collision. The supplemental shaft
inspection moves only the camera, pauses and restores player physics, and
claims no player access into the shaft. No second player placement supplies
access. The roof strips now have explicit interior trace points as well as
pass-through movement.

The 175-check run passes with zero failures and zero script errors. Actual
controller positions fall inside the following current authored roof spaces:

- `ROOF_DECK_EAST`
- `ROOF_DECK_MIDDLE`
- `ROOF_DECK_NORTH`
- `ROOF_DECK_NORTHEAST`
- `ROOF_DECK_SOUTH`
- `ROOF_DECK_SOUTHEAST`
- `ROOF_DECK_WEST`
- `ROOF_PUBLIC_CORE`
- `ROOF_SERVICE_CORE`

## Plant behavior and limits

Ordinary player input opens/closes the roof doors and independently toggles the
two task-light circuits. Original light owners remain active. The test checks
both real bulkhead supply bores, the retained lower/retired upper conduit cap,
solid perimeter barriers and the open chimney mouth.

Tank entry and reopening use ordinary E input. Abort and the authored service
verbs are invoked directly through the maintenance director. Abort restores
state and movement; completing service leaves the valve holding and overflow
stopped. Timber tank and support collision are checked with actual rays and
an upright player capsule. This is not a claim that all service verbs were
performed through physical input.

The drive observes the production lift. The player capsule stops at its guard;
the sheave follows the real car and stops with it. Directly requested car travel
exercises continuous counterweight and crosshead clearances, constant suspension
length and opposite counterweight motion. The real roof rope apertures remain
open. The test does not provide lift repair, disk reconstruction, refusal policy
or a complete authority-lifecycle contract.

## Program authoring and proof binding

Two source purposes now identify the existing physical functions: the public
roof core includes guarded passenger lift machinery, and the west deck includes
house-tank service. Projection changes only those two purpose strings; every
other layout value, position and native geometry is unchanged. The original
source-owned identities remain. The reader audit reports zero new unread fields.
Four roof projection tests and three ventilation-projection tests pass.

Test: **game/tests/OrisonV2RoofProgramContractTest.tscn**.
The test-authored schema-2 contract is committed at
**art/renders/orison_v2/roof_program_20261012/runtime_contract.json**.
The separate **roof-final.log.receipt.json** is the execution wrapper. Current
runtime/surface hashes, root and helper hashes, trace containment and measured
retirement validate before this SPATIAL_ACCESS channel admits any room. The
production root and two route drivers retire. Godot reports seven Texture RID
leaks at shutdown; resource-clean shutdown is not claimed.

The first diagnostic exposed a fresh-world door assumption when the circuits
were combined. The second driver now closes an already-open leaf using ordinary
interaction before its inherited closed-leaf checks. It also exposed rotation
drift in carried-light interpolation; normalized rotation inputs prevent the
Quaternion errors while preserving aim and positional lag. The final run checks
recovery from measured-size scale drift and convergence to the camera aim, and
contains no rotation errors. The failed diagnostic is not acceptance evidence.

## Remaining verification

The affected surface, first-slice and both apartment route proofs have been
renewed and independently validated against the current inputs. Clean candidate
comparison is pending. This checkpoint grants only
spatial proof; full V2 runtime, case, narrative, visual and human-navigation
requirements remain open.
