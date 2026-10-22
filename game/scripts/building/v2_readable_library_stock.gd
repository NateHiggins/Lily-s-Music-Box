extends RefCounted
## World-owned native mesh/shape cache; identity and text stay in the library.
const PATH := "res://data/orison_v2/readable_library.json"
const PHYSICAL_COPIES := "res://data/orison_v2/nook_readable_books.json"
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
var closed_hulls: Dictionary = {}
var closed_poses: Dictionary = {}
var printed_materials: Dictionary = {}
var _tinted_parts: Dictionary = {}
var _tint_cache: Dictionary = {}
var _morph_geometry: Dictionary = {}

func prepare() -> bool:
	data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var content: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SPREADS))
	if data.get("schema_version")!=1 or content.get("schema_version")!=1 or str(content.get("authorship","")).is_empty(): return false
	spreads=content.spreads
	var catalogue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/runtime_material_sets.json")).materials
	if data.books.size()!=spreads.size() or str(data.material_intent.soot).is_empty() or str(data.material_intent.paper).is_empty(): return false
	# Validate the authored consumer schema before constructing any physics or
	# labels. Identity maps remain dynamic; malformed dimensions/text fail closed.
	for format_id: String in data.formats:
		var format: Dictionary=data.formats[format_id]
		if float(format.width_m)<=.10 or float(format.height_m)<=.15 or float(format.cover_m)<=0. or float(format.leaf_m)<=0. or str(format.binding).is_empty(): return false
	for publisher_id: String in data.publishers:
		if str(data.publishers[publisher_id].name).is_empty() or str(data.publishers[publisher_id].place).is_empty(): return false
	for layout_id: String in data.publication_layouts:
		var layout: Dictionary=data.publication_layouts[layout_id]
		if float(layout.body_em_m)<.002 or float(layout.margin_fraction)<=0. or int(layout.columns) not in [1,2] or float(layout.plate_fraction)<=0.: return false
	for identity: String in data.books:
		var book: Dictionary=data.books[identity]
		if not data.formats.has(str(book.format)) or not data.publishers.has(str(book.publisher)) or not data.publication_layouts.has(str(book.layout)): return false
		var format: Dictionary=data.formats[str(book.format)]
		if not is_equal_approx(float(book.width),float(format.width_m)) or not is_equal_approx(float(book.height),float(format.height_m)): return false
		if int(book.page_count)<8 or not is_equal_approx(float(book.thickness),int(book.page_count)*.5*float(format.leaf_m)+2.*float(format.cover_m)): return false
		if str(book.opening_style) not in ["hardback","paperback","pamphlet"]: return false
		if book.opening_keys.size()!=8 or book.opening_angles.size()!=9 or book.spine_frames.size()!=9 or book.get("subtitle") is not String: return false
		for index in 9:
			if not is_equal_approx(float(book.opening_angles[index]),PI*index/8.) or book.spine_frames[index].size()!=7: return false
		for index in 8:
			if str(book.opening_keys[index])!="Opening%02d"%(index+1): return false
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
		if data.parts[identity].has("render_surface") and data.parts[identity].render_surface is not bool: return false
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
	for identity: String in data.parts:
		var part: Dictionary=data.parts[identity]
		if not part.has("tint"): continue
		if part.tint is not Array or part.tint.size()!=4: return false
		for value: Variant in part.tint:
			if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)) or float(value)<0. or float(value)>1.: return false
		var key:=str(part.material)+JSON.stringify(part.tint)
		if not _tint_cache.has(key):
			var pigment: StandardMaterial3D=materials[str(part.material)].duplicate()
			pigment.albedo_color=Color(part.tint[0],part.tint[1],part.tint[2],part.tint[3]);_tint_cache[key]=pigment
		_tinted_parts[identity]=_tint_cache[key]
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
	_gather_book_hulls(data.books)
	for style: String in data.bookends:
		var end: Dictionary=data.bookends[style]
		if float(end.mass_kg)<=0.: return false
		var bounds:=_bounds(end.parts)
		if absf(bounds.size.x-float(end.width))>.00002 or absf(bounds.size.z-float(end.depth))>.00002 \
			or bounds.end.y>float(end.height)+.00002 or bounds.position.y<float(end.support_y)-.00002: return false
	for decoration_id: String in data.decorations:
		var decoration: Dictionary=data.decorations[decoration_id]
		if decoration.get("parts") is not Array or decoration.parts.is_empty() or decoration.get("open_vessel") is not bool: return false
		for part: String in decoration.parts:
			if not meshes.has(part): return false
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

