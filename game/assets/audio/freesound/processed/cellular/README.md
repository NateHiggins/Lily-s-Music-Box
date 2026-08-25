# MBIO-5 cellular sonification palette

Four mono, 48 kHz events made from the repository's licensed recordings. They
are artistic sonification of microscopic work enlarged to room scale, not a
claim that isolated microorganisms produce these airborne sounds.

| Key | Cellular read | Recorded source | Length | Mean / peak | SHA-256 |
| --- | --- | --- | ---: | ---: | --- |
| `cellular_channel` | sparse wet electrical opening | GammaGool water drop | 0.417 s | -24.6 / -11.8 dB | `70c333745d951f941edc74ad0dc0248a7c24c1402568d5e5bccb6f3d3afad67e` |
| `cellular_cilia` | quiet combed membrane friction | gecop door friction | 0.626 s | -31.6 / -16.6 dB | `9f40495f94a8e3d7f80d04c84e2c251c05716349c40c9cf6627c2bab40de5d7a` |
| `cellular_relay` | travelling porous/granular wash | dimapain water-bubble flow | 1.255 s | -28.2 / -8.1 dB | `3ae9af681d2d4d0affc8edb3bd19bab4fd24201012b47ba8cb4111e359ec2208` |
| `cellular_vesicle` | close membrane tack and release | separate GammaGool water drop | 0.636 s | -24.3 / -10.2 dB | `27ffb400f2b8c55a51cef82f5756a58e375ae1935ec99be859650d249a052001` |

All were excerpted, filtered, faded, loudness-shaped and encoded as Vorbis
without overwriting a source. Full source identities and licenses are in the
parent `ATTRIBUTION.md`.

Production mapping is deliberately causal. `ELECTRIC` cellular packets use
channel; a `VASCULAR` packet from cilia uses cilia, other vascular transport
uses relay, and `SECRETION` uses vesicle. A raw `MECHANICAL` packet has no
sound: only the cell's later answer is presented. One
`DreamCellularAudioPool` under the encroachment's existing ecology owner holds
four finite-distance `AudioStreamPlayer3D` voices. A burst steals the
soonest-finishing voice instead of allocating a fifth.

Proof: `DreamCellularAudioTest` passes 9/9 and the production-root
`DreamCellularAudioLiveTest` passes 5/5. The contracts cover the voice ceiling,
inverse-distance setup, positional source placement, deterministic stealing,
unknown-key silence, raw-mechanics silence, no sound-to-signal feedback, no
per-organelle player, no case mutation and no save seam.
