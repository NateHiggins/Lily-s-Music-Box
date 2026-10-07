# Closed retail back doors and the empty funeral display

Evidence class: **INERT**. Fabrication guide, not whole-shop acceptance.

Twenty-four immutable source records supply twelve assemblies in eleven shops:
eleven closed back doors with their original knob owners, and the funeral
parlour's empty window plinth/backboard. The source shop guide, section II.4,
explicitly leaves the backs unmodelled. These are passive visual representations;
no opening, lock, route or interaction is added.

**build_shop_joinery.py** builds 595 closed stocks, 35 material partitions and
120,440 triangles. Exact source-box retirement removes 288 original triangles.
Fifty declared samples bind frame backs to retained wainscot and feet to the
actual shop floors. Source cell **shop_otis___son** maps to the existing runtime
cell **shop_otis_son**; source ids and geometry remain unchanged.

The cases have real jambs, heads and thresholds. Each six-panel leaf has split
rails meeting a continuous centre stile, recessed fields, small beads, two
hinges, a turned brass knob and rose screws. The earlier overlapping cross-rails
produced black coplanar seams in native renders and were replaced with butt
joints before Godot import. Known walnut grain follows the construction length.

Door widths, top heights and knob centres retain their original data. The new
frame front lies 55mm ahead of the wainscot, 30mm beyond the original flat leaf.
The knob reaches 102mm ahead of that wall, 47mm beyond its original box. The
threshold fills the source's 40mm floor gap. Frames sit wholly in front of the
retained wall; hidden wall penetration is not permitted by the fit checks.

The funeral stand retains its .44m display datum and empty top. Six feet support
the panelled lower frame and framed plywood back. Existing wood, brass, iron and
plywood catalogue/shipping maps remain; no new bitmap, material key or lettering.

**inspect_shop_joinery.py** checks closed positive volumes, joined assemblies,
metre UV derivatives, all floor/wall bearings, source triangle retirement and
intersections against retained architecture and 49 accepted native families.
Original assembled receiving cabinets retire by their exact draw names/counts;
accepted receiving geometry remains conservative restoration context. Actual
production cabinet presence retains its existing policy. Isolated front views
and room context are rendered together; an occluded room camera is not evidence
of an unobstructed player observation.

**OrisonV2ShopJoineryTest** checks exact retirement, retained attributes/materials,
catalogue ownership, physical triangles, all contacts, the 11mm panel recess,
knob projection, passive ownership, the empty stand datum and standing views.
It runs in the shared fabrication batch. The passage residency validator also
checks every cell's correct part count and collision ownership after reload.

Rear clerestories, darkroom/chapel connections, services and routes remain
separate work. This batch does not make the unmodelled back rooms accessible.
