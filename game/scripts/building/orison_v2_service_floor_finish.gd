extends RefCounted
## Inferred use history, pinned to current plant positions, not room-wide grime.
static func apply(world: Node) -> void:
	for room in ["B1_LAUNDRY","B1_BOILER_ROOM"]:
		var shell: Node=world.adapter.root.get_node(room)
		var floor_draw: MeshInstance3D=shell.get_node("Floor")
		var original:=floor_draw.get_active_material(0) as ShaderMaterial
		assert(original!=null and original.shader==SurfacePass.OPAQUE)
		var finish:=original.duplicate() as ShaderMaterial
		finish.shader=preload("res://shaders/orison_service_floor.gdshader")
		var patches:=PackedVector4Array()
		if room=="B1_LAUNDRY":
			for identity in ["B1_WASHER_01","B1_WASHER_02","B1_LAUNDRY_AIRER_01"]:
				var actor: Node3D=world.adapter.resolve(identity)
				var center:=actor.to_global(Vector3(0,0,-.27))
				patches.append(Vector4(center.x,center.z,.78,.18))
			finish.set_shader_parameter("service_residue",Vector3(.57,.55,.49))
			finish.set_shader_parameter("service_roughness",.76)
		else:
			var boiler: Node3D=world.adapter.resolve("B1_BOILER_01")
			for offset in [Vector3(0,0,-.65),Vector3(-.45,0,.15),Vector3(.45,0,.15)]:
				var center:=boiler.to_global(offset)
				patches.append(Vector4(center.x,center.z,.8,.22 if offset.z<0 else .10))
			finish.set_shader_parameter("service_residue",Vector3(.10,.092,.075))
			finish.set_shader_parameter("service_roughness",.90)
		finish.set_shader_parameter("service_patches",patches)
		floor_draw.set_surface_override_material(0,finish)
		floor_draw.set_meta("v2_service_floor_finish",true)
