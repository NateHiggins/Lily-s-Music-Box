extends TapProp
## Native kitchen faucet and fitted bearers; TapProp retains every water verb.

func kitchen_rim_height() -> float:
	# The rolled lip bears ON the 905 mm worktop instead of being half buried.
	return .9175 if compact_kitchen else .90

func _build_kitchen_sink(parent: Node3D) -> void:
	var width := .50 if compact_kitchen else .61
	var depth := .38 if compact_kitchen else .46
	var top := kitchen_rim_height()
	_open_rect_basin(parent, Vector3(0, top, 0), width, depth, .15, ENAMEL)
	_box_on(parent, Vector3(width+.03,.16,.035), Vector3(0,top+.075,depth*.5-.004), ENAMEL)
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
	_build_stopper(Vector3(0,top-.135,.01))
	if has_drainboard: _build_drainboard(parent,width,depth,top)
	_add_use_wear(parent,Vector3(-width*.35,top+.004,-depth*.37),true)
	_stream = _make_stream(outlet.position+Vector3(0,-.002,0),.254,.007)
	_water_empty_y = top-.137
	_water_full_y = top-.025
	_basin_water = _make_water_surface(Vector3(0,_water_empty_y,0),Vector2(width-.09,depth-.09))

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
