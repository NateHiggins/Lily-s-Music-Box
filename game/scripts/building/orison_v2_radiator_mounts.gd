extends RefCounted
## Fit only surveyed floating ties. Existing walls retain collision authority.
const MODEL := preload("res://assets/props/radiator_wall_tie.glb")
var walls: Array[AABB] = []
var plates := {}
var root: Node3D

func configure(building: Node3D) -> void:
	root = building
	for wall: MeshInstance3D in root.find_children("Wall*","MeshInstance3D",true,false):
		if wall.get_node_or_null("Collision") != null:
			walls.append((root.global_transform.affine_inverse()*wall.global_transform)*wall.get_aabb())

func fit(radiator: RadiatorProp, anchor: Node3D, level: String) -> void:
	var pose := root.global_transform.affine_inverse()*anchor.global_transform
	var half := float(radiator.section_count-1)*RadiatorProp.SECTION_PITCH*.5
	var depths := PackedFloat32Array()
	for side in [-1.0,1.0]:
		var x: float = half*.55*float(side)
		var local_y := .58-radiator.installation_drop
		var a := pose*Vector3(x,local_y,.10)
		var b := pose*Vector3(x,local_y,.50)
		var depth := INF
		for wall in walls:
			var hit: Variant = wall.intersects_segment(a,b)
			if hit is Vector3:
				depth = minf(depth,(pose.affine_inverse()*hit).z)
		if is_finite(depth) and depth>.1905:
			# Embed the retained rod by 4 mm. Its wall plate remains fixed;
			# the real slot clears the shell's existing pitch movement.
			depths.append(depth+.004)
			if not plates.has(level): plates[level] = []
			plates[level].append(pose*Transform3D(Basis.IDENTITY,Vector3(x,local_y,depth)))
		else:
			depths.append(.19)
	radiator.wall_standoff_depths = depths

func draw() -> void:
	if plates.is_empty(): return
	var owner := Node3D.new()
	owner.name = "RadiatorTiePlates"
	root.add_child(owner)
	var model := MODEL.instantiate() as Node3D
	for level: String in plates:
		var floor := Node3D.new()
		floor.name = level
		owner.add_child(floor)
		for part: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var draw := MultiMeshInstance3D.new()
			draw.name = str(part.name)
			draw.material_override = MatLib.get_mat(str(part.name))
			draw.multimesh = MultiMesh.new()
			draw.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			draw.multimesh.mesh = part.mesh
			draw.multimesh.instance_count = plates[level].size()
			for i in plates[level].size(): draw.multimesh.set_instance_transform(i,plates[level][i]*part.transform)
			floor.add_child(draw)
	model.free()
