class_name SurfacePass
extends RefCounted
## MX-4 — the layered surface in production (TASKS.md §MX, owner direction
## 2026-08-21). After the floor scenes load, the surface classes in CLASSES
## trade their shipping StandardMaterial3D for `orison_surface.gdshader`
## (or the cutout variant where the shipping material scissors) carrying
## the SAME maps and scalars, plus the layers the class's recipe names:
## the height tier calibrated in millimetres, the self-detail tier, and any
## standing mask states. One ShaderMaterial per (shipping material, recipe),
## cached: the glTF shares one material per `M_<key>` per storey file, so
## this is hundreds of materials, not thousands of surfaces, and no draw is
## added.
##
## `SURFACE=0` in the environment leaves the shipping materials in place —
## the A of every A/B. `SURFACE_BUDGET=0.5` scales the parallax governor.
##
## Frames and costs that chose the recipes: art/renders/orison_surface_mx1/.
## The proof harness (game/tests/SurfaceShot.tscn) builds its options through
## `surface_for`, so what it photographs is what ships.

const OPAQUE := preload("res://shaders/orison_surface.gdshader")
const CUTOUT := preload("res://shaders/orison_surface_cutout.gdshader")
const HEIGHT_DIR := "res://assets/building/textures/height/"

## Millimetres of relief spanned by a set's height map (0..1). Mortar is the
## deepest thing on the building; a board seam is barely anything. MX-3
## moves these into the generated set table with the tile size.
const RELIEF_MM := {
	"face_brick": 10.0, "common_brick": 9.0, "brick": 9.0, "brick_patched": 9.0,
	"concrete": 3.0, "slab": 3.0, "limestone": 4.0, "subway_tile": 3.0,
	"ceramic": 2.5, "terrazzo": 0.6, "stair": 3.0, "landing": 2.0,
	"floor_oak": 1.5, "wainscot": 6.0, "tin_ceiling": 6.0, "cast_iron": 2.0,
	"sidewalk_haunted": 5.0, "asphalt": 5.0, "wet_asphalt": 4.0,
}
## Metres of world per texture tile, as the ingest recorded them
## (art/textures/ai_materials/<key>/material.json) and the builder baked them.
const TILE_M := {
	"face_brick": 2.2, "common_brick": 1.2, "brick": 1.5, "brick_patched": 1.2,
	"concrete": 2.8, "slab": 2.8, "limestone": 1.6, "plaster": 1.8,
	"plaster_stained": 1.8, "subway_tile": 0.67, "ceramic": 0.65, "terrazzo": 4.0,
	"stair": 1.2, "floor_oak": 2.7, "wainscot": 0.72, "tin_ceiling": 1.2,
	"cast_iron": 0.4, "sidewalk_haunted": 1.52, "asphalt": 2.5, "wet_asphalt": 2.5,
	"trim": 1.1, "marble_lobby": 1.5,
}

## Surface classes by buffer-name substring, in rollout order, each with its
## standing recipe (shader parameters applied over the shipping material).
## Only the classes listed are touched; the census (MX-0) chose the order.
## Relief ships at 2.5x the calibrated millimetres: owner ruling 2026-08-21
## on the MX-1 frames ("exaggeration is cool").
const RELIEF_EXAGGERATION := 2.5

