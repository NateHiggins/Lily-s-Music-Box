extends RefCounted
## Finish every actual room-facing wall, including shared stock and cut walls.
## Geometry/collision ownership remains with the shell. All trim is visual.
const PROFILE := preload("res://assets/props/millwork_profile.glb")
const STOCK_SHADER := preload("res://shaders/v2_millwork_stock.gdshader")
const EYE_RAIL_HEIGHT := 1.65
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

static func collect_wall_stock(shell: Node3D) -> Array[Dictionary]:
	var stock: Array[Dictionary] = []
	for owner: Node in shell.get_children():
		if not owner is Node3D: continue
		for wall: Node in owner.get_children():
			if not wall is MeshInstance3D or not str(wall.name).begins_with("Wall"): continue
			var label := str(wall.name)
			var along_x := label.begins_with("WallNorth") or label.begins_with("WallSouth")
			if not along_x and not (label.begins_with("WallWest") or label.begins_with("WallEast")): continue
			var collision := wall.get_node_or_null("Collision")
			if collision == null: continue
			for shape: Node in collision.get_children():
				if not shape is CollisionShape3D or not shape.shape is BoxShape3D: continue
				var transform: Transform3D = shell.global_transform.affine_inverse()*shape.global_transform
				var box: AABB = transform*AABB(-shape.shape.size*.5,shape.shape.size)
				stock.append({"owner":str(owner.name),"source":str(owner.name)+"/"+label,"label":label,"along_x":along_x,"bounds":box})
	return stock

static func _room_wall_faces(record: Dictionary, stock: Array[Dictionary], wall_depth: float) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	var rect: Array = record.rect
	for wall: Dictionary in stock:
		for along_x: bool in [bool(wall.along_x),not bool(wall.along_x)]:
			var box: AABB = wall.bounds
			var fixed: float = box.get_center().z if along_x else box.get_center().x
			var normal_start: float = float(rect[1 if along_x else 0])
			var normal_end: float = float(rect[3 if along_x else 2])
			var own_extension: bool = along_x==bool(wall.along_x) and wall.owner==str(record.id) and "Extension" in str(wall.label)
			var inner_rect: bool = record.get("rect_is_inner",false)
			var normal_half: float = (box.size.z if along_x else box.size.x)*.5
			var inward := signf((normal_start+normal_end)*.5-fixed)
			if inward==0.0: continue
			var face: float = (box.end.z if inward>0.0 else box.position.z) if along_x else (box.end.x if inward>0.0 else box.position.x)
			var tolerance := (maxf(normal_half,wall_depth*.5)+.025 if inner_rect else maxf(normal_half,wall_depth*.5)+.005) if along_x==bool(wall.along_x) else wall_depth*.5+.005
			if not own_extension and minf(absf(face-normal_start),absf(face-normal_end))>tolerance: continue
			var start: float = box.position.x if along_x else box.position.z
			var finish: float = box.end.x if along_x else box.end.z
			if not own_extension:
				start=maxf(start,float(rect[0 if along_x else 1]))
				finish=minf(finish,float(rect[2 if along_x else 3]))
			if finish-start<.001: continue
			faces.append({"along_x":along_x,"inward":inward,"face":face,"start":start,"finish":finish,"low":box.position.y,"high":box.end.y,"source":wall.source})
	# Clip only where a real perpendicular inner wall closes the corner.
	# Open-ended stock keeps its full exposed length and receives a return.
	for face: Dictionary in faces:
		for other: Dictionary in faces:
			if bool(face.along_x)==bool(other.along_x): continue
			if minf(float(face.high),float(other.high))-maxf(float(face.low),float(other.low))<.001: continue
			if float(face.face)<float(other.start)-.005 or float(face.face)>float(other.finish)+.005: continue
			var plane: float = other.face
			if plane>float(face.start) and plane-float(face.start)<wall_depth*.75: face.start=plane
			if plane<float(face.finish) and float(face.finish)-plane<wall_depth*.75: face.finish=plane
	return faces

