# Playtest findings

No human playthrough or perceptual acceptance was conducted during sanitation. Static and headless tests below do not replace playing.

- BASE-IMPORT: clean-base headless import exited 0. Unicode parsing diagnostics remain in evidence/base_import/godot.log.stderr; attribution pending. Import is not gameplay boot.
- BASE-M08F: fresh task-local profile exposed failure of save/destroy/CampaignShell reconstruction. The test writes user://tests/m08f_runtime.json without creating its parent. The controlled comparison in evidence/base_runtime preserves exit 1 on a fresh profile and exit 0 after another test creates the folder. Both retain four objects/two audio resources.
- Production presentation, real camera/motion, route comprehension, tactile interaction, audio location and input-only routes remain NOT_OBSERVED by this pass.

Next player-visible proof: boot the clean composed baseline, traverse the accepted opening/exterior scope with actual PlayerController, and observe/save/reconstruct the open-shift route. Record surprises, obstructions, dead interactions, warnings and performance in context rather than extrapolating from fixture totals.

- BASE-ROOTS: the actual two-root/CampaignShell matrix passed 24 checks (exit 0; 77.012 s whole process, headless). This is reconstruction evidence, not frame-performance or visual proof.
- BASE-RETENTION: verbose M08F identifies appliance_pop.ogg/OggPacketSequence and playback objects still alive at exit. Owner attribution is under focused investigation.
- BASE-ART: five v1 compositions could not place cam_noel_witches on a legal wall; authored art was omitted. Keep as a v1 control finding; new room-production effort remains V2.