const CLASSES := [
	{"key": "walls", "match": "_walls",
			"recipe": {"parallax_mode": 2, "pom_steps_min": 6, "pom_steps_max": 14,
					"relief_mul": RELIEF_EXAGGERATION,
					"has_detail": true, "detail_albedo_strength": 0.18,
					"detail_normal_strength": 0.45}},
	{"key": "finish", "match": "_finish_",
			"recipe": {"has_detail": true, "detail_albedo_strength": 0.12,
					"detail_normal_strength": 0.35}},
	# Floors: M-COVER's anti-repetition rule per set (the coverage recipe is
	# resolved from the albedo's file name by COVERAGE_RULES) plus the height
	# tier and self-detail. Supersedes FloorCoveragePass.
	{"key": "floors", "match": "_floors_",
			"recipe": {"coverage_rule": true, "parallax_mode": 2, "pom_steps_min": 4,
					"pom_steps_max": 10, "relief_mul": RELIEF_EXAGGERATION,
					"has_detail": true, "detail_albedo_strength": 0.15,
					"detail_normal_strength": 0.4}},
	# The third class of the census order: relief where the set has a height
	# map (wainscot beadboard, tin ceiling, stair and landing stone, slabs,
	# limestone trim), self-detail everywhere. Painted trim and sash have no
	# height map and get the normal tier only. `_stone_trim` is listed before
	# `_trim` so the substring match lands on the right class.
	{"key": "wainscot", "match": "_wainscot",
			"recipe": {"parallax_mode": 2, "pom_steps_min": 4, "pom_steps_max": 10,
					"relief_mul": RELIEF_EXAGGERATION, "has_detail": true,
					"detail_albedo_strength": 0.12, "detail_normal_strength": 0.4}},
	{"key": "ceiling", "match": "_ceiling",
			"recipe": {"parallax_mode": 1, "relief_mul": RELIEF_EXAGGERATION,
					"has_detail": true, "detail_albedo_strength": 0.12,
					"detail_normal_strength": 0.35}},
	{"key": "stairs", "match": "_stairs",
			"recipe": {"parallax_mode": 1, "relief_mul": RELIEF_EXAGGERATION,
					"has_detail": true, "detail_albedo_strength": 0.15,
					"detail_normal_strength": 0.4}},
	{"key": "slabs", "match": "_slabs",
			"recipe": {"parallax_mode": 1, "relief_mul": RELIEF_EXAGGERATION,
					"has_detail": true, "detail_albedo_strength": 0.15,
					"detail_normal_strength": 0.4}},
	{"key": "stone_trim", "match": "_stone_trim",
			"recipe": {"parallax_mode": 1, "relief_mul": RELIEF_EXAGGERATION,
					"has_detail": true, "detail_albedo_strength": 0.12,
					"detail_normal_strength": 0.4}},
	{"key": "trim", "match": "_trim",
			"recipe": {"has_detail": true, "detail_albedo_strength": 0.10,
					"detail_normal_strength": 0.35}},
	{"key": "sash", "match": "_sash",
			"recipe": {"has_detail": true, "detail_albedo_strength": 0.10,
					"detail_normal_strength": 0.35}},
	# The glTF furnishing (built-in furniture, retail fit-outs, transit
	# shelters): the normal tier only — no parallax, no detail; the census
	# put the per-pixel budget on the architecture (self-detail here cost
	# +1.2 ms at a flat stand). Two-sided and blended surfaces are left alone
	# by _eligible. Being on the one surface is what lets a state (grime,
	# moisture, corruption) reach them later without a second shader.
	{"key": "furnish", "match": "_furnish_", "recipe": {}, "draw_heavy": true},
	{"key": "furniture", "match": "_furniture_", "recipe": {}, "draw_heavy": true},
	{"key": "retail", "match": "_retail", "recipe": {}, "draw_heavy": true},
	{"key": "transit", "match": "_transit", "recipe": {}, "draw_heavy": true},
]

## The draw-heavy tiers — the glTF furnishing classes above and the batched
## props — are ON by owner ruling 2026-08-21 ("it should reach the props"):
## the states (grime, moisture, corruption) must be able to reach a prop.
## Measured at the 4B stand: furnishing +0.9 ms for 1,004 surfaces, props
## +1.1 ms for 4,274 draws (a ShaderMaterial draw costs more than a
## StandardMaterial3D draw on Compatibility; props are 87 % of draws). The
## governor pays for it: with the parallax budget already at zero and the
## frame still over target it drops the prop tier, and brings it back with
## headroom. `SURFACE_PROPS=0` keeps the tiers off for an A/B.
static func draw_heavy_enabled() -> bool:
	return OS.get_environment("SURFACE_PROPS") != "0"

