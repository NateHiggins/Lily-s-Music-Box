class_name LightDebugHandle
extends Area3D
## Debug-only physical selection target. The player looks at the real fitting
## and presses E; there is no fixture-name scavenger hunt in a giant menu.

var rig: LightRig
var fixture: Node
var marker: Node3D


func setup(owner_rig: LightRig, owner_fixture: Node) -> void:
	rig = owner_rig
	fixture = owner_fixture
	name = "DebugLightHandle"
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.48
	shape.shape = sphere
	add_child(shape)
	marker = _make_marker()
	add_child(marker)
	marker.visible = false


func set_inspection_enabled(enabled: bool) -> void:
	collision_layer = 1 if enabled else 0
	monitoring = enabled
	monitorable = enabled
	if not enabled:
		marker.visible = false


func set_selected(selected: bool) -> void:
	marker.visible = selected and rig.debug_inspect_enabled


func interact_prompt() -> String:
	if not rig or not rig.debug_inspect_enabled:
		return ""
	return "[E]  Tune this light"


func interact(_player: Node) -> void:
	if rig and rig.debug_inspect_enabled:
		rig.select_debug_fixture(fixture)


func _make_marker() -> Node3D:
	var root := Node3D.new()
	root.name = "SelectionMarker"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.34
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.25, 0.92, 0.72, 0.90)
	material.emission_enabled = true
	material.emission = Color(0.08, 0.65, 0.42)
	material.emission_energy_multiplier = 1.8
	ring.material_override = material
	root.add_child(ring)
	var label := Label3D.new()
	label.text = "LIGHT SELECTED"
	label.position.y = -0.38
	label.font_size = 30
	label.pixel_size = 0.0025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.6, 1.0, 0.82)
	root.add_child(label)
	return root