func load_copy_programme() -> Dictionary:
	var copies: Variant=JSON.parse_string(FileAccess.get_file_as_string(PHYSICAL_COPIES))
	if copies is not Dictionary or copies.get("ends") is not Array: return {}
	if not append_copies(copies) or not valid_copy_records(copies.copies,self) or not valid_end_records(copies.ends,self): return {}
	return copies

func append_copies(copies: Dictionary) -> bool:
	if copies.get("schema_version")!=1 or copies.get("books") is not Dictionary or copies.get("parts") is not Dictionary or copies.get("copies") is not Array: return false
	if copies.books.size()!=copies.copies.size(): return false
	var seen: Dictionary={}
	for record: Variant in copies.copies:
		if record is not Dictionary: return false
		var identity:=str(record.get("id",""));var title:=str(record.get("title_id",""))
		if identity.is_empty() or seen.has(identity) or data.books.has(identity) or not copies.books.has(identity) or not spreads.has(title): return false
		seen[identity]=true
		var book: Dictionary=copies.books[identity]
		if str(book.get("binding","")).is_empty() or book.get("parts") is not Array: return false
		for field: String in ["width","height","thickness","left_page_z","right_page_z"]:
			if typeof(book.get(field)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(book[field])): return false
		if float(book.width)<=.12 or float(book.height)<=.12 or float(book.thickness)<=.004: return false
	var packed:=load(str(copies.asset)) as PackedScene
	if packed==null: return false
	var model:=packed.instantiate()
	for identity: String in copies.parts:
		if data.parts.has(identity): model.free();return false
		var spec: Dictionary=copies.parts[identity]
		var original:=model.find_child(identity,true,false) as MeshInstance3D
		if original==null or not materials.has(str(spec.material)): model.free();return false
		meshes[identity]=original.mesh;poses[identity]=original.transform
		if bool(spec.collision):
			var hull:=original.mesh.create_convex_shape(true,false)
			if hull==null: model.free();return false
			var bounds:=original.mesh.get_aabb();var centre:=bounds.get_center();var points:=hull.points
			for index in points.size(): points[index]-=centre
			hull.points=points;hull.margin=minf(.00015,minf(bounds.size.x,minf(bounds.size.y,bounds.size.z))*.08)
			hulls[identity]=hull;hull_poses[identity]=original.transform*Transform3D(Basis.IDENTITY,centre)
	model.free()
	data=data.duplicate()
	data.books=data.books.duplicate();data.books.merge(copies.books)
	data.parts=data.parts.duplicate();data.parts.merge(copies.parts)
	_gather_book_hulls(copies.books)
	return true

func _gather_book_hulls(blueprints: Dictionary) -> void:
	for identity: String in blueprints:
		var groups: Dictionary={}
		var frames: Dictionary={}
		for role: String in ["left","right","fixed"]:
			var vertices:=PackedVector3Array()
			for part: String in blueprints[identity].parts:
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
		var closed:=PackedVector3Array()
		for role: String in groups:
			for point: Vector3 in groups[role].points: closed.append(frames[role]*point)
		var bounds:=AABB(closed[0],Vector3.ZERO)
		for point: Vector3 in closed: bounds=bounds.expand(point)
		var centre:=bounds.get_center()
		for index in closed.size(): closed[index]-=centre
		var hull:=ConvexPolygonShape3D.new();hull.points=closed;hull.margin=.00008
		closed_hulls[identity]=hull;closed_poses[identity]=Transform3D(Basis.IDENTITY,centre)

