# 4B alcove room lighting — pending runtime verification

Base f02ef7e. The sleeping alcove now consumes the existing flush-dome fixture
and physical switch through the shared V2 room-lighting owner. Fixture range
is 5 m and energy scale 1.25, initially borrowing the established 3B bedroom
setting. These settings require rendered review; no visual acceptance claimed.

The ceiling anchor is 2.9 m above the F04 floor. The east-wall switch at
(-10.66, 1.12, 9.1) faces into the alcove, beyond the doorway's 8.45 m end.
Existing fixture/switch records are unchanged. Static checks confirm unique
anchors and that every lighting record resolves to an authored anchor.

OrisonV2EarnedDreamBoundaryTest now uses the existing interaction-capable
controller driver after the real earned wake. In addition to the six egress
waypoints it approaches the switch, checks the actual ray/prompt, presses E
twice, checks power changes/restoration and walks back to bed. It also tracks
the fixture and plate through Dream world replacement. This is authored test
coverage, not an executed result. Switch disk persistence remains outside this
change, as with the existing V2 room circuits.

The unchanged serial runner refused before launch while foreign Godot tests
were active. Both the preceding bed integration and this lighting extension
still require parsing, runtime, stderr and image verification.

Next run: OrisonV2EarnedDreamBoundaryTest.tscn via tools/run_godot_serial.ps1,
180-second ceiling, with V2_EARNED_SAVE pointing to
v2_mina_physical_residue_01/earned_regression/earned_dream_pending.json.
Inspect the unmodified earned_wake view as well as the staged bedside_review
and switch captures. Revise any clearance or presentation problems before
claiming the wake room complete. V2 remains unfinished and V1 remains default.
