class_name PassageFinishPass
extends Node3D
## M0.5's movable middle layer and final public-hall wear.  The generated glTF
## owns the ruled shell and eleven shop interiors; this pass owns only things
## that can move, be repaired or accumulate after construction.

const PUSH_CART_SCRIPT := preload("res://scripts/props/passage_pushcart.gd")
const HOURS_SCRIPT := preload(
		"res://scripts/building/passage_hours_director.gd")

const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")
const Surface := preload("res://scripts/building/surface_pass.gd")
const EDGE_STOCKS := ["PublicFloor_00__hatch_outside_00","PublicFloor_00__hatch_outside_02"]
const EDGE_GRATE_COUNT := 13
const EDGE_GRATE_SIZE := Vector3(.09,.007,1.32)

var geometry_nodes: Array[GeometryInstance3D] = []
var pushcarts: Array[Node3D] = []
var hours_director: PassageHoursDirector


func build(layout: Dictionary, prepared_storefronts: Dictionary = {}, prepared_shell: Dictionary = {}) -> Dictionary:
	name = "PassageFinishPass"
	if prepared_storefronts.is_empty():
		_build_threshold_nosings(layout)
		_build_edge_drains()
		_build_floor_wear()
	else:
		_build_fitted_nosings(prepared_storefronts)
		_build_fitted_grates(prepared_shell)
		_build_floor_wear(true)
	_build_pushcarts()
	hours_director = HOURS_SCRIPT.new()
	add_child(hours_director)
	hours_director.build(get_parent() as Node3D, layout, pushcarts)
	geometry_nodes.append_array(hours_director.geometry_nodes)
	print("[PASSAGE FINISH] %d gated draws, %d handcarts, hours active" %
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


## This covers the material seam at the floor datum. The solid floor already
## supports walking. The 6 mm stock sits below the leaves' 20 mm undercut.
func _build_fitted_nosings(storefronts: Dictionary) -> void:
	var blank := BoxMesh.new()
	blank.size = Vector3(1.96,0.006,0.07)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = MetreUV.chart(blank)
	batch.instance_count = storefronts.size()
	var index := 0
	for identity: String in storefronts:
		var door: DoorProp = storefronts[identity]
		var centre := Vector3(door.width * 0.5,blank.size.y * 0.5,0.0)
		var world_pose := door.global_transform * Transform3D(Basis.IDENTITY,centre)
		batch.set_instance_transform(index,global_transform.affine_inverse() * world_pose)
		index += 1
	var stock := MatLib.get_mat("brass_dull",Color(0.66,0.52,0.25),0.48).duplicate() as StandardMaterial3D
	stock.uv1_triplanar = false
	var draw := MultiMeshInstance3D.new()
	draw.name = "PassageThresholdNosings"
	draw.multimesh = batch
	draw.material_override = Surface.surface_for(stock,{"uv_mode":0})
	draw.set_meta("material_key","brass_dull")
	draw.add_to_group("passage_finish_geometry")
	add_child(draw)
	geometry_nodes.append(draw)


## Keep 13 drain covers on each uninterrupted 150 mm outer floor strip.
## The cut floor pieces provide the stock datum and exclude service hatches.
func _build_fitted_grates(shell: Dictionary) -> void:
	var origin: Array = shell.source_origin_blender_m
	var poses: Array[Transform3D] = []
	for stock: Dictionary in shell.closed_stocks:
		var side := EDGE_STOCKS.find(stock.name)
		if side < 0: continue
		var rect: Array = stock.plan_rect_m
		var x := float(rect[0]) + .10 if side == 0 else float(rect[2]) - .10
		var run := (float(rect[3]) - float(rect[1])) / EDGE_GRATE_COUNT
		for i: int in EDGE_GRATE_COUNT:
			var point := Vector3(float(origin[0]) + x, EDGE_GRATE_SIZE.y * .5,
				-float(origin[1]) + float(rect[1]) + run * (float(i) + .5))
			poses.append(Transform3D(Basis.IDENTITY,point))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail := BoxMesh.new()
	rail.size = Vector3(.012,EDGE_GRATE_SIZE.y,EDGE_GRATE_SIZE.z)
	var rail_mesh := MetreUV.chart(rail)
	for x: float in [-.039,.039]:
		mesh.append_from(rail_mesh,0,Transform3D(Basis.IDENTITY,Vector3(x,0,0)))
	var bar := BoxMesh.new()
	bar.size = Vector3(.066,EDGE_GRATE_SIZE.y,.022)
	var bar_mesh := MetreUV.chart(bar)
	for i: int in 17:
		var z := lerpf(-.649,.649,float(i)/16.0)
		mesh.append_from(bar_mesh,0,Transform3D(Basis.IDENTITY,Vector3(0,0,z)))
	var geometry := mesh.commit()
	var rail_finish := MatLib.get_mat("cast_iron",Color(0.29,0.30,0.28),0.52).duplicate() as StandardMaterial3D
	rail_finish.uv1_triplanar = false
	geometry.surface_set_material(0,Surface.surface_for(rail_finish,{"uv_mode":0}))
	# A dark, shallow liner obscures the pavement between the iron bars.
	# It is visual finish only. The floor collision remains unbroken.
	var liner := BoxMesh.new()
	liner.size = Vector3(.066,.001,EDGE_GRATE_SIZE.z)
	var liner_surface := SurfaceTool.new()
	liner_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	liner_surface.append_from(MetreUV.chart(liner),0,Transform3D(Basis.IDENTITY,Vector3.DOWN*.003))
	liner_surface.commit(geometry)
	var liner_finish := MatLib.get_mat("iron_blackened",Color(.13,.12,.11)).duplicate() as StandardMaterial3D
	liner_finish.uv1_triplanar = false
	geometry.surface_set_material(1,Surface.surface_for(liner_finish,{"uv_mode":0}))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = geometry
	batch.instance_count = poses.size()
	for i: int in poses.size():
		batch.set_instance_transform(i,poses[i])
	var draw := MultiMeshInstance3D.new()
	draw.name = "PassageEdgeDrains"
	draw.multimesh = batch
	draw.set_meta("material_key","cast_iron")
	draw.add_to_group("passage_finish_geometry")
	add_child(draw)
	geometry_nodes.append(draw)


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


func _build_floor_wear(fitted := false) -> void:
	# A single transparent batch records the handcarts' recurring wheel paths.
	# It is deliberately irregular and edge-biased: a generic grime wash would
	# flatten the terrazzo instead of explaining how this hall is used.
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never,
		shadows_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

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
	ALBEDO = texture(albedo_tex, UV).rgb * vec3(0.032, 0.026, 0.019);
	ROUGHNESS = texture(rough_tex, UV).r;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.04;
	ALPHA = lane * feather * (0.035 + broken * 0.075);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var stock := MatLib.get_mat("soot")
	material.set_shader_parameter("albedo_tex",stock.albedo_texture)
	material.set_shader_parameter("rough_tex",stock.roughness_texture)
	material.set_shader_parameter("normal_tex",stock.normal_texture)
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
	if fitted:
		# The new transverse crossing runs along X past the last cart.
		marks[7] = [15.30,-59.55,.39,2.3,PI * .5 + .06]
		marks[8] = [12.70,-60.35,.35,2.0,PI * .5 - .02]
	var height := .0015 if fitted else .024
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
				GameBoot.b2g([float(mark[0]), float(mark[1]), height])))
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
