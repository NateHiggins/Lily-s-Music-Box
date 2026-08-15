# Title screen — Clockwork Waltz provisional theme

Owner ruling, 2026-08-15: **Clockwork Waltz is the theme music for now.** This
is a provisional production choice, not permanent score canon.

The title presents two complete, separately selectable records:

| Face | Shipped stream | Source master | Duration | SHA-256 |
|---|---|---|---:|---|
| Returned | `clockwork_waltz_escapement_failure.ogg` | `The_Clockwork_Waltz__ESCAPEMENT_FAILURE_x1414.wav` | 112.576875 s | `2A68B3A25070822D58DB6F46FA17AAB2CF6413725F9D7DCB1035AA5F6505CF97` |
| Original | `clockwork_waltz_original.ogg` | `art/audio/The_Clockwork_Waltz.48k.wav` | 158.731625 s | `77DC9AD56B10C82DCBBBE60E6C6403ECFA4E94479A2EA837BCCFA6A23944B1AD` |

Both shipped streams are 48 kHz stereo Ogg Vorbis at FFmpeg quality 8. Nothing
is excerpted, faded into a loop, pitch-corrected or layered over the other
record. The untouched original opens the title. When either complete stream
ends, the other starts from zero. `HEAR THE RETURN` and `PLAY THE ORIGINAL
MASTER` provide the same transition on demand. Per-track trims compensate for
their measured 1.53 LU loudness difference without changing the masters.

Owner correction, 2026-08-15: **the dream world is the reveal.** The title
therefore uses one record-independent waking-world hero,
`orison_grand_mundane_title_v1.png`. It makes the approved three-zone scope
grand through things the player can already encounter: the seven-storey
Orison, driving rain and roadway, a historical transit-style kiosk, the lit
Vantry Arcade, an off-hook telephone, a work order, a toolbox and a maintenance
worker crossing between them. It contains no dream geography, Tenant,
impossible architecture, supernatural figure or preview of dream play. The
fantasy is entirely composition, scale, weather and light applied to mundane
work. Selecting a record never changes the image. The menu title is the actual
project title, *Please Remain On The Line*.

`TitleScreenTest.tscn` proves full durations, loop flags, opening selection,
single-hero invariance and alternation. `TitleScreenAudioTest.tscn` proves
actual playback and the finished-signal handoff. Production renders live in
`art/renders/title_clockwork_theme/`; the superseded first redesign remains
there as decision history.