## M-COVER's per-set coverage rule, keyed by the substring of the albedo
## file name (longest key wins). `cells` is the divider grid per tile
## counted on the albedo (terrazzo, _b, _d: 3x3; _c: 2x2); oak seams run
## along V, so rows step across U. Frames: art/renders/material_coverage_m/.
const COVERAGE_RULES := {
	"terrazzo_b": {"coverage": 2, "lattice_cells": 3.0},
	"terrazzo_c": {"coverage": 2, "lattice_cells": 2.0},
	"terrazzo_d": {"coverage": 2, "lattice_cells": 3.0},
	"terrazzo": {"coverage": 2, "lattice_cells": 3.0},
	"floor_oak": {"coverage": 3, "rows_per_tile": 14.0, "grain_along_u": false},
	"ceramic": {"coverage": 1, "hex_scale": 1.0},
	"concrete": {"coverage": 1, "hex_scale": 1.0},
}


static func coverage_rule_for(texture_path: String) -> Dictionary:
	var file := texture_path.get_file()
	var keys: Array = COVERAGE_RULES.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for key in keys:
		if file.contains("_%s_" % key):
			return COVERAGE_RULES[key]
	return {}

var swapped := 0
var materials := 0
var _cache := {}

## ---- MX-2: the parallax governor ------------------------------------------
## The probe measures, the material obeys. Every GOVERN_INTERVAL seconds the
## building reports the viewport's measured GPU frame time; over the target
## the budget steps down (POM marches fewer steps and flattens, then stops
## marching at 0), under the target with headroom it steps back up. Pushed to
## every layered material as `parallax_budget`. SURFACE_TARGET_MS overrides
## the target (a low value is the way to watch it act); SURFACE_BUDGET pins
## the budget and disables the loop.
const GOVERN_INTERVAL := 0.5
const GOVERN_TARGET_MS := 14.0
const GOVERN_HEADROOM_MS := 3.0
const GOVERN_STEP := 0.25

var budget := 1.0
var governed_steps := 0
var _govern_clock := 0.0
var _govern_pinned := false
var _govern_target := GOVERN_TARGET_MS
## The second lever: the prop tier, dropped when the budget is spent.
var props_tier_on := true
var _props_root: Node = null
## Called (with no arguments) after the prop sweep lands or the lever
## re-applies the tier, so whoever layers states onto props can re-reach.
var on_props_applied: Callable = Callable()
var _over_streak := 0
var _under_streak := 0
## Flipping 4,000 material overrides in one frame read as a 900 ms hitch;
## the lever works through a queue, this many draws per physics frame.
const LEVER_CHUNK := 160
var _lever_queue: Array = []


func govern_setup() -> void:
	_govern_pinned = not OS.get_environment("SURFACE_BUDGET").is_empty()
	var target_env := OS.get_environment("SURFACE_TARGET_MS")
	if not target_env.is_empty():
		_govern_target = maxf(0.1, float(target_env))


## Call every physics frame with the delta and the viewport's measured GPU
## time (0 when measurement is unavailable: headless, or the dummy driver).
func govern(delta: float, gpu_ms: float) -> void:
	if _govern_pinned or gpu_ms <= 0.0:
		return
	_drain_lever()
	_govern_clock += delta
	if _govern_clock < GOVERN_INTERVAL:
		return
	_govern_clock = 0.0
	var next := budget
	if gpu_ms > _govern_target:
		next = maxf(0.0, budget - GOVERN_STEP)
		_over_streak += 1
		_under_streak = 0
	elif gpu_ms < _govern_target - GOVERN_HEADROOM_MS:
		next = minf(1.0, budget + GOVERN_STEP)
		_under_streak += 1
		_over_streak = 0
	else:
		_over_streak = 0
		_under_streak = 0
	# The prop tier: the last thing to go and the last to come back.
	if props_tier_on and budget <= 0.0 and _over_streak >= 3 and _props_root != null 			and _lever_queue.is_empty():
		props_tier_on = false
		for entry in _prop_swaps:
			_lever_queue.append([entry[0], entry[1]])
		_prop_swaps.clear()
		props_swapped = 0
		print("[SURFACE] governor: gpu %.1f ms with no parallax left -> prop tier OFF (%d draws queued)"
				% [gpu_ms, _lever_queue.size()])
	elif not props_tier_on and budget >= 1.0 and _under_streak >= 6 and _props_root != null 			and _lever_queue.is_empty():
		props_tier_on = true
		_queue_apply_props(_props_root)
		print("[SURFACE] governor: gpu %.1f ms with headroom -> prop tier ON (%d draws queued)"
				% [gpu_ms, _lever_queue.size()])
	if is_equal_approx(next, budget):
		return
	budget = next
	governed_steps += 1
	for m in _cache.values():
		(m as ShaderMaterial).set_shader_parameter("parallax_budget", budget)
	print("[SURFACE] governor: gpu %.1f ms vs %.1f target -> parallax budget %.2f"
			% [gpu_ms, _govern_target, budget])


