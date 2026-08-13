class_name PassageFinishPass
extends Node3D
## M0.5's movable middle layer and final public-hall wear.  The generated glTF
## owns the ruled shell and eleven shop interiors; this pass owns only things
## that can move, be repaired or accumulate after construction.

const PUSH_CART_SCRIPT := preload("res://scripts/props/passage_pushcart.gd")

var geometry_nodes: Array[GeometryInstance3D] = []
var pushcarts: Array[Node3D] = []


func build(layout: Dictionary) -> Dictionary:
	name = "PassageFinishPass"
	_build_threshold_nosings(layout)
	_build_edge_drains()
	_build_floor_wear()
	_build_pushcarts()
	print("[PASSAGE FINISH] %d gated draws, %d shoveable handcarts" %
			[geometry_nodes.size(), pushcarts.size()])
	return {"draws": geometry_nodes.size(), "pushcarts": pushcarts.size()}


func _build_threshold_nosings(layout: Dictionary) -> void:
	var entries := []
	for floor in layout.get("floors", []):
		if String(floor.get("id", "")) != "F01":
			continue
		for marker in floor.get("markers", []):
			if String(marker.get("zone", "")) != "PASSAGE" \
					or String(marker.get("kind", "")) != "door" \
					or not String(marker.get("id", "")).begins_with(
							"SITE_SHOP_DOOR_"):
					continue
			var p: Array = marker.get("pos", [])
			var width := float(marker.get("w", 0.95))
			var west := is_equal_approx(float(marker.get("yaw_deg", 0.0)), 90.0)
			var centre_y := float(p[1]) + (-0.5 if west else 0.5) * width
			entries.append([11.03 if west else 16.97, centre_y, width])

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.016, 1.0)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for i in entries.size():
		var entry: Array = entries[i]
		var basis := Basis.from_scale(Vector3(1.0, 1.0, float(entry[2])))
		multimesh.set_instance_transform(i, Transform3D(basis,
				GameBoot.b2g([float(entry[0]), float(entry[1]), 0.018])))
	var instance := MultiMeshInstance3D.new()
	instance.name = "PassageThresholdNosings"
	instance.multimesh = multimesh
	instance.material_override = MatLib.get_mat("brass_dull",
			Color(0.66, 0.52, 0.25), 0.48)
	instance.add_to_group("passage_finish_geometry")
	add_child(instance)
	geometry_nodes.append(instance)


func _build_edge_drains() -> void:
	# Twenty-six removable grates make the glass hall's rain problem physical.
	# They remain at the architectural edges and consume no part of the six
	# metre walking band.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.026, 1.72)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = 26
	var index := 0
	for x in [11.13, 16.87]:
		for i in range(13):
			var y := -39.53 - float(i) * 2.0
			multimesh.set_instance_transform(index,
					Transform3D(Basis.IDENTITY, GameBoot.b2g([x, y, 0.012])))
			index += 1
	var instance := MultiMeshInstance3D.new()
	instance.name = "PassageEdgeDrains"
	instance.multimesh = multimesh
	instance.material_override = MatLib.get_mat("cast_iron",
			Color(0.29, 0.30, 0.28), 0.52)
	instance.add_to_group("passage_finish_geometry")
	add_child(instance)
	geometry_nodes.append(instance)


func _build_floor_wear() -> void:
	# A single transparent batch records the handcarts' recurring wheel paths.
	# It is deliberately irregular and edge-biased: a generic grime wash would
	# flatten the terrazzo instead of explaining how this hall is used.
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never,
		shadows_disabled;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float lane = 1.0 - smoothstep(0.22, 0.46, abs(p.x));
	float broken = smoothstep(0.23, 0.72,
		hash(floor(UV * vec2(18.0, 34.0))));
	float feather = (1.0 - smoothstep(0.72, 1.0, abs(p.y)))
		* (1.0 - smoothstep(0.58, 1.0, abs(p.x)));
	ALBEDO = vec3(0.032, 0.026, 0.019);
	ROUGHNESS = 0.34;
	ALPHA = lane * feather * (0.035 + broken * 0.075);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var marks := [
		[12.72, -44.9, 0.38, 2.1, -0.08],
		[15.30, -46.2, 0.34, 1.7, 0.05],
		[12.69, -48.3, 0.40, 2.4, 0.03],
		[15.31, -50.4, 0.36, 2.0, -0.06],
		[12.70, -52.8, 0.34, 2.2, 0.07],
		[15.29, -54.7, 0.42, 2.5, -0.03],
		[12.71, -57.0, 0.36, 1.9, -0.05],
		[15.30, -59.0, 0.39, 2.3, 0.06],
		[12.70, -61.2, 0.35, 2.0, -0.02],
	]
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = marks.size()
	for i in marks.size():
		var mark: Array = marks[i]
		var basis := Basis(Vector3.UP, float(mark[4])) \
				* Basis(Vector3.RIGHT, -PI * 0.5) \
				* Basis.from_scale(Vector3(float(mark[2]), float(mark[3]), 1.0))
		multimesh.set_instance_transform(i, Transform3D(basis,
				GameBoot.b2g([float(mark[0]), float(mark[1]), 0.024])))
	var instance := MultiMeshInstance3D.new()
	instance.name = "PassageCartWheelWear"
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("passage_finish_geometry")
	add_child(instance)
	geometry_nodes.append(instance)


func _build_pushcarts() -> void:
	# Parked in the gaps between public thresholds. Alternating sides creates
	# the movable middle layer while x=14 remains capsule-clear for every
	# schedule route before the player touches a cart.
	var specs := [
		["laundry", "laundry", 13.0, -46.9, -2.0],
		["market", "crates", 15.0, -54.8, 2.5],
		["news", "papers", 13.0, -60.2, -1.5],
	]
	for spec in specs:
		var cart = PUSH_CART_SCRIPT.new()
		cart.setup(String(spec[0]), String(spec[1]))
		cart.position = GameBoot.b2g(
				[float(spec[2]), float(spec[3]), 0.035])
		cart.rotation_degrees.y = float(spec[4])
		add_child(cart)
		pushcarts.append(cart)
