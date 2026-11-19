extends Node3D
## The player's capsule remains the movement authority. The hoop rolls over
## sampled ground on its own axis, ahead of the player and inside the stick's reach.
const STOCK := preload("res://assets/props/rolling_hoop.glb")
const RADIUS := 0.37
const LEAD := 1.84
const GUIDE_SIDE := 0.43
const SPEED_MULTIPLIER := 1.35

var _wheel: Node3D
var _stick: Node3D
var _heading := Vector3.ZERO
var _centre := Vector3.ZERO
var _spin := 0.0
var _probe := SphereShape3D.new()


func _ready() -> void:
	top_level = true
	_probe.radius = RADIUS - 0.035
	_wheel = Node3D.new()
	_stick = Node3D.new()
	_wheel.name = "Wheel"
	_stick.name = "GuideStick"
	add_child(_wheel)
	add_child(_stick)
	_stock_parts(_wheel, _stick)
	hide()


static func _stock_parts(wheel: Node3D, stick: Node3D) -> void:
	var stock := STOCK.instantiate()
	for source: MeshInstance3D in stock.find_children("*", "MeshInstance3D", true, false):
		var draw := MeshInstance3D.new()
		draw.name = source.name
		draw.mesh = source.mesh
		var key := str(source.name).get_slice("__", 1)
		var tint := Color(.72, .49, .33) if key == "timber" else Color(.52, .50, .44)
		var finish := MatLib.get_mat(key, tint).duplicate() as StandardMaterial3D
		finish.uv1_triplanar = false
		finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		draw.material_override = finish
		var parent := wheel if str(source.name).begins_with("Hoop__") else stick
		parent.add_child(draw)
	stock.free()


static func draw_in_case(parent: Node3D) -> void:
	var wheel := Node3D.new()
	var stick := Node3D.new()
	parent.add_child(wheel)
	parent.add_child(stick)
	wheel.rotation.z = PI * 0.5
	wheel.position.y = 0.008
	wheel.scale = Vector3.ONE * 0.115
	stick.rotation.x = PI * 0.5
	stick.position = Vector3(0.011, 0.012, 0.064)
	stick.scale = Vector3.ONE * 0.115
	_stock_parts(wheel, stick)


func rest() -> void:
	hide()
	_heading = Vector3.ZERO


func guide(player: CharacterBody3D, wish: Vector3, delta: float) -> bool:
	var forward := -player.global_basis.z
	if wish.length_squared() < 0.04 or wish.normalized().dot(forward) < 0.48:
		rest()
		return false
	var direction := wish.normalized()
	var heading := direction if _heading == Vector3.ZERO else _heading.slerp(direction, minf(1.0, delta * 9.0)).normalized()
	var feet := player.global_position
	# Run a little to the right of the wheel. The stick can reach the rim and
	# the rider sees the opening of the hoop instead of its edge.
	var ahead := feet + heading * LEAD - heading.cross(Vector3.UP) * GUIDE_SIDE
	var space := player.get_world_3d().direct_space_state
	var floor_ray := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.23,
			ahead + Vector3.DOWN * 0.20, player.collision_mask, [player.get_rid()])
	var ground := space.intersect_ray(floor_ray)
	if ground.is_empty() or (ground.normal as Vector3).y < 0.75:
		rest()
		return false
	var centre: Vector3 = ground.position + Vector3.UP * (RADIUS + 0.005)
	var start := Vector3(feet.x, maxf(centre.y, feet.y + RADIUS + 0.005), feet.z)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _probe
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	query.transform.origin = centre
	if not space.intersect_shape(query, 1).is_empty():
		rest()
		return false
	# On deployment the hoop must fit all the way from the player. Once rolling,
	# sweep from its last occupied position to catch corners while turning.
	query.transform.origin = _centre if visible else start
	query.motion = centre - query.transform.origin
	if space.cast_motion(query)[0] < 0.995:
		rest()
		return false
	_heading = heading
	_centre = centre
	return true


func present(player: CharacterBody3D, camera: Camera3D, travel: Vector3) -> void:
	var metre := travel.dot(_heading)
	if _heading == Vector3.ZERO or metre <= 0.0001 or not player.is_on_floor():
		rest()
		return
	_spin = fposmod(_spin - metre / RADIUS, TAU)
	var right := _heading.cross(Vector3.UP)
	var upright := Basis(right, Vector3.UP, -_heading)
	_wheel.global_transform = Transform3D(upright * Basis(Vector3.RIGHT, _spin), _centre)
	var grip := camera.global_position + player.global_basis.x * 0.38 \
			- Vector3.UP * 0.39 - player.global_basis.z * 0.28
	var contact := _centre - _heading * (RADIUS * 0.8) + Vector3.UP * (RADIUS * 0.6)
	var shaft := grip - contact
	var up := shaft.normalized()
	right = (right - up * right.dot(up)).normalized()
	var posed_stick := Basis(right, up * shaft.length(), right.cross(up))
	_stick.global_transform = Transform3D(posed_stick, grip)
	show()
