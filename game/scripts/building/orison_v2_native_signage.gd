extends "res://scripts/building/orison_v2_native_service_instruments.gd"
## Fitted visual payloads; source scripts keep every switch and observation.
const SIGN_PATH := "res://data/orison_v2/signage.json"
var retained: Dictionary = {}

func install(world: Node) -> bool:
	for identity in ["F01_BAR_SIGNAGE","FittedBodegaSignage","F01_NEON_BLADE"]:
		var actor := _find_actor(world,identity)
		if actor==null: errors.append("unique sign owner: "+identity); return false
		var draws := actor.find_children("*","MeshInstance3D",true,false).filter(func(n):return n.mesh!=null)
		var labels := actor.find_children("*","Label3D",true,false)
		var lights := actor.find_children("*","Light3D",true,false)
		retained[identity]={"actor":weakref(actor),"pose":actor.global_transform,
			"draws":draws.map(func(n):return {"node":weakref(n),"mesh":n.mesh,"pose":n.transform,"parent":n.get_parent().get_instance_id()}),
			"labels":labels.map(func(n):return {"node":weakref(n),"text":n.text,"pose":n.transform}),
			"lights":lights.map(func(n):return {"node":weakref(n),"pose":n.transform,"energy":n.light_energy,"color":n.light_color})}
	if not mount(world,SIGNAGE_PATH):return false
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SIGN_PATH))
	var layered := {}
	for finish: Dictionary in data.materials:
		var key := str(finish.key)
		layered[key]=SurfacePass.surface_for(_materials[key],{"pigment_variation":float(finish.pigment)},key)
	for row: Dictionary in data.actors:
		var actor := _find_actor(world,str(row.id))
		for part: Dictionary in row.replacements:
			if part.preserve_material:continue
			var mesh: ArrayMesh=_meshes[str(part.mesh)]
			for i in mesh.get_surface_count():mesh.surface_set_material(i,layered[str(part.materials[i])])
		for part: Dictionary in row.additions:
			var draw := actor.get_node(str(part.mesh)) as MeshInstance3D
			for i in draw.mesh.get_surface_count():draw.mesh.surface_set_material(i,layered[str(part.materials[i])])
	for finish: Dictionary in data.source_finishes:
		var state: Dictionary=retained[str(finish.actor)]
		var draw := state.draws[int(finish.index)].node.get_ref() as MeshInstance3D
		var material := draw.get_active_material(0) as StandardMaterial3D
		if material==null:return false
		material.roughness=float(finish.roughness)
		var color: Array=finish.color
		material.albedo_color=Color(color[0],color[1],color[2],color[3])
		if not finish.emission.is_empty():
			var emission: Array=finish.emission
			material.emission=Color(emission[0],emission[1],emission[2])
	return true

func _find_actor(world: Node, identity: String) -> Node3D:
	if identity!="FittedBodegaSignage":return super._find_actor(world,identity)
	var matches := world.find_children("*","Node3D",true,false).filter(func(n):return n is BodegaSignageProp)
	return matches[0] as Node3D if matches.size()==1 else null