static func _corner_run(face: Dictionary, low: float, high: float, depth: float, faces: Array[Dictionary]) -> Vector2:
	var start: float = face.start
	var finish: float = face.finish
	if bool(face.along_x): return Vector2(start,finish)
	# X members own the butt corner only where a perpendicular wall really exists.
	for other: Dictionary in faces:
		if not bool(other.along_x) or minf(high,float(other.high))-maxf(low,float(other.low))<.001: continue
		if float(face.face)<float(other.start)-.001 or float(face.face)>float(other.finish)+.001: continue
		if absf(float(other.face)-start)<.001: start+=depth
		if absf(float(other.face)-finish)<.001: finish-=depth
	return Vector2(start,finish)

static func build(room: Node3D, record: Dictionary, floor_y: float,
		clear_height: float, wall_thickness: float, material: Material,
		panel_material: Material, doors: Array = [], window_boxes: Array[AABB] = [],
		wall_stock: Array[Dictionary] = []) -> void:
	if record.get("open_shell",false): return
	if wall_stock.is_empty(): wall_stock=collect_wall_stock(room.get_parent())
	var faces := _room_wall_faces(record,wall_stock,wall_thickness)
	var casings := _casing_boxes(record,doors,floor_y,wall_thickness)
	casings.append_array(window_boxes)
	var decorative: bool = str(record.get("class","")) in ["private","public"] or "PUBLIC_CORE" in str(record.id)
	var paneled: bool = str(record.get("class",""))=="public" or "PUBLIC_CORE" in str(record.id)
	var batches := {"HistoricMillwork":[],"PublicWainscot":[],"PublicWainscotFrames":[],"PublicWainscotCap":[]}
	var sources := {"HistoricMillwork":PackedStringArray(),"PublicWainscot":PackedStringArray(),"PublicWainscotFrames":PackedStringArray(),"PublicWainscotCap":PackedStringArray()}
	var profiles: Array[Dictionary] = [
		{"at":.07,"height":.14,"depth":.032,"batch":"HistoricMillwork"},
		{"at":.153,"height":.026,"depth":.042,"batch":"HistoricMillwork"}]
	if decorative:
		profiles.append({"at":EYE_RAIL_HEIGHT,"height":.042,"depth":.042,"batch":"HistoricMillwork"})
		if not record.get("no_ceiling",false):
			for band: Vector3 in [Vector3(clear_height-.025,.05,.032),Vector3(clear_height-.075,.05,.046),Vector3(clear_height-.1125,.025,.054)]:
				profiles.append({"at":band.x,"height":band.y,"depth":band.z,"batch":"HistoricMillwork"})
	if paneled:
		profiles.append_array([
			{"at":.743,"height":1.154,"depth":.016,"batch":"PublicWainscot"},
			{"at":1.34,"height":.04,"depth":.050,"batch":"PublicWainscotCap"},
			{"at":.211,"height":.030,"depth":.036,"batch":"PublicWainscotFrames"},
			{"at":1.255,"height":.030,"depth":.036,"batch":"PublicWainscotFrames"}])
	for face: Dictionary in faces:
		for profile: Dictionary in profiles:
			var low := maxf(floor_y+float(profile.at)-float(profile.height)*.5,float(face.low))
			var high := minf(floor_y+float(profile.at)+float(profile.height)*.5,float(face.high))
			if high-low<.001: continue
			var extent := _corner_run(face,low,high,float(profile.depth),faces)
			for band: Vector2 in _height_bands(low,high,casings):
				var normal_a: float = face.face
				var normal_b: float = normal_a+float(face.inward)*float(profile.depth)
				for run: Vector2 in _clear_runs(extent.x,extent.y,band.x,band.y,minf(normal_a,normal_b),maxf(normal_a,normal_b),bool(face.along_x),casings):
					if run.y-run.x<.001: continue
					var transform := _placement(face,run,(band.x+band.y)*.5,band.y-band.x,float(profile.depth))
					var label: String = profile.batch
					batches[label].append(transform)
					sources[label].append(str(face.source))
					if label!="PublicWainscot": continue
					var stile_low := maxf(floor_y+.226,band.x)
					var stile_high := minf(floor_y+1.240,band.y)
					if stile_high-stile_low<.001 or run.y-run.x<.15: continue
					var count := maxi(1,ceili((extent.y-extent.x)/.72))
					for index in count+1:
						var along := lerpf(extent.x+.038,extent.y-.038,float(index)/count)
						if along-.018<run.x or along+.018>run.y: continue
						var stile := _placement(face,Vector2(along-.018,along+.018),(stile_low+stile_high)*.5,stile_high-stile_low,.036)
						# Native longitudinal UV follows the vertical stile after rotation.
						var angle := (0.0 if float(face.inward)>0.0 else PI) if bool(face.along_x) else (PI*.5 if float(face.inward)>0.0 else -PI*.5)
						stile.basis=Basis(Vector3.UP,angle)*Basis(Vector3.BACK,PI*.5)*Basis.from_scale(Vector3(stile_high-stile_low,.036,.036))
						batches.PublicWainscotFrames.append(stile)
						sources.PublicWainscotFrames.append(str(face.source))
	for label: String in batches:
		_emit(room,label,batches[label],sources[label],"trim" if label=="HistoricMillwork" else "wood_dark")

