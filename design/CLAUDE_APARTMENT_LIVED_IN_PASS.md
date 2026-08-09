# Claude Brief: Apartment Logic and Lived-In Pass

## Objective

Make every occupied Orison apartment read as a functioning home belonging to
its named resident, without materially increasing draw calls, shadow casters,
navigation obstruction, or the number of fully interactive systems.

Do not redesign the building shell. The current exported layout passes all
placement, furnishing, door-swing, refrigerator-clearance and entry-route
validators. Work through `art/data/gen_layout.py`; regenerate rather than
hand-editing the exported JSON or glTF files.

## Verified baseline

Audited against the current `game/data/building_layout.json`:

- Placement validator: 0 failures.
- Movement validator: 0 failures.
- Furnishing validator: 0 failures.
- 962 furniture assemblies, including 202 live switch plates.
- 101 doorway leaves and 23 radiators.
- Every standard occupied unit has at least one bed, wardrobe, dining surface,
  two chairs, complete kitchen run, stove, refrigerator, toilet, sink, shower
  and radiator.
- Every standard kitchen trio shares a consistent facing.
- The Godot WalkTest passes the apartment/building traversal checks.

The baseline is physically serviceable. The remaining problem is credibility,
specificity and interaction semantics.

## What “functional” currently means

Keep these categories separate when reporting work:

1. **Gameplay-functional:** apartment doors, switch plates, television sets,
   the 4B kettle and toaster, case props and director-controlled anomalies have
   scripts or interaction behavior.
2. **Simulation-functional:** radiators, lights, clocks, audio-network props and
   possessed objects react to directors but may not accept player interaction.
3. **Visually functional:** standard sinks, showers, stoves, refrigerators,
   wardrobes and most furniture have correct recognizable geometry and usable
   clearance, but are static scenery.

Do not claim every appliance is interactive. It is not, and it does not need
to be. Make only objects with a gameplay sentence interactive.

## Apartment-by-apartment audit and intent

