extends Node3D
## INERT geometry acquisition for native review, not a runtime contract.
const Selector=preload("res://scripts/building/building_root_selector.gd")
var regions: Array[AABB]=[]
var copied: Array[Dictionary]=[]
var mesh_cache: Dictionary={}
var gray: StandardMaterial3D

func _ready() -> void:
	_run.call_deferred()

func _near(bounds: AABB) -> bool:
	for region: AABB in regions:
		if region.intersects(bounds):return true
	return false

func _digest() -> String:
	var output: Array=[]
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	if OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],output)!=0:return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func _render_digest() -> String:
	var output: Array=[]
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var code: String="import pathlib,sys; root=pathlib.Path(sys.argv[1]); sys.path.insert(0,str(root/'tools')); import v2_surface_evidence; print(v2_surface_evidence.inputs(root)['sha256'])"
	if OS.execute("python",["-c",code,root],output)!=0:return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func _route_capture(world: OrisonV2RuntimeRoot, branch: Dictionary, directory: String, detail: bool) -> Dictionary:
	var points: Array=branch.points_local_godot
	var first:=Vector3(points[0][0],points[0][1],points[0][2])
	var last_data: Array=points[-1]
	var last:=Vector3(last_data[0],last_data[1],last_data[2])
	var root: Node3D=world.adapter.root
	var eye: Vector3
	var target: Vector3
	if detail:
		eye=last+Vector3(.5 if last.x<2.0 else -.5,-.65,-.65)
		target=last+Vector3(0,-.22,0)
	else:
		eye=first+Vector3(-.85,-.14,-.05) if str(branch.riser)=="H-C" else first+Vector3(.08,-.14,.95)
		target=first+Vector3(-.35,0,0) if str(branch.riser)=="H-C" else first+Vector3(0,.02,.22)
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=55;camera.make_current()
	var fill:=OmniLight3D.new();camera.add_child(fill);fill.light_energy=.6;fill.omni_range=3
	camera.global_position=root.to_global(eye);camera.look_at(root.to_global(target))
	await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
	var label: String=str(branch.id)+("_ceiling_entry" if detail else "_shaft_exit")
	var path:=directory.path_join(label+".png")
	var error:=get_viewport().get_texture().get_image().save_png(path)
	camera.free()
	return {"name":label,"path":path,"sha256":FileAccess.get_sha256(path),"saved":error==OK,"diagnostic_fill":true}

func _emitter_capture(world: OrisonV2RuntimeRoot, radiator: RadiatorProp, directory: String, detail: bool) -> Dictionary:
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=55;camera.make_current()
	var fill:=OmniLight3D.new();camera.add_child(fill);fill.light_energy=.6;fill.omni_range=3
	camera.global_position=radiator.to_global(Vector3(-.55,-.30,-.65) if detail else Vector3(-.9,.5,-1.5))
	camera.look_at(radiator.to_global(Vector3(-.67,-.745,0) if detail else Vector3(0,-.35,0)))
	await get_tree().create_timer(.4).timeout;await RenderingServer.frame_post_draw
	var label:=str(radiator.name)+("_supply" if detail else "_body")
	var path:=directory.path_join(label+".png")
	var error:=get_viewport().get_texture().get_image().save_png(path)
	camera.free()
	return {"name":label,"path":path,"sha256":FileAccess.get_sha256(path),"saved":error==OK,"diagnostic_fill":true}

func _copy(context: Node3D, source: GeometryInstance3D, mesh: Mesh, pose: Transform3D, index: int=-1) -> void:
	if mesh==null or not _near(pose*mesh.get_aabb()):return
	var key:=mesh.get_instance_id()
	if not mesh_cache.has(key):
		var duplicate:=mesh.duplicate() as Mesh
		for surface in duplicate.get_surface_count():duplicate.surface_set_material(surface,gray)
		mesh_cache[key]=duplicate
	var draw:=MeshInstance3D.new();draw.name="Context_%05d"%copied.size()
	draw.mesh=mesh_cache[key];draw.transform=pose;context.add_child(draw);draw.owner=context
	copied.append({"name":str(draw.name),"source":str(source.get_path()),"instance":index})

