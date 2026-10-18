extends RefCounted
## Floor-borne programmes reference retained platforms; core air volumes remain.

static func _valid_rect(value: Variant) -> bool:
	if value is not Array or value.size()!=4:return false
	for v: Variant in value:
		if typeof(v) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(v)):return false
	return value[0]<value[2] and value[1]<value[3]

static func programme_errors(layout: Dictionary, space: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	if not space.has("floor_platforms") and not space.has("landing_core") and not space.has("programme_anchors"):return errors
	var core: Dictionary={};var platforms: Dictionary={};var anchors: Dictionary={}
	for row: Dictionary in layout.get("spaces",[]):
		if str(row.id)==str(space.get("landing_core","")):core=row
	for row: Dictionary in layout.get("platforms",[]):platforms[str(row.id)]=row
	for row: Dictionary in layout.get("anchors",[]):anchors[str(row.id)]=row
	var floor:=str(space.get("level",""))
	if core.is_empty() or str(core.get("class",""))!="core" or str(core.get("level",""))!=floor or str(core.id)!=floor+"_PUBLIC_CORE":errors.append("existing same-floor public core required")
	if str(space.get("class",""))!="public" or not bool(space.get("open_shell",false)) or not bool(space.get("no_floor",false)) or not bool(space.get("no_ceiling",false)):errors.append("landing must retain its open, externally supported construction")
	var ids: Variant=space.get("floor_platforms",[])
	var expected: Array[String]=[]
	for identity: String in platforms:
		if identity.begins_with(floor+"_PUBLIC_LANDING_"):expected.append(identity)
	if ids is not Array or ids.is_empty() or ids.size()!=expected.size():errors.append("complete platform ownership required");return errors
	var seen: Dictionary={};var bounds: Array=[]
	for value: Variant in ids:
		if value is not String or seen.has(value) or value not in expected:errors.append("unknown, duplicate or foreign landing platform");continue
		seen[value]=true
		var owner: Dictionary=platforms[value]
		if str(owner.level)!=floor:errors.append("platform belongs to another floor");continue
		if not _valid_rect(owner.get("rect")):errors.append("invalid platform footprint");continue
		var r: Array=owner.rect
		if bounds.is_empty():bounds=r.duplicate()
		else:bounds=[minf(bounds[0],r[0]),minf(bounds[1],r[1]),maxf(bounds[2],r[2]),maxf(bounds[3],r[3])]
	if not core.is_empty() and not _valid_rect(core.get("rect")):errors.append("invalid core envelope")
	elif not core.is_empty() and bounds.size()==4:
		var c: Array=core.rect;var box: Array=space.get("rect",[])
		if box.size()!=4:errors.append("landing envelope required")
		else:
			for i in 4:
				if absf(float(box[i])-float(bounds[i]))>.00001:errors.append("landing envelope differs from its supports");break
		if bounds[0]<c[0] or bounds[1]<c[1] or bounds[2]>c[2] or bounds[3]>c[3]:errors.append("landing exceeds its core")
	var landmarks: Variant=space.get("programme_anchors",[])
	if landmarks is not Array or landmarks.is_empty():errors.append("physical landmark anchors required")
	else:
		seen.clear()
		for value: Variant in landmarks:
			var anchor: Dictionary=anchors.get(str(value),{})
			if value is not String or seen.has(value) or anchor.is_empty() or str(anchor.get("level",""))!=floor or str(anchor.get("space",""))!=str(space.get("landing_core","")) or str(anchor.get("kind",""))!="furniture":errors.append("same-core landmark required")
			seen[value]=true
	var entrance:=false
	for stair: Dictionary in layout.get("stairs",[]):
		if floor in [str(stair.get("from","")),str(stair.get("to",""))]:entrance=true
	for landing: Dictionary in layout.get("lift_landings",[]):
		if str(landing.get("level",""))==floor:entrance=true
	if not entrance:errors.append("existing vertical entrance required")
	return errors

static func rectangles(layout: Dictionary, space: Dictionary) -> Array:
	if not space.has("floor_platforms") and not space.has("landing_core") and not space.has("programme_anchors"):return [space.rect]
	# A broken owner must never fall back to the envelope and fill a shaft.
	if not programme_errors(layout,space).is_empty():return []
	var result: Array=[]
	for row: Dictionary in layout.platforms:
		if str(row.id) in space.floor_platforms:result.append(row.rect)
	return result

static func contains_xz(layout: Dictionary, space: Dictionary, point: Vector2) -> bool:
	for r: Array in rectangles(layout,space):
		if r[0]<=point.x and point.x<=r[2] and r[1]<=point.y and point.y<=r[3]:return true
	return false

static func room_index(layout: Dictionary) -> Array[Dictionary]:
	var heights: Dictionary={}
	for row: Dictionary in layout.get("levels",[]):heights[str(row.id)]=float(row.y)
	var index: Array[Dictionary]=[]
	for space: Dictionary in layout.get("spaces",[]):
		var r: Array=space.rect
		index.append({"id":str(space.id),"y":float(heights.get(str(space.level),INF)),"rectangles":rectangles(layout,space),"programme":space.has("floor_platforms"),"area":float((r[2]-r[0])*(r[3]-r[1]))})
	return index

static func room_at_index(index: Array[Dictionary], point: Vector3, floor_height: float) -> String:
	var chosen: String="";var smallest:=INF;var programme:=false
	for entry: Dictionary in index:
		if point.y<float(entry.y)-.15 or point.y>=float(entry.y)+floor_height-.15:continue
		var inside:=false
		for r: Array in entry.rectangles:
			if r[0]<=point.x and point.x<=r[2] and r[1]<=point.z and point.z<=r[3]:inside=true;break
		if not inside:continue
		var is_programme: bool=entry.programme;var area: float=entry.area
		if (is_programme and not programme) or (is_programme==programme and area<smallest):chosen=str(entry.id);smallest=area;programme=is_programme
	return chosen

static func room_at(layout: Dictionary, point: Vector3) -> String:
	return room_at_index(room_index(layout),point,float(layout.dimensions.floor_to_floor))