| Unit | Resident | Existing layout | Logic verdict | Required pass |
|---|---|---|---|---|
| 1A | Evelyn Marsh | one bedroom | Sound | Add medication organizer, teacher's reading chair wear, carefully corrected shopping lists, tea routine, spare guest cup never used. Keep unusually orderly paths. |
| 1D | Teresa Vale | bedroom plus office | Sound | Office becomes sleep-disrupted night-shift station: blackout curtains, scrubs landing zone, work shoes, thermos, alarm/medication drawer. Add hamper and exhausted half-finished meal. |
| 2A | Mina Vale | one bedroom | Sound | Make filing and caption workstation dominant. Add labeled charging station, cable discipline, closed storage, duplicate correction tools and one conspicuously unlabeled object. |
| 2B | Lena Ortiz | studio with sleeping alcove | Sound | Emphasize convertible work/home space: folding cutting surface, repair queue, fabric stored vertically, mended upholstery and a clear path from bed to sewing station. |
| 2C | Juno Kells | two bedrooms | Illogical as two sleeping rooms | Retain one bed. Convert the second bedroom into an acoustically improvised recording room with blankets fixed to walls, cable routing, instrument stands and stolen-session archive. No draped simulation cloth. |
| 3A | Malcolm Reed | one bedroom | Sound | Add propagation shelves at window light, watering tray, soil sweepings, reused jars, pruning station and one empty memorial spot. Protect plant access route. |
| 3B | Omar Bell | studio with sleeping alcove | Sound | Add repair intake/outgoing zones, labeled fastener drawers, sacrificial appliance, extension lead and a clear workbench service aisle. His home should look maintained, not generically messy. |
| 3D | Rhea Sato | bedroom plus office | Sound; intentional no-TV layout | Office is vocal booth/edit room. Add thrift-glam dressing mirror, hydration station, take sheets, isolated microphone storage and evidence of noise complaints. Do not add a television merely for completeness. |
| 4A | Peter Wren | one bedroom | Sound | Add document staging by status, date stamp, municipal binders, careful shoe placement, umbrella drip tray and an unresolved form at every daily station. |
| 4B | Player | bespoke studio/alcove | Visually present but exempted from normal completeness audit | Formalize its special audit: mattress, clothing storage, kitchen sink/counter, cold storage, cooking surface, trash, desk and bath. Existing mattress and sink are raw box geometry; give them semantic IDs so regressions are caught. |
| 4C | Cam Ortiz and Noel Price | two bedrooms | Correct for two residents | Split ownership visibly. Cam's side: courier gear, bike maintenance, quick food. Noel's side: archival containers and protected objects. Living room must show negotiated shared territory rather than two unrelated prop piles. |
| 4D | Transient Guests | bedroom plus office | Sound | Make it a short-term rental: generic host furniture, locked owner closet, duplicate rules, inadequate cookware, rolling luggage, takeout and objects left by prior guests. Avoid permanent personal history. |
| 5A | Nadia Quell | one bedroom | Sound | Strengthen architect/tenant-organizer logic: code books, corrected plans, scale tools, landlord correspondence, measured egress route and practical emergency supplies. Keep the actual exit path clear. |
| 5B | Cal Dwyer | studio with sleeping alcove | Sound | Build listening triangle, repair mat, antenna experiments, cataloged tapes and a chair worn toward the radio rather than the television. |
| 5C | Iris Bell | two bedrooms | Illogical as two sleeping rooms | Retain one bed. Convert second bedroom to painting studio: rigid canvas storage, drying rack, pigment station, wash jar, failed work facing the wall and protected floor. |
| 6A | Sacha Reed | one bedroom | Sound; intentional no-sofa/no-TV layout | Treat living room as photography workspace: backdrop rail, equipment charging, contact sheets, cases and one practical folding chair. Add an actual rest/eating perch so it remains habitable. |
| 6B | Jonah Price | studio with sleeping alcove | Sound | Add writing sightline from bed, task lamp, draft archive, bookstore receipts, cold drink rings, wastebasket of rejected endings and a clear nocturnal route. |
| 6C | Mae Kessler | two bedrooms | Illogical as two sleeping rooms | Retain one bed. Convert second bedroom into climate-conscious archive/storage: shelving, catalog table, packing material, gloves, disputed family objects and a locked provenance drawer. |

## Building-wide omissions to address

### Essential-life layer

Every occupied physical unit needs these cues, even when represented cheaply:

- Trash and recycling location.
- Laundry hamper or laundry staging.
- Toilet paper, towels, soap and toothbrush storage.
- Dish drying, cookware, staple food and refrigerator-door evidence.
- Coat/shoe/key landing zone at the entry.
- Bedding appropriate to the sleeper count.
- Charging/power use near bed and work position.
- Cleaning tool storage.
- Window treatment state appropriate to sleep schedule and privacy.
- Vantry fire/flood/listening coverage. Every enclosed room now has one quiet
  batched face; the current chirp alone is promoted to the shared functional
  owner. Do not reintroduce modern smoke or CO detectors.

### Avoid generic completeness

Do not put a television, sofa, desk and decorative plant into every unit by
habit. Rhea and Sacha intentionally replace television/sofa conventions with
their work. A home is complete when its resident can sleep, wash, eat, store
clothes, work/rest and enter/leave—not when it matches a furniture checklist.

## Efficient implementation architecture

### 1. Add a resident life-profile catalog

Create `game/data/apartment_life_profiles.json` and an authoring copy under
`art/data/`. Each resident entry should contain:

```json
{
  "unit": "2C",
  "resident_ids": ["juno_kells"],
  "room_conversions": {"bedroom_1": "recording_room"},
  "daily_loops": ["sleep", "record", "eat", "leave"],
  "surface_sets": ["music_work", "late_meal", "cable_management"],
  "entry_set": "working_musician",
  "bath_set": "single_adult",
  "kitchen_set": "takeout_plus_coffee",
  "cleanliness": 0.38,
  "maintenance": 0.61
}
```

This becomes the source of truth for dressing; do not spread resident checks
through another long chain of `if unit ==` statements.

### 2. Author semantic sockets, not individual coordinates

Have the generator expose reusable sockets:

