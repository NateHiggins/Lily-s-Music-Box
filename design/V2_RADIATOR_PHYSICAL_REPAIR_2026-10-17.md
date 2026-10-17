# V2 radiator physical repair

Evidence class: **INERT**. Implementation report; no ledger promotion or human acceptance.

The native radiator now reports a successful repair after the player assembles
and operates the actual fittings. It no longer accepts a legacy maintenance-panel
result as an instruction to move its parts or declare the fault repaired.

Only the existing **F02_B_RADIATOR_01** service target can report completion for
**lena_radiator_round_2b**. WorkOrders must already hold its repairable stage;
the existing ServiceRound director still owns diagnosis, repair credit and the
resident conversation. No new job, case or durable completion flag is introduced.

The observer reads the existing maintenance activity's completion metadata. The
correct physical insert must be present and seated, the cap and packed union
sealed, the supply fully open and the radiator pitched toward its supply. The
shared HeatBalance must deliver steam without hammer, hiss or material steam
loss. The real float must reach its needle seat, followed by three seconds of
continuous sound conditions. A held part interrupts proof. Restoring a mechanism
discards this transient interval; a saved timer cannot finish the repair.

Completion consumes an existing returned packing custody record once, retains
the physical liner in its seat, and emits the existing maintenance-completed
signal. It does not install an insert, close a cap, tighten a retainer, change
pitch, open a valve, manufacture packing or advance diagnosis on the player's
behalf. Factory-healthy radiators elsewhere cannot complete the 2B job.

The porter's past V2 shutoff now remains historical after its real action.
Repeated actor updates cannot hold the wheel shut against subsequent player
motion. On reconstruction, a completed V2 job supersedes old interference and
porter residue as a narrative fact while preserving the actual household parts,
including later damage. The legacy V1 intervention behavior remains available.

The fast production-player bench passed with one repair event and one custody
transfer. It exercised actual retainer and supply motion, Space inspection,
diagnosis gating, no-steam and partial-valve refusal, float closure, interrupted
proof on restore, the real porter action and later physical changes. Lobby and
boiler comparison callbacks are explicit fixtures here; this is not a played
route through those rooms. The earlier packing scenario's actual earned custody
snapshot supplies the independent repair fixture; no production item is reset.

The existing MaintenanceServiceRound, OpenShiftAuthority and OpenShiftMeddle
suites passed. The systemic-authority tools suite passed all 59 tests; the data
reader gate reports zero new unread fields. The fresh composed radiator/fuse
review passed 1,180 checks with zero failures. It does not play the new repair
route; that completion is exercised in the fast bench. The existing seven-
Texture-RID shutdown warning remains open.

Evidence lives in **art/reviews/v2_radiator_cutover_20261017/physical_repair**.
The first bench failure is retained: its mouse driver allowed fewer increments
than a full 3.5-turn stem requires, and its earlier scenario had already consumed
the liner. The corrected driver retains real mouse increments; the independent
custody fixture restores the earlier earned record through MaintenanceInventory.

This work changes no visual stocks or PBR maps. Prior native fit and visual
reviews retain their original scope. Fine cap threads, cloth/brass/wood polish,
full played-route and disk reconstruction proof, broad stale runtime/spatial/
surface qualification and human appearance acceptance remain open. V2 is not
complete or ready for integration on the strength of this focused bench.
