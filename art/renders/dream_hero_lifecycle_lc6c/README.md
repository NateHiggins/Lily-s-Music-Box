# LC-6C — the modelled hero lives, exchanges and leaves a sheath

Captured 2026-08-25 in Forward+ on the RTX 4080 from the production
`orison_root.tscn`. The subject is the production modelled hero in the real 2A
encroachment, lit by the player's production lamp. The harness relocates that
same owner to a ray-cleared wall for a fixed readable camera; it adds no body,
material, light, collision, draw owner or save fact.

## What this proves

The hero consumes the shared eight-stage vocabulary through encounter states
it already owned. Bulge is folded reserve; emergence is bud; orientation is
juvenile calibration; seeking is mature work; touch, caress, taste and margin
contact are exchange; withdrawal/flinch is senescence; cross-section loss is
shed; absence is stain. This classification introduces no second clock and
does not alter the approved encounter timing, safety tells, `grow` law or
cross-sectional withdrawal. Every life stage keeps anatomy scale 1.0.

The existing skin's flesh and mineral network carry the visible chemistry:
sealed wine reserve, red perfusion, uneven carmine/lilac calibration, settled
adult gold, cold electrochemical exchange, bruised mineral senescence and a
drained terminal section. These are surface changes on the authored complete
anatomy, never scale-from-zero growth.

A successful addressed secretion to another morph is the only condition that
selects pansexual recruitment here. Without that real exchange, a later return
remains honestly quiescent rather than being called a birth. A permitted
post-exchange return retains the hero's function and advances one generation.
The hero owns those semantics; no breeding director was added.

On complete cross-sectional loss, the existing bounded 24-patch residue owner
records one elongated, non-breathing empty sheath. Repeated deaths at the same
root coalesce. The sheath survives later work during the current encroachment
visit, but clears with that owner and never enters `RealityState` or a save.

## Production frames

`contact_sheet.png` reads left-to-right, top-to-bottom: mature control A,
folded, bud, juvenile, mature, exchange, senescent, shed, sheath control A and
the same sheath after later owner work.

- `00_mature_control_a.png`, `00_mature_control_b.png` — live A/A floor.
- `01_folded_reserve.png` — sealed wine tissue and quiet mineral channels.
- `02_bud_perfused.png` — red perfusion through complete anatomy.
- `03_juvenile_calibrating.png` — uneven carmine/lilac pressure territories.
- `04_mature_seeking.png` — settled adult gold.
- `05_exchange_band.png` — cold electrochemical/secretion response.
- `06_senescent_mineral_bloom.png` — bruised violet mineralization.
- `07_shed_cross_section.png` — drained terminal section.
- `08_sheath_control_a.png`, `08_sheath_control_b.png` — live sheath A/A.
- `09_sheath_after_time.png` — the same visit-local sheath after more work.

## A/A pricing

ImageMagick RMSE was measured in the fixed central body ROI
`500x150+500+270`. The mature A/A floor is **0.0242785**. Every adjacent
living-stage change clears it:

| Transition | RMSE | Multiple of A/A |
| --- | ---: | ---: |
| folded → bud | 0.116510 | 4.80× |
| bud → juvenile | 0.0843995 | 3.48× |
| juvenile → mature | 0.140047 | 5.77× |
| mature → exchange | 0.145671 | 6.00× |
| exchange → senescent | 0.0970861 | 4.00× |
| senescent → shed | 0.0428472 | 1.76× |

The sheath ROI is `500x700+360+10`. Its A/A is **0.00365755** and the later
frame differs by **0.00397055**—the production room continues to shimmer, so
pixel identity is not claimed. Persistence is the unchanged visible sheath in
both frames plus the executable record assertion, not a noisy pixel equality.

## Executable proof

- `DreamHeroLifecycleTest.tscn`: **10/10 PASS** — all stages, stage wire,
  anatomy scale, reproduction choice, death-before-successor, coalescing,
  persistence, same-function generation and ownership invariants.
- `DreamHeroLifecycleLiveTest.tscn`: **7/7 PASS** — full production root owns
  the hero/residue route, pansexual exchange and visit-local sheath without a
  new node/surface owner or waking/save mutation.
- `DreamHeroRestTest.tscn`: **5/5 PASS** — authored-cage/rest-space anatomy is
  unchanged.
- `DreamEcologyTest.tscn`: **61/61 PASS** — shared signal/attention ecology
  remains intact and reports the hero's mature lifecycle census in production.
- `ShaderParseCheck.tscn`: **PASS**.

All Godot runs used `tools/run_godot_serial.ps1`; no second instance was
started. Production-root capture still emits the pre-existing procedural-probe
`!is_inside_tree()` warning and renderer light-unpair shutdown noise after the
frames are written; neither is introduced or hidden by this proof.

## SHA-256

```text
d21c7ff0a6a99a7890479646d579247de11ad5567f4030213a7b79584bb09b60  00_mature_control_a.png
7c8f3b0f3d89454f5b339274da384e226027c1bec9581cddb9e059cb8355655b  00_mature_control_b.png
445ea39ad6e9799592a664477417ce38b215f1844fe85be35a8c6cd2139c18e7  01_folded_reserve.png
38fd72ff0be7d6ae8a881445f70047b7402d5ddacac77d8d19e98c3f851783a0  02_bud_perfused.png
322aaeeed9ec7ce5f418d2553b979912d3fb46fcac1e371d684389f1d37ee3eb  03_juvenile_calibrating.png
429b595b822451973df73d30e15a614843ee1cdecd8e37eb255dfd62157068e8  04_mature_seeking.png
f8357c0c6e03fca6e9f86771a5b48185c2b684c6628d68062b1c44179f2baa77  05_exchange_band.png
924eb39caa0593962e08370cf8d541b1a9a4b70ee59b6a60fad4be3699232e76  06_senescent_mineral_bloom.png
d54250f98d6aa8d9c39b9e1fab6d9a03ae45585bb4efff0bce3a8ede18f1eca6  07_shed_cross_section.png
53532f781e1d1cd1c7025ea0085e583a6af7ddf218ab796ccf4e5af94cff76d5  08_sheath_control_a.png
707d91f47c2d4b10a3529d304aa1f9dc573d124d6e3591468a51743df3cd7832  08_sheath_control_b.png
3957ef36d4c2d4ea1a84f62fb7e7d7b7a833428f6476afa0bc26480a9e34277d  09_sheath_after_time.png
6f682feefc7bcd02b504139484713fde3a5ad89e69dce614e333ac4be2b642d3  contact_sheet.png
```
