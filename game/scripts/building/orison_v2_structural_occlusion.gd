extends Node3D
## Conservative interior occluders from complete solid wall/slab boxes.
## Slabs require actual six-face closure; one-sided sheets cannot become
## double-sided occluders. Apertures never acquire an invented backing.
## Never infer an occluder across a door, window, service bore or moving leaf.
## V1's coincident-facade self-occlusion failure is explicitly excluded here:
## volumes sit inside solid stock and their source walls cannot occlude themselves.
var sources: Array[WeakRef]=[]
var previous_flags: Array[bool]=[]
var rejected := 0
var slab_sources: Array[WeakRef] = []
var rejected_slabs := 0

func setup(blockout: Node3D) -> int:
	for draw: MeshInstance3D in blockout.find_children("*","MeshInstance3D",true,false):
		if not draw.get_parent().has_meta("room_id"): continue
		var slab := str(draw.name) in ["Floor","Ceiling"]
		if not slab and not str(draw.name).begins_with("Wall"):continue
		if slab and not _opaque_slab(draw):rejected_slabs += 1;continue
		var collisions:=draw.find_children("*","CollisionShape3D",true,false)
		if collisions.size()!=1 or collisions[0].shape is not BoxShape3D: rejected+=1;continue
		var shape:=collisions[0] as CollisionShape3D
		if slab and shape.disabled:rejected_slabs += 1;continue
		var box:=shape.shape as BoxShape3D
		if not _complete_solid(draw.mesh,box.size): rejected+=1;continue
		var extent:=box.size-Vector3.ONE*.012
		if minf(extent.x,minf(extent.y,extent.z))<=.01: rejected+=1;continue
		var volume:=BoxOccluder3D.new();volume.size=extent
		var instance:=OccluderInstance3D.new();instance.name=("SlabSolid_" if slab else "InteriorSolid_")+str(sources.size())
		instance.occluder=volume
		add_child(instance)
		instance.global_transform=shape.global_transform
		sources.append(weakref(draw));previous_flags.append(draw.ignore_occlusion_culling)
		draw.ignore_occlusion_culling=true
		if slab:slab_sources.append(weakref(draw))
	return sources.size()

static func _opaque_slab(draw: MeshInstance3D) -> bool:
	if draw.mesh==null or not draw.is_visible_in_tree() or draw.material_overlay!=null \
		or draw.transparency!=0. or draw.visibility_range_begin!=0. or draw.visibility_range_end!=0. \
		or draw.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:return false
	for surface in draw.mesh.get_surface_count():
		var material := draw.get_active_material(surface)
		if material is StandardMaterial3D:
			if material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED \
				or material.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED or material.grow_enabled or material.fixed_size \
				or material.cull_mode==BaseMaterial3D.CULL_FRONT or material.proximity_fade_enabled or material.no_depth_test \
				or material.distance_fade_mode!=BaseMaterial3D.DISTANCE_FADE_DISABLED:return false
		elif material is ShaderMaterial:
			# Only the registered non-deforming opaque shader; never cutout,
			# glass, arbitrary vertex displacement or shader-created holes.
			if material.shader==null or material.shader.resource_path!="res://shaders/orison_surface.gdshader":return false
		else:return false
	return true

static func _complete_solid(mesh: Mesh, size: Vector3) -> bool:
	# Actual rendered triangles must cover all six original box faces exactly.
	# Retired/parted skins and service penetrations cannot supply a solid proxy.
	if mesh==null or mesh.get_aabb().position.distance_to(-size*.5)>.00005 or mesh.get_aabb().size.distance_to(size)>.00005: return false
	var areas: Array[float]=[0.,0.,0.,0.,0.,0.]
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES: return false
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in vertices.size(): indices.append(index)
		for start in range(0,indices.size(),3):
			var a:=vertices[indices[start]];var b:=vertices[indices[start+1]];var c:=vertices[indices[start+2]]
			var cross: Vector3=(b-a).cross(c-a)
			if cross.length_squared()<1e-16: continue
			var axis:=cross.abs().max_axis_index()
			var side:=1 if a[axis]>0 else 0
			var plane: float=size[axis]*.5*(1.0 if side else -1.0)
			if absf(a[axis]-plane)>.00002 or absf(b[axis]-plane)>.00002 or absf(c[axis]-plane)>.00002: return false
			areas[axis*2+side]+=cross.length()*.5
	for axis in 3:
		var expected: float=size[(axis+1)%3]*size[(axis+2)%3]
		for side in 2:
			if absf(areas[axis*2+side]-expected)>maxf(.00001,expected*.00005): return false
	return true

func _exit_tree() -> void:
	for index in sources.size():
		var draw: MeshInstance3D=sources[index].get_ref()
		if is_instance_valid(draw): draw.ignore_occlusion_culling=previous_flags[index]
