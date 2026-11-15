extends "res://tests/harukiya_cost_attribution.gd"
## Caster attribution only: no production quality change or budget substitution.
var caster_states: Array = []
var caster_inventory: Array = []
var excluded_static: Array = []
var caster_control := ""
var ground_only := false
var world_groups := false

func _opposition_programme() -> void:
	if not await _prepare_cost_context(): return
	if not _check(bool(PlayerSupport.inspect(world.bar_region,world.player,world.player.global_position).get("supported",false)),"supported actual pool stance"): return
	world.player.rotation.y += 3.0*PI*.5
	world.player.camera.rotation = Vector3.ZERO
	wall_pilot = world.bar_region.wall_occlusion
	if not _wall_valid(): return
	ground_only = OS.get_environment("ORISON_SHADOW_SOURCE_SUBSET") == "ground_native"
	world_groups = OS.get_environment("ORISON_SHADOW_SOURCE_SUBSET") == "world_groups"
	if ground_only:
		var ground: Node3D = world.get("_blockout").get_node("Ground")
		var apron: Node3D = ground.get_node("orison_ground/DistantApron")
		for draw: MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
			if apron.is_ancestor_of(draw): continue
			if WallPilot._admit(draw): _register(draw,"ground_native","original_ground_without_apron")
		if not _check(not caster_states.is_empty(),"nonempty admitted original ground caster subset"): return
	if world_groups:
		var blockout: Node3D = world.get("_blockout")
		var groups: Dictionary = {"distant_apron":blockout.get_node("Ground/orison_ground/DistantApron"),
			"city_shells":world.get_node("CityShells"),"vantry_arcade":world.get_node("VantryArcade"),
			"city_foundations":blockout.get_node("CityFoundations")}
		for family: String in groups:
			for draw: MeshInstance3D in groups[family].find_children("*","MeshInstance3D",true,false):
				if WallPilot._admit(draw): _register(draw,family,family)
	var roots: Array = []
	for id: String in routes: roots.append({"node":routes[id].actor,"id":id})
	for id: String in ["stacy","lily"]: roots.append({"node":world.harukiya_counter.cast.actors[id],"id":id})
	roots.append({"node":world.player_avatar,"id":"player_avatar"})
	var seen: Dictionary = {}
	for owner: Dictionary in ([] if ground_only or world_groups else roots):
		if not _check(is_instance_valid(owner.node),"actual cast root "+owner.id): return
		var count := 0
		for draw: MeshInstance3D in owner.node.find_children("*","MeshInstance3D",true,false):
			if draw.mesh == null or seen.has(draw.get_instance_id()): continue
			seen[draw.get_instance_id()] = true
			_register(draw,"people",owner.id); count += 1
		_check(count>0,"actual cast meshes "+owner.id)
	var geometry: Node3D = world.bar_region.get_node("RetainedBarGeometry")
	for draw: MeshInstance3D in geometry.find_children("*","MeshInstance3D",true,false):
		if ground_only or world_groups: break
		if seen.has(draw.get_instance_id()): continue
		var reason := _static_exclusion(draw,geometry)
		if not reason.is_empty():
			excluded_static.append({"path":str(draw.get_path()),"reason":reason}); continue
		_register(draw,"static_bar","retained_native_bar")
	for draw: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if ground_only or world_groups: break
		if seen.has(draw.get_instance_id()) or world.bar_region.is_ancestor_of(draw): continue
		if world.player.is_ancestor_of(draw) or world.service_set_carrier.is_ancestor_of(draw): continue
		if not WallPilot._admit(draw): continue
		_register(draw,"outside_bar_opaque","composed_world_outside_bar")
	for light: Light3D in world.find_children("*","Light3D",true,false):
		light_states.append({"node":light,"shadow":light.shadow_enabled,"family":"unchanged"})
	for view: SubViewport in world.find_children("*","SubViewport",true,false):
		view_states.append({"node":view,"path":str(view.get_path())})
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
	controls_owned = true
	control_labels.assign(["normal_a","people_cast_disabled","people_restored","static_bar_cast_disabled","static_bar_restored","outside_bar_cast_disabled","normal_return"])
	if ground_only: control_labels.assign(["normal_a","ground_native_cast_disabled","normal_return"])
	if world_groups: control_labels.assign(["normal_a","distant_apron_cast_disabled","apron_restored","city_shells_cast_disabled","shells_restored","vantry_arcade_cast_disabled","arcade_restored","city_foundations_cast_disabled","normal_return"])
	var required_groups: Array = ["ground_native"] if ground_only else ["distant_apron","city_shells","vantry_arcade","city_foundations"] if world_groups else ["people","static_bar","outside_bar_opaque"]
	for group: String in required_groups:
		var enabled_count := 0
		for row: Dictionary in caster_states:
			if row.family==group and row.shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: enabled_count+=1
		if not _check(enabled_count>0,"nonempty originally shadow-casting group "+group): return
	for label: String in control_labels:
		if not _cohort_valid() or not _wall_valid(): break
		_apply_control(label)
		var before: Dictionary = _cohort()
		if not _casters_valid(): break
		timing = true
		for frame in WARM_FRAMES: await RenderingServer.frame_post_draw
		var row: Dictionary = await _measure_control(label)
		timing = false
		_check(_cohort_valid() and _cohort()==before,"unchanged actual cohort "+label)
		if not _casters_valid() or not _wall_valid(): break
		row.cohort=before;row.wall_occlusion_enabled=true
		if (ground_only or world_groups) and OS.get_environment("ORISON_COST_CAPTURE") == "1":
			var image: Image = get_viewport().get_texture().get_image()
			var capture: String = directory.path_join(label+".png")
			_check(image != null and image.save_png(capture)==OK,"post-timing ground attribution capture "+label)
			row.capture = capture
		attribution.append(row)
		print("HARUKIYA SHADOW CASTERS ",label," median_ms=",row.wall_ms.median," shadow_draws=",row.shadow_draws.median)
		if not failures.is_empty(): break
	_restore_controls()
	_check(attribution.size()==control_labels.size(),"all caster A/B/A phases sampled")