static func _placement(face: Dictionary, run: Vector2, height_at: float, height: float, depth: float) -> Transform3D:
	var inward: float = face.inward
	var along_x: bool = face.along_x
	var normal_at: float = float(face.face)+inward*depth*.5
	var position := Vector3((run.x+run.y)*.5,height_at,normal_at) if along_x else Vector3(normal_at,height_at,(run.x+run.y)*.5)
	var angle := (0.0 if inward>0.0 else PI) if along_x else (PI*.5 if inward>0.0 else -PI*.5)
	return Transform3D(Basis(Vector3.UP,angle)*Basis.from_scale(Vector3(run.y-run.x,height,depth)),position)

static func _emit(room: Node3D, label: String, transforms: Array, sources: PackedStringArray, key: String) -> void:
	if transforms.is_empty(): return
	if _meshes.is_empty():
		var source := PROFILE.instantiate()
		for pair: Array in [["HistoricMillwork","BeadedTrim"],["PublicWainscotFrames","WainscotFrame"],["PublicWainscotCap","WainscotCap"],["PublicWainscot","WainscotBacking"]]:
			_meshes[pair[0]]=(source.find_child(pair[1],true,false) as MeshInstance3D).mesh
		source.free()
	var recipe := key+":"+str(label!="PublicWainscot")
	if not _materials.has(recipe):
		var stock := MatLib.get_mat(key) as StandardMaterial3D
		var finish := ShaderMaterial.new()
		finish.shader=STOCK_SHADER
		finish.set_shader_parameter("albedo_tex",stock.albedo_texture)
		finish.set_shader_parameter("rough_tex",stock.roughness_texture)
		finish.set_shader_parameter("normal_tex",stock.normal_texture)
		finish.set_shader_parameter("stock_tint",stock.albedo_color)
		finish.set_shader_parameter("roughness_gain",stock.roughness)
		finish.set_shader_parameter("normal_gain",.12)
		finish.set_shader_parameter("longitudinal_grain",label!="PublicWainscot")
		finish.set_shader_parameter("meters_per_tile",float(preload("res://scripts/generated/material_sets.gd").SETS[key][3]))
		_materials[recipe]=finish
	var batch := MultiMeshInstance3D.new()
	batch.name=label
	batch.material_override=_materials[recipe]
	var multimesh := MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data=true
	multimesh.mesh=_meshes[label]
	multimesh.instance_count=transforms.size()
	for index in transforms.size():
		var transform: Transform3D=transforms[index]
		multimesh.set_instance_transform(index,transform)
		multimesh.set_instance_custom_data(index,Color(transform.basis.x.length(),transform.basis.y.length(),transform.basis.z.length(),1.0 if label=="PublicWainscot" else 0.0))
	batch.multimesh=multimesh
	batch.set_meta("wall_sources",sources)
	batch.set_meta("material_key",key)
	batch.set_meta("separate_wood_piece",label=="PublicWainscotCap")
	room.add_child(batch)

