# Common reading-room furniture

Evidence class: **INERT**

The production sweep confirmed an empty reading-room shell. The room now has
one six-place oak table, six chairs and two freestanding bookcases. Rebuild
**reading_furniture.blend** and **game/assets/props/reading_furniture.glb** with
**art/blender/scripts/build_reading_furniture.py**. All library parts remain
editable before export batching. No reference bytes or generated text are used.

The table has five boards, breadboard ends, aprons, turned legs and stretchers.
Chairs have solid scooped seats, splayed feet, connected stretchers and slatted
backs. Bookcases have backs, separate shelves, plinths and cornices; individual
bindings surround recessed paper blocks. These books are fixed furnishing,
not new readable items or a substitute for the existing bookshelf mechanism.
Shared reading activities remain outside this geometry batch.

**orison_v2_reading_furniture.gd** places the library relative to the existing
**F01_COMMON_B** room rectangle. The door and windows retain their original
owners. All nine furniture bodies use collision from their rendered triangles;
there is no invisible broad envelope across chair or table legs. The installed
assembly has 18 material batches and 29,824 triangles; six chairs and both
bookcases share mesh resources. The exported library is about 1 MB.

Metre UVs and unit transforms prepare the mapping pass. Material bindings reuse
**oak_quartered**, **cast_iron**, **paper** and tinted **linen** from MatLib.
The existing wood plate's grain direction and close-range relief still need
the coordinated material pass. No new catalogue key, image or lighting change
is introduced. Detail captures add a local inspection fill only.

**OrisonV2ReadingFurnitureTest** traverses the existing public-door test first,
then walks a continuous circuit around both table sides, along the bookcases
and back to the entry. It compares nine actual contacts against imported
triangles and checks that feet meet the floor. Focused results: 25 waypoints,
zero failures. Player-height, clear survey and joinery/binding detail captures
are under **tmp/reading-room/shots**. Final candidate verification and bound
suite-run receipts belong under **tmp/reading-room/verified**. These are not
runtime-contract evidence or whole-building acceptance.