## Returns the number of surfaces swapped. Idempotent per surface.
func apply(floor_nodes: Dictionary) -> int:
	if OS.get_environment("SURFACE") == "0":
		return 0
	govern_setup()
	var budget_env := OS.get_environment("SURFACE_BUDGET")
	if not budget_env.is_empty():
		budget = clampf(float(budget_env), 0.0, 1.0)
	for fid in floor_nodes:
		var floor_node: Node = floor_nodes[fid]
		for node in floor_node.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var cls := _class_for(mi.name)
			if cls.is_empty():
				continue
			if bool(cls.get("draw_heavy", false)) and not draw_heavy_enabled():
				continue
			for s in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(s) != null:
					continue
				var original := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if not _eligible(original):
					continue
				var recipe: Dictionary = (cls.recipe as Dictionary).duplicate()
				recipe["parallax_budget"] = budget
				mi.set_surface_override_material(s, surface_for(original, recipe, str(cls.key), _cache))
				swapped += 1
	materials = _cache.size()
	print("[SURFACE] %d surfaces layered (%d materials)" % [swapped, materials])
	return swapped


## The script-built props, AFTER they have been batched: every
## MeshInstance3D outside the glTF whose `material_override` (what the
## batcher and the prop builders set) is a textured, triplanar
## StandardMaterial3D — a MatLib material — takes the layered surface in
## triplanar mode with the same maps, tint, scale, roughness and metallic.
## One layered material per MatLib material, so the batcher's groups stay
## one draw each. Colour-only standards (no albedo map) and blended ones are
## left alone; so are props built after this sweep (spawned later).
## `restore_props` undoes it, for the harness.
## Normal tier only (the census put the per-pixel budget on the
## architecture): with self-detail the props cost +1.1 ms at a flat stand.
const PROPS_RECIPE := {"uv_mode": 1}

var props_swapped := 0
var _prop_swaps: Array = []


func apply_props(root: Node) -> int:
	if OS.get_environment("SURFACE") == "0" or not draw_heavy_enabled():
		return 0
	_props_root = root
	if not props_tier_on:
		return 0
	var recipe := PROPS_RECIPE.duplicate()
	recipe["parallax_budget"] = budget
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not (mi.material_override is StandardMaterial3D):
			continue
		if _is_imported(mi):
			continue
		var original := mi.material_override as StandardMaterial3D
		if not original.uv1_triplanar or not _eligible(original):
			continue
		var layered := surface_for(original, recipe, "props", _cache)
		_prop_swaps.append([mi, original])
		mi.material_override = layered
		props_swapped += 1
	materials = _cache.size()
	print("[SURFACE] %d prop draws layered in triplanar mode (%d materials)"
			% [props_swapped, materials])
	if props_swapped > 0 and on_props_applied.is_valid():
		on_props_applied.call()
	return props_swapped


