extends RefCounted
## Installed wet-room charts, finish state, loaded maps and corner/floor views.
func run(world: OrisonV2RuntimeRoot, suite: Node) -> void:
	var shell: Node3D = world.adapter.root
	var floors := 0
	var walls := 0
	var vertices := 0
	var max_error := 0.0
	var max_basis_error := 0.0
	var cardinal_basis_valid := true
	var floor_rooms: Dictionary={}
	var wall_rooms: Dictionary={}
	var worst := ""
	var textures_checked := {}
	world.player.carried_device.set_capture_hidden(true)
	for draw: MeshInstance3D in shell.find_children("*","MeshInstance3D",true,false):
		var key := str(draw.get_meta("v2_material_key",""))
		if key not in ["bath_wall_tile","bath_floor_tile"]: continue
		if key == "bath_floor_tile":
			floors += 1;floor_rooms[str(draw.get_parent().name)]=true
		else:
			walls += 1;wall_rooms[str(draw.get_parent().name)]=true
		var material := draw.get_active_material(0) as ShaderMaterial
		suite.check(material != null,"bath tile uses layered PBR: "+str(draw.get_path()))
		if material == null: continue
		suite.check(int(material.get_shader_parameter("coverage"))==0 and not bool(material.get_shader_parameter("has_detail")),"ordered grout has no stochastic or self-detail duplicate: "+str(draw.get_path()))
		suite.check(not bool(material.get_shader_parameter("has_mask_tex")) and material.get_shader_parameter("mask_amount")==Vector4.ZERO,"bath tile has no repeated grime mask: "+str(draw.get_path()))
		for channel in ["albedo_tex","normal_tex","rough_tex","height_tex"]:
			var texture := material.get_shader_parameter(channel) as Texture2D
			if texture!=null and textures_checked.has(texture.get_instance_id()): continue
			suite.check(texture!=null and texture.get_image().has_mipmaps(),"bath tile loaded mip chain: "+key+"/"+channel)
			if texture!=null: textures_checked[texture.get_instance_id()]=true
		for surface in draw.mesh.get_surface_count():
			# Room slabs also own exposed plaster undersides. Those retain
			# their separate finish and local charts; they are not floor tile.
			if draw.get_active_material(surface)!=material: continue
			var a := draw.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			for i in points.size():
				var p := shell.to_local(draw.to_global(points[i]))
				var u := Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				var v := normals[i].cross(u)*tangents[i*4+3]
				# Godot stores directions as 16-bit octahedral coordinates.
				# The merged wall builder authors UVs before that packing; the
				# floor's v2_metre_box_uv builder uses already-decoded directions.
				# Check each source frame without widening the metric tolerance.
				var chart_u:=u.snapped(Vector3.ONE);var chart_v:=v.snapped(Vector3.ONE)
				max_basis_error=maxf(max_basis_error,maxf(u.distance_to(chart_u),v.distance_to(chart_v)))
				cardinal_basis_valid=cardinal_basis_valid and chart_u.length_squared()==1. and chart_v.length_squared()==1. and chart_u.dot(chart_v)==0.
				if key=="bath_wall_tile":u=chart_u;v=chart_v
				var error := uv[i].distance_to(Vector2(p.dot(u),p.dot(v)))
				if error>max_error:
					max_error=error
					worst=str(draw.get_path())+" uv="+str(uv[i])+" p="+str(p)
				vertices += 1
	var expected := 0
	for room: Dictionary in world.layout.spaces:
		if room.get("class","")=="wet" and not room.get("no_floor",false):
			expected += 1
			suite.check(floor_rooms.has(str(room.id)) and wall_rooms.has(str(room.id)),"authored wet room owns both tiled floor and merged wall stock: "+str(room.id))
	suite.check(floors==expected and walls>=expected,"all authored wet floors and room-facing walls use the new tile sets: floors=%d expected=%d walls=%d" % [floors,expected,walls])
	suite.check(cardinal_basis_valid and max_basis_error<.0001,"packed tile directions retain orthogonal architectural chart axes; max direction error="+str(max_basis_error))
	suite.check(vertices>0 and max_error<.00002,"installed UVs match source metre charts across walls and floors; max metre error="+str(max_error)+" "+worst)
	var camera := Camera3D.new()
	camera.fov=65
	world.add_child(camera)
	var fill := OmniLight3D.new()
	fill.light_color=Color(1.0,.94,.85)
	fill.light_energy=.65
	fill.omni_range=5
	world.add_child(fill)
	for room: Dictionary in world.layout.spaces:
		if str(room.id) not in ["F02_A_BATH","F04_B_BATH","F05_C_BATH"]: continue
		var r: Array = room.rect
		var floor_y: float = shell.level_y[room.level]
		var centre := Vector3((r[0]+r[2])*.5,floor_y+1.4,(r[1]+r[3])*.5)
		fill.global_position=shell.to_global(centre+Vector3(0,.6,0))
		camera.global_position=shell.to_global(Vector3(r[2]-.4,floor_y+1.6,r[3]-.4))
		camera.look_at(shell.to_global(Vector3(r[0]+.3,floor_y+.9,r[1]+.3)))
		camera.make_current()
		await suite.shot("tile_"+str(room.id)+"_corner")
		camera.global_position=shell.to_global(centre+Vector3(0,.35,.25))
		camera.look_at(shell.to_global(Vector3(centre.x,floor_y,centre.z-.25)))
		await suite.shot("tile_"+str(room.id)+"_floor")
	fill.free()
	camera.free()
	world.player.camera.make_current()
