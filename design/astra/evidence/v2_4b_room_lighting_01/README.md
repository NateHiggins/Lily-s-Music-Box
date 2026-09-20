# 4B room circuits and radiator binding source pass

Added a main-room pendant and bathroom flush-dome fixture, each controlled by
a physical switch through the existing V2 RoomLighting/SwitchSystem owners.
The main switch sits inside the entrance beside the opening. The bathroom
switch sits on its west wall clear of the door aperture. Fixture and switch
anchors are contained in their named rooms. The existing pendant's lowest
geometry is approximately 2.239 m above the floor at the new ceiling anchor.

Starting intensity/range settings reuse the existing 2A main-room and 3B
bathroom settings. They are initial authored values, not visually tuned or
approved brightness. No existing circuit, light-budget policy, alcove setting
or legacy readability light was changed. Physical fixtures do not by themselves
complete replacement of development lighting.

Also bound the 2B radiator explicitly to the campaign MaintenanceInventory and
its stable `F02_B_RADIATOR_01` graph ID, matching the existing 3B composition.
Its packing-custody reader otherwise reports the radiator as custodian when
inventory is absent. No inventory or radiator mechanism was rewritten.

Source placement/circuit checks and independent syntax parsing pass. Existing
lighting records remain unchanged. The earned boundary harness now checks
reconstructed room switches, power toggle/restore, unchanged alcove power,
and 2B inventory/graph identity. These new assertions use direct interaction
calls and have not run; they do not prove a physical player approach.

**Godot was not launched, per owner instruction.** Next engine validation must
walk to both switches, check ray targeting, capture the actual room light,
verify floor budgeting and run the radiator custody/service regression.

Heating audit: the shared HeatBalance budget depends on its entire radiator
roster. V2 currently mounts only 2B and 3B radiators. Connecting a two-radiator
budget as though it were the whole building would alter heat distribution;
whole-building balance remains pending, as do persisted plant state and full
service topology. This pass makes no heating or release-completion claim.
