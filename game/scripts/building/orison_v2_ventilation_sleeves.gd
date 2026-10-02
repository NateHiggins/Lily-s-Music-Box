extends RefCounted
## Shared slab at an adjacent floor/ceiling receives one sleeve, not two.
const MODEL := preload("res://assets/props/ventilation_slab_sleeve.glb")

static func stations(layout: Dictionary, stacks: Dictionary) -> Dictionary:
	var levels: Dictionary={}
	var spaces: Dictionary={}
	for level: Dictionary in layout.levels: levels[str(level.id)]=float(level.y)
	for space: Dictionary in layout.spaces: spaces[str(space.id)]=space
	var result: Dictionary={}
	var seen: Dictionary={}
	for opening: Dictionary in layout.get("slab_openings",[]):
		var identity:=str(opening.id)
		if not identity.begins_with("VENT_"): continue
		var stack:=identity.get_slice("_",1)
		if not stacks.has(stack): continue
		var room: Dictionary=spaces[str(opening.space)]
		var upper: float=levels[str(room.level)]
		if opening.surface=="Ceiling": upper+=float(layout.dimensions.floor_to_floor)
		var key: String="%s:%.4f" % [stack,upper]
		if seen.has(key): continue
		seen[key]=true
		if not result.has(stack): result[stack]=[]
		result[stack].append(Transform3D(Basis.IDENTITY,Vector3(stacks[stack].riser[0],upper,stacks[stack].riser[1])))
	return result

static func mount(root: Node3D, layout: Dictionary, stacks: Dictionary) -> void:
	var placement:=stations(layout,stacks)
	var template:=MODEL.instantiate() as Node3D
	var source:=template.find_child("SlabSleeve",true,false) as MeshInstance3D
	for stack: String in placement:
		var draw:=MultiMeshInstance3D.new()
		draw.name="SlabSleeves"
		draw.material_override=MatLib.get_mat("metal")
		draw.multimesh=MultiMesh.new()
		draw.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		draw.multimesh.mesh=source.mesh
		draw.multimesh.instance_count=placement[stack].size()
		for index in placement[stack].size(): draw.multimesh.set_instance_transform(index,placement[stack][index]*source.transform)
		root.get_node("Stack_"+stack).add_child(draw)
	template.free()
