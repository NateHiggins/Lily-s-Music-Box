# LC-6A — production margin lifecycle

These frames instantiate `orison_root.tscn`, wait for its production `ApartmentEncroachment` to grow a palp on real building geometry, then photograph that named palp through `DreamPalpRenderer`, `dream_palp.gdshader`, and the player's service lamp. No proof mesh or proof light replaces a production owner.

`00_control_a.png` and `00_control_b.png` are identical mature state, camera, lamp, owner data and pinned palp shader clock. Engine time is held after the live root and lamp settle so unrelated animated building surfaces do not become the comparison. The controls price residual render noise before any stage comparison. Frames 01–08 hold the same individual at the midpoint of each shared lifecycle stage, from one fixed oblique stand with one fixed lamp transform.

What this proves: the margin owner uses the shared eight-stage language; folded and shed are architectural-surface postures of complete anatomy; mature and exchange reach into playable space; senescence droops and returns toward the surface; no stage scales the organ from zero. The packed stage also changes perfusion, wetness and bruising in the production shader, but this sheet does not try to separate those material deltas from the larger posture change.

What this does **not** prove: a persistent post-removal margin stain. Frame 08 is the spent attached imprint immediately before owner removal. Persistent architectural memory remains the next LC-6 owner slice.

## Frames

- 00_control_a.png — mature A/A control.
- 00_control_b.png — unchanged mature A/A control.
- 01_folded.png — folded at anatomy scale 1.0; reach 0.597 m.
- 02_bud.png — bud at anatomy scale 1.0; reach 0.536 m.
- 03_juvenile.png — juvenile at anatomy scale 1.0; reach 0.643 m.
- 04_mature.png — mature at anatomy scale 1.0; reach 0.820 m.
- 05_exchange.png — exchange at anatomy scale 1.0; reach 0.879 m.
- 06_senescent.png — senescent at anatomy scale 1.0; reach 0.607 m.
- 07_shed.png — shed at anatomy scale 1.0; reach 0.561 m.
- 08_stain.png — stain at anatomy scale 1.0; reach 0.594 m.

## A/A ruling

Measured over the fixed subject ROI `(350,150)–(900,600)`, RGB RMSE normalized to 0–1:

- control A → control B: **0.000112**
- control B → folded: 0.024010 (**214.31×** A/A)
- folded → bud: 0.011287 (**100.75×**)
- bud → juvenile: 0.023074 (**205.96×**)
- juvenile → mature: 0.025421 (**226.91×**)
- mature → exchange: 0.017744 (**158.38×**)
- exchange → senescent: 0.023405 (**208.91×**)
- senescent → shed: 0.022207 (**198.21×**)
- shed → attached stain: 0.006811 (**60.80×**)

Every adjacent transition clears the equal-state noise floor. This prices visible change; the 44/44 focused contract separately proves that every frame retains anatomy scale 1.0 and substantial authored reach.

## SHA-256

```text
00_control_a.png A3CA12F058B29469DDFBFD2D4C95BFE1B14B83974356097147980EE96BACD568
00_control_b.png 21F665CCBFB3DBF26EB489F4CA47EDE917EF23A6B75F4BFDAFB20D462021D821
01_folded.png    1C56391BE4B67DD4918B3FAD810255F0BDA1908D66338AF11A0E4652CE177E7E
02_bud.png       7E461A6E068264DAACF962810C4CB5EC09D8618DD057BA636A28FAFA4AE53022
03_juvenile.png  B8221C3FD2B439C635BF9B96BAF30587C6820D99AB1CEA8DF1C2B68CD19BB71F
04_mature.png    89DE9B16962683FE5E822CF20F036B68CDB4AA04772D451B2AFDD75870E25EE7
05_exchange.png  FA423762F2BCA5477A9857C859C367A6E32016B4017339F92A65F6742CE1F6B1
06_senescent.png 9799616DC06FE45A120C387714D5CC35E8584E4750920BF6CE893A5EEE719914
07_shed.png      CA6EC9B48AAC88768CB75164B79B3B2954EA2C3643DE36A75F3D49F3A43CE05C
08_stain.png     1E054E3BBB4E69A39D83494A992157E89793B7A5DAA06BE4C86AAC8FA1C1209D
```
