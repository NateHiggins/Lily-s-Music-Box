extends "res://scripts/props/bookshelf_prop.gd"
## Keep the native library and sorting UI; persist only the resident's order.
signal order_changed
var _reported_order: Array = []

func _make_lift_door(y: float) -> void:
	# Same sash coordinates and motion owner; native UVs and distinct stock.
	var model := preload("res://assets/props/bookcase_lift_door.glb").instantiate()
	var native := model.get_node("LiftDoor") as MeshInstance3D
	var mesh := ArrayMesh.new()
	var wood := MatLib.get_mat("wood_dark",Color(.80,.70,.55)).duplicate() as StandardMaterial3D
	wood.uv1_triplanar = false
	var glass := ShaderMaterial.new()
	glass.shader = preload("res://shaders/lamp_glass_surface.gdshader")
	preload("res://scripts/building/v2_clear_glass_finish.gd").apply(glass)
	for index in native.mesh.get_surface_count():
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.append_from(native.mesh,index,Transform3D(Basis.IDENTITY,Vector3(0,y,_case_d*.5+.012)))
		surface.commit(mesh)
		var key: String = native.mesh.surface_get_material(index).resource_name
		mesh.surface_set_material(index,glass if key=="glassish" else wood)
	var door := MeshInstance3D.new()
	door.name = "LiftDoor%d" % _doors.size()
	door.mesh = mesh
	add_child(door)
	_doors.append(door)
	model.free()

func rebuild_books() -> void:
	super.rebuild_books()
	if sorter.order != _reported_order:
		_reported_order = sorter.order.duplicate()
		order_changed.emit()

func restore_order(value: Array) -> void:
	close_panel()
	sorter.order = value.duplicate()
	sorter.held = -1
	sorter.moves = 0
	_door_open = 0.0
	_door_target = 0.0
	_apply_doors()
	rebuild_books()

func panel_closed() -> void:
	sorter.held = -1
	super.panel_closed()

func close_panel() -> void:
	if not is_instance_valid(_panel):
		_panel = null
		return
	# The native panel is owned by the current scene, outside this world.
	# Detach its callback before retirement, then release any live player lock.
	var panel := _panel
	_panel = null
	panel.set("_prop", null)
	if not is_instance_valid(panel.get("_player")): panel.set("_player", null)
	panel.call("close")

func _exit_tree() -> void:
	close_panel()
	super._exit_tree()
