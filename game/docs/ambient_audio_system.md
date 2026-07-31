# Ambient Audio System

`AmbientSoundscape` supplies four continuously crossfaded beds:

- exterior Queens traffic and electrical rumble
- interior plaster, pipe, and mains room tone
- basement boiler pressure
- roof wind

It also places quiet creaks, knocks, and ticks around the player at irregular
intervals. Events are deliberately sparse and the public
`set_paranormal_focus()` control ducks ambience by up to 10 dB, leaving
spectral and dynamic space for viral/paranormal cues.

The current beds are procedural, deterministic, loop-clean, and carry no
third-party license obligation. Replacement recordings can be assigned to
the four bed players without changing the zone or mixing logic.

## Recommended free recording sources

1. **Kenney audio** — CC0; simplest license chain. Best for UI, doors and
   generic game effects.
2. **Freesound** — use only sounds explicitly marked CC0 or CC-BY. Record
   creator, sound URL, filename, license, and modification in an asset
   manifest. Do not use CC-BY-NC in a potentially commercial game.
3. **Sonniss GameAudioGDC bundles** — their bundle license permits personal
   and commercial game synchronization and modification without attribution.
   Best source for high-quality room tones, buildings, pipes, elevators,
   traffic, wind and structural creaks.
4. **Pixabay audio** — usable under the Pixabay Content License, but keep
   the downloaded license record and never redistribute files as standalone
   stock assets.

Suggested search terms: `apartment room tone`, `old building ambience`,
`steam radiator`, `boiler room`, `elevator machinery`, `Queens traffic
night`, `roof wind urban`, `wood stair creak`, `pipe water hammer`.

Before import, trim seamless beds to 30–90 seconds, remove DC offset, apply
short equal-power loop crossfades, convert to 48 kHz OGG, and preserve
one-shots as WAV where transient accuracy matters.
