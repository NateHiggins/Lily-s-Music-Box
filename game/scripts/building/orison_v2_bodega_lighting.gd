extends RefCounted
## The bodega's night lighting, culled for cost and mood (Lily, 2026-11-23: cull
## unneeded lights and move existing ones for efficient, moody lighting).
##
## The template authors seven omni lights in a shop about 4 m by 11 m, two of them
## re-rendering cube shadows every frame. A 1928 grocer at night burns two pendants:
## one over the counter and one down the aisles, with the back left to the dark and
## the delivery bulb in its alcove. So:
##   - the counter and cooler fills go: both sit inside the front and middle pools;
##   - the back practical goes, and its ceiling fixture is dark, the bulb unlit;
##   - the middle pendant reaches a little further to carry the aisle ends;
##   - the storefront spill keeps its light but not its cube shadow (the signboard
##     lamps and the windows carry the pavement); the front pendant keeps the one
##     interior shadow.
## The template stays as authored (its digest is bound); this owner changes only the
## mounted nodes and records every original so restore() returns them exactly.
const ShadowPolicy := preload("res://scripts/rendering/shadow_policy.gd")

const CULLED := ["counter_practical", "cooler_practical", "back_shop_practical"]
const UNSHADOWED := ["storefront_spill"]
const RANGE := {"middle_shop_practical": 6.6}
const DARK_FIXTURES := ["ceiling_practical_back"]
const META := "bodega_light_cull"


static func _lights(shop: Node3D) -> Dictionary:
	var out := {}
	for light: Light3D in shop.find_children("*", "Light3D", true, false):
		var identity := str(light.get_meta("authored_record_id", ""))
		if identity != "":
			out[identity] = light
	return out


static func apply(shop: Node3D) -> bool:
	if shop == null or shop.has_meta(META):
		return false
	var lights := _lights(shop)
	for identity: String in CULLED + UNSHADOWED + RANGE.keys():
		if not lights.has(identity):
			push_error("Bodega lighting: authored light missing: " + identity)
			return false
	var record := {"lights": [], "fixtures": []}
	for identity: String in lights:
		var light: OmniLight3D = lights[identity]
		record.lights.append({"node": weakref(light), "visible": light.visible,
			"shadow": ShadowPolicy.wanted(light), "range": light.omni_range})
		if identity in CULLED:
			light.visible = false
		if identity in UNSHADOWED:
			ShadowPolicy.set_shadow(light, false)
		if RANGE.has(identity):
			light.omni_range = float(RANGE[identity])
	for identity: String in DARK_FIXTURES:
		var draw: MeshInstance3D = preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop, identity)
		if draw == null:
			push_error("Bodega lighting: fixture missing: " + identity)
			continue
		for surface in draw.get_surface_override_material_count():
			var material := draw.get_surface_override_material(surface) as StandardMaterial3D
			if material == null or not material.emission_enabled:
				continue
			record.fixtures.append({"material": material, "emission": true})
			material.emission_enabled = false
	shop.set_meta(META, record)
	return true


static func restore(shop: Node3D) -> bool:
	if shop == null or not shop.has_meta(META):
		return false
	var record: Dictionary = shop.get_meta(META)
	for row: Dictionary in record.lights:
		var light := (row.node as WeakRef).get_ref() as OmniLight3D
		if light == null:
			continue
		light.visible = bool(row.visible)
		ShadowPolicy.set_shadow(light, bool(row.shadow))
		light.omni_range = float(row.range)
	for row: Dictionary in record.fixtures:
		(row.material as StandardMaterial3D).emission_enabled = bool(row.emission)
	shop.remove_meta(META)
	return true


static func culled(shop: Node3D) -> bool:
	return shop != null and shop.has_meta(META)
