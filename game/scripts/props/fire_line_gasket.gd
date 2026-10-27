extends RigidBody3D
## Retained native washer: direct hand placement, authored seat and storage.
var actor: Node3D
var draw: MeshInstance3D
var _held:=false
var _observed_seated:=false
var home_position:=Vector3.ZERO
const SNAP_RADIUS:=.025

func configure(owner_actor: Node3D) -> void:
	actor=owner_actor;draw=actor._spare_gasket
	home_position=draw.position;position=home_position;mass=.012;freeze=true;collision_layer=1;collision_mask=1
	physics_material_override=PhysicsMaterial.new();physics_material_override.friction=.85
	var bounds: AABB=draw.mesh.get_aabb()
	var cuts: Array[float]=[bounds.position.y,bounds.end.y]
	for shape: ConvexPolygonShape3D in preload("res://scripts/props/native_annular_collision.gd").build(draw.mesh,cuts,32):
		var collision:=CollisionShape3D.new();collision.shape=shape;add_child(collision)
	sync()

func seat_position() -> Vector3:return actor._coupling.position+Vector3(0,.020,0)

func seatable() -> bool:
	if not actor.door_open or actor.coupling_made_up:return false
	var distance: float=position.distance_to(seat_position())
	return distance<=SNAP_RADIUS and distance<position.distance_to(home_position)

func _fit() -> void:
	actor.gasket_seated=true;freeze=true;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	position=seat_position();basis=Basis.IDENTITY;sync()
	if actor._click!=null:actor._click.play()
	# Fitting alone does not manufacture the separate seen/inspection fact.
	# The existing release owner commits the final snapshot exactly once.

func sync() -> void:
	if actor==null or draw==null:return
	if actor.gasket_seated:
		freeze=true;position=seat_position();basis=Basis.IDENTITY
	elif _observed_seated and not _held:
		position=home_position;basis=Basis.IDENTITY
	_observed_seated=actor.gasket_seated
	draw.global_transform=global_transform;draw.visible=true

func observe(hit: Dictionary) -> void:
	if actor.gasket_seen or not actor.door_open or actor.coupling_made_up:return
	var player: Node=actor.get_tree().get_first_node_in_group("player_controller")
	if player==null or not player.inspecting() or player.inspect_owner!=actor:return
	var local: Vector3=actor._coupling.to_local(hit.position)
	var surface_y: float=.020+float(actor._joint_stock.data.dimensions.gasket_thickness_m) if actor.gasket_seated else .020
	var radius: float=Vector2(local.x,local.z).length()
	if absf(local.y-surface_y)>.0001 or radius<.01915 or radius>.02265:return
	actor.gasket_seen=true;actor.manipulation_changed.emit()

func manipulation_target(hit: Dictionary) -> Dictionary:
	if actor==null or not actor.door_open:return {}
	if actor.gasket_seated:
		observe(hit)
		if actor.coupling_made_up:return {}
	return {"owner":actor,"part":self,"frame":actor,"kind":"free",
		"read_basis":func():return basis,"write_basis":_rotate,
		"read":func():return position,"write":func(value: Vector3):
			if _held:_carry(value),
		"begin":func():
			if not actor._claim("gasket"):return false
			_held=true;actor.gasket_seated=false;return true,
		"owns":func():return _held and actor._hand=="gasket",
		"end":func():
			_held=false
			if seatable():_fit()
			else:position=home_position;basis=Basis.IDENTITY;sync()
			actor._release()}
func _rotate(value: Basis) -> void:
	if _held and value.is_finite():basis=value.orthonormalized();sync()

func _carry(value: Vector3) -> void:
	if not value.is_finite() or value.length_squared()>=100000000.:return
	position=value;sync()

func snapshot() -> Dictionary:
	var q: Quaternion=basis.get_rotation_quaternion()
	return {"position":[position.x,position.y,position.z],"rotation":[q.x,q.y,q.z,q.w]}

static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2:return false
	for key: String in ["position","rotation"]:
		if value.get(key) is not Array or value[key].size()!=(3 if key=="position" else 4):return false
		for item: Variant in value[key]:
			if typeof(item) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(item)):return false
	var q:=Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3])
	return Vector3(value.position[0],value.position[1],value.position[2]).length()<10000. and absf(q.length_squared()-1.)<.0001

func restore(value: Dictionary) -> void:
	_held=false;linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	# Preserve validated older loose poses exactly; every new release parks
	# or seats the washer and there is no settling pass after restoration.
	position=Vector3(value.position[0],value.position[1],value.position[2])
	basis=Basis(Quaternion(value.rotation[0],value.rotation[1],value.rotation[2],value.rotation[3]))
	freeze=true;sync()

