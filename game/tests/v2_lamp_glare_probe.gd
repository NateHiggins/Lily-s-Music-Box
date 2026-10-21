extends RefCounted
## Controlled live-world captures; no source lighting/material edits or proof grant.
func run(world: OrisonV2RuntimeRoot,directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var player: PlayerController=world.player
	var atmo: Node3D=world.get_node("LampAtmosphere")
	var old_pose:=player.global_transform;var old_camera:=player.camera.transform
	var was_ticking:=player.is_physics_processing();var was_lit:=player.lamp_is_enabled()
	var observer:=preload("res://tests/v2_area_survey.gd").new()
	var observations: Array=[]
	player.set_physics_process(false);player.carried_device.set_capture_hidden(true)
	for identity: String in ["F03_B_BATH","F06_B_KITCHEN"]:
		var room: Dictionary={}
		for entry: Dictionary in world.layout.spaces:
			if str(entry.id)==identity:room=entry;break
		var stance: Dictionary=observer._stance(world,world.adapter.root,room.rect,world.adapter.root.level_y[room.level])
		if stance.is_empty():observations.append({"id":identity,"failure":"no physical stance"});continue
		player.global_position=Vector3(stance.feet[0],stance.feet[1],stance.feet[2]);player.global_rotation=Vector3(0,world.adapter.root.global_rotation.y,0);player.camera.rotation=Vector3(-.08,0,0)
		for treatment: String in ["normal","voxel_receivers_hidden","lamp_off","all_lights_off","room_fixture_off","celestial_off","room_reflections_off","ssil_off","restored_normal"]:
			atmo.set_process(treatment in ["normal","restored_normal"])
			player.set_lamp_enabled(treatment not in ["lamp_off","all_lights_off","room_fixture_off","celestial_off","room_reflections_off","ssil_off"])
			if treatment not in ["normal","restored_normal"]:
				atmo.receivers.hide_all();atmo.volume.visible=false;atmo.particles.visible=false;atmo.field.enabled=false
			var reflection_owner: Node=world.get_node("V2RoomReflections")
			var env: Environment=world.get_node("WakingAtmosphere/WorldEnvironment").environment
			var original_ssil: bool=env.ssil_enabled
			if treatment=="room_reflections_off":reflection_owner.set_reflections_enabled(false)
			if treatment=="ssil_off":env.ssil_enabled=false
			var masks: Dictionary={}
			for light: Light3D in world.find_children("*","Light3D",true,false):
				var room_fixture: String="3B_LT_SCONCE" if identity=="F03_B_BATH" else "F06_B_KITCHEN_LT_KITCHEN_LINEAR"
				if treatment=="all_lights_off" or (treatment=="room_fixture_off" and room_fixture in str(light.get_path())) or (treatment=="celestial_off" and str(light.name)=="CelestialKey"):
					masks[light]=light.light_cull_mask;light.light_cull_mask=0
			for frame in 60:await RenderingServer.frame_post_draw
			var lights: Array=[]
			for light: Light3D in world.find_children("*","Light3D",true,false):
				if light.light_energy<=0.:continue
				var reach: float=light.omni_range if light is OmniLight3D else light.spot_range if light is SpotLight3D else 10000.
				var distance: float=light.global_position.distance_to(player.camera.global_position)
				if distance<reach:lights.append({"path":str(light.get_path()),"energy":light.light_energy,"range":reach,"distance":distance,"shadow":light.shadow_enabled,"mask":light.light_cull_mask})
			var eye:=player.camera.global_position
			var query:=PhysicsRayQueryParameters3D.create(eye,eye-player.camera.global_basis.z*10.,1,[player.get_rid()])
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			var surface: Dictionary={}
			if not hit.is_empty():
				surface["collider"]=str(hit.collider.get_path());surface["position"]=str(hit.position)
				var draw: Node=hit.collider.get_parent()
				if draw is MeshInstance3D:
					surface["draw"]=str(draw.get_path())
					var material: Material=draw.get_active_material(0)
					if material is ShaderMaterial:
						surface["shader"]=material.shader.resource_path;surface["uniforms"]={}
						for uniform: Dictionary in material.shader.get_shader_uniform_list():
							var value: Variant=material.get_shader_parameter(uniform.name)
							surface.uniforms[str(uniform.name)]=value.resource_path if value is Resource else str(value)
					elif material is BaseMaterial3D:
						for property: String in ["albedo_color","metallic","roughness","emission_enabled","emission","emission_energy_multiplier","shading_mode","disable_ambient_light"]:surface[property]=str(material.get(property))
			var picture:=player.get_viewport().get_texture().get_image()
			var filename:=identity+"_"+treatment+".png";picture.save_png(directory.path_join(filename))
			for light: Light3D in masks:light.light_cull_mask=masks[light]
			if treatment=="room_reflections_off":reflection_owner.set_reflections_enabled(true)
			env.ssil_enabled=original_ssil
			observations.append({"id":identity,"treatment":treatment,"image":filename,"stance":stance,"surface":surface,"lights":lights,"lamp_energy":player.flashlight.light_energy})
	observer.free();atmo.set_process(true);player.set_lamp_enabled(was_lit);player.global_transform=old_pose;player.camera.transform=old_camera;player.set_physics_process(was_ticking)
	FileAccess.open(directory.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Same-world normal, voxel receiver hiding, lamp-off and restored controls. No geometry, light-source or material repair is made by this probe.","observations":observations},"\t"))
