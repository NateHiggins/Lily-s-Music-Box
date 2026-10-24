extends "res://tests/v2_fire_capacity_rig_programme.gd"
## Separate610-ring candidate. Dense prototype defaults/predicates remain intact.
class CandidateWorldProgramme extends "res://tests/v2_fire_hose_world_contact_programme.gd":
	func _analytic_boxes_enabled() -> bool:return true
	func run(root: Node3D,owner_rig: RefCounted,excluded: Array[RID]) -> RefCounted:
		var contact: RefCounted=await super.run(root,owner_rig,excluded)
		if failures.is_empty():await _compare_box_faces(root,owner_rig,contact)
		return contact
	func _compare_box_faces(root: Node3D,owner_rig: RefCounted,contact: RefCounted) -> void:
		var before: PackedVector3Array=owner_rig.strand.points.duplicate()
		var after:=before.duplicate()
		for i in after.size():after[i]+=Vector3.DOWN*.02
		var frames: Array[Transform3D]=owner_rig.model_frames(before);var lowest:=INF
		for i in before.size():
			for point: Vector3 in contact.sections[i].outer:lowest=minf(lowest,(frames[i]*point).y)
		var body:=StaticBody3D.new();var leaf:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(4,.04,4);leaf.shape=box;body.add_child(leaf);root.add_child(body)
		var original: Transform3D=owner_rig.model.global_transform;var rows: Array=[]
		for height: float in [-3.2,9.6,19.2]:
			for angle: float in [PI,-PI]:
				owner_rig.model.global_transform=Transform3D(Basis(Vector3.UP,angle),Vector3(-4.35,height,-7.87))
				body.global_transform=owner_rig.model.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,lowest-.025,.1))
				await root.get_tree().physics_frame;await root.get_tree().physics_frame
				var results: Array=[]
				for enabled: bool in [false,true]:
					contact.analytic_boxes=enabled
					var result: Dictionary=contact.motion_constraints(before,after,4096)
					var offsets: Dictionary={};var normals:=true
					for plane: Dictionary in result.planes:
						offsets[plane.ring]=plane.offset;normals=normals and plane.normal.dot(Vector3.UP)>.999999
					results.append({"valid":result.valid,"truncated":result.truncated,"offsets":offsets,"normals":normals,"analytic_segments":contact.analytic_segments})
				var error:=0.;var same: bool=results[0].offsets.size()==results[1].offsets.size()
				for ring: int in results[0].offsets:
					if not results[1].offsets.has(ring):same=false;continue
					error=maxf(error,absf(results[0].offsets[ring]-results[1].offsets[ring]))
				check(same and error<=.000002 and results[0].valid and results[1].valid and not results[0].truncated and not results[1].truncated and results[0].normals and results[1].normals and results[1].analytic_segments>0,"real box-face shortcut matches native response rings and planes within2um at "+str([height,angle]))
				rows.append({"height":height,"angle":angle,"maximum_plane_difference_m":error,"ring_sets_equal":same,"analytic_segments":results[1].analytic_segments})
		# A second shape on the same body invalidates the complete-face shortcut,
		# even if broad-phase output reports only the nearby first shape.
		var extra:=CollisionShape3D.new();extra.shape=BoxShape3D.new();extra.position=Vector3(10,10,10);body.add_child(extra)
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		contact.analytic_boxes=true
		var compound: Dictionary=contact.motion_constraints(before,after,4096)
		check(compound.valid and not compound.planes.is_empty() and contact.analytic_segments==0,"multi-shape body uses original native shell queries")
		body.free();owner_rig.model.global_transform=original
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		# A small box fitting the actual bore must never become a solid halfspace.
		body=StaticBody3D.new();leaf=CollisionShape3D.new();box=BoxShape3D.new();box.size=Vector3(.004,.004,.004);leaf.shape=box;body.add_child(leaf);root.add_child(body)
		body.global_position=(owner_rig.model.global_transform*frames[0])*Vector3(0,.004,0)
		await root.get_tree().physics_frame;await root.get_tree().physics_frame
		check(not contact.intersects_pose(before),"a real4mm box still fits the open native hose bore")
		body.free();await root.get_tree().physics_frame;await root.get_tree().physics_frame
		var out:=OS.get_environment("SHOT_DIR")
		if not out.is_empty():FileAccess.open(out.path_join("box_support_comparison.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","rows":rows,"failures":failures},"\t"))
	func _check_native_sections(owner_rig: RefCounted,owner_contact: RefCounted) -> void:
		check(owner_contact.sections.size()==610 and owner_contact.sections.size()==owner_rig.indices.size(),"all610 candidate sections retain32outer and32inner native points")
	func _projection_path() -> String:return "res://tests/fixtures/v2_deployable_hose_rig.json"
	func _flat_probe_span(rest: PackedVector3Array,index: int) -> bool:
		# The actual probe sits30mm along the straight native bore. Validate
		# 40mm of physical straight stock rather than assuming eight5mm rows.
		if index<1 or index+1>=rest.size():return false
		var axis: Vector3=(rest[index+1]-rest[index]).normalized()
		if axis.dot((rest[index]-rest[index-1]).normalized())<.999999:return false
		var distance:=0.
		for i in range(index,rest.size()-1):
			var span: Vector3=rest[i+1]-rest[i]
			if axis.dot(span.normalized())<.999999:return false
			distance+=span.length()
			if distance>=.04:return true
		return false
func _projection_path() -> String:return "res://tests/fixtures/v2_deployable_hose_rig.json"
func _make_world_programme() -> RefCounted:return CandidateWorldProgramme.new()
func _check_native_density() -> void:
	check(rig.indices.size()==610 and rig.indices.size()==rig.rest.size() and absf(rig.strand.total_length-15.24)<.00002,"610 native candidate rings retain the full15.24m strand")
	var widest:=0.
	for distance: float in rig.strand.lengths:widest=maxf(widest,distance)
	check(widest<=.080001,"candidate straight spans are at most80mm and all authored curve rings remain")
	print("FIRE CANDIDATE RESOLUTION: rings=",rig.indices.size()," maximum_interval_m=",widest)
