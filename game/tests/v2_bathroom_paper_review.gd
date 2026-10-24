extends "res://tests/v2_bathroom_moisture_review.gd"
## Existing actual-input route, then untimed static holder/material/contact views.
func _init() -> void: route_label="V2 BATHROOM PAPER AND MOISTURE REVIEW"

func _route() -> void:
	await super._route()
	# Independent static installation checks still run after an optical failure.
	await _paper_review()

func _paper_review() -> void:
	_phase="paper_review_excluded"
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/bath_details.json"))
	var inspector:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var rows: Array=[];var contacts: Array=[];var meshes: Dictionary={};var materials: Dictionary={};var count:=0
	for record: Dictionary in source.props:
		if record.kind!="toilet_roll":continue
		count+=1
		var wc:=world.adapter.resolve(str(record.support)) as StaticBody3D
		var detail: Node3D=wc.find_child(str(record.id),true,false)
		if not _require(detail!=null,"wall roller retains existing household dressing identity: "+str(record.id)):continue
		_require(detail.get_parent()==wc,"fixed toilet owner still owns dressing lifetime")
		_require(detail.position.is_equal_approx(Vector3(record.position[0],record.position[1],record.position[2])),"holder uses authored wall installation offset")
		_require(detail.find_children("*","CollisionObject3D",true,false).is_empty() and not detail.is_processing(),"static paper adds no simulation or player obstruction")
		var visuals:=detail.find_children("*","MeshInstance3D",true,false)
		_require(visuals.size()==3,"holder exports exactly three immutable material batches")
		for i in visuals.size():
			var visual:=visuals[i] as MeshInstance3D;var key:=str(record.id)+"/"+str(i)
			meshes[key]=inspector._mesh(visual.mesh);materials[key]=inspector._material(visual.get_active_material(0))
			rows.append({"path":str(visual.get_path()),"mesh":key,"materials":[key]})
		# Original architectural wall, with no new fitting collision to mask a gap.
		var bad_contact:=false
		for x in [-.073,.073]:
			var contact:=detail.to_global(Vector3(x,0,0))
			var normal: Vector3=detail.global_basis.z.normalized()
			var ray:=PhysicsRayQueryParameters3D.create(contact-normal*.04,contact+normal*.04,1,[player.get_rid(),wc.get_rid()])
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
			var bearing_ok:=not hit.is_empty() and (hit.position as Vector3).distance_to(contact)<.002
			bad_contact=bad_contact or not bearing_ok
			contacts.append({"id":record.id,"x":x,"expected":str(contact),"hit":str(hit.get("position","missing")),"owner":str(hit.collider.get_path()) if not hit.is_empty() else "missing","error_m":(hit.position as Vector3).distance_to(contact) if not hit.is_empty() else -1.0})
			_require(bearing_ok,"mounting escutcheon bears on retained wall within 2 mm: "+str(record.id))
		var low:=Vector3(record.bounds[0][0],record.bounds[0][1],record.bounds[0][2])
		var high:=Vector3(record.bounds[1][0],record.bounds[1][1],record.bounds[1][2])
		var fitted:=detail.transform*AABB(low,high-low)
		_require(fitted.end.x<-.27 and fitted.position.y>.45 and (fitted.position.z>.14 or not is_zero_approx(detail.rotation.y)),"entire holder clears bowl/seat envelope")
		if record.unit in ["4B","3B","5C"] or not is_zero_approx(detail.rotation.y) or bad_contact:
			var camera:=Camera3D.new();world.add_child(camera);camera.attributes=player.camera.attributes;camera.fov=47.0
			camera.global_position=detail.to_global(Vector3(-.10,.15,-.52));camera.look_at(detail.to_global(Vector3(0,-.04,-.07)));camera.make_current()
			for frame in 16:await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("paper_"+str(record.unit)+".png"))
			player.camera.make_current();camera.queue_free()
	_require(count==12,"all twelve installed developed-home paper holders inspected")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("paper_surfaces.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Twelve installed fixed paper holders; no interaction/save or whole-world qualification","contacts":contacts,"draws":rows,"meshes":meshes,"materials":materials,"textures":inspector.texture_rows,"failures":failures},"\t"))
	inspector.free()
