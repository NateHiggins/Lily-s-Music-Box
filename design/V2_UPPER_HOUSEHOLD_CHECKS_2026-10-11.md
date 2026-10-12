# V2 upper household composition checks

Evidence class: **INERT**. Section 7 implementation report; no ledger promotion.

Starting main / origin: **78dffbf5**. Clean verification baseline:
**b73a8753615bcbdf4477f1a01ab989f1c08207bb**. No gate or production asset edits.

## Change and reason

The six upper households already contain native Blender furniture and cabinets.
Their old suites assumed every draw had a material_override and that a desk
retained exactly three primitive boxes. Actual mesh surface bindings and native
triangle collision replaced those representations. The furniture diagnostic
completed with **1,125 checks / 488 failures**: 486 override-only assertions and
two primitive-count assertions. Kitchen diagnostics completed with **1,189
checks / 206 failures**: 200 override-only assertions and six clearance failures.

The revised suites inspect each actual active surface material and require the
albedo/normal/roughness triplet on standard finishes. The exhaustive existing
composed surface review remains the UV, shader, loaded-mip and filtering proof.
The desk checks now raycast its bearing top at the source height and both end
supports, and require open central leg space. Household identity, wardrobe
operation, preparation-panel movement, sink-valve reach, saved-state isolation,
animated collider alignment and retirement checks remain.

The kitchen suite now takes capsule radius and standing height from the actual
PlayerController constants (**0.33 m / 1.524 m**) rather than a separate 0.38 m
review capsule. It still queries every one of the **166** upper approaches in
each reconstruction cycle. The wider capsule overlaps the bed at
**5C_w0_wardrobe_STANCE**, the bed at **6B_abed_STANCE**, and the chair at
**F06_A_STUDY_SWITCH_STANCE**. These remain recorded extra-clearance concerns;
the changed test measures actual player clearance, not a promised extra margin.
Failure diagnostics identify the actual collider and report nearby clear
candidates, without moving any production actor or marker.

## Verification

Final kitchen run: **1,841 checks / zero failures / zero script errors**,
121 seconds, both reconstruction cycles. Both successful wrapper receipts
bind the exact current root-test bytes. Fresh candidate verification pending.
The completed furniture run has **1,867 checks / zero failures / zero script
errors**, including both full-world reconstruction cycles. The revised-material
kitchen run with the old wider capsule has **1,841 checks / six failures / zero
script errors**; all six are the three repeated extra-clearance concerns above.
A serial attempt reached its default 60-second ceiling and has no verdict;
subsequent runs use the long runner with an explicit 1,500-second ceiling.

Packet: **art/renders/orison_v2/upper_household_checks_20261011**. Successful
logs are suite-run checks, not schema-2 runtime-contract acceptance. Existing
unchanged render/surface evidence is reused; no new appearance claim is made.

## Remaining scope and decision

Upper private entry/distribution routes and storage access still need their own
physical and privacy proof. No lexical program rename or ledger relaxation is
made. Full V2 remains unfinished; prior **0/1/127/35/144/146** scope blockers
remain open. Owner decision required: none. No resident, authority, production
material, collider, geometry, save contract or protected path is changed.
