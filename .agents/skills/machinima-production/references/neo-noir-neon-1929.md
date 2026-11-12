# Neo-Noir Neon 1929 in production

Authority: Lily's 2026-11-12 supplied rulebook, adopted in
[ORISON_BIBLE.md](../../../../design/ORISON_BIBLE.md), §VIII.5 (RUL-017).
This guide implements that style; the Bible wins any disagreement. It combines
Expressionist geometry, noir shadows and fatalism, saturated neon colour and
1929 production design. Preserve the inhabited, repaired material world.

## Record intent and actual settings

For each shot, record its frame range, musical/dialogue beat, location and date,
foreground/midground/background, subjects and eye lines, camera path, lens
equivalent, focus target, depth-of-field treatment, shutter intent, motivated
key/fill sources, palette, atmospheric source, diffusion, transition and audio
overlap. Record actual engine/post settings separately from photographic intent.
If a feature is unavailable, identify the chosen approximation and review its
output; never invent an engine parameter or label absent motion blur a shutter.

| Choice | Owner target | Implementation and review |
|---|---|---|
| Architectural wides | 18–24 mm full-frame equivalent | Derive the field of view from the declared sensor gate and camera axis. Horizontal FOV is `2*atan(36/(2*f))`; convert for aspect ratio if the engine stores vertical FOV. Perspective comes from camera position. Review edge distortion and building scale. |
| Compressed views | 135–200 mm | Place the camera far enough away; frame through bottles, curtains or other real foreground geometry. Keep the subject readable through occlusion. |
| MCU/ECU focus | T1.4–T2.0 intent | Focus on the intended eye, hand or story detail. Calibrate engine DOF by subject/background separation; T-stop is not a literal blur slider. Avoid translucent-hair fringes and broken silhouette blur. |
| Temporal exposure | 180° dialogue; 45° panic/violence | Exposure time is `angle/(360*fps)`: at 24 fps, 1/48 s or 1/192 s. Use a verified temporal method where available. Disclose a crisp no-blur approximation. No violence is required just to use the rule. |
| Diffusion | 1/4 or 1/2 Black Pro-Mist-like | Bloom/halation around bright practicals, retained black floor and fine facial detail. This describes the look, not a calibrated branded-filter simulation. |
| Contrast | 16:1 key-to-fill, four stops | Establish actual motivated source contributions and exposure; document the measurement/approximation. Lamp-energy numbers alone do not prove the ratio. Keep the shot's subject readable. |
| Palette | Cyan, magenta, deep crimson; expressive absinthe green | Choose a dominant source and controlled counter-colour. Motivate spill from signs/windows/practicals; preserve skin differentiation and material colour. Warm wood need not become a glowing material. |
| Shadow | Hard, geometric | Use actual Deco grates, blinds or fan blades for gobos. Inspect the subject, shadow edge, temporal stability and source direction. |
| Atmosphere | Present in every scene | Use room haze/smoke or exterior air to separate planes and reveal beams. Keep indoor volumes bounded; don't turn all weather into rain or erase distant architecture with a uniform fog wash. |
| Depth staging | Foreground, midground, background | A near blurred glass, sharp person and distant action are an example, not mandatory props. Avoid cast lined flat against a wall. |
| Angles | Motivated Dutch cant 15–30°; expressive high/low | Name the dramatic reason. Ordinary dialogue need not be tilted, and film cants never rewrite the player's camera. |
| Movement | At least 90% controlled screen time | Use locked shots, stable tracks and near-imperceptible pushes. Measure by shot duration, not shot count. Reserve handheld rupture for loss of control. |
| Special moves | Pedestal-down/tilt-up skyline; lateral tracking; climactic dolly zoom | Give each move a beat and a subject. Dolly zoom requires camera translation plus coordinated focal change, not zoom alone. Don't manufacture a plot reversal. |
| Rhythm | Average shot length 6–10 s | Measure the actual edit. Cut on phrase, action or realization; don't pad every shot to the same duration. Declare motivated exceptions. |
| Montage | J/L cuts, graphic/motion matches, rare smash cuts | Bind offsets to the selected audio timeline; preview both sides of cuts with sound. Let juxtaposition imply emotion without inventing narrative facts. |

## Proof before a full film

Review one representative interior and exterior, the hardest close-up, and one
cut between locations before the expensive capture. Use installed sets/cast;
show actual instrument contact if the shot depends on it. Carry consistent key
direction, palette, screen direction and performance across adjacent shots.
The sky, haze and reflections must move coherently; atmospheric noise or blown
neon is not intentional film grain. Inspect shadow stability and dark detail in
the final encoded proof, not only the editor viewport.

Keep movie lighting, render clocks and controlled actor presentation inside an
isolated film fixture with restoration on exit. The canonical style directs
future game lighting work, but a film override does not qualify or silently
install a global lighting/shader change. Preserve readable gameplay, accessibility,
physical surfaces and save/calendar owners. Teaching examples involving weapons,
death or a detective's identity are not game canon or required video content.

Follow the main skill's FIFO, hidden-desktop, bounded-capture and final-decode
workflow. A style checklist records intended and observed choices; it cannot
replace viewing the result or Lily's artistic judgment.