func _run() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	var route_path:=OS.get_environment("ORISON_HEATING_REVIEW_ROUTES")
	if directory.is_empty() or route_path.is_empty() or DisplayServer.get_name()=="headless":
		push_error("Native geometry acquisition needs windowed SHOT_DIR and ORISON_HEATING_REVIEW_ROUTES");get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(directory)
	var route_sha:=FileAccess.get_sha256(route_path)
	var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(route_path))
	for branch: Dictionary in routes.branches:
		var points: Array=branch.points_local_godot
		for i in range(points.size()-1):
			var a:=Vector3(points[i][0],points[i][1],points[i][2]);var b:=Vector3(points[i+1][0],points[i+1][1],points[i+1][2])
			var region:=AABB(a.min(b),a.max(b)-a.min(b)).grow(.2)
			# Include actual overhead hanger substrates and the full emitter bay,
			# rather than acquiring only the pipe's narrow collision corridor.
			region.size.y+=1.1
			regions.append(region)
	var before:=_digest();var render_before:=_render_digest()
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,750);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	Selector.reset_for_tests("v2")
	var world: OrisonV2RuntimeRoot=(load(Selector.scene_path()) as PackedScene).instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed:push_error("Production world refused context acquisition");get_tree().quit(1);return
	world.player.set_physics_process(false)
	for layer in world.player.carried_device.get_children():
		if layer is CanvasLayer:layer.hide()
	var captures: Array=[]
	if OS.get_environment("ORISON_HEATING_REVIEW_CAPTURES")=="1":
		for branch: Dictionary in routes.branches:
			var radiator:=world.adapter.resolve(str(branch.id)) as RadiatorProp
			# Acquisition-only paths cover fixed main fabric without inventing
			# another radiator or claiming a camera stance inside its solid chase.
			if radiator==null:continue
			captures.append(await _route_capture(world,branch,directory,false))
			captures.append(await _route_capture(world,branch,directory,true))
			if OS.get_environment("ORISON_HEATING_REVIEW_EMITTERS")=="1":
				captures.append(await _emitter_capture(world,radiator,directory,false))
				captures.append(await _emitter_capture(world,radiator,directory,true))
	gray=StandardMaterial3D.new();gray.albedo_color=Color(.45,.48,.5);gray.roughness=.8
	var context:=Node3D.new();context.name="HeatingRetrofitContext";add_child(context)
	var origin: Transform3D=world.adapter.root.global_transform.affine_inverse()
	for node: Node in world.find_children("*","GeometryInstance3D",true,false):
		if not node is MeshInstance3D and not node is MultiMeshInstance3D:continue
		if "/WakingAtmosphere/" in str(node.get_path()):continue
		if node.get_world_3d()!=world.get_world_3d() or str(node.get_meta("surface_role","physical"))!="physical" or not str(node.get_meta("retired_surface","")).is_empty():continue
		var pose: Transform3D=origin*node.global_transform
		if node is MeshInstance3D:_copy(context,node,node.mesh,pose)
		elif node.multimesh!=null:
			for index in node.multimesh.instance_count:_copy(context,node,node.multimesh.mesh,pose*node.multimesh.get_instance_transform(index),index)
	var walls: Array=[]
	for node: Node in world.adapter.root.find_children("Wall*","MeshInstance3D",true,false):
		var body:=node.get_node_or_null("Collision")
		if body==null:continue
		for shape: Node in body.get_children():
			if not shape is CollisionShape3D or not shape.shape is BoxShape3D:continue
			var box: AABB=(origin*shape.global_transform)*AABB(-shape.shape.size*.5,shape.shape.size)
			if _near(box):walls.append({"room":str(node.get_parent().name),"wall":str(node.name),"bounds":[box.position.x,box.position.y,box.position.z,box.end.x,box.end.y,box.end.z]})
	DirAccess.make_dir_recursive_absolute(directory)
	var document:=GLTFDocument.new();var state:=GLTFState.new()
	var append_error:=document.append_from_scene(context,state)
	var export_error:=document.write_to_filesystem(state,directory.path_join("context.glb")) if append_error==OK else append_error
	var after:=_digest();var render_after:=_render_digest();var valid:=export_error==OK and not before.is_empty() and before==after and not render_before.is_empty() and render_before==render_after and not copied.is_empty() and route_sha==FileAccess.get_sha256(route_path)
	for capture: Dictionary in captures:valid=valid and capture.saved
	var report: Dictionary={"evidence_class":"INERT","scope":"Actual composed static geometry near the supplied routes, in building-local coordinates, and optional filled diagnostic captures. Gray exported materials are diagnostic only; no whole installation, surface or runtime acceptance.","valid":valid,"runtime_inputs_sha256":after,"rendering_inputs_sha256":render_after,"route_sha256":route_sha,"context_sha256":FileAccess.get_sha256(directory.path_join("context.glb")),"draws":copied,"wall_boxes":walls,"captures":captures}
	FileAccess.open(directory.path_join("context.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("HEATING CONTEXT: ",copied.size()," draws; ",walls.size()," wall boxes; valid=",valid)
	context.free();world.shutdown_for_tests();world.free()
	get_tree().quit(0 if valid else 1)
