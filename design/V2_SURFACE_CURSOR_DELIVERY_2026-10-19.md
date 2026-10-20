# V2 surface inventory and cursor delivery — 2026-10-19

Evidence class: **INERT**. Technical inventory and harness diagnostics;
not a passing whole-world contract or human acceptance.

REPORT - V2-SURFACE-CURSOR - 2026-10-19

Branch / HEAD / origin/main / merge-base: **codex/v2-fire-fitting-checkpoint**;
preceding checkpoint **a06f3305**; origin/main and merge-base **82887a14**.
Worktree cleanliness and final commit identity are recorded by the checkpoint
command. The canonical main checkout retains inherited uncommitted work.

The new completed **652-second** world run contains **26,844 draws**, **17,517
meshes**, **6,389 materials** and **500 textures**. Independent evaluation now
reports **zero unresolved UV/PBR/mipmap surfaces**, resolving the prior 255
surface findings. This is technical inventory evidence, not acceptance.
The complete failed runtime contract, inventory, findings and original logs
remain in **art/reviews/v2_surface_cursor_20261019**.

Overall qualification failed six assertions: four nozzle operations after
cursor delivery failed, and two collision checks on the restored cabinet
leaf. The first inspection opened, but the viewport cursor stayed at its
center after a requested move. That run did not record window focus or mouse
mode at failure, so its precise native-window cause is not established.
No assertion has been waived or reclassified as a passing contract.

The fixture now waits for a rendered frame before requesting cursor movement,
checks its own window focus and requests the foreground when necessary. It
reissues a bounded move until the real viewport position acknowledges it.
Failure diagnostics include focus, mouse mode and viewport bounds. Neither
player state nor the interaction ray is replaced. The existing eight-attempt
bound remains. These APIs are described in the official
[Godot DisplayServer reference](https://docs.godotengine.org/en/latest/classes/class_displayserver.html#class-displayserver-method-warp-mouse).
The complete isolated nozzle, folds, rack and shared-hand run passes after
the change. Confirmation in the composed world is still required, including
the two failed leaf collision assertions.

Protected 17/17: no protected path changes; the V2 default and explicit V1
rollback remain. Ledger before -> after: **7 / 8 / 110 / 42 / 134 / 136**
-> **7 / 8 / 110 / 42 / 134 / 136**; requirements_changed: []. The five
affected static gates retain their previous results with zero regressions;
reader NEW is zero. The prior full 95-gate comparison and unchanged tool
verification are reused. Global surface qualification remains stale.

Changes outside the expected boundary, and why: none in production code.
A read-only geometry triage records visible primitive stock from the earlier
inventory. Apartment chain guards and number plates, plus the historical
handheld chassis, need closer native review. The current chain guard has
both plates on the swinging leaf and four solid cylinders standing in for
links; native link/aperture geometry, proper support and direct manipulation
remain work. Stove counts include grease films and flame effects, so they
are not evidence that native stove models require replacement. No geometry
was changed or accepted by this triage. Hose refinement remains parked.

Open findings not fixed: the new readiness checks need composed confirmation;
all six original failed assertions remain recorded. The passing map audit
does not replace whole-world qualification or rendered human acceptance.
Current-main integration, further geometry/appearance work, acoustic/V1
replacement and completion requirements remain open. Decision needed from
owner: none for this authorized verification and reversible harness change.

BLOCKED current-main merge qualification pending a passing world renewal.