- `ENTRY_DROP`, `SHOE_ZONE`, `BEDSIDE_L/R`, `WARDROBE_TOP`
- `COUNTER_DRY`, `COUNTER_DIRTY`, `FRIDGE_FACE`, `DINING_SURFACE`
- `SINK_EDGE`, `SHOWER_EDGE`, `TOILET_SIDE`, `BATH_WALL`
- `WORK_PRIMARY`, `WORK_ARCHIVE`, `WINDOW_LIGHT`, `TRASH_ZONE`

Socket placement must derive from existing room/furniture transforms. Dressing
then survives layout changes and can be audited for clearance.

### 3. Build pooled lived-in kits

Create approximately 12 shared kits, each containing 3–8 tiny objects:

- entry landing, bathroom daily use, laundry state, dish state, food state,
  bedtime, medication, paperwork, repair, audio, art and archive.

Use the existing primitive/assembly library and four shared texture atlases.
Vary tint, rotation, count, wear mask and one hero item. Merge each static kit
to one mesh per material using the established static-merge path. Prefer decals
for rings, dust shadows, labels, scuffs, spills and missing-object silhouettes.

### 4. Correct the three spare-bedroom contradictions

Convert 2C, 5C and 6C from two-bed generic layouts to one bedroom plus one
character workroom. Do this before adding clutter, then rerun movement and
furnishing validators with a new rule allowing a declared room conversion to
satisfy the second-room program.

### 5. Give 4B explicit completeness assertions

The player apartment is currently exempt from the standard audit except for
its bath. Add semantic requirements for its bespoke box-built mattress,
kitchen and clothing storage. If any is intentionally absent for narrative
reasons, record that explicitly rather than relying on the exception.

### 6. Use interaction sparingly

Promote only these domestic actions initially:

- Sit/rest point.
- Drink/prepare kettle where narratively useful.
- Inspect refrigerator or medicine cabinet evidence.
- Toggle television/radio/light.
- Examine the resident-specific hero object.

Everything else should imply use through pose, wear and state. Do not add 17
working sinks or physics-enabled cabinet doors.

### 7. Add automated lived-in audits

Extend generation validation with:

- Required life functions per occupied unit: sleep, wash, toilet, eat/cook,
  clothing storage, entry landing, trash and laundry.
- Sleeper count equals authored resident/guest capacity.
- Declared room conversions contain their required work kit and no stray bed.
- Bathroom and kitchen interaction bands remain unobstructed.
- No floor kit enters the 0.8 m circulation routes or door swings.
- Each resident gets at least three ordinary-life clues, two character clues,
  one contradiction and one director-reactive object.
- Per-unit added cost target: at most 6 merged meshes, 2 atlas materials,
  0 new shadow-casting lights and 0 continuous `_process()` nodes unless the
  object belongs to a director system.

## Execution order

1. Introduce the life-profile schema and socket generator with no visual change.
2. Add tests for life functions, sleeper counts, conversions and cost budgets.
3. Convert 2C, 5C and 6C spare bedrooms; formalize 4B requirements.
4. Add one shared essential-life kit to every occupied unit.
5. Add resident surface, entry and work kits from the profile catalog.
6. Add decals and wear that explain repeated use of those stations.
7. Promote only the approved hero interactions.
8. Regenerate Blender/glTF and synchronized game JSON outputs.
9. Run generator validation, Godot parser, WalkTest, lighting audit and a
   screenshot sweep from each unit entry, living area, kitchen, bath and bed.

## Acceptance criteria

- From the doorway, each apartment can be identified without reading a label.
- The resident can plausibly sleep, wash, dress, eat, work/rest and leave.
- No single resident occupies two generic made beds unless explicitly authored.
- Objects cluster around actions and surfaces; clutter is not evenly sprinkled.
- Clear paths remain from entry to living, bed, bath, kitchen and secondary exit.
- No new prop intersects a wall, door sweep, fixture or resident route.
- Character work areas have a usable chair/standing position and storage.
- The apartment looks different after inferring time of day and routine, not
  merely after changing material colors.
- The pass stays within the per-unit mesh/material/light/process budgets above.
- All existing validators and WalkTest remain green.
