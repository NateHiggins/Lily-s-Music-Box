class_name OrisonV2FittedDoor
extends DoorProp
## Retained room jambs admit a quarter turn. Roof weather owners keep 100 degrees.
var open_stop_degrees := 90.0
var native_service_joinery := false
const KEYWAY := preload("res://assets/props/door_keyway.glb")
const JOINERY := preload("res://assets/props/domestic_door_leaves.glb")
static var _joinery_meshes: Dictionary = {}
static var _paint_finishes: Dictionary = {}

func _build_service() -> void:
	# The two retained timber core leaves use the Blender joinery family,
	# while keeping service-door mechanics, hinges, lock and semantic owners.
	if native_service_joinery:_build_domestic(false)
	else:super._build_service()

func _build_domestic(is_entry: bool) -> void:
	if _joinery_meshes.is_empty():
		var source := JOINERY.instantiate()
		for draw: MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
			_joinery_meshes[str(draw.name)]=draw.mesh
		source.free()
	var identity := "Leaf%04dx%04d" % [roundi(width*1000),roundi(height*1000)]
	assert(_joinery_meshes.has(identity),"Native V2 door family missing: "+identity)
	var palette := [Color(.38,.34,.25),Color(.25,.34,.29),Color(.35,.27,.24)] \
			if is_entry else [Color(.69,.66,.58),Color(.58,.61,.53),Color(.62,.55,.50)]
	var tint: Color=palette[finish_variant%palette.size()]
	var finish_key := tint.to_html()
	if not _paint_finishes.has(finish_key):
		var paint := MatLib.get_mat("door_paint",tint).duplicate() as StandardMaterial3D
		paint.uv1_triplanar=false
		_paint_finishes[finish_key]=paint
	var leaf := MeshInstance3D.new()
	leaf.name="NativePaintedJoinery";leaf.mesh=_joinery_meshes[identity]
	leaf.material_override=_paint_finishes[finish_key];_body.add_child(leaf)
	var brass := MatLib.get_mat("door_brass")
	_build_knob_set(brass)
	if is_entry:
		_box(_body,Vector3(width-.13,.17,.008),Vector3(width*.5,.13,-.029),brass)
		_cyl(_body,.014,.018,Vector3(width*.5,1.49,-.034),brass,90)
		var iron := MatLib.get_mat("cast_iron",Color(.42,.40,.36))
		_box(_body,Vector3(.22,.055,.065),Vector3(width-.18,height-.115,-.055),iron)
		var arm := _box(_body,Vector3(.33,.018,.018),Vector3(width-.34,height-.07,-.065),iron)
		arm.rotation.z=-.16

func _build_knob_set(_material: StandardMaterial3D) -> void:
	if native_service_joinery and knob_mesh!=null:
		# The retained service authority uses a 44 mm timber leaf here.
		# Seat its backplates on that native face, not the older 52 mm metal skin.
		for face: float in [-1.0,1.0]:
			var part:=MeshInstance3D.new();part.mesh=knob_mesh
			part.material_override=MatLib.get_mat("door_brass")
			part.position=Vector3(width-.085,1.0,face*.022)
			part.rotation.y=PI if face<0 else 0
			_body.add_child(part)
		return
	super._build_knob_set(MatLib.get_mat("door_brass"))

## Only the visible slab is parted. The retained solid physics leaf still
## blocks actors and owns the original interaction, hinge and lock state.
func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var is_slab := parent == _body and knob_mesh != null \
			and is_equal_approx(size.x, width - .02) \
			and is_equal_approx(size.y, height - .02) \
			and (is_equal_approx(size.z, .044) or is_equal_approx(size.z, .052))
	if not is_slab:
		return super._box(parent, size, at, material)
	var center := Vector2(width - .085, .884)
	var lo := center - Vector2.ONE * .030
	var hi := center + Vector2.ONE * .030
	# Four adjoining stocks leave precisely the native insert's footprint.
	for rect: Rect2 in [Rect2(.01, .01, lo.x - .01, height - .02),
			Rect2(hi.x, .01, width - .01 - hi.x, height - .02),
			Rect2(lo.x, .01, .060, lo.y - .01),
			Rect2(lo.x, hi.y, .060, height - .01 - hi.y)]:
		super._box(parent, Vector3(rect.size.x, rect.size.y, size.z),
				Vector3(rect.get_center().x, rect.get_center().y, at.z), material)
	var native := KEYWAY.instantiate()
	var source := native.get_node("Keyway52" if size.z > .05 else "Keyway44") as MeshInstance3D
	var insert := MeshInstance3D.new()
	insert.name = "ThroughKeyway"
	insert.mesh = source.mesh
	insert.position = Vector3(center.x, center.y, at.z)
	insert.material_override = material
	parent.add_child(insert)
	native.free()
	return insert

func _ready() -> void:
	super._ready()
	if open:
		_body.sync_to_physics=false
		_body.rotation.y=motion_target_angle(true)
		_body.force_update_transform()
		_body.sync_to_physics=true

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-open_stop_degrees if swing_out else open_stop_degrees) if want_open else 0.0
