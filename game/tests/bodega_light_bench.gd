extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## The bodega's night-light cull, measured. Two fixed interior views in the real
## composed world, culled (as installed), restored to the authored seven lights,
## and culled again (A/B/A), each warmed and then timed with the viewport's own
## render timers and draw counters, with a capture per view. Diagnostic only: the
## restore is the owner's own reversal, not a quality setting, and frame times on a
## shared GPU are reported, never claimed, unless every repeat agrees.
const Lighting := preload("res://scripts/building/orison_v2_bodega_lighting.gd")
const WARM := 30
const FRAMES := 90
## Shop-local eye and target.
const VIEWS := {
	"door_in": [Vector3(0.0, 1.6, -0.7), Vector3(0.2, 1.1, -7.5)],
	"rear_out": [Vector3(0.6, 1.6, -9.6), Vector3(-0.4, 1.1, -1.0)],
}

func _init() -> void:
	route_label = "BODEGA LIGHT BENCH"


func _route() -> void:
	var shop: Node3D = world.exterior_cell.instance_node("SHOP_BODEGA")
	if not _require(shop != null and Lighting.culled(shop), "the installed bodega lighting is culled"):
		return
	# The template's seven practicals (the signboard's two lamps live here too).
	var lights := shop.find_children("*", "Light3D", true, false).filter(func(l): return str(l.get_meta("authored_record_id", "")) != "")
	var shown := lights.filter(func(l): return l.visible)
	# Distant shadows are the far-light owner's; it manages only what still casts.
	var managed: Array = world.far_light_shadows.rows.map(func(r): return r.light)
	var casting := lights.filter(func(l): return managed.has(l))
	_require(lights.size() == 7 and shown.size() == 4 and casting.size() == 1
			and str(casting[0].get_meta("authored_record_id")) == "front_shop_practical",
			"seven authored lights retained, four burn, the front pendant alone casts: %d/%d/%d" % [lights.size(), shown.size(), casting.size()])
	var dark := preload("res://scripts/building/orison_v2_bodega_frontage.gd").authored_mesh(shop, "ceiling_practical_back")
	_require(dark != null and _unlit(dark), "the back pendant's bulb is dark")
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for canvas: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		canvas.hide()
	var camera: Camera3D = world.player.camera
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var rows: Array = []
	for condition: String in ["culled_a", "authored", "culled_b"]:
		if condition == "authored":
			_require(Lighting.restore(shop), "the owner restores the seven authored lights")
		elif condition == "culled_b":
			_require(Lighting.apply(shop), "the owner culls them again")
		for view: String in VIEWS:
			var pose: Array = VIEWS[view]
			camera.global_position = shop.to_global(pose[0])
			camera.look_at(shop.to_global(pose[1]))
			camera.make_current()
			for frame in WARM:
				await RenderingServer.frame_post_draw
			var cpu: Array[float] = []
			var gpu: Array[float] = []
			var draws: Array[int] = []
			var objects: Array[int] = []
			for frame in FRAMES:
				await RenderingServer.frame_post_draw
				var rid := get_viewport().get_viewport_rid()
				cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid))
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
				draws.append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
						+ RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
				objects.append(RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
			var row := {"condition": condition, "view": view, "gpu_ms": _median(gpu), "cpu_ms": _median(cpu),
				"draw_calls": _median_int(draws), "shadow_draw_calls": _median_int(objects),
				"lights_shown": shop.find_children("*", "Light3D", true, false).filter(func(l): return l.is_visible_in_tree()).size()}
			rows.append(row)
			print("BODEGA LIGHT ", JSON.stringify(row))
			await _capture_interaction("bodega_light_%s_%s" % [condition, view])
	var by := {}
	for row: Dictionary in rows:
		by["%s/%s" % [row.condition, row.view]] = row
	for view: String in VIEWS:
		var a: Dictionary = by["culled_a/" + view]
		var b: Dictionary = by["culled_b/" + view]
		var o: Dictionary = by["authored/" + view]
		_require(int(a.shadow_draw_calls) < int(o.shadow_draw_calls) and int(b.shadow_draw_calls) < int(o.shadow_draw_calls),
				"%s: the cull renders fewer shadow draws (%d, %d against %d)" % [view, int(a.shadow_draw_calls), int(b.shadow_draw_calls), int(o.shadow_draw_calls)])
		_require(int(a.draw_calls) <= int(o.draw_calls) and int(b.draw_calls) <= int(o.draw_calls),
				"%s: and no more draws in all (%d, %d against %d)" % [view, int(a.draw_calls), int(b.draw_calls), int(o.draw_calls)])
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file := FileAccess.open(directory.path_join("bodega_light_bench.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class": "INERT", "rows": rows,
			"limits": "Fixed cameras, player lamp off, overlays hidden; A/B/A by the owner's own restore. GPU and CPU medians on a shared machine are reported, not claimed. Not a runtime contract or artistic acceptance."}, "\t"))


func _unlit(draw: MeshInstance3D) -> bool:
	for surface in draw.get_surface_override_material_count():
		var material := draw.get_surface_override_material(surface) as StandardMaterial3D
		if material != null and material.emission_enabled:
			return false
	return true


func _median(values: Array[float]) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if not sorted.is_empty() else -1.0


func _median_int(values: Array[int]) -> int:
	var sorted := values.duplicate()
	sorted.sort()
	return int(sorted[sorted.size() / 2]) if not sorted.is_empty() else -1
