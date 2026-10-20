extends RefCounted
## World-owned native mesh/shape cache; identity and text stay in the library.
const PATH := "res://data/orison_v2/readable_library.json"
const SPREADS := "res://data/orison_v2/book_spreads.json"
var data: Dictionary
var spreads: Dictionary
var meshes: Dictionary = {}
var poses: Dictionary = {}
var materials: Dictionary = {}
var hulls: Dictionary = {}
var hull_poses: Dictionary = {}
var gathering_hulls: Dictionary = {}
var gathering_poses: Dictionary = {}
var printed_materials: Dictionary = {}

func prepare() -> bool:
	data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SPREADS))
	if data.get("schema_version")!=1 or content.get("schema_version")!=1 or str(content.get("authorship","")).is_empty(): return false
	spreads=content.spreads
	var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json")).materials
	if data.books.size()!=spreads.size() or str(data.material_intent.soot).is_empty() or str(data.material_intent.paper).is_empty(): return false
	# Validate the authored consumer schema before constructing any physics or
	# labels. Identity maps remain dynamic; malformed dimensions/text fail closed.
	for identity: String in data.books:
		var book: Dictionary=data.books[identity]
		if not data.page_designs.has(identity): return false
		var design: Dictionary=data.page_designs[identity]
		if str(design.style) not in ["manual","register","prospectus","verse","botanical","literary","pamphlet"] or str(design.annotation_heading).is_empty(): return false
		if not spreads.has(identity) or str(book.binding).is_empty() or float(book.thickness)<=0. \
			or not is_finite(float(book.left_page_z)) or not is_finite(float(book.right_page_z)): return false
		var spread: Dictionary=spreads[identity]
		if spread.right.has("illustration") and str(design.get("caption","")).is_empty(): return false
		if int(spread.page)<1: return false
		for side: Dictionary in [spread.left,spread.right]:
			if str(side.heading).is_empty() or str(side.body).is_empty(): return false
			if side.has("illustration") and not data.illustrations.has(str(side.illustration)): return false
	for style: String in data.cases:
		var body: Dictionary=data.cases[style]
		if body.shelf_tops.size()!=3 or float(body.depth)<=0. or float(body.width)<=0. or float(body.height)<=0.: return false
		for door: Dictionary in body.doors:
			if door.pivot.size()!=3 or float(door.angle_limit)<=0. or float(door.angle_limit)>PI*.5 \
				or float(door.inset_limit)<=0. or float(door.inset_limit)>float(body.depth): return false
	for identity: String in data.parts:
		if str(data.parts[identity].role) not in ["fixed","left","right","carriage","case","door","print","end"]: return false
	for key: String in data.finishes:
		var finish: Dictionary=data.finishes[key]
		if str(finish.catalog_key)!=key or not catalogue.has(key) or not is_equal_approx(float(finish.pigment),1.): return false
		var material: StandardMaterial3D
		if key=="glass_drawn_expressive":
			material=preload("res://scripts/building/orison_v2_expressive_glass.gd").make(key)
		else:
			material=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			var tint: Array=finish.tint
			material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
		material.normal_enabled=true
		material.normal_scale=float(finish.normal)
		material.roughness=float(finish.roughness)
		material.uv1_triplanar=false
		material.uv1_scale=Vector3.ONE/float(catalogue[key].meters_per_tile)
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[key]=material
	var packed:=load(str(data.asset)) as PackedScene
	if packed==null: return false
	var model:=packed.instantiate()
	for identity: String in data.parts:
		var source:=model.find_child(identity,true,false) as MeshInstance3D
		if source==null or not materials.has(str(data.parts[identity].material)): model.free();return false
		meshes[identity]=source.mesh
		poses[identity]=source.transform
		if bool(data.parts[identity].collision):
			var hull:=source.mesh.create_convex_shape(true,false)
			if hull==null: model.free();return false
			var bounds:=source.mesh.get_aabb()
			var centre:=bounds.get_center()
			var points:=hull.points
			for index in points.size(): points[index]-=centre
			hull.points=points
			hull_poses[identity]=source.transform*Transform3D(Basis.IDENTITY,centre)
			hull.margin=minf(.00015,minf(bounds.size.x,minf(bounds.size.y,bounds.size.z))*.08)
			hulls[identity]=hull
	model.free()
	if not meshes.has(str(data.typography.running_rule)): return false
	# A gathering is one rigid laminate: cover board plus its bound paper.
	# A convex hull of those actual vertices avoids competing sub-millimetre
	# contact manifolds from adjacent layers of the same manufactured piece.
	for identity: String in data.books:
		var groups: Dictionary={}
		var frames: Dictionary={}
		for role: String in ["left","right","fixed"]:
			var vertices:=PackedVector3Array()
			for part: String in data.books[identity].parts:
				if not bool(data.parts[part].collision) or str(data.parts[part].role)!=role: continue
				for point: Vector3 in meshes[part].get_faces(): vertices.append(poses[part]*point)
			if vertices.is_empty(): continue
			var bounds:=AABB(vertices[0],Vector3.ZERO)
			for point: Vector3 in vertices: bounds=bounds.expand(point)
			var centre:=bounds.get_center()
			for index in vertices.size(): vertices[index]-=centre
			var hull:=ConvexPolygonShape3D.new();hull.points=vertices;hull.margin=.00008
			groups[role]=hull
			frames[role]=Transform3D(Basis.IDENTITY,centre)
		gathering_hulls[identity]=groups
		gathering_poses[identity]=frames
	for style: String in data.bookends:
		var end: Dictionary=data.bookends[style]
		if float(end.mass_kg)<=0.: return false
		var bounds:=_bounds(end.parts)
		if absf(bounds.size.x-float(end.width))>.00002 or absf(bounds.size.z-float(end.depth))>.00002 \
			or bounds.end.y>float(end.height)+.00002 or bounds.position.y<float(end.support_y)-.00002: return false
	for style: String in data.illustrations:
		var plate: Dictionary=data.illustrations[style]
		var bounds:=_bounds([plate.part])
		if absf(bounds.size.x-float(plate.width))>.00002 or absf(bounds.size.y-float(plate.height))>.00002: return false
		if plate.has("image"):
			var ink:=load(str(plate.image)) as Texture2D
			if ink==null: return false
			var paper: StandardMaterial3D=materials.paper.duplicate()
			paper.detail_enabled=true;paper.detail_albedo=ink
			paper.detail_uv_layer=BaseMaterial3D.DETAIL_UV_2
			paper.detail_blend_mode=BaseMaterial3D.BLEND_MODE_MUL
			printed_materials[str(plate.part)]=paper
	return true

func _bounds(parts: Array) -> AABB:
	var result:=AABB()
	for index in parts.size():
		var identity:=str(parts[index])
		var bounds: AABB=poses[identity]*meshes[identity].get_aabb()
		result=bounds if index==0 else result.merge(bounds)
	return result

func draw(parent: Node3D, identity: String) -> MeshInstance3D:
	var result:=MeshInstance3D.new()
	result.name=identity
	result.mesh=meshes[identity]
	result.transform=poses[identity]
	result.material_override=printed_materials.get(identity,materials[str(data.parts[identity].material)])
	result.set_meta("readable_library_part",identity)
	result.set_meta("material_key",str(data.parts[identity].material))
	parent.add_child(result)
	return result

func collision(parent: CollisionObject3D, identity: String, pose: Transform3D) -> CollisionShape3D:
	if not hulls.has(identity): return null
	var shape:=CollisionShape3D.new()
	shape.name=identity+"_Solid"
	shape.shape=hulls[identity]
	shape.transform=pose*hull_poses[identity]
	parent.add_child(shape)
	return shape

func finish() -> void:
	meshes.clear();poses.clear();materials.clear();printed_materials.clear();hulls.clear();hull_poses.clear();gathering_hulls.clear();gathering_poses.clear()
