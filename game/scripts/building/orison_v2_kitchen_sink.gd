extends TapProp
## Native kitchen faucet and fitted bearers; TapProp retains every water verb.
var _kitchen_plug: Node3D
var _casting_mesh: Mesh
var _plug_pose_closed := false
var _plug_progress := 1.0
var _plug_start := Vector3.ZERO
var supply_stops: Node3D

func _effective_openings() -> Vector2:
	return _valve_openings*supply_stops.openings if is_instance_valid(supply_stops) else _valve_openings

func inspection_owner_for(part: Node3D) -> Node3D:
	return supply_stops if is_instance_valid(supply_stops) and supply_stops.is_ancestor_of(part) else self

func kitchen_rim_height() -> float:
	# The rolled lip bears ON the 905 mm worktop instead of being half buried.
	return .9175 if compact_kitchen else .90

func _build_kitchen_sink(parent: Node3D) -> void:
	var width := .50 if compact_kitchen else .61
	var depth := .38 if compact_kitchen else .46
	var top := kitchen_rim_height()
	var water_mesh := _install_casting(parent)
	_panel_front_z = depth*.5-.0215
	_valve_mount_z = _panel_front_z+VALVE_SEAT_DZ
	var model := preload("res://assets/props/kitchen_faucet.glb").instantiate() as Node3D
	parent.add_child(model)
	var family := "Compact" if compact_kitchen else "Standard"
	for child in model.get_children():
		if child.name != family and not (child.name == "StandardBearers" and not compact_kitchen and has_drainboard):
			model.remove_child(child)
			child.free()
	_skin_kitchen_model(model)
	for index in 2:
		var handle := model.find_child(("HotValve" if index == 0 else "ColdValve")+family,true,false) as Node3D
		assert(handle != null, "Native kitchen valve pivot missing")
		handle.reparent(self)
		_handles.append(handle)
		_handle_turns.append(0.0)
		_handle_wall_mounted.append(true)
		var mark := Label3D.new()
		mark.text = "H" if index == 0 else "C"
		mark.font_size = 40
		mark.pixel_size = .00035
		mark.modulate = Color(.10,.10,.09)
		mark.outline_size = 0
		mark.position = Vector3(0,0,-.066)
		mark.rotation.y = PI
		handle.add_child(mark)
	# Flatten fixed stock for FunctionalProp's existing material batching.
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		draw.reparent(parent)
	model.free()
	var outlet := Marker3D.new()
	outlet.name = "SpoutOutlet"
	outlet.position = Vector3(0,top+.126,.015)
	add_child(outlet)
	_stream = _make_stream(outlet.position+Vector3(0,-.002,0),.254,.007)
	_water_empty_y = top-.137
	_water_full_y = top-.025
	_basin_water = _make_water_surface(Vector3(0,_water_empty_y,0),Vector2(width-.09,depth-.09))
	_basin_water.mesh = water_mesh
	_update_kitchen_plug(1.0)

func _install_casting(parent: Node3D) -> Mesh:
	var model := preload("res://assets/props/kitchen_basins.glb").instantiate() as Node3D
	parent.add_child(model)
	var family := "Standard" if not compact_kitchen else ("Compact" if has_drainboard else "Countertop")
	for child: Node in model.get_children():
		if child.name != family:
			model.remove_child(child)
			child.free()
	_skin_kitchen_model(model)
	_kitchen_plug = model.find_child("Plug"+family,true,false) as Node3D
	_kitchen_plug.reparent(self)
	var water := model.find_child("Water"+family,true,false) as MeshInstance3D
	var water_mesh := water.mesh
	water.get_parent().remove_child(water)
	water.free()
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.name).begins_with("ContinuousCasting"): _casting_mesh = draw.mesh
		# Only the board changes side. Mirroring the whole casting would swap
		# the valve convention and the drain's original slight fore/aft offset.
		if drain_side < 0 and (str(draw.name).begins_with("SlopingDrainboard") or str(draw.name).begins_with("DrainFlute")):
			draw.position.x = -draw.position.x
			draw.scale.x = -draw.scale.x
		draw.reparent(parent)
	model.free()
	return water_mesh

func _process(delta: float) -> void:
	super._process(delta)
	_update_kitchen_plug(delta)

func _update_kitchen_plug(delta: float) -> void:
	if _kitchen_plug == null or _plug_hand != null: return
	var top := kitchen_rim_height()
	var target := Vector3(0,top-.123,.01) if _stopper else Vector3(.095,top-.124,-.045)
	if _plug_pose_closed != _stopper:
		_plug_pose_closed = _stopper
		_plug_start = _kitchen_plug.position
		_plug_progress = 0.0
	_plug_progress = minf(1.0,_plug_progress+delta*4.0)
	# Lift clear of the ferrule before sliding aside. These are presentation
	# values only; the inherited stopper flag remains the water authority.
	_kitchen_plug.position = _plug_start.lerp(target,_plug_progress) + Vector3.UP*.04*sin(PI*_plug_progress)

func install_kitchen_stand() -> void:
	# The original 3B pilot has no passive sink stand record. Give its retained
	# tap a physical native frame after the basin collision has been bounded.
	if fixture != "kitchen_sink" or unit != "3B": return
	var model := preload("res://assets/props/kitchen_faucet.glb").instantiate() as Node3D
	var frame := model.find_child("IndependentFrame",true,false) as Node3D
	var body := StaticBody3D.new()
	body.name = "KitchenStand"
	add_child(body)
	for child: Node in frame.find_children("*","",true,false): child.owner = null
	frame.owner = null
	model.remove_child(frame)
	body.add_child(frame)
	_skin_kitchen_model(frame)
	for draw: MeshInstance3D in frame.find_children("*","MeshInstance3D",true,false):
		var collision := CollisionShape3D.new()
		collision.shape = draw.mesh.create_trimesh_shape()
		body.add_child(collision)
		collision.global_transform = draw.global_transform
		draw.reparent(body)
	frame.free()
	model.free()
	merge_static(body)

func _skin_kitchen_model(model: Node3D) -> void:
	_skin_fixture_model(model)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		assert(draw.mesh.get_surface_count() == 1)
		draw.material_override = draw.get_surface_override_material(0)
		# The cast bearers and the independent pilot frame share the support
		# stand's quiet iron stock. Nickel valve parts retain their own finish.
		if str(draw.mesh.surface_get_material(0).resource_name)=="cast_iron":
			var iron:=MatLib.get_mat("iron_blackened").duplicate() as StandardMaterial3D
			iron.uv1_triplanar=false
			draw.material_override=iron

func _build_primary_interaction() -> void:
	super._build_primary_interaction()
	if fixture != "kitchen_sink": return
	var top := kitchen_rim_height()
	_plug_hand=preload("res://scripts/props/basin_plug.gd").new(self,_kitchen_plug,
		Vector3(0,top-.123,.01),Vector3(.095,top-.124,-.045))
