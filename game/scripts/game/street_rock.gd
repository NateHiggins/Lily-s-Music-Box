extends RigidBody3D
## Reports physical tricks from the current kick only. Resting stones can sleep.
signal trick_scored(trick: String, points: int)

const ART := preload("res://assets/props/street_rock.glb")
const SURFACE := preload("res://scripts/building/surface_pass.gd")
const TRACK_TIME := 1.45
const SETTLED_SPEED := 0.16

var _size: float
var _track_left := 0.0
var _base_y := 0.0
var _air_turn := 0.0
var _banked := false
var _spun := false
var _incoming := Vector3.ZERO


func build(stone_size: float, yaw: float) -> void:
	_size = stone_size
	rotation.y = yaw
	mass = 0.45 * _size
	continuous_cd = true
	max_contacts_reported = 4
	linear_damp = 0.7
	angular_damp = 0.9
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.52
	physics_material_override.bounce = 0.34
	var art := ART.instantiate() as Node3D
	art.scale *= _size
	add_child(art)
	var source := MatLib.get_mat("limestone", Color(0.61, 0.58, 0.51)).duplicate() as StandardMaterial3D
	source.uv1_triplanar = false
	var material := SURFACE.surface_for(source, {"uv_mode": 0}, "street_rock")
	for mesh: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = material
		var hull := mesh.mesh.create_convex_shape(true, false)
		var points := hull.points
		for index in points.size():
			points[index] = mesh.transform * points[index] * _size
		hull.points = points
		var shape := CollisionShape3D.new()
		shape.shape = hull
		add_child(shape)


func kick(direction: Vector3, speed: float, lift: float, spin: float) -> void:
	_base_y = position.y
	_track_left = TRACK_TIME
	_air_turn = 0.0
	_banked = false
	_spun = false
	sleeping = false
	linear_velocity *= 0.33
	angular_velocity *= 0.33
	_incoming = linear_velocity + direction * speed + Vector3.UP * lift
	apply_central_impulse((_incoming - linear_velocity) * mass)
	apply_torque_impulse(direction.cross(Vector3.UP) * spin * _size)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _track_left <= 0.0:
		return
	_track_left -= state.step
	if not _spun and state.transform.origin.y - _base_y > 0.16:
		_air_turn += state.angular_velocity.length() * state.step
		if _air_turn >= TAU:
			_spun = true
			trick_scored.emit("Air Spin", 75)
	if not _banked:
		for index in state.get_contact_count():
			var normal := state.get_contact_local_normal(index)
			if absf(normal.y) < 0.48 and absf(_incoming.dot(normal)) > 1.1 \
					and state.get_contact_collider_object(index) is StaticBody3D:
				_banked = true
				trick_scored.emit("Bank Shot", 65)
				break
	_incoming = state.linear_velocity
	if state.linear_velocity.length_squared() < SETTLED_SPEED * SETTLED_SPEED:
		_track_left = 0.0