## Queue the prop sweep instead of doing it at once (the governor's lever).
func _queue_apply_props(root: Node) -> void:
	var recipe := PROPS_RECIPE.duplicate()
	recipe["parallax_budget"] = budget
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not (mi.material_override is StandardMaterial3D):
			continue
		if _is_imported(mi):
			continue
		var original := mi.material_override as StandardMaterial3D
		if not original.uv1_triplanar or not _eligible(original):
			continue
		_lever_queue.append([mi, surface_for(original, recipe, "props", _cache), original])


func _drain_lever() -> void:
	if _lever_queue.is_empty():
		return
	var n := mini(LEVER_CHUNK, _lever_queue.size())
	var applied := false
	for _i in n:
		var entry: Array = _lever_queue.pop_front()
		var mi := entry[0] as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		mi.material_override = entry[1]
		if entry.size() > 2:
			_prop_swaps.append([mi, entry[2]])
			props_swapped += 1
			applied = true
	if _lever_queue.is_empty() and applied and on_props_applied.is_valid():
		on_props_applied.call()


func restore_props() -> void:
	for entry in _prop_swaps:
		(entry[0] as MeshInstance3D).material_override = entry[1]
	_prop_swaps.clear()
	props_swapped = 0


## glTF geometry is owned by its imported scene; a prop's mesh is not.
static func _is_imported(node: Node) -> bool:
	var cursor: Node = node
	while cursor != null:
		var ext := cursor.scene_file_path.get_extension()
		if ext == "gltf" or ext == "glb":
			return node.owner == cursor
		cursor = cursor.get_parent()
	return false


static func _class_for(node_name: String) -> Dictionary:
	for cls in CLASSES:
		if node_name.contains(str(cls.match)):
			return cls
	return {}


## Textured, back-culled, opaque or scissored: what the layered surface can
## stand in for without changing how the surface sorts or faces.
static func _eligible(original: BaseMaterial3D) -> bool:
	if original == null or original.albedo_texture == null:
		return false
	if original.cull_mode != BaseMaterial3D.CULL_BACK:
		return false
	return original.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			or original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR


static func catalog_key(original: BaseMaterial3D) -> String:
	var key := String(original.resource_name)
	if key.begins_with("M_"):
		key = key.substr(2)
	return key


## A family variant (`face_brick_c`) shares its base key's relief and tile
## size; its own height map ships under the full key.
static func base_key(key: String) -> String:
	for suffix in ["_b", "_c", "_d"]:
		if key.ends_with(suffix):
			return key.substr(0, key.length() - 2)
	return key


