extends RefCounted
## Unculled fitting reference, with the owner's eye-level rail removal applied.
## Shared face/profile operations remain the shipping geometry authority.
const Trim=preload("res://scripts/building/orison_v2_millwork.gd")
static func build(room: Node3D, record: Dictionary, floor_y: float,
		clear_height: float, wall_thickness: float, material: Material,
		panel_material: Material, doors: Array = [], window_boxes: Array[AABB] = [],
		wall_stock: Array[Dictionary] = []) -> void:
	if record.get("open_shell",false): return
	if wall_stock.is_empty(): wall_stock=Trim.collect_wall_stock(room.get_parent())
	var faces := Trim._room_wall_faces(record,wall_stock,wall_thickness)
	var casings := Trim._casing_boxes(record,doors,floor_y,wall_thickness)
	casings.append_array(window_boxes)
	var decorative: bool = str(record.get("class","")) in ["private","public"] or "PUBLIC_CORE" in str(record.id)
	var paneled: bool = str(record.get("class",""))=="public" or "PUBLIC_CORE" in str(record.id)
	var batches := {"HistoricMillwork":[],"PublicWainscot":[],"PublicWainscotFrames":[],"PublicWainscotCap":[]}
	var sources := {"HistoricMillwork":PackedStringArray(),"PublicWainscot":PackedStringArray(),"PublicWainscotFrames":PackedStringArray(),"PublicWainscotCap":PackedStringArray()}
	var profiles: Array[Dictionary] = [
		{"at":.07,"height":.14,"depth":.032,"batch":"HistoricMillwork"},
		{"at":.153,"height":.026,"depth":.042,"batch":"HistoricMillwork"}]
	if decorative:
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
			var extent := Trim._corner_run(face,low,high,float(profile.depth),faces)
			var normal_a: float = face.face
			var normal_b: float = normal_a+float(face.inward)*float(profile.depth)
			for section: Rect2 in Trim._profile_sections(extent,low,high,minf(normal_a,normal_b),maxf(normal_a,normal_b),bool(face.along_x),casings):
				var band := Vector2(section.position.y,section.end.y)
				for run: Vector2 in [Vector2(section.position.x,section.end.x)]:
					if run.y-run.x<.001: continue
					var transform := Trim._placement(face,run,(band.x+band.y)*.5,band.y-band.x,float(profile.depth))
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
						var stile := Trim._placement(face,Vector2(along-.018,along+.018),(stile_low+stile_high)*.5,stile_high-stile_low,.036)
						# Native longitudinal UV follows the vertical stile after rotation.
						var angle := (0.0 if float(face.inward)>0.0 else PI) if bool(face.along_x) else (PI*.5 if float(face.inward)>0.0 else -PI*.5)
						stile.basis=Basis(Vector3.UP,angle)*Basis(Vector3.BACK,PI*.5)*Basis.from_scale(Vector3(stile_high-stile_low,.036,.036))
						batches.PublicWainscotFrames.append(stile)
						sources.PublicWainscotFrames.append(str(face.source))
	for label: String in batches:
		Trim._emit(room,label,batches[label],sources[label],"trim" if label=="HistoricMillwork" else "wood_dark")
