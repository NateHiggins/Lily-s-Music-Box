# Tentacle gang review

The focused runtime contract passes **1,248 checks**. Its process wrapper reports
zero script/shader/startup errors. This is an isolated native-radiator fixture;
it is not full campaign or whole-building surface acceptance.

The installed V2 radiator test passes **18 checks**, including actual grab,
motion and release, and valve operation/restoration before, during and after the
encounter. Its wrapper has zero script errors but reports **seven texture RIDs
leaked at whole-world shutdown**, which remains unresolved.

- [Installed encounter](installed/installed_encounter.png), [restored working area](installed/installed_clean.png)
- [Installed runtime contract](installed/runtime_contract.json), [process receipt](installed_run.log.receipt.json)

- [Front-lit gang](focused/02_front.png)
- [Side light](focused/02b_side.png), [backlight](focused/02c_back.png)
- [Stable](focused/02d_stable.png), [unstable](focused/02e_unstable.png)
- [Occluder](focused/02f_occluder.png), [lamp off](focused/03_lamp_off.png)
- [Contact and anchor overlay](focused/02a_contact_and_anchor_clearance.png)
- [Contact](focused/04_contact.png), [alarm](focused/04b_alarm.png)
- [Mid-retreat](focused/05_retreat.png), [root withdrawal](focused/06_root_withdrawal.png)
- [Haze](focused/07_haze.png), [hidden-volume control](focused/07b_hidden_haze_control.png)
- [Late haze](focused/08_haze_late.png), [clean area](focused/09_clean.png)
- [Blender exterior](anatomy_review.png), [modeled interior](anatomy_internal_review.png)
- [Test-written runtime contract](focused/runtime_contract.json)
- [Process receipt](focused_run.log.receipt.json), [source snapshot manifest](source_manifest.json)
- [UV/triangle audit](asset_audit.json)

The runtime contract includes measured optical-region luminance, phase timing,
contact diagnostics and resource-release assertions. All optical comparisons use
the same camera pose. The native filament's cooling is preserved; the shared
instantaneous field is also checked independently at switch-off. Timing is
frame-capped and includes a first-use hitch, so it is not a marginal GPU benchmark.

The source manifest records the executed focused and installed test sources.
See the repository implementation report and [static board](static_board.md)
for gate findings and remaining acceptance limits.
