# Photo darkroom and Radio window fittings

Evidence class: **INERT**. Fabrication guide, not runtime acceptance.

The four immutable furniture records are grouped into three assemblies in
**art/data/photo_radio_fittings/source_plan.json**. The Blender recipe produces
50 closed pieces, metre charts and separate catalogue material partitions.
The darkroom frame rebates over the actual wainscot and carries two opaque,
overlapping curtain leaves. The closed wall and all route authorities remain.
Its front is 50 mm forward of the old slab to clear the retained dado.

The Radio stand preserves the original 440 mm deck and its outline. The
accepted horn and cone remain on their exact two bearing points. Six feet
meet the shop floor; an inset panel surround and framed plywood back replace
the former two boxes. No merchandise or lettering is added.

Photo's red wall lamp belongs to its existing electrical actor,
**SITE_SHOP_DARKROOM_PHOTO_SUPPLIES**. V2 chooses **photo_darkroom_light.gd**,
a visual subclass of **LightFixtureProp**. It loads the two lamp partitions
from the same native export, flattens them beneath the actor's visual node
and transforms authored geometry into that actor's unchanged coordinate
frame. The old static red box is retired by the cell; no second lamp is added.
Its source position, yaw, family, circuit, range, energy and standby remain.
The emitter moves to the native opal diffuser. The existing hours director
lights it while trading and extinguishes it after hours. The bolted body
does not inherit a hanging cage's swing. V1 still constructs the old cage.

The scene mount keeps cell geometry disposable and the original actor
persistent across Passage retirement. Neither PackedScene nor discarded
partitions are cached by the subclass. The original electrical envelope
controls the red lens, and the inherited bounce obeys its hours dimmer.

Build and inspect in one Blender process with the batch runner. The native
inspector loads the retained cells and accepted Photo/Radio fittings, retires
exact source triangles, checks reciprocal contact planes and all composed
intersections, and renders the complete batch. It includes both native
Radio consumer contacts. **audit_native_support_dependents.py** independently
checks those consumers against the new exported provider's native geometry.

The shared Godot batch runs **photo_radio_fittings** and **radio_display**
with affected room families in one world. The new validator checks actual
source retirement, materials, collision poses, bearings, V1 fallback and
trading/after-hours light control. The residency contract checks both cell
reconstruction and the original persistent lamp actor. Native inspection,
batch captures and wrapper receipts are INERT; only a test-authored schema-2
runtime contract constitutes runtime proof for its explicit scope.
