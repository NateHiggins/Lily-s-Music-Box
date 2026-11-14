# Household control persistence

Source integration over `312c001`. Godot remains paused. This packet does not
claim executed save/load, physical behavior or V2 completion.

One V2 household state owner now captures 56 control settings under the additive
`v2_household_controls` save field: 39 lighting circuits (38 apartment rooms plus
laundry), five ordinary radiator supply positions, six kitchen sliding-cabinet
doors and six medicine-cabinet doors. Lena's 2B radiator remains exclusively
restored by its existing packing/situation authority. Heat output, vent repairs,
case state, fixtures' animations, audio playback and transforms are not copied
into this household field.

The owner resolves the full roster and validates the entire saved block before
applying any setting. Old saves without this field use freshly constructed
defaults; partial valid records inherit those defaults. Unknown identities,
future schema versions, nonboolean door/light values, nonfinite or out-of-range
valves and extra transform fields are refused. Malformed live-load records are
left intact, and household writes stop until a valid load arrives.

Actual control events capture changed settings and call RealityState.commit.
The existing snapshot_preparing signal also captures direct control changes
before a normal save. The capture callback never commits recursively. Unchanged
captures do not write, and protected saves are not mutated. RealityState and its
crash-recovery storage remain the only save writer; neither is modified.

Loading/resetting state into an existing world restores valid new facts instead
of saving the previous world's controls over them. Cabinet restore methods set
the physical endpoint without animation or sound replay. Normal interaction
keeps its existing movement/sound. Shutdown disconnects every signal before the
adapter removes consumers; a detached or partly freed roster cannot make a
partial snapshot. Only one household save owner may bind at a time.

Source evidence is in `../../work/v2_household_persistence_01/source_checks.json`.
All 56 IDs resolve uniquely through existing manifests, and six scripts parse
with gdtoolkit. Heating, accessories and kitchen-cabinet category source checks
still pass. Layout, furnishing/material data, native save storage, switches and
the existing radiator/case owners are preserved.

`game/tests/OrisonV2HouseholdStateTest.tscn` is prepared for a real disk round-trip
using a unique test-only save path, two complete world lifetimes, all 56 restored
values, quiet cabinet restore, eight malformed payloads, live-load refusal and
recovery, protected-save handling, omitted legacy fields, idempotent capture and
retired-listener checks. It has only been syntax parsed. No player's save was
opened or written by this source pass.

Remaining work includes household categories outside this bounded save schema,
sixteen residential programs with their authored dispositions, shared/service
spaces, wider migration and the queued runtime/visual/performance checks. The
arcade ceiling reference work remains integrated. V1 is still the default and
S2J remains open.
