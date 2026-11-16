extends Node3D
## Nearby physics attribution preflight, not stage or gameplay qualification.
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var output:=OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK:get_tree().quit(2);return
	var kit:Node3D=preload("res://scripts/building/orison_v2_harukiya_drumkit.gd").mount(self,Transform3D.IDENTITY)
	if kit==null:get_tree().quit(2);return
	var identity:=preload("res://tests/harukiya_native_contact_identity.gd").new()
	if not identity.load_sources():get_tree().quit(2);return
	await get_tree().physics_frame;await get_tree().physics_frame
	var rows:Array=[]
	var data:Dictionary=kit.get_meta("source")
	for id:String in identity.source.contacts:
		var p:Array=data.contacts[id].position;var n:Array=data.contacts[id].normal
		var point:=Vector3(float(p[0]),float(p[1]),float(p[2]))
		var normal:=Vector3(float(n[0]),float(n[1]),float(n[2])).normalized()
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.02,point-normal*.02,1))
		var row:Dictionary={"contact":id,"point":point,"ray_hit":hit.get("position"),"normal":hit.get("normal"),"matched":identity.match_hit(hit,id)}
		if not hit.is_empty():
			var collider:Node=hit.collider
			var draw:=collider.get_parent() as MeshInstance3D
			row["draw_transform"]=draw.global_transform
			row["part"]=draw.get_meta("harukiya_drum_part","")
			row["hit_face_index"]=hit.get("face_index",-1)
			var shapes:=collider.find_children("*","CollisionShape3D",true,false)
			row["shape_count"]=shapes.size()
			if shapes.size()==1:
				var shape:=shapes[0] as CollisionShape3D
				row["shape_class"]=shape.shape.get_class();row["shape_transform"]=shape.global_transform
				if shape.shape is ConcavePolygonShape3D:
					var faces:PackedVector3Array=shape.shape.get_faces();var numeric:Array=[]
					for v:Vector3 in faces:numeric.append([v.x,v.y,v.z])
					row["all_collision_faces_local"]=numeric
					row["mesh_format"]=draw.mesh.surface_get_format(0)
		rows.append(row)
	FileAccess.open(output.path_join("native_faces.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Native-only collision attribution; no current cast or stage acceptance","rows":rows},"\t"))
	kit.free();await get_tree().process_frame
	get_tree().quit(0)
