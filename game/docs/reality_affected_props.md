# Reality-Affected Prop Library

The master production list lives in
`res://data/reality_affected_props.json`. It currently defines 62 placed
objects: three personal anchors for each of the 18 resident cases, plus eight
shared Reality Maintenance objects.

## Inventory by case

| Resident / case | Unit | Affected anchors |
|---|---:|---|
| Evelyn — Paper Jam | 1A | Self-Grading Papers; Red Correction Pencil; Retirement Desk Bell |
| Teresa — Call Bells | 1D | Disconnected Call Bell; Night-Shift Thermos; Expired Hospital Pager |
| Mina — Caption Crisis | 2A | Unassigned Caption Cards; Personal Style Guide; Redaction Pencil |
| Lena — Unraveling | 2B | Boundary Stitcher; Family Thread Spools; Heavy Fabric Shears |
| Juno — Feedback Tetris | 2C | Field Recorder; Uncredited Master; Open Channel Patch |
| Malcolm — Memory Plants | 3A | Last Conversation Cutting; Pot Marked KEEP; Propagation Shears |
| Omar — Unrepairable | 3B | Categorized Tool Case; Alternate-Timeline Toaster; UNREPAIRABLE Tags |
| Rhea — Bad Karaoke | 3D | Control Tuning Fork; Humiliation Session Reel; Cracked Pop Filter |
| Peter — Form Corridor | 4A | Self-Appending Forms; Rolling Notary Seal; Disclosure Wallet |
| Cam — Tilted Room | 4C | Crash-Marked Helmet; Reality Furniture Wedges; Undelivered Courier Bag |
| Noel — Museum Apartment | 4C | Misdated Artifact Box; White Handling Gloves; Museum Accession Tags |
| Transient Guests — Wrong Checkout | 4D | Luggage from Tomorrow; Impossible Keycards; Checkout Towel |
| Nadia — Impossible Plans | 5A | Contradictory Blueprints; Impossible Scale Rule; REJECTED Stamp |
| Cal — Broadcast Delay | 5B | Shortwave Receiver; Bent Rooftop Antenna; Delayed Voice Reel |
| Iris — Color Leak | 5C | Unfinished Self-Portrait; Mourning Palette; Impossible Paint Cans |
| Sacha — Witness Loop | 6A | Evidence Camera; Statement Recorder; Unfiled Signal Cables |
| Jonah — Missing Words | 6B | Unfinished Apology; Cold Writing Mug; Loose Missing Words |
| Mae — Inherited Room | 6C | Contradictory Antique Box; Provenance Gloves; TRUE / FELT TRUE Tags |

Shared props are the work-order board, elevator stabilizer panel, maintenance
cart, maintenance clipboard, brass tape measure, portal-rule tags, grief crate,
and shame crate. The storage-related items are staged in the former fourth-floor
suite so that room reads as the Reality Maintenance hub.

## Placement

Case entries use normalized `u` and `v` coordinates inside the resident's
living-room rectangle. `0,0` is one room corner and `1,1` is the opposite
corner, so placement survives modest layout resizing. `surface` is either
`floor` or `table`; it selects a standard local height. Shared entries use an
explicit building coordinate and floor.

At building assembly, `BuildingRoot` reads the catalog, creates each
`RealityAffectedProp`, parents it to the correct floor, and verifies IDs and the
expected count. A duplicate ID or missing placement is reported as an error.

## Manifestation behavior

Every case prop listens to its assigned `RealityCases` state. Active,
recognized, reopened, resistant, and integration-ready cases cause their
anchors to:

- reveal their identifying label;
- acquire a cold teal emission;
- hover and drift subtly;
- become more agitated and brighter after each recurrence.

Stabilized, resolved, and unseen cases settle at their original transform. This
makes the same ordinary-looking prop persist through repair, relapse, and final
resolution instead of swapping it for a disconnected supernatural effect.
Shared maintenance props remain labeled for navigation.

## Adding or replacing an object

Add a unique catalog entry and select an existing silhouette `kind`, or add a
new silhouette branch in
`res://scripts/cases/reality_affected_prop.gd`. Update
`expected_prop_count`. For final art, the procedural mesh can be replaced by a
scene mapped to the same `kind`; keep the catalog ID, placement, case binding,
and affected-state response intact.