## One layered material for a shipping material and a recipe, carrying the
## shipping maps and scalars; `recipe` entries are shader parameters, except
## `relief_mul`, which scales the calibrated relief. `cache` (optional) is
## keyed by (material id, cache_key).
static func surface_for(original: BaseMaterial3D, recipe: Dictionary,
		cache_key: String = "", cache: Dictionary = {}) -> ShaderMaterial:
	var ck := "%d|%s" % [original.get_instance_id(), cache_key]
	if not cache_key.is_empty() and cache.has(ck):
		return cache[ck]
	var key := catalog_key(original)
	var cutout := original.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var m := ShaderMaterial.new()
	m.shader = CUTOUT if cutout else OPAQUE
	m.set_shader_parameter("albedo_tex", original.albedo_texture)
	m.set_shader_parameter("albedo_color", original.albedo_color)
	if original.normal_texture != null and original.normal_enabled:
		m.set_shader_parameter("normal_tex", original.normal_texture)
		m.set_shader_parameter("normal_scale", original.normal_scale)
		m.set_shader_parameter("has_normal_tex", true)
	else:
		m.set_shader_parameter("has_normal_tex", false)
	if original.roughness_texture != null:
		m.set_shader_parameter("rough_tex", original.roughness_texture)
		m.set_shader_parameter("has_rough_tex", true)
		m.set_shader_parameter("rough_channel",
				1 if original.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN else 0)
	else:
		m.set_shader_parameter("has_rough_tex", false)
	m.set_shader_parameter("roughness_mul", original.roughness)
	m.set_shader_parameter("metallic", original.metallic)
	var base := base_key(key)
	m.set_shader_parameter("tile_m", float(TILE_M.get(base, 1.0)))
	if original.uv1_triplanar:
		# MatLib: uv1_scale = 1 / (metres per tile x scale_mult).
		var repeats := maxf(0.001, original.uv1_scale.x)
		m.set_shader_parameter("uv_scale", repeats)
		m.set_shader_parameter("tile_m", 1.0 / repeats)
		m.set_shader_parameter("uv_mode", 1)
	var height: Texture2D = original.heightmap_texture if original.heightmap_enabled else null
	if height == null and ResourceLoader.exists(HEIGHT_DIR + key + ".png"):
		height = load(HEIGHT_DIR + key + ".png")
	var relief := float(RELIEF_MM.get(base, 0.0))
	if height != null and relief > 0.0:
		m.set_shader_parameter("height_tex", height)
		m.set_shader_parameter("has_height", true)
		m.set_shader_parameter("height_relief_mm", relief)
		m.set_shader_parameter("height_range", height_range(height))
	var stats := texture_stats(original)
	m.set_shader_parameter("albedo_mean", stats.albedo_mean)
	m.set_shader_parameter("rough_mean", stats.rough_mean)
	if cutout:
		m.set_shader_parameter("cutout_mode", 1)
		m.set_shader_parameter("cutout_threshold", original.alpha_scissor_threshold)
	for p in recipe:
		if p == "relief_mul":
			if height != null and relief > 0.0:
				m.set_shader_parameter("height_relief_mm", relief * float(recipe[p]))
			continue
		if p == "coverage_rule":
			if bool(recipe[p]):
				var rule := coverage_rule_for(original.albedo_texture.resource_path)
				for rk in rule:
					m.set_shader_parameter(rk, rule[rk])
			continue
		m.set_shader_parameter(p, recipe[p])
	if not cache_key.is_empty():
		cache[ck] = m
	return m


## The working range of a height map — its 5th and 95th percentiles from a
## 128x128 resample. The ingest's band-passed heights never reach 0 or 1
## (face brick spans 0.39..0.65, concrete 0.45..0.54), so the millimetres of
## relief are mapped onto the range the map actually uses. Cached per texture.
static var _range_cache := {}
static func height_range(height: Texture2D) -> Vector2:
	var id := height.get_instance_id()
	if _range_cache.has(id):
		return _range_cache[id]
	var out := Vector2(0.0, 1.0)
	var img := height.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.resize(128, 128, Image.INTERPOLATE_BILINEAR)
		var values: Array[float] = []
		values.resize(128 * 128)
		for y in 128:
			for x in 128:
				values[y * 128 + x] = img.get_pixel(x, y).r
		values.sort()
		out = Vector2(values[int(values.size() * 0.05)], values[int(values.size() * 0.95)])
		if out.y - out.x < 0.05:
			out = Vector2(out.x, out.x + 0.05)
	_range_cache[id] = out
	return out


## Means of the albedo and roughness maps from a 32x32 resample — the
## variance-preserving coverage blend and the self-detail overlay both need
## to know what "average" is. Once per shipping material at build.
static func texture_stats(original: BaseMaterial3D) -> Dictionary:
	var out := {"albedo_mean": Vector3(0.5, 0.5, 0.5), "rough_mean": 0.5}
	var img := original.albedo_texture.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.resize(32, 32, Image.INTERPOLATE_BILINEAR)
		var sum := Vector3.ZERO
		for y in 32:
			for x in 32:
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b)
		out.albedo_mean = sum / 1024.0
	if original.roughness_texture != null:
		var rimg := original.roughness_texture.get_image()
		if rimg != null:
			if rimg.is_compressed():
				rimg.decompress()
			rimg.resize(32, 32, Image.INTERPOLATE_BILINEAR)
			var rsum := 0.0
			var green := original.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			for y in 32:
				for x in 32:
					var c := rimg.get_pixel(x, y)
					rsum += c.g if green else c.r
			out.rough_mean = rsum / 1024.0
	return out