func _register(draw: MeshInstance3D, family: String, owner_id: String) -> void:
	caster_states.append({"node":draw,"id":draw.get_instance_id(),"mesh":draw.mesh,"shadow":draw.cast_shadow,"family":family,"visible":draw.visible})
	caster_inventory.append({"path":str(draw.get_path()),"instance_id":draw.get_instance_id(),"mesh_id":draw.mesh.get_instance_id() if draw.mesh!=null else 0,"family":family,"owner":owner_id,"shadow":draw.cast_shadow,"visible_in_tree":draw.is_visible_in_tree(),"material_key":str(draw.get_meta("material_key","")),"entry_part":str(draw.get_meta("harukiya_entry_part","")),"destination_part":str(draw.get_meta("harukiya_destination_part",""))})

func _static_exclusion(draw: MeshInstance3D, geometry: Node3D) -> String:
	if not WallPilot._admit(draw): return "nonopaque/deforming/material not admitted"
	var label: String = (str(draw.get_path())+" "+str(draw.get_meta("material_key",""))).to_lower()
	for token: String in ["cloth","fabric","linen","curtain","rug","felt","vinyl","leather","plant","paper","stagehat","barstage"]:
		if token in label: return "excluded flexible/alpha/movable family: "+token
	var destination: Node3D = world.bar_region.destination
	var architecture: Node = destination.get_node_or_null("Architecture") if is_instance_valid(destination) else null
	var part: String = str(draw.get_meta("harukiya_destination_part",""))
	var admitted_destination: bool = not part.is_empty() and architecture != null and architecture.is_ancestor_of(draw)
	if "cue" in part.to_lower(): return "excluded pool cue presentation"
	var ancestor: Node = draw
	while ancestor != geometry and ancestor != null:
		if ancestor is Skeleton3D or ancestor is CharacterBody3D or ancestor is RigidBody3D or ancestor is AnimatableBody3D: return "dynamic ancestor"
		if ancestor.get_script()!=null and not (admitted_destination and ancestor==destination): return "script-owned native assembly (conservative exclusion)"
		ancestor = ancestor.get_parent()
	return ""

