extends RefCounted
## Shared native deep linings. Proxy Frame* boxes retain only source dimensions.
const DATA := "res://data/orison_v2/door_lining_mitres.json"
var variants: Dictionary = {}
var openings: Dictionary = {}
var errors: Array[String] = []

func prepare(layout: Dictionary) -> bool:
	variants.clear(); openings.clear(); errors.clear()
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if source is not Dictionary or source.schema_version != 1 or float(source.board_width) != .09:
		errors.append("native lining schema or stock width changed"); return false
	var packed := load(str(source.asset)) as PackedScene
	if packed == null: errors.append("native lining asset missing"); return false
	var model := packed.instantiate() as Node3D
	for row: Dictionary in source.variants:
		var key := str(row.id)
		var draw := model.find_child(key,true,false) as MeshInstance3D
		if variants.has(key) or draw == null or draw.mesh == null:
			errors.append("missing or duplicate native lining: "+key); continue
		var expected := key_for(float(row.width),float(row.height),float(row.depth))
		if key != expected or draw.mesh.get_faces().size() != 36*3:
			errors.append("native lining dimensions or topology changed: "+key); continue
		var parts := {}
		for member: String in ["left","head","right"]:
			var part := model.find_child(key+"_"+member,true,false) as MeshInstance3D
			if part == null or part.mesh == null: errors.append("native lining member missing: "+key+"/"+member)
			else: parts[member] = part.mesh
		if parts.size() == 3:
			variants[key] = {"mesh":draw.mesh,"parts":parts,"width":float(row.width),"height":float(row.height),"depth":float(row.depth)}
	model.free()
	for row: Dictionary in source.doors:
		var identity := str(row.id)
		if openings.has(identity) or not variants.has(str(row.variant)):
			errors.append("duplicate opening or missing lining variant: "+identity); continue
		var span := Vector2(row.span[0],row.span[1])
		openings[identity] = {"variant":str(row.variant),"span":span}
	if openings.size() != layout.doors.size(): errors.append("lining inventory does not cover every opening")
	var half_depth := float(layout.dimensions.partition_wall)*.5
	for row: Dictionary in layout.doors:
		var identity := str(row.id)
		if not openings.has(identity): errors.append("opening has no native lining: "+identity); continue
		var span: Vector2 = preload("res://scripts/generated/v2_exterior_masonry.gd").DOOR_SPANS.get(identity,Vector2(-half_depth,half_depth))
		var expected := key_for(float(row.width),float(row.height),span.y-span.x)
		if openings[identity].span != span or str(openings[identity].variant) != expected:
			errors.append("lining source opening or wall span changed: "+identity)
	return errors.is_empty() and not variants.is_empty()

static func key_for(width: float,height: float,depth: float) -> String:
	return "L%04d_%04d_%04d" % [roundi(width*1000),roundi(height*1000),roundi(depth*1000)]

func frame_for(identity: String) -> Dictionary:
	if not openings.has(identity): return {}
	return variants.get(str(openings[identity].variant),{})
