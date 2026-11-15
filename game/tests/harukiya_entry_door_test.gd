extends Node3D
## DRAFT. Actual native replacement frame and actual DoorProp subclass.
const Entry = preload("res://scripts/building/orison_v2_bar_entry.gd")
const NativeDoor = preload("res://scripts/building/orison_v2_bar_entry_door.gd")
var failures: Array[String] = []
var checks := 0
var door: NativeDoor
var frame: Node3D
var contact_cases: Array = []

func _enter_tree() -> void:
	RealityState.persistence_enabled = false

func _ready() -> void:
	var spec := Entry.read_spec()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var marker := {}
	for floor: Dictionary in layout.floors:
		if str(floor.id) != "F01": continue
		for row: Dictionary in floor.markers:
			if str(row.id) == "F01_BAR_RED_DOOR": marker = row
	if not _check(not marker.is_empty(), "retained red-door marker"): _finish(); return
	frame = Entry.prepare_model(spec)
	if not _check(frame != null,"actual native replaced frame prepared"): _finish(); return
	add_child(frame)
	var frame_shapes := frame.find_children("*","CollisionShape3D",true,false)
	_check(not frame_shapes.is_empty(),"native frame has real collision")
	for shape: CollisionShape3D in frame_shapes:
		_check(not shape.disabled and shape.shape is ConcavePolygonShape3D and not shape.shape.get_faces().is_empty(),"native frame collision remains enabled")
	door = NativeDoor.new(); door.name = str(marker.id)
	door.width = float(marker.w); door.height = float(marker.h)
	door.leaf_state = str(marker.leaf); door.swing_out = str(marker.get("swing","")) == "out"
	door.door_kind = str(marker.get("subtype","storefront"))
	door.finish_variant = int(marker.get("finish_variant",0))
	door.position = GameBoot.b2g(marker.pos)
	door.rotation.y = -deg_to_rad(float(marker.yaw_deg))
	add_child(door)
	if not _check(not door.native_failed,"native leaf built"): _finish(); return
	_check(door.name == "F01_BAR_RED_DOOR" and is_equal_approx(door.width,.9) and is_equal_approx(door.height,2.05),"retained identity and dimensions")
	_check(door.position.is_equal_approx(GameBoot.b2g([4.15,-33.95,-2.8])) and is_equal_approx(door.rotation.y,-PI/2),"retained source placement and negative runtime yaw")
	var offset := DoorProp.HINGE_SETBACK * (-1.0 if door.swing_out else 1.0)
	_check(is_equal_approx(door._body.position.z,-offset) and is_equal_approx(door.native_leaf.position.z,offset),"hinge setback applied exactly once")
	_check(door.is_in_group("passage_doors") and door._body is AnimatableBody3D,"inherited passage/body owner")
	var shapes: Array[CollisionShape3D] = []
	var hardware := 0
	for child in door._body.get_children():
		if child is CollisionShape3D: shapes.append(child)
		if child is MeshInstance3D: hardware += 1
	if not _check(shapes.size()==1 and shapes[0].shape is BoxShape3D,"exact one inherited leaf box"): _finish(); return
	var leaf_shape := shapes[0]
	var bounds := door.closed_leaf_bounds()
	_check(leaf_shape.shape.size == bounds.size and leaf_shape.position.is_equal_approx(bounds.get_center()+Vector3.BACK*offset),"inherited slab dimensions and placement")
	_check(not leaf_shape.disabled and door._body.collision_layer != 0 and door._body.collision_mask != 0,"leaf collision remains live")
	_check(door.native_leaf.find_children("*","CollisionObject3D",true,false).is_empty(),"no duplicate collider hidden under native leaf")
	_check(hardware>0 and door._fixed.get_child_count()>0,"inherited moving and fixed hardware survive native replacement")
	var key := door._body.get_node_or_null("KeyholeControl") as Area3D
	_check(key != null and key.position.is_equal_approx(Vector3(door.width-.085,.89,offset)),"inherited key target remains on leaf")
	# Store actual native local points; independently predict each world position.
	var probes: Array[Dictionary] = []
	for draw: MeshInstance3D in door.native_leaf.find_children("*","MeshInstance3D",true,false):
		var pose := StaticMeshBatcher._relative_xform(draw,door.native_leaf)
		var points: PackedVector3Array = draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		probes.append({"draw":draw,"pose":pose,"points":points,"hull":draw.mesh.create_convex_shape(true,false)})
	_check(probes.size()==spec.door_parts.size(),"complete native leaf inventory")
	var fixed_pose := door._fixed.global_transform
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target := door.motion_target_angle(true)
	# Do not use motion_clear as architecture proof: it checks people/stock only.
	# Query real frame collision at every two degrees, with no erased floor,
	# raised support, disabled frame or special collision-layer exclusions.
	for step in 51:
		var angle := target*float(step)/50.0
		_check(door.valid_mechanism({"angle":angle}),"authored travel accepted " + str(step))
		door.restore_mechanism({"angle":angle})
		door.set_physics_process(false)
		_check(is_equal_approx(float(door.mechanism_snapshot().angle),angle),"inherited mechanism roundtrip " + str(step))
		_check(door._fixed.global_transform == fixed_pose,"fixed hardware does not swing " + str(step))
		var expected := door.global_transform * Transform3D(Basis(Vector3.UP,angle),Vector3(0,0,-offset)) * Transform3D(Basis.IDENTITY,Vector3(0,0,offset))
		for probe: Dictionary in probes:
			var draw: MeshInstance3D = probe.draw
			var max_error := 0.0
			for point: Vector3 in probe.points:
				max_error=maxf(max_error,(draw.global_transform*point).distance_to(expected*probe.pose*point))
			_check(max_error<.00001,"native vertex hinge frame " + str(draw.name) + " " + str(step))
		_query_frame(leaf_shape.shape,leaf_shape.global_transform,"inherited slab",angle)
		for probe: Dictionary in probes:
			_query_frame(probe.hull,probe.draw.global_transform,str(probe.draw.name)+" conservative visual hull",angle)
	_check(contact_cases.is_empty(),"native frame clears inherited slab and conservative visual envelopes throughout sampled travel")
	# Invalid durable mechanism must not move the live leaf.
	var stable := door.mechanism_snapshot()
	_check(not door.valid_mechanism({"angle":target*2.0}),"out-of-travel mechanism rejected")
	door.restore_mechanism({"angle":target*2.0})
	_check(door.mechanism_snapshot()==stable,"invalid restore leaves live mechanism unchanged")
	_finish()

func _query_frame(shape: Shape3D, pose: Transform3D, label: String, angle: float) -> void:
	if not _check(shape != null,"query shape " + label): return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape; query.transform=pose; query.margin=0.0
	query.collision_mask=0xFFFFFFFF; query.collide_with_bodies=true; query.collide_with_areas=false
	query.exclude=[door._body.get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(query,128)
	for hit: Dictionary in hits:
		# Only actual replacement native-frame contacts qualify this bounded check.
		if frame.is_ancestor_of(hit.collider): contact_cases.append({"angle_deg":rad_to_deg(angle),"part":label,"frame":str(frame.get_path_to(hit.collider))})

func _check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok: failures.append(label); push_error(label)
	return ok

func _finish() -> void:
	if is_instance_valid(door): door.free()
	if is_instance_valid(frame): frame.free()
	print(JSON.stringify({"test":"harukiya_entry_door", "checks":checks,"failures":failures,"contacts":contact_cases,"scope":"actual native replacement frame, sampled leaf and conservative visual hull clearance"}))
	get_tree().quit(0 if failures.is_empty() else 1)