func _apply_control(label: String) -> void:
	caster_control = "people" if label=="people_cast_disabled" else "static_bar" if label=="static_bar_cast_disabled" else "outside_bar_opaque" if label=="outside_bar_cast_disabled" else ""
	if label == "ground_native_cast_disabled": caster_control = "ground_native"
	if world_groups and label.ends_with("_cast_disabled"): caster_control = label.trim_suffix("_cast_disabled")
	for row: Dictionary in caster_states:
		if is_instance_valid(row.node):
			var desired: int = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if row.family==caster_control else int(row.shadow)
			if row.node.cast_shadow != desired: row.node.cast_shadow = desired

func _casters_valid() -> bool:
	var issues: Array[String] = []
	var invalid_count := 0
	for row: Dictionary in caster_states:
		if not is_instance_valid(row.node):
			invalid_count += 1
			if issues.size()<20: issues.append("caster instance disappeared")
			continue
		var draw: MeshInstance3D = row.node
		var expected: int = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if row.family==caster_control else int(row.shadow)
		if draw.get_instance_id()!=row.id or draw.mesh!=row.mesh or draw.visible!=row.visible or draw.cast_shadow!=expected:
			invalid_count += 1
			if issues.size()<20: issues.append(str(draw.get_path()))
	return _check(invalid_count==0,"all "+str(caster_states.size())+" caster identities/meshes/visibility/flags valid; invalid="+str(invalid_count)+" first="+str(issues))

func _wall_valid() -> bool:
	return _check(is_instance_valid(wall_pilot) and wall_pilot.enabled and wall_pilot.errors.is_empty() and wall_pilot.sources.size()==4,"original four-wall occlusion owner remains enabled and valid")

func _restore_controls() -> void:
	_apply_control("normal_return")
	if controls_owned:
		_casters_valid()
		_wall_valid()
		for row: Dictionary in view_states:
			if is_instance_valid(row.node): RenderingServer.viewport_set_measure_render_time(row.node.get_viewport_rid(),false)
	controls_owned=false
	# Release borrowed mesh references while their production owners still exist.
	caster_states.clear();view_states.clear();light_states.clear()

func _finish() -> void:
	_restore_controls()
	# Settle actual changed render dependencies before parent destroys the world.
	await RenderingServer.frame_post_draw
	await super._finish()

func _decorate_result(result: Dictionary) -> void:
	super._decorate_result(result)
	result.suite="HarukiyaShadowSourceProbe"
	result.scope="Pool heading3 actual occupied caster A/B/A diagnostic. Mesh shadow flags only; no visibility/physics/animation/light-owner changes. Includes finite outside-bar opaque group; this group is not asserted static. No budget pass, batching fix, fullworld shadow coverage or visual acceptance claimed."
	result.details.caster_inventory=caster_inventory
	result.details.excluded_static=excluded_static
	result.details.caster_controls_restored=not controls_owned and caster_control.is_empty()
	result.details.ground_only=ground_only
	result.details.world_groups=world_groups
	if ground_only:
		result.scope="Pool heading3 current21 occupied Ground-only shadow-flag A/B/A diagnostic. Original native Ground MeshInstances only, excludes DistantApron; no visibility, physics, mesh, material, animation or light-owner changes. Full exact shadow enum restoration; no production optimization, budget pass or appearance acceptance."
	result.details.subset_limit="People: MeshInstance descendants of actual18+2 and player avatar; no other residents/MultiMesh. Static: opaque unskinned triangles under RetainedBarGeometry excluding flexible families and script-owned ancestry; excludes BarActors, city, private views and scripted native assemblies except exact metadata-bound Destination/Architecture. Outside-bar group: other opaque unskinned admitted MeshInstances in composed world, excluding bar, registered people, player and carrier; may include moving vehicles/props and is NOT a static-batching candidate set. Finite subsets, not all world casters."
	if ground_only: result.details.subset_limit="Original Ground admitted opaque MeshInstances only; DistantApron is excluded. All21 NPCs remain active and included in the inherited cohort; people, static bar and outside-bar groups are not controlled."
	if world_groups:
		result.scope="Pool heading3 current21 occupied caster attribution: independent DistantApron, CityShells, VantryArcade and CityFoundations shadow-flag controls, each followed by original-state return. No production optimization, visibility/physics/mesh/material/animation/light-owner changes, budget pass or appearance acceptance."
		result.details.subset_limit="Admitted opaque MeshInstances beneath each exact named owner only; no original Ground, bar or people controls. These subsets are attribution scopes, not claims of immutable batch eligibility."
