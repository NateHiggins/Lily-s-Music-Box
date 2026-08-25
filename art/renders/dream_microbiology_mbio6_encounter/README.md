# MBIO-6 — one production cellular encounter

All frames come from one Forward+ `orison_root.tscn` process. The three duplicate-control pairs price local noise after each camera setup. The production-born cilium, existing margin renderer, signal bed, LivingField and modelled hero are retained; anatomy is staged at readable authored maxima. No proof mesh, material, light, collision, biology owner, case fact or save seam is added.

The companion `DreamMicrobiologyEncounterTest` proves 12/12 that the real player path is dark → slow scan → photoshock → adaptation → collision-resolved footfall → finite cilium answer → LivingField uptake → later hero vesicle. This sheet proves those already-causal states remain legible in one production session. It does not claim combat or a completed waking case loop.

## Read order

1. `00_dark_control_a/b` price the dark receptor setup.
2. `01_slow_scan` shows the cilia extending under gradual light.
3. `02_photoshock` shows the same complete anatomy folding under an abrupt lamp exposure.
4. `03_adapted` shows recovery under sustained exposure.
5. `04_reply_control_a/b` price the adapted receptor setup; `05_cilia_architecture_reply` shows the finite mechanical answer after it has reached the cilium and entered the LivingField.
6. `06_vesicle_control_a/b` price the modelled hero setup; `07_later_vesicle` shows the later secretion consequence.

The controls are deliberately local rather than one global pair: the camera changes only before the hero sequence, while live Forward+ architecture and irradiance can otherwise create a misleading noise floor.

## A/A pricing

Mean absolute RGB difference was measured in normalized linear file values over a receptor ROI `(520, 180)–(1080, 640)` and a hero ROI `(170, 20)–(1160, 470)`:

| Comparison | ROI MAE | Multiple of local A/A |
|---|---:|---:|
| dark control A/B | 0.000002375 | 1.0× |
| slow scan vs dark B | 0.013900576 | 5,853.2× |
| photoshock vs slow scan | 0.004395892 | 1,851.0× |
| adaptation vs photoshock | 0.004145329 | 1,745.5× |
| reply control A/B | 0.000000000 | byte-identical |
| cilia/architecture reply vs reply control B | 0.005938573 | above a zero floor |
| vesicle control A/B | 0.000021490 | 1.0× |
| later vesicle vs vesicle control B | 0.000341674 | 15.9× |

The lighting jump in `01` is expected and is not used alone to claim receptor motion. The two same-lamp comparisons (`02` against `01`, and `03` against `02`) independently clear the dark A/A floor by more than 1,700×. The reply controls are also the exact bytes of the adapted frame, making `05` a directly priced posture change rather than an unpriced live-animation difference.

## SHA-256

```text
b255686e7e234f6e8c56584f5804487200f4f561f9a8d31198812f2194866c87  00_dark_control_a.png
f0564f027eb6a60ea2077d1de8b1a4e96fcd1c91a3dffc9b6fc024d4e3fc0b61  00_dark_control_b.png
6864a57773110a0fcf2996418fff5106855fbcde0d08197ba4bd836672b88959  01_slow_scan.png
dddf3d6bcd137b423874283f71423aa1c7f9a730401cbffaea58f7c0330b9616  02_photoshock.png
45e225cb6a5c435beb0e8e5d1af198af246e9cb1316d328f5cdb777d139b17f0  03_adapted.png
45e225cb6a5c435beb0e8e5d1af198af246e9cb1316d328f5cdb777d139b17f0  04_reply_control_a.png
45e225cb6a5c435beb0e8e5d1af198af246e9cb1316d328f5cdb777d139b17f0  04_reply_control_b.png
23722e26805d7270d35ccb7c8518fc7ab7a73ff530e892069f17c3787d5029e3  05_cilia_architecture_reply.png
649ea0661f49b91c69c6c22faed62a9e1307a71e78540c5edef038c84dd5f629  06_vesicle_control_a.png
c6b2a03026577e80a547a820e1f3449bd201497b2001ed2a75a021c62baadb15  06_vesicle_control_b.png
bd6687ec39ac408ec5d04523d213c2a5f2d9b5ca68353631afc6e6fa901a2783  07_later_vesicle.png
```

The capture completed all eleven 1280×720 frames and exited 0. Godot emitted the existing Forward+ renderer teardown diagnostics, including seven texture RID leak reports, after capture; no clean-stderr claim is made.
