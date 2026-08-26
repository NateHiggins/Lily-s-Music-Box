# Period reality layer

The Orison should sell 1928 and Queens through corroborating background facts,
not a museum label. The preferred detail is small, mechanically specific,
occasionally noticed, and cheap enough to survive every production scene.

## The rule

Add a detail when it answers at least two of these questions:

1. **Where are we?** Queens rather than generic New York.
2. **When are we?** 1928 rather than an undifferentiated vintage aesthetic.
3. **What is the weather doing?** Wind, rain, visibility or temperature becomes
   visible or audible.
4. **Who lives here?** Ordinary labor and domestic routines leave a residue.

A detail must not create case evidence, persistence, collision, navigation, a
new light owner, or a gameplay obligation merely because it exists.

## Cost ladder

Prefer, in order:

1. Existing material parameter or deterministic text on a shared substrate.
2. Rare positional mono sound with no visible source.
3. One MultiMesh or one combined ArrayMesh, shadowless and collisionless.
4. One vertex-animated mesh responding to an existing weather uniform.
5. A stateful prop only when the player can physically alter it.

Reject a background detail that needs AI, physics, per-frame raycasts, a unique
4K texture, or a realtime light unless its silhouette cannot work without it.

## Source discipline

Record one primary or institutional source beside every historical claim.
Separate three things in comments and reports:

- **documented:** the object, route, date or practice existed;
- **inferred:** it could plausibly be seen or heard from this block;
- **authored:** this particular flight, advertisement, tenant or failure occurs.

Never turn a famous object into routine scenery merely because it is famous.
The Spirit of St. Louis did not circle Queens nightly. A Pitcairn-type contract
mail plane is appropriate because CAM 19 began New York–Atlanta service on
1 May 1928; the individual crossing remains authored.

## Runtime owners

`PeriodRealityLayer` owns noninteractive distant life. It currently provides:

- a single-draw, collisionless, shadowless fabric biplane silhouette;
- an original procedural nine-cylinder/propeller mono loop;
- an original procedural distant Lo-V traction, rail-joint and brake event.

Neither event publishes a signal or writes state. Test hooks may start them,
but production schedules them sparsely with a deterministic seed.

Weather-reactive details should consume the resolved live-weather snapshot:

- wind direction/speed: smoke lean, laundry phase, aerial sway;
- low/mid/high cloud: aircraft contrast and beacon attenuation;
- precipitation: sound filtering, wetness and event scarcity;
- visibility: distant geometry fade, never gameplay reach.

The first set now follows that contract. `BuildingRoot` constructs the period
layer before the live-weather service can publish, then hands it the same
normalized snapshot used by sky and precipitation. Observed wind displaces the
middle of the mailwing track while preserving both horizon endpoints. Low cloud,
fog and precipitation reduce silhouette contrast; a closed ceiling suppresses
an unseeable flyby rather than staging it behind the cloud. The existing
aircraft and rail players lower their distance-filter cutoff in wet/low-cloud
conditions. No weather fact alters the deterministic schedule, publishes a
signal, or enters persistence.

## Shared ephemera atlas

`orison_1928_ephemera_substrates_v1.png` contains sixteen blank paper, enamel
and painted substrates. Generated imagery supplies material wear only. All
words, numerals and logos must be deterministic engine text or authored vector
art so historical spelling remains exact and localization remains possible.

Good atlas uses include coal/ice cards, airmail notices, apartment vacancies,
telephone service instructions, inspection slips and rain-softened newspaper
fragments. Do not fabricate a real company endorsement or headline.

## Placement checklist

- Can it be seen or heard from a production player position?
- Does weather or occlusion attenuate it naturally?
- Does it repeat rarely enough to remain environmental rather than theatrical?
- Does it have one declared owner and one budget assertion?
- Does an A/A capture prove the idle state costs and changes nothing?
- Does abort/reload manufacture no historical event?
- Does the detail remain optional and non-evidentiary?

## Sources for the first set

- NYC environmental documentation: Flushing Airport opened in 1927.
- Smithsonian National Postal Museum: Pitcairn CAM 19 began New York–Atlanta
  night-mail service on 1 May 1928.
- New York Transit Museum: Lo-V cars built 1916–1925 served Queens with special
  gearing for the Steinway Tunnel grade.
- National Archives: broadcast radio had become a defining domestic medium in
  the 1920s.

Future additions should extend this document's source table and cost contract,
not create an unrelated ambience subsystem.
