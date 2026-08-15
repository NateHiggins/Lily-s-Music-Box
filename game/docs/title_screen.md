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
record. The returned reconstruction opens the title. When either complete
stream ends, the other starts from zero. `HEAR THE 1928 ORIGINAL` and `RETURN
IT TOO FAST` provide the same transition on demand. Per-track trims compensate
for their measured 1.53 LU loudness difference without changing the masters.

The two visual faces are also existing production art, not newly invented
canon. Escapement Failure uses `orison_stairwell_title_v2.png` with the quiet
clockwork diagram; the original uses `orison_original_advert_lobby_v1.png`.
The menu title is the actual project title, *Please Remain On The Line*.

`TitleScreenTest.tscn` proves full durations, loop flags, opening selection,
visual selection and alternation. `TitleScreenAudioTest.tscn` proves actual
playback and the finished-signal handoff. The two production renders live in
`art/renders/title_clockwork_theme/`.
