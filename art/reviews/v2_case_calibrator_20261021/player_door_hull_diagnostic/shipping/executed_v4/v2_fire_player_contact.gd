extends RefCounted
## Player-only contact stock. Every original door collider remains authoritative
## for mechanisms, carried parts, NPCs and inspection. No saved or repair facts.
const LAYER:=1<<21
var ready:=false
var enabled:=true
var active:=false
var errors: Array[String]=[]
var pairs: Array[Dictionary]=[]
var _player: PlayerController
var _added: Array[PhysicsBody3D]=[]

func configure(player: PlayerController,stations: Dictionary) -> bool:
	if _player!=null or player==null or player._native_contact_agent!=null or stations.is_empty():return false
	_player=player
	for reference: WeakRef in stations.values():
		var actor: Node3D=reference.get_ref()
		if actor==null or not actor._bodies.has("door") or not actor._stock.has("door"):
			return _fail("missing native door authority")
		var original: PhysicsBody3D=actor._bodies.door
		if original.get_parent()!=actor._door_pivot or not original.transform.is_equal_approx(Transform3D.IDENTITY) or (original.collision_layer&1)==0 or actor._stock.door.is_empty():
			return _fail("unexpected native door collision frame")
		var proxy:=StaticBody3D.new();proxy.name="PlayerContactStock";proxy.collision_layer=LAYER;proxy.collision_mask=0
		original.add_child(proxy);pairs.append({"original":original,"proxy":proxy})
		for record: Dictionary in actor._stock.door:
			if record.shape is not ConvexPolygonShape3D or record.shape.points.size()<4 or not record.frame.is_finite():return _fail("invalid native constraint hull")
			var leaf:=CollisionShape3D.new();leaf.shape=record.shape;leaf.transform=record.frame;proxy.add_child(leaf)
	ready=pairs.size()==stations.size()
	if not ready or not player.install_native_contact_agent(self):return _fail("player contact installation refused")
	return true

func _fail(reason: String) -> bool:
	errors.append(reason);release();return false

func _supported() -> bool:
	return is_instance_valid(_player) and _player._capsule!=null and _player._shape!=null \
		and _player._shape.shape==_player._capsule and absf(_player._capsule.radius-PlayerController.BODY_RADIUS)<.000001 \
		and _player._shape.basis.is_equal_approx(Basis.IDENTITY) \
		and _player.global_basis.y.normalized().dot(Vector3.UP)>.999999 \
		and _player.global_basis.get_scale().is_equal_approx(Vector3.ONE)

func sync() -> void:
	var wanted: bool=ready and enabled and _supported() and not _player.noclip
	if wanted==active:return
	if wanted:
		# Validate the whole substitution before changing a single pair. The
		# proxy is parented to the exact moving part and reuses its query hulls.
		for pair: Dictionary in pairs:
			if not is_instance_valid(pair.original) or not is_instance_valid(pair.proxy) or pair.proxy.get_parent()!=pair.original or pair.proxy.get_child_count()==0 or pair.original in _player.get_collision_exceptions():return
		for pair: Dictionary in pairs:
			_player.add_collision_exception_with(pair.original);_added.append(pair.original)
		_player.set_native_contact_layers(LAYER);active=true
	else:
		for original: PhysicsBody3D in _added:
			if is_instance_valid(original):_player.remove_collision_exception_with(original)
		_added.clear()
		if is_instance_valid(_player):_player.set_native_contact_layers(0)
		active=false

func release() -> void:
	enabled=false;sync()
	for pair: Dictionary in pairs:
		if is_instance_valid(pair.proxy):pair.proxy.free()
	pairs.clear();ready=false;_player=null
