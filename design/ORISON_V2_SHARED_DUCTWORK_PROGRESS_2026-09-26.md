# V2 shared bathroom ductwork

Evidence class: **INERT**

REPORT - V2-SHARED-DUCTWORK - 2026-09-26

Branch / base / origin/main at start / merge-base: main /
474cd87b2db5a31fe80b4359c1245f53e0cd9a71 (all three references).
Implementation HEAD is the commit introducing this report.

## Construction and ownership

Twenty-three passive bathroom registers now connect to four modeled sheet-metal
risers, overhead branches, plenums and roof terminals. Two risers occupy the
existing wet-service chase; two follow exterior-wall fabric. The terminal bends
stay below the roof deck. The roof ventilators move and turn so their guarded
inspection faces remain accessible from inside the parapets.

The old assignment inferred a stack from the apartment letter, although V2's
letters do not describe four physical vertical runs. The explicit source graph
now assigns five northwest bathrooms to A, six southwest bathrooms to B, five
north-central bathrooms to C, and six eastern bathrooms plus the staff restroom
to D. The production motors retain their four variants, automatic cycles,
bearing tones and guarded-service refusal. Each motor's existing emitters bind
to the same actual register roster as its physical ductwork. No bathroom gains
a private motor or switch; no new repair, campaign state or save owner is added.

The vertical-services source retains ownership of register and fan positions.
The completion-interiors source owns the explicit assignment graph and emits
it through its existing projector. Runtime construction validates the complete
roster before mounting consumers. Static ductwork uses eight material-batched
draws and matching collision sections, with existing catalogue materials.

## Verification and corrections

Logs, frames and adjacent suite-run receipts are under tmp/v2-ducts. The first
run exposed a capture-only register-ID error; its printed zero-failure line is
not a valid pass because stderr records a script error. The test now keeps an
incomplete-run failure until its last check, and explicitly checks capture
anchors before using them. Roof terminals were projected from their actual
vertical-services owner rather than the roof-shell source.

The rendered second run exposed register/light overlap inherited from centered
bathroom anchors. Registers move 0.65 metres toward their stack and down to
2.60 metres above the floor. This clears the globes and ceiling trim while
retaining normal standing headroom. The corrected third run passes all 23
sound-position, geographic-assignment and real plenum-collision checks, standing
capsule queries, four guarded E interactions and actual curb stops. The sealed
2D and 3C apartment barriers remain locked and solid. Captures cover four
bathrooms and all four roof machines; a revised interior camera stance replaces
one view that fell outside the east wall.

That interior view exposed an east riser crossing glazing. A new physics query
over every declared window also caught the west riser at 4B. The west and east
runs move into solid fabric, and the southwest run clears the upper bathroom
windows. The final test checks all 72 window apertures against actual duct
collision; existing glazing and walls are not removed to pass it.
The vent6 run completes all checks without script errors, and its corrected
interior frames were inspected.

The complete roof circuit passes 47 live waypoints, including tank service,
both doors, both stair connections and solid perimeter barriers. The working
home suite passes 144 live waypoints through all six added homes and the staff
restroom, including their production doors and hot/cold-water interactions. The
gate board has zero regressions against the clean 474cd87 baseline; the reader
has zero new unread fields. Twenty-nine reviewed spatial dependencies are
admitted. One obsolete hardcoded staff-register special case is retired from
the manifest, replaced by explicit preserved data references for all 23
registers. Existing classifications and historical evidence are unchanged.

These checks do not promote runtime-contract or acceptance status. The
ventilation installation suite uses initial placements for isolated inspection
and collision checks; the separate roof and home suites exercise travel.
The owner's four render files remain outside this change.

## Remaining limitations

The ducts model architectural connections, not pressure, smoke transport or a
new maintenance simulation. Lift ropes and counterweight motion remain absent.
The first Mina campaign slice remains the supported story loop. Fuse and tank
repairs keep local instance state. Primary voxel lighting remains beam-local,
not whole-building indirect illumination. Existing H23 seams and historical
M11C1 receipt-hash debt are not claimed fixed by this work.

No owner decision is required for this installation.
