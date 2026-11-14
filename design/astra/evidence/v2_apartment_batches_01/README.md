# Apartment category batches

Owner direction: furnish by category across apartments, rather than completing
one fixture per turn. This is now the continuation workflow.

Installed 21 additions across the detailed V2 apartment rooms:

- Toilets: 2A and 2B, using the source porcelain assembly and shared flush owner.
- Sinks: both bathroom and kitchen sinks in 2A and 2B, with the existing V2
  hot/cold targets and boiler supply.
- Showers: 2A and 2B, using the production curtain, valves and receptor collision.
- Kitchen appliances: 2A stove, 2B stove and 2B icebox. Source settings are
  retained, including 2B's authored ambient burner; the existing 2A fridge is
  preserved with its established Mina binding.
- Furniture: two beds, one nightstand, two wardrobes and three shelves, using
  the actual 2A/2B assembly records and household finishes.
- Supports: two newly authored open metal stands beneath the full-size kitchen
  sinks and drainboards. They are not claimed as extracted source furniture.

2A, 2B, 3B and 4B now each have one toilet, two sinks, one shower, one stove and
one fridge in source. The furniture dataset grows from 16 to 28 records, the
fitting dataset from 11 to 20, and the layout receives 42 anchors. All earlier
records are preserved. New extracted/support geometry totals 4,288 triangles,
excluding the live fixture and wardrobe-leaf geometry built at runtime.

Wardrobe validation now accepts the shared mechanism's supported wood_dark
finish as well as oak_quartered, so 2A/2B retain their actual household wood.
Shared prop implementations, campaign owners and materials are unchanged.

The generator at `../../work/v2_apartment_batches_01/build.py` performs pure
assembly extraction with no Blender/Godot imports or launches. It validates
materials, finite geometry, room containment, non-overlap and standing-point
clearance, then applies additive records. Fixture footprints are conservative
source estimates. A second installation produced byte-identical data files.
Independent GDScript syntax parsing passes.

The prepared OrisonV2ApartmentBatchTest covers the whole four-apartment
sanitary/appliance roster, furniture reconstruction, shared toilet flushing,
wardrobe finish/opening and retirement with active tweens. Existing hot-water
tests derive their expanded twelve-fitting roster from installed data.
**No engine tests ran. No Godot launched.** Actual routes, fixture targeting,
dynamic leaf clearances, support contacts, lighting/material presentation,
performance and lifecycle remain pending.

`../../work/v2_apartment_batches_01/apartment_inventory.json` records every
source unit's mounted sanitary objects and remaining source furniture. Twenty
source unit IDs lack corresponding detailed V2 apartment rooms; their room
programs must be established before placing their objects. This is not a claim
that every source unit has the same apartment program or that the building is
fully furnished.

Continue with category passes across all available rooms: room lights and
switches, seating/tables/work surfaces, storage, then smaller domestic props.
Extend the remaining unit room programs and repeat the same category passes.
Do not return to one-fixture-per-turn work. V1 remains the default; V2 visual
acceptance, full building coverage and default cutover are still open.