# Derive the complete casing envelopes once per room, including the returns
# on perpendicular walls at narrow vestibule corners. Coordinates remain owned
# by the semantic aperture; these boxes are visual clipping only.
static func _casing_boxes(room: Dictionary, doors: Array, floor_y: float,
        wall_depth: float) -> Array[AABB]:
	var boxes: Array[AABB] = []
	var roof_fits: Array = []
	if str(room.get("level",""))=="ROOF":
		roof_fits=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_roof_drainage_falls.json")).door_fittings
	for door: Dictionary in doors:
		if str(room.id) not in door.connects: continue
		var width := float(door.width)
		var height := float(door.height)
		var span: Vector2 = preload("res://scripts/generated/v2_exterior_masonry.gd").DOOR_SPANS.get(str(door.id),Vector2(-wall_depth*.5,wall_depth*.5))
		var casing_floor_y := floor_y
		for fit: Dictionary in roof_fits:
			if str(fit.id)==str(door.id): casing_floor_y+=float(fit.candidate_mount_offset)
		var placement := Transform3D(Basis(Vector3.UP,float(door.yaw)),Vector3(door.center[0],casing_floor_y,door.center[1]))
		for side in [-1.0,1.0]:
			var z: float = (span.x if side<0 else span.y)+side*.009
			for x in [-width*.5-.045,width*.5+.045]:
				var size := Vector3(.09,height,.018)
				boxes.append(placement*AABB(Vector3(x,height*.5,z)-size*.5,size))
			var size := Vector3(width+.18,.09,.018)
			boxes.append(placement*AABB(Vector3(0,height+.045,z)-size*.5,size))
	return boxes

static func _clear_runs(start: float, finish: float, low: float, high: float,
        normal_low: float, normal_high: float, along_x: bool,
        casings: Array[AABB]) -> Array[Vector2]:
	var runs: Array[Vector2] = [Vector2(start,finish)]
	for casing: AABB in casings:
		if minf(high,casing.end.y)-maxf(low,casing.position.y)<.0001: continue
		var back: float = casing.position.z if along_x else casing.position.x
		var front: float = casing.end.z if along_x else casing.end.x
		if minf(normal_high,front)-maxf(normal_low,back)<.0001: continue
		var left: float = casing.position.x if along_x else casing.position.z
		var right: float = casing.end.x if along_x else casing.end.z
		var remaining: Array[Vector2] = []
		for run: Vector2 in runs:
			if right<=run.x or left>=run.y:
				remaining.append(run)
			else:
				if left-run.x>.001: remaining.append(Vector2(run.x,left))
				if run.y-right>.001: remaining.append(Vector2(right,run.y))
		runs=remaining
	return runs

# Split tall panel backing at aperture edges before clipping horizontal runs.
# Otherwise a low sill erases the entire panel below it.
static func _height_bands(low: float, high: float, casings: Array[AABB]) -> Array[Vector2]:
	var edges: Array[float]=[low,high]
	for casing: AABB in casings:
		for edge in [casing.position.y,casing.end.y]:
			if edge>low+.001 and edge<high-.001: edges.append(edge)
	edges.sort()
	var result: Array[Vector2]=[]
	var start := low
	for edge: float in edges:
		if edge-start>.001:
			result.append(Vector2(start,edge))
			start=edge
	return result