# Reuse imported vertex streams. Only accepted/proposed opening work samples
# them; parked and held closed volumes never run a deformation simulation.
func opening_weights(angle: float) -> PackedFloat32Array:
	var weights:=PackedFloat32Array();weights.resize(8)
	var step:=clampf(angle,0.,PI)*8./PI
	var low:=floori(step);var high:=mini(8,low+1);var fraction:=step-low
	if low>0: weights[low-1]=1.-fraction
	if high>0 and high!=low: weights[high-1]=fraction
	return weights

func left_pose(identity: String,angle: float) -> Transform3D:
	var thickness:=float(data.books[identity].thickness)
	if not data.books[identity].has("opening_keys"): return Transform3D(Basis(Vector3.DOWN,angle),Vector3.ZERO)
	var flex: float={"hardback":0.,"paperback":.22,"pamphlet":.30}.get(str(data.books[identity].get("opening_style","hardback")),0.)
	var span:=thickness*(1.-.06*sin(angle)-flex*pow(sin(angle*.5),2.))
	return Transform3D(Basis(Vector3.DOWN,angle),Vector3(-span*sin(angle*.5)+thickness*.5*sin(angle),0.,-thickness*.5+span*cos(angle*.5)-thickness*.5*cos(angle)))

func _part_points(identity: String,weights: PackedFloat32Array) -> PackedVector3Array:
	if not _morph_geometry.has(identity):
		var streams: Array=[]
		var mesh: ArrayMesh=meshes[identity]
		for surface in mesh.get_surface_count():
			streams.append({"base":mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX],"targets":mesh.surface_get_blend_shape_arrays(surface)})
		_morph_geometry[identity]=streams
	var points:=PackedVector3Array()
	var normalized: bool=(meshes[identity] as ArrayMesh).blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED
	for stream: Dictionary in _morph_geometry[identity]:
		var vertices: PackedVector3Array=stream.base
		var posed:=vertices.duplicate()
		for key in mini(weights.size(),stream.targets.size()):
			if weights[key]<=0.: continue
			var target: PackedVector3Array=stream.targets[key][Mesh.ARRAY_VERTEX]
			for index in posed.size(): posed[index]+=(target[index]-vertices[index] if normalized else target[index])*weights[key]
		for point: Vector3 in posed: points.append(poses[identity]*point)
	return points

func page_profile(identity: String,side: String,angle: float) -> Array:
	var face_z:=float(data.books[identity].left_page_z)+.00004 if side=="left" else float(data.books[identity].right_page_z)-.00004
	return surface_profile(identity+"__"+side+"_leaves",face_z,angle)

func surface_profile(part: String,face_z: float,angle: float) -> Array:
	var neutral:=_part_points(part,opening_weights(0.))
	var posed:=_part_points(part,opening_weights(angle))
	var samples: Dictionary={}
	for index in neutral.size():
		if absf(neutral[index].z-face_z)>.0000002: continue
		var key:=roundi(neutral[index].x*100000000.)
		samples[key]=Vector3(neutral[index].x,posed[index].x,posed[index].z)
	var result: Array=samples.values()
	result.sort_custom(func(a: Vector3,b: Vector3): return a.x<b.x)
	return result

func sample_page(profile: Array,x: float) -> Vector4:
	var low:=0;var high:=profile.size()-1
	while high-low>1:
		var middle: int=(low+high)/2
		if float(profile[middle].x)<x: low=middle
		else: high=middle
	var a: Vector3=profile[low];var b: Vector3=profile[high]
	var fraction:=clampf((x-a.x)/(b.x-a.x),0.,1.)
	return Vector4(lerpf(a.y,b.y,fraction),lerpf(a.z,b.z,fraction),(b.y-a.y)/(b.x-a.x),(b.z-a.z)/(b.x-a.x))

