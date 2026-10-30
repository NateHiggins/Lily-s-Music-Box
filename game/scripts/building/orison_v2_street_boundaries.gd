extends Node3D
## Open exterior exploration. Native scaffold framing keeps its front-door
## registration; only the distant temporary radius limits normal locomotion.
const SOURCE := "res://data/orison_v2/exterior/construction_shed.json"
const NATIVE := "res://assets/props/construction_shed.glb"
const NATIVE_ORIGIN := Vector3(22.25,0,0)
const EXPLORATION_RADIUS_M := 450.0
const EXPLORATION_SEGMENTS := 256
var startup_failed:=false
var _programmes: Variant
var _exterior_safety_net: SafetyNet
var _exterior_ground_zone := AABB()
var _exterior_world: OrisonV2RuntimeRoot

func configure(programmes: Variant) -> bool:
	if is_inside_tree() or programmes==null:return false
	_programmes=programmes
	return true

static func valid_source_header(source: Variant) -> bool:
	if source is not Dictionary: return false
	var version: Variant = source.get("schema_version")
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and float(version) == 1.0 \
			and source.get("frame") == "ORISON_FRONT_DOOR_THRESHOLD" \
			and source.get("boxes") is Array and source.get("lights") is Array

func _ready() -> void:
	if _programmes==null:_programmes=preload("res://scripts/building/orison_v2_public_region_programmes.gd").load_default()
	if _programmes==null:startup_failed=true;push_error("Construction public programme is invalid");return
	var registered: Transform3D=_programmes.body_transform("StreetBoundaries")
	if not registered.origin.is_finite():startup_failed=true;push_error("Construction frame is invalid");return
	transform=registered
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not valid_source_header(source):
		push_error("Street boundaries require the supported front-door source frame")
		return
	_mount_exploration_limit()
	_register_exterior_ground()
	_mount_native_stock()
	for record: Dictionary in source.boxes:
		# The native recipe replaces quartered oak with raw site timber, while
		# the notice retains paper. A source-stock change requires a new native
		# recipe/export; silently binding the old wood to masonry is invalid.
		var expected_stock := "paper" if str(record.id)=="ClosureNoticeBoard" else "oak_quartered"
		assert(str(record.material)==expected_stock,"Construction source stock requires a matching native recipe: "+str(record.id))
		var body := StaticBody3D.new()
		body.name = record.id
		body.position = Vector3(record.center[0], record.center[1], record.center[2])
		body.rotation_degrees.z = float(record.get("roll_degrees", 0.0))
		var size := Vector3(record.size[0], record.size[1], record.size[2])
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	for record: Dictionary in source.lights:
		var light := LightFixtureProp.new()
		light.prop_type = "cage_bulb"
		light.name = record.id
		light.position = Vector3(record.center[0], record.center[1], record.center[2])
		light.range_clamp = 5.0
		light.energy_scale = 0.65
		light.navigation_light = true
		light.standby_scale = 0.35
		add_child(light)

func _mount_native_stock() -> void:
	# Visual stock has metre UVs and real lapped joints. Existing source boxes
	# remain the collision authority; no imported mesh collision is generated.
	var model := (load(NATIVE) as PackedScene).instantiate() as Node3D
	model.name="NativeConstructionStock"
	model.position=NATIVE_ORIGIN
	var finishes := {}
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in draw.mesh.get_surface_count():
			var imported := draw.get_active_material(surface)
			assert(imported!=null and imported.resource_name.begins_with("CATALOG_"),"Construction stock requires a catalogue partition")
			var key := imported.resource_name.trim_prefix("CATALOG_")
			assert(MatLib.SETS.has(key),"Unknown construction finish: "+key)
			if not finishes.has(key):
				var stock := MatLib.get_mat(key).duplicate() as StandardMaterial3D
				stock.uv1_triplanar=false;stock.uv2_triplanar=false
				stock.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				if key.begins_with("site_softwood"):
					stock.texture_repeat=false
					stock.uv1_scale=Vector3.ONE
				stock.set_meta("v2_surface_stock",key)
				finishes[key]=stock
			draw.set_surface_override_material(surface,finishes[key])
	add_child(model)

func _mount_exploration_limit() -> void:
	# Temporary, non-diegetic physics wall. It neither changes player position
	# nor writes narrative/save state; the later sleep/bed event has no owner here.
	var faces := PackedVector3Array()
	for index in EXPLORATION_SEGMENTS:
		var angle := TAU * index / EXPLORATION_SEGMENTS
		var next := TAU * (index + 1) / EXPLORATION_SEGMENTS
		var a := Vector3(cos(angle)*EXPLORATION_RADIUS_M,-128,sin(angle)*EXPLORATION_RADIUS_M)
		var b := Vector3(a.x,256,a.z)
		var c := Vector3(cos(next)*EXPLORATION_RADIUS_M,256,sin(next)*EXPLORATION_RADIUS_M)
		var d := Vector3(c.x,-128,c.z)
		faces.append_array(PackedVector3Array([a,c,b,a,d,c]))
	var body := StaticBody3D.new()
	body.name = "TemporaryExteriorLimit"
	body.add_to_group("temporary_exterior_limit")
	body.set_meta("radius_m",EXPLORATION_RADIUS_M)
	var collision := CollisionShape3D.new()
	collision.name = "RadialWall"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _register_exterior_ground() -> void:
	if _exterior_safety_net != null: return
	var world := get_parent() as OrisonV2RuntimeRoot
	if world == null: return
	_exterior_world = world
	if world.safety_net == null:
		# Exterior composition precedes the existing safety owner. Bind its
		# actual creation, rather than guessing a deferred-frame delay.
		if not world.child_entered_tree.is_connected(_safety_owner_added):
			world.child_entered_tree.connect(_safety_owner_added)
		return
	if world.child_entered_tree.is_connected(_safety_owner_added):
		world.child_entered_tree.disconnect(_safety_owner_added)
	assert(world.adapter != null)
	var ground := world.adapter.root.get_node("Ground") as Node3D
	var apron := ground.find_child("DistantApron",true,false) as Node3D
	assert(apron != null,"Exploration requires its actual authored ground")
	var region := AABB()
	var found := false
	for draw: MeshInstance3D in apron.find_children("*","MeshInstance3D",true,false):
		var bounds: AABB = draw.global_transform * draw.get_aabb()
		region = region.merge(bounds) if found else bounds
		found = true
	assert(found and region.size.x >= EXPLORATION_RADIUS_M*2. and region.size.z >= EXPLORATION_RADIUS_M*2.)
	# SafetyNet already owns non-finite and below-world recovery. Register the
	# real imported terrain footprint through its existing API; its old240m
	# fallback must not become a second, silently teleporting travel limit.
	var high := maxf(region.end.y,256.)
	region.position.y = SafetyNet.FLOOR_OF_THE_WORLD
	region.size.y = high-region.position.y
	_exterior_ground_zone = region
	_exterior_safety_net = world.safety_net
	_exterior_safety_net.exempt_zones.append(region)

func _safety_owner_added(node: Node) -> void:
	if node is SafetyNet: _register_exterior_ground()

func _unregister_exterior_ground() -> void:
	if is_instance_valid(_exterior_safety_net):
		_exterior_safety_net.exempt_zones.erase(_exterior_ground_zone)
	_exterior_safety_net = null
	if is_instance_valid(_exterior_world) and _exterior_world.child_entered_tree.is_connected(_safety_owner_added):
		_exterior_world.child_entered_tree.disconnect(_safety_owner_added)
	_exterior_world = null

func _exit_tree() -> void:
	_unregister_exterior_ground()
