extends Node
## Presentation-only reachability for source-owned service practicals.
## Closed leaves already decide room separation. Never raycast, alter a leaf,
## change an electrical fact or remove the visible fixture/emissive lens.
var world: Node3D
var sources: Array[Dictionary]=[]
var edges: Array[Dictionary]=[]
var spaces: Dictionary={}
var enabled:=false
var context_room: String=""
var visible_sources: Array[String]=[]
var reachable: Dictionary={}
var conservative:=true
var _due:=0.
var _key: String=""

func setup(owner_world: Node3D) -> bool:
	if world!=null:return false
	world=owner_world;process_priority=90;set_process(false)
	for room: Dictionary in world.layout.spaces:spaces[str(room.id)]=room
	for opening: Dictionary in world.layout.openings:
		if opening.get("connects",[]).size()==2:edges.append({"connects":opening.connects,"door":null})
		if not opening.has("shared_wall_owner"):continue
		var light:=world.adapter.root.get_node_or_null(str(opening.id)+"/ServicePractical/WarmServiceLight") as OmniLight3D
		if light==null:return false
		sources.append({"id":str(opening.id),"light":light,"connects":opening.connects,"visible":light.visible})
	for record: Dictionary in world.layout.doors:
		if record.get("connects",[]).size()!=2:continue
		var anchor: Node=world.adapter.root.get_node_or_null(str(record.id))
		var leaf: DoorProp
		if anchor!=null:
			for node: Node in anchor.get_children():
				if node is DoorProp:leaf=node;break
		# Glazing, cutouts and unknown shaders cannot establish a sealed portal.
		if leaf!=null and _transmits_light(leaf):leaf=null
		# Unknown/retained leaf owners stay connected, conservatively.
		edges.append({"connects":record.connects,"door":leaf})
		if leaf!=null:leaf.manipulation_changed.connect(_invalidate)
	return not sources.is_empty()

func _transmits_light(leaf: DoorProp) -> bool:
	for draw: GeometryInstance3D in leaf.find_children("*","GeometryInstance3D",true,false):
		if draw is MultiMeshInstance3D:return true
		if not draw is MeshInstance3D or draw.mesh==null:continue
		for surface in draw.mesh.get_surface_count():
			var material: Material=draw.get_active_material(surface)
			if material is ShaderMaterial:return true
			if material is BaseMaterial3D and material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return true
	return false

func _invalidate() -> void:
	_key="";_due=0.

func set_enabled(value: bool) -> void:
	enabled=value;set_process(value);_invalidate()
	if value:_poll()
	else:
		for source: Dictionary in sources:
			if is_instance_valid(source.light):source.light.visible=source.visible

func _process(delta: float) -> void:
	_due-=delta
	if _due<=0.:
		_due=.08;_poll()

func _open_room(room: Dictionary) -> bool:
	return str(room.get("class",""))=="core" or bool(room.get("open_shell",false)) or bool(room.get("no_ceiling",false)) or bool(room.get("no_floor",false))

func _poll() -> void:
	if not enabled or not is_instance_valid(world) or not is_instance_valid(world.player):return
	context_room=world.room_at_world(world.player.camera.global_position)
	var signature: String=context_room
	for edge: Dictionary in edges:
		var leaf: DoorProp=edge.door
		signature+="1" if leaf==null or not is_instance_valid(leaf) or leaf.open else "0"
	if signature==_key:return
	_key=signature;reachable={};conservative=not spaces.has(context_room)
	if not conservative:
		var pending: Array[String]=[context_room];reachable[context_room]=true
		while not pending.is_empty():
			var here: String=pending.pop_back()
			if _open_room(spaces.get(here,{})):conservative=true;break
			for edge: Dictionary in edges:
				var leaf: DoorProp=edge.door
				if leaf!=null and is_instance_valid(leaf) and not leaf.open:continue
				var connects: Array=edge.connects
				var other: String=str(connects[1]) if str(connects[0])==here else str(connects[0]) if str(connects[1])==here else ""
				if not other.is_empty() and not reachable.has(other):reachable[other]=true;pending.append(other)
	visible_sources.clear()
	for source: Dictionary in sources:
		var active: bool=conservative or reachable.has(str(source.connects[0])) or reachable.has(str(source.connects[1]))
		if active:visible_sources.append(source.id)
		if source.light.visible!=(active and source.visible):source.light.visible=active and source.visible

func _exit_tree() -> void:
	set_enabled(false)