func posed_gatherings(identity: String,angle: float) -> Dictionary:
	var groups: Dictionary={}
	if is_zero_approx(angle):
		for role: String in gathering_hulls[identity]: groups[role]={"shape":gathering_hulls[identity][role],"pose":gathering_poses[identity][role]}
		return groups
	var weights:=opening_weights(angle)
	for role: String in ["left","right","fixed"]:
		var vertices:=PackedVector3Array()
		var frame:=left_pose(identity,angle) if role=="left" else Transform3D.IDENTITY
		for part: String in data.books[identity].parts:
			if not bool(data.parts[part].collision) or str(data.parts[part].role)!=role: continue
			vertices.append_array(_part_points(part,weights))
		if vertices.is_empty(): continue
		var bounds:=AABB(vertices[0],Vector3.ZERO)
		for point: Vector3 in vertices: bounds=bounds.expand(point)
		var centre:=bounds.get_center()
		for index in vertices.size(): vertices[index]-=centre
		var hull:=ConvexPolygonShape3D.new();hull.points=vertices;hull.margin=.00008
		groups[role]={"shape":hull,"pose":frame*Transform3D(Basis.IDENTITY,centre)}
	return groups

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
	result.material_override=_tinted_parts.get(identity,printed_materials.get(identity,materials[str(data.parts[identity].material)]))
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
	_tinted_parts.clear();_tint_cache.clear();_morph_geometry.clear();meshes.clear();poses.clear();materials.clear();printed_materials.clear();hulls.clear();hull_poses.clear();gathering_hulls.clear();gathering_poses.clear();closed_hulls.clear();closed_poses.clear()

static func valid_copy_records(records: Array, stock: RefCounted) -> bool:
	var seen: Dictionary={}
	for record: Variant in records:
		if record is not Dictionary or record.get("id") is not String or seen.has(record.id): return false
		if not stock.data.books.has(record.id) or not stock.spreads.has(str(record.get("title_id",""))): return false
		seen[record.id]=true
		if record.get("assembly") is not String or str(record.assembly).is_empty(): return false
		if record.get("position") is not Array or record.position.size()!=3 or record.get("basis") is not Array or record.basis.size()!=3: return false
		for vector: Variant in [record.position]+record.basis:
			if vector is not Array or vector.size()!=3: return false
			for value: Variant in vector:
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
		var axes: Array=record.basis
		var basis:=Basis(Vector3(axes[0][0],axes[0][1],axes[0][2]),Vector3(axes[1][0],axes[1][1],axes[1][2]),Vector3(axes[2][0],axes[2][1],axes[2][2]))
		if not Vector3(record.position[0],record.position[1],record.position[2]).is_finite(): return false
		if not basis.is_equal_approx(basis.orthonormalized()) or absf(basis.determinant()-1.)>.0001: return false
		if typeof(record.get("opening")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(record.opening)) or float(record.opening)<0. or float(record.opening)>PI: return false
	return not records.is_empty()

static func valid_end_records(records: Array, stock: RefCounted) -> bool:
	var seen: Dictionary={}
	for record: Variant in records:
		if record is not Dictionary or record.get("id") is not String or seen.has(record.id) or not stock.data.bookends.has(str(record.get("style",""))): return false
		seen[record.id]=true
		if record.get("assembly") is not String or str(record.assembly).is_empty(): return false
		if record.get("position") is not Array or record.position.size()!=3 or record.get("basis") is not Array or record.basis.size()!=3: return false
		for vector: Variant in [record.position]+record.basis:
			if vector is not Array or vector.size()!=3: return false
			for value: Variant in vector:
				if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return false
		var axes: Array=record.basis
		var basis:=Basis(Vector3(axes[0][0],axes[0][1],axes[0][2]),Vector3(axes[1][0],axes[1][1],axes[1][2]),Vector3(axes[2][0],axes[2][1],axes[2][2]))
		if not Vector3(record.position[0],record.position[1],record.position[2]).is_finite() or not basis.is_equal_approx(basis.orthonormalized()) or absf(basis.determinant()-1.)>.0001: return false
	return true
