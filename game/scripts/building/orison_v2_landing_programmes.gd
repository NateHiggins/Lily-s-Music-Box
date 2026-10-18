extends RefCounted
## Actual floor owners, landmarks and unit decisions; no duplicated geometry.
var errors: Array[String]=[]
var _bindings: Dictionary={}
var _letters: Array[WeakRef]=[]
var _titles: Array[Dictionary]=[]
var _frame: WeakRef
var _rooms: Array[Dictionary]=[]
var _floor_height:=0.0
const Footprints=preload("res://scripts/building/orison_v2_space_footprints.gd")

func setup(world: OrisonV2RuntimeRoot) -> bool:
	if not _bindings.is_empty():return false
	var frame:=world.adapter.root as Node3D
	for space: Dictionary in world.layout.spaces:
		if not space.has("landing_core"):continue
		var faults:=Footprints.programme_errors(world.layout,space)
		if not faults.is_empty():errors.append_array(faults);return false
		var identity:=str(space.id);var floor:=str(space.level)
		var core:=frame.get_node_or_null(str(space.landing_core)) as Node3D
		var semantic:=frame.get_node_or_null(identity) as Node3D
		var sign:=frame.get_node_or_null("Wayfinding/"+str(space.landing_core)+"_Plaque") as Node3D
		if core==null or semantic==null or sign==null:errors.append("missing landing owner or floor plaque: "+identity);return false
		if str(semantic.get_meta("landing_core",""))!=str(space.landing_core) or semantic.get_meta("floor_platforms",[])!=space.floor_platforms or semantic.get_meta("programme_anchors",[])!=space.programme_anchors:errors.append("landing semantic ownership differs from authored source: "+identity);return false
		var supports: Array[WeakRef]=[];var landmarks: Array[WeakRef]=[]
		for id: String in semantic.get_meta("floor_platforms"):
			var draw:=frame.get_node_or_null(id) as MeshInstance3D
			if draw==null or draw.mesh==null or draw.get_node_or_null("Collision")==null:errors.append("missing physical platform: "+id);return false
			supports.append(weakref(draw))
		for id: String in semantic.get_meta("programme_anchors"):
			var actor:=world.adapter.resolve(id) as Node3D
			if actor==null or actor.find_children("*","MeshInstance3D",true,false).is_empty():errors.append("missing native landing landmark: "+id);return false
			landmarks.append(weakref(actor))
		var units: Array[String]=[];var thresholds: Array[Dictionary]=[]
		for record: Dictionary in world.layout.doors:
			if str(record.level)!=floor:continue
			var anchor:=world.adapter.resolve(str(record.id)) as Node3D
			if anchor==null:continue
			for child: Node in anchor.get_children():
				if child is not DoorProp or str(child.unit).is_empty():continue
				var unit:=str(child.unit)
				if unit not in units:units.append(unit)
				thresholds.append({"id":str(record.id),"unit":unit,"leaf":weakref(child)})
		units.sort()
		if units.is_empty():errors.append("no actual apartment decisions on landing: "+identity);return false
		var title:=sign.get_node("Floor") as Label3D
		if title==null:errors.append("missing authored floor lettering: "+identity);return false
		_titles.append({"node":weakref(title),"font_size":title.font_size,"pixel_size":title.pixel_size,"y":title.position.y})
		title.font_size=80;title.pixel_size=.0018;title.position.y=.13
		var letters:=Label3D.new();letters.name="Apartments";letters.font=title.font
		letters.font_size=54;letters.pixel_size=.0011;letters.text="  /  ".join(units)
		letters.modulate=Color(.015,.012,.008);letters.outline_size=0;letters.shaded=false;letters.double_sided=false
		letters.position=Vector3(0,-.005,.016);sign.add_child(letters);_letters.append(weakref(letters))
		semantic.set_meta("landing_units",units.duplicate())
		_bindings[identity]={"level":floor,"core":weakref(core),"semantic":weakref(semantic),"supports":supports,"landmarks":landmarks,"sign":weakref(sign),"units":units,"thresholds":thresholds}
	if _bindings.size()!=6:return false
	_frame=weakref(frame);_rooms=Footprints.room_index(world.layout);_floor_height=float(world.layout.dimensions.floor_to_floor)
	return true

func room_at(world_position: Vector3) -> String:
	var frame:=_frame.get_ref() as Node3D if _frame!=null else null
	if frame==null:return ""
	return Footprints.room_at_index(_rooms,frame.to_local(world_position),_floor_height)

func snapshot() -> Dictionary:
	return _bindings.duplicate(true)

func teardown() -> void:
	for reference: WeakRef in _letters:
		var node: Node=reference.get_ref()
		if node!=null:node.free()
	for original: Dictionary in _titles:
		var title:=original.node.get_ref() as Label3D
		if title!=null:title.font_size=original.font_size;title.pixel_size=original.pixel_size;title.position.y=original.y
	_letters.clear();_titles.clear();_bindings.clear();_rooms.clear();_frame=null
