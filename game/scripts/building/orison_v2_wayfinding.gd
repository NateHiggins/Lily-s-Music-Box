extends Node3D
## Lit physical plaques; coordinates come from the actual core/stair schedule.
var plaques: Array[Node3D] = []

func mount(layout: Dictionary) -> bool:
	var primary: Dictionary = {}
	for stair: Dictionary in layout.stairs:
		if str(stair.id).begins_with("PRIMARY_"):
			primary = stair
			break
	if primary.is_empty(): return false
	var spaces := {}
	for room: Dictionary in layout.spaces: spaces[str(room.id)] = room
	var inset := float(layout.dimensions.core_wall)*.5+.025
	for level: Dictionary in layout.levels:
		for core in ["PUBLIC","SERVICE"]:
			var identity: String = str(level.id)+"_"+core+"_CORE"
			if not spaces.has(identity): return false
			var rect: Array = spaces[identity].rect
			var public: bool = core == "PUBLIC"
			# F01's south threshold is open to the lobby; use its east wall.
			var east_wall: bool = not public or level.id=="F01"
			var at := Vector3(float(primary.origin[0])+float(primary.width)+float(primary.gap)*.5,
				float(level.y)+1.70,float(rect[1])+inset) if not east_wall else Vector3(
				float(rect[2])-inset,float(level.y)+1.70,float(rect[1])+1.10)
			var plaque := Node3D.new()
			plaque.name = identity+"_Plaque"
			plaque.position = at
			plaque.rotation.y = -PI*.5 if east_wall else 0.0
			plaque.set_meta("level",str(level.id))
			plaque.set_meta("core",core)
			add_child(plaque)
			plaques.append(plaque)
			var backing := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.3,.48,.025)
			backing.mesh = mesh
			backing.material_override = MatLib.get_mat("enamel_appliance",Color(.75,.71,.59),.9)
			plaque.add_child(backing)
			var title := "BASEMENT" if level.id=="B1" else "ROOF" if level.id=="ROOF" else "FLOOR "+str(int(str(level.id).substr(1)))
			var note := "STREET BELOW / ROOF ABOVE" if public else "SERVICE STAIR"
			if level.id=="B1": note = "LAUNDRY  <    BOILER  >" if public else "WORKSHOP / BOILER"
			elif level.id=="F01": note = "STREET / WATCH STATION" if public else "GROUND FLOOR SERVICE"
			elif level.id=="ROOF": note = "ROOF ACCESS / STAIRS DOWN"
			_letter(plaque,"Floor",title,.09,64,.0022)
			_letter(plaque,"Directions",note,-.12,32,.0018)
	return plaques.size()==16

func _letter(parent: Node3D, label: String, words: String, y: float, size: int, scale_m: float) -> void:
	var text := Label3D.new()
	text.name = label
	text.text = words
	text.font_size = size
	text.pixel_size = scale_m
	text.modulate = Color(.015,.012,.008)
	text.outline_size = 0
	# The enamel receives light; matte printed lettering stays dark.
	text.shaded = false
	text.double_sided = false
	text.position = Vector3(0,y,.016)
	parent.add_child(text)
