# DO-4 — production-root organelle conversation

Approved production proof, 2026-08-24. These eleven fixed-camera Forward+
frames come from the real `orison_root.tscn` and the owners assembled by
`ApartmentEncroachment`: modelled hero, margin palps and cilia, fauna,
`LivingField` architecture and `DreamEcologyDirector`. The encounter is
arranged deterministically; no stand-in owner interprets a packet.

## Read the sequence

| Frame | Production fact |
|---|---|
| `00_control_A.png`, `00_control_A_repeat.png` | Same frozen state twice; prices the remaining live-render noise. |
| `01_hero_secretes.png` | Hero contact leaves residue and one `SECRETE / SECRETION` packet. |
| `02_palp_adopts.png` | One idle palp locally reaches toward the packet. |
| `03_contact_recognized.png` | Contact crossing emits one `RECOGNIZE / ELECTRIC` packet. |
| `04_fauna_presents_receptors.png` | High-social fauna presents receptors; the low-social control remains folded. |
| `05_neighbours_answer.png` | Delayed local conduction turns two neighbouring palps without global attention. |
| `06_cilia_close.png` | Deployed cilia close across the recognized site during their 0.48 s sample. |
| `07_cilia_reopen.png` | Cilia reopen after one `PULSE / VASCULAR` answer; production architecture receives it once and pressurizes 14 existing cells. |
| `08_attention_snap.png` | A real `player.world_modified` event passes the 22 s gate and seizes 11/12 visible recipients together. It emits no packet. |
| `09_autonomy_returns.png` | Release is already asynchronous: 2 recipients have let go while 10 still attend. |

The captured census at frame 07 is `emitted=3`,
`by_function={secrete:1, recognize:1, pulse:1}`,
`architecture.received=1`, `cells_pressurized=14`. At frames 08 and 09
`emitted` remains 3, proving that rare whole-body attention is regulation
beside the local packet conversation, not another packet producer.

## A/A and visual threshold

ImageMagick whole-frame normalized RMSE:

| Pair | RMSE |
|---|---:|
| control A → control repeat | 0.00710458 |
| secretion → palp adoption | 0.0155445 |
| fauna → neighbour answer | 0.0347715 |
| neighbour answer → cilia close | 0.0179940 |
| cilia close → reopen / architecture receipt | 0.0168343 |
| architecture receipt → whole-body snap | 0.0457886 |
| whole-body snap → partial release | 0.0322710 |

The fauna presentation and recognition flash individually sit below the
whole-frame A/A floor; their causal facts are therefore claimed from the
production-owner census and the 61/61 executable contract, not from a noisy
pixel delta. The palp, delayed-neighbour, cilia, attention and release beats
all clear the measured floor in this composition.

## Executable contract

`DreamEcologyTest.tscn` passes **61/61** against the same production root. In
addition to packet ordering and recipient differences it proves:

- `player.world_modified`, not a direct director call, triggers attention;
- attention adds no packet;
- no waking case record or persistence setting changes;
- every collision body, layer, mask and shape-disabled state is byte-stable;
- no maze, pursuer or hazard owner appears;
- the architecture consumes the addressed packet once;
- the signal bed stays bounded at 32 slots.

The production sequence exposed and fixed one live-topology defect:
acceptance-arranged primary palps lacked the default `spread` field read
during attention release. The shared default is now `0.0`; the clean
recapture has no GDScript error from the exchange.

## Reproduction

```powershell
$env:SWEEP_MODE='organelle'
$env:SWEEP_DIR='C:\PleaseRemainOnTheLine\art\renders\dream_organelle_production'
$env:SWEEP_WARM='10'
.\Godot_v4.7.1-stable_win64_console.exe --path game --resolution 1280x720 res://tests/DreamHeroSweep.tscn

.\Godot_v4.7.1-stable_win64_console.exe --headless --path game res://tests/DreamEcologyTest.tscn
```

The loaded production building still reports its pre-existing tentacle
pre-tree transform warning and renderer teardown RID/indexing diagnostics.
Those occur outside the DO-4 exchange; the targeted sequence completes and
the headless contract exits 0. This closes the shared downstream organelle
proof. It does **not** create or complete a waking case loop, and it does not
make flora, incarnations, pursuers or hazards runtime recipients yet.
