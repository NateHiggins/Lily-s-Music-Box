extends "res://tests/orison_v2_exterior_masonry_test.gd"
## Native repair contacts and loaded charts; inherited eight daylight views.
func _check_ceiling_interfaces(world: OrisonV2RuntimeRoot,masonry: Node3D) -> void:
	super._check_ceiling_interfaces(world,masonry)
	var repairs := world.adapter.root.get_node("FireRepairs") as Node3D
	var triangles := 0
	for draw: MeshInstance3D in repairs.find_children("*","MeshInstance3D",true,false):
		check(draw.get_child_count()>0,"repair stock has matching physical collision")
		for surface in draw.mesh.get_surface_count():
			var mat := draw.material_override as StandardMaterial3D
			check(not mat.uv1_triplanar,"repair stock uses authored metric UVs")
			for texture: Texture2D in [mat.albedo_texture,mat.roughness_texture,mat.normal_texture]:
				check(texture!=null and texture.get_image().get_mipmap_count()>0,"repair PBR map has a real loaded mip chain")
			var arrays := draw.mesh.surface_get_arrays(surface)
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var bad := 0
			for i in range(0,indices.size(),3):
				var a := uv[indices[i+1]]-uv[indices[i]]
				var b := uv[indices[i+2]]-uv[indices[i]]
				if absf(a.cross(b))<1e-12: bad+=1
			triangles+=indices.size()/3
			check(bad==0,"all imported repair triangles retain noncollapsed charts")
	check(triangles>7000,"complete staging and masonry heads are installed")
	# Existing entrance approach stays outside the fixed scaffold footprint.
	var query := PhysicsRayQueryParameters3D.create(world.adapter.root.to_global(Vector3(0,1,-15)),world.adapter.root.to_global(Vector3(0,1,-12)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"entrance approach is clear of staging")
