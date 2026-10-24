extends "res://scripts/props/v2_library_movable.gd"
## A binding opens at its authored featured gathering, without a reading panel.
const SERIF := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const ITALIC := preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")
const HAND := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
const PrintMesh := preload("res://scripts/props/book_print_mesh.gd")
## A spread the player has opened wide enough to read grants world knowledge
## (design/ORISON_DIALOGUE_DRAFTS_2026-10-22.md section 3). Pages print at
## .04 rad; a reader holds the book open well past that.
const SPREAD_KNOWLEDGE := {"minutes": "minutes_read"}
const READ_OPENING := 0.6
var stock: RefCounted
var title_id := "" # Physical stock_id may identify a distinct copy of this title.
var entry: Dictionary
var spread: Dictionary
var construction: Dictionary
var left: Node3D
var opening := 0.0
var _before_opening := 0.0
var _cover_blocked := false
var _left_solids: Array[CollisionShape3D] = []
var _group_solids: Dictionary = {}
var _cover_area: Area3D
var _cover_target: CollisionShape3D
var _closed_solid: CollisionShape3D
var _native_draws: Array[MeshInstance3D] = []
var _spine: Node3D
var _print_surfaces: Array[Dictionary] = []
var _print_angle := -1.0
var printed_labels: Array[Label3D] = []
var _sheets: Array[Node3D] = []
var _pages_ready := false
var _print_ready := false
var _heading_font: FontVariation
var shelf_slot := -1
var _floating_camera := Transform3D.IDENTITY
var _floating_frames := 0

func requires_shelf_withdrawal() -> bool: return shelf_slot>=0

func pickup_centre() -> Vector3:
	return Vector3(float(construction.width)*.5,float(construction.height)*.5,0)

func begin_floating_view(camera_pose: Transform3D) -> void:
	_floating_camera=camera_pose
	_floating_frames=0
	freeze=true
	shelf_slot=-1
	_contact_mode(true)
	set_physics_process(true)
	# Prepare hidden glyph streams while the supported view settles. Their
	# bounded slices do not sit on the first cover-drag input event.
	if not _pages_ready:_print_pages()

func end_floating_view() -> void:
	set_physics_process(false)
	if _closed_solid!=null: _contact_mode(false)

func _physics_process(_delta: float) -> void:
	if _held: return
	var before:=global_transform
	hold_pose(_floating_camera,true)
	_floating_frames+=1
	# Once supported in the fixed view, no solver or repeated shape queries.
	if global_transform.is_equal_approx(before) or _floating_frames>=180:
		set_physics_process(false)

func park_in_slot(index: int, pose: Transform3D) -> void:
	shelf_slot=index
	transform=pose
	linear_velocity=Vector3.ZERO;angular_velocity=Vector3.ZERO
	_rest_until=-1
	freeze=true;sleeping=true
	_contact_mode(true)

func start_at_rest() -> void:
	if shelf_slot>=0:
		freeze=true;sleeping=true
		return
	super.start_at_rest()

func _ready() -> void:
	super._ready()
	set_physics_process(false)
	set_meta("library_stock_id",stock_id)
	if title_id.is_empty(): title_id=stock_id
	construction=stock.data.books[stock_id]
	spread=stock.spreads[title_id]
	mass=maxf(.025,float(construction.width)*float(construction.height)*float(construction.thickness)*650.)
	left=Node3D.new()
	left.name="OpeningGathering"
	left.set_meta("library_stock_id",stock_id)
	add_child(left)
	for identity: String in construction.parts:
		var part: Dictionary=stock.data.parts[identity]
		var moving: bool=str(part.role)=="left"
		if not part.has("render_surface") or bool(part.render_surface): _native_draws.append(stock.draw(left if moving else self,identity))
	for role: String in stock.gathering_hulls[stock_id]:
		var shape:=CollisionShape3D.new();shape.name=role+"GatheringSolid";shape.shape=stock.gathering_hulls[stock_id][role]
		shape.transform=stock.gathering_poses[stock_id][role]
		add_child(shape);_solids.append(shape);_group_solids[role]=shape
		if role=="left": _left_solids.append(shape)
	_closed_solid=CollisionShape3D.new();_closed_solid.name="ClosedBindingSolid"
	_closed_solid.shape=stock.closed_hulls[stock_id];_closed_solid.transform=stock.closed_poses[stock_id]
	add_child(_closed_solid)
	_contact_mode(freeze)
	_spine=Node3D.new();_spine.name="BindingImprint";add_child(_spine)
	_print()
	_cover_area=preload("res://scripts/props/manipulation_area.gd").install(left,cover_grip)
	for child: Node in _cover_area.get_children(): child.free()
	_cover_target=CollisionShape3D.new();_cover_target.name="AcceptedGatheringTarget";_cover_area.add_child(_cover_target)
	_sync_cover_target()
	_corner("ManipulateSpine",.82,Vector3.UP)
	_corner("RollForeedge",.16,Vector3.BACK)

func _sync_cover_target() -> void:
	# A 1 mm picking halo follows the accepted physical gathering. It wins
	# the ray-depth tie against the book body without selecting another part.
	var points: PackedVector3Array=_group_solids.left.shape.points.duplicate()
	var extent:=Vector3.ZERO
	for point: Vector3 in points: extent=extent.max(point.abs())
	var scale:=Vector3.ONE+Vector3.ONE*.001/extent.max(Vector3.ONE*.00001)
	# Keep the sewn/spine edge exact. Inflating this axis puts the cover's
	# picking halo ahead of a thin paperback spine and steals its pickup grip.
	scale.x=1.
	for index in points.size(): points[index]*=scale
	var target:=ConvexPolygonShape3D.new();target.points=points;target.margin=0.
	_cover_target.shape=target
	_cover_target.transform=left.transform.affine_inverse()*_group_solids.left.transform

func _corner(label: String, fraction: float, axis: Vector3) -> void:
	var target:=preload("res://scripts/props/manipulation_area.gd").new() as Area3D
	target.name=label
	target.provider=func():return turn_grip(axis) if label!="ManipulateSpine" and shelf.supports_inspected_stock(self) else grip()
	target.collision_layer=1;target.collision_mask=0;target.monitoring=false
	target.add_to_group("functional_interaction_areas")
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(.010,float(construction.height)*.13,.004)
	shape.shape=box
	shape.position=Vector3(-.0043,float(construction.height)*fraction,float(construction.thickness)*.5+.006)
	target.add_child(shape)
	add_child(target)

func _letter(parent: Node3D, label: String, text: String, at: Vector3, width: float, em: float, colour: Color) -> Label3D:
	var result:=Label3D.new()
	result.name=label;result.text=text
	if _heading_font==null:
		_heading_font=FontVariation.new();_heading_font.base_font=SERIF;_heading_font.variation_opentype={"wght":600.}
	result.font=HAND if str(construction.binding)=="lace pamphlet" or (str(stock.data.books[title_id].layout)=="ledger" and (label.begins_with("Body") or label=="Chapter")) else (ITALIC if label.begins_with("Annotation") else (_heading_font if label in ["Chapter","CoverTitle"] else SERIF))
	result.font_size=40;result.pixel_size=em/40.
	result.width=width/result.pixel_size
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	result.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	result.outline_size=0;result.modulate=colour
	result.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	result.shaded=true;result.double_sided=false;result.no_depth_test=false
	result.alpha_cut=Label3D.ALPHA_CUT_DISCARD;result.alpha_scissor_threshold=.4
	result.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE;result.alpha_antialiasing_edge=.15
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	result.visibility_range_end=2.5
	result.position=at
	parent.add_child(result)
	_matte_letter.call_deferred(result)
	printed_labels.append(result)
	return result

func _matte_letter(label: Label3D) -> void:
	# Label3D creates privately owned glyph materials with specular=.5. That
	# dielectric highlight washes black ink out under the close carried lamp.
	# Keep diffuse lighting/depth and font-owned MSDF; make the ink matte.
	var mesh_rid:=label.get_base()
	for surface in RenderingServer.mesh_get_surface_count(mesh_rid):
		var glyph:=RenderingServer.mesh_surface_get_material(mesh_rid,surface)
		RenderingServer.material_set_param(glyph,"specular",0.)

func _print() -> void:
	var width:=float(construction.width)
	var height:=float(construction.height)
	var thickness:=float(construction.thickness)
	var foil:=Color.BLACK if str(construction.get("opening_style","hardback"))!="hardback" else (Color(.12,.085,.05) if str(construction.material)=="paper" else Color(.73,.64,.42))
	_letter(left,"CoverTitle",str(entry.title),Vector3(.013,height*.76,thickness*.5+.00006),width-.026,.006,foil)
	var edition: Dictionary=stock.data.books[title_id]
	if not str(edition.subtitle).is_empty():
		_letter(left,"CoverSubtitle",str(edition.subtitle),Vector3(.013,height*.51,thickness*.5+.00006),width-.026,.0032,foil)
	_letter(left,"CoverPublisher",str(stock.data.publishers[str(edition.publisher)].name),Vector3(.013,height*.105,thickness*.5+.00006),width-.026,.0024,foil)
	_letter(left,"CoverAuthor",str(entry.author),Vector3(.013,height*.37,thickness*.5+.00006),width-.026,.0042,foil)
	_letter(left,"Edition",str(entry.year),Vector3(.013,height*.20,thickness*.5+.00006),width-.026,.0038,foil)
	if thickness>.01:
		for row in [["SpineTitle",str(entry.title),thickness*.13,.0045],["SpineAuthor",str(entry.author),-thickness*.20,.0028]]:
			var measure:=SERIF.get_string_size(str(row[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,40).x
			var em:=minf(float(row[3]),(height-.025)*40./maxf(measure,1.))
			var label:=_letter(_spine,str(row[0]),str(row[1]),Vector3(-minf(.0012,float(stock.data.formats[str(stock.data.books[title_id].format)].cover_m)*.85)-.00006,.012,float(row[2])),height-.024,em,foil)
			label.rotation=Vector3(0,-PI*.5,PI*.5)
func _print_pages() -> void:
	_pages_ready=true
	var edition: Dictionary=stock.data.books[title_id]
	var layout: Dictionary=stock.data.publication_layouts[str(edition.layout)]
	var publisher: Dictionary=stock.data.publishers[str(edition.publisher)]
	var width:=float(construction.width);var height:=float(construction.height)
	var margin:=width*float(layout.margin_fraction);var measure:=width-2.*margin
	var ink:=Color.BLACK;var style:=str(edition.layout)
	var em:=float(layout.body_em_m)
	var design: Dictionary=stock.data.page_designs[title_id]
	var facing_plate: bool=spread.right.has("illustration")
	for side: String in ["left","right"]:
		var parent: Node3D=left if side=="left" else self
		var sheet:=Node3D.new();sheet.name=side.capitalize()+"PrintedSpread"
		sheet.visible=false
		parent.add_child(sheet);_sheets.append(sheet)
		if side=="left": sheet.transform=Transform3D(Basis(Vector3.UP,PI),Vector3(width,0,float(construction.left_page_z)))
		else: sheet.position.z=float(construction.right_page_z)
		var content: Dictionary=spread[side]
		_letter(sheet,"RunningTitle",str(entry.author) if side=="left" else str(entry.title),Vector3(margin,height*.955,.00003),measure,.0026,ink)
		var rule: MeshInstance3D=stock.draw(sheet,str(stock.data.typography.running_rule))
		rule.position=Vector3(width*.5,height*.917,.00003)
		# Print measure is a page-layout decision. The PBR metre coordinates
		# are rebuilt with the ink mesh, rather than stretching native paper.
		rule.set_meta("print_width",measure)
		var chapter:=_letter(sheet,"Chapter",str(content.heading).to_upper() if style in ["manual","reference","ledger"] else str(content.heading),Vector3(margin,height*.855,.00003),measure,.0048,ink)
		if style in ["fiction","verse","illustrated"]:
			chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;chapter.position.x=width*.5
		var folio:=_letter(sheet,"PageNumber",str(int(spread.page)+(1 if side=="right" else 0)),Vector3(width*.5,.015,.00003),.025,.0028,ink)
		folio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if content.has("illustration"):
			var illustration: Dictionary=stock.data.illustrations[str(content.illustration)]
			var plate:=stock.draw(sheet,str(illustration.part)) as MeshInstance3D
			var maximum_height:=minf(height*float(layout.plate_fraction),height*.775-.045)
			var scale_width:=minf(measure,minf(float(illustration.width),maximum_height*float(illustration.width)/float(illustration.height)))
			var print_height:=float(illustration.height)*scale_width/float(illustration.width)
			plate.position=Vector3(width*.5,height*.775-print_height*.5,.00004)
			plate.set_meta("print_width",scale_width)
			plate.set_meta("printed_illustration",str(content.illustration))
			plate.set_meta("declared_print_width",scale_width)
			plate.set_meta("declared_print_height",print_height)
			var bottom:=plate.position.y-print_height*.5-.008
			var caption:=_letter(sheet,"PlateCaption",str(design.get("caption",content.heading)),Vector3(margin,bottom,.00003),measure,.0031,ink)
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.position.x=width*.5

		else:
			var columns:=int(layout.columns);var gap:=.006
			var body_floor:=height*.735
			var words:=str(content.body).split(" ",false)
			for column in columns:
				var start:=floori(float(words.size())*column/columns);var end:=floori(float(words.size())*(column+1)/columns)
				var text:=str(content.body) if columns==1 else " ".join(words.slice(start,end))
				var column_width: float=(measure-gap*(columns-1))/columns
				var body:=_letter(sheet,"BodyText" if columns==1 else "BodyColumn%d"%column,text,Vector3(margin+column*(column_width+gap),height*.735,.00003),column_width,em,ink)
				if style=="verse": body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				body_floor=minf(body_floor,body.position.y-body.font.get_multiline_string_size(body.text,HORIZONTAL_ALIGNMENT_LEFT,body.width,body.font_size).y*body.pixel_size)
			if side=="left" and facing_plate:
				_letter(sheet,"AnnotationHeading",str(design.annotation_heading),Vector3(margin,body_floor-.009,.00003),measure,.0028,ink)
				_letter(sheet,"AnnotationText",str(spread.right.body),Vector3(margin,body_floor-.018,.00003),measure,em*.9,ink)
		if side=="left":
			_letter(sheet,"Publisher",str(publisher.name)+" - "+str(publisher.place),Vector3(margin,.028,.00003),measure,.0023,ink)
	_capture_print.call_deferred()

func _capture_print() -> void:
	preload("res://scripts/props/book_print_preparation.gd").prepare(weakref(self))

func _warp_print() -> void:
	if not _print_ready:return
	if _print_surfaces.is_empty(): return
	if is_equal_approx(_print_angle,opening): return
	_print_angle=opening
	var profiles: Dictionary={}
	var samples: Dictionary={"left":{},"right":{},"cover_left":{}}
	for side: String in ["left","right"]: profiles[side]=stock.page_profile(stock_id,side,opening)
	if str(construction.get("opening_style","hardback"))!="hardback": profiles.cover_left=stock.surface_profile(stock_id+"__left_board",float(construction.thickness)*.5,opening)
	for printed: Dictionary in _print_surfaces:
		var node: Node3D=printed.node
		var side: String=printed.side
		var face_z:=float(printed.face_z)
		var mesh: RID=printed.mesh
		RenderingServer.mesh_clear(mesh)
		for surface: Dictionary in printed.surfaces:
			var inverse: Transform3D=surface.inverse
			var reference_points: PackedVector3Array=surface.reference_points
			var reference_normals: PackedVector3Array=surface.reference_normals
			var reference_tangents: PackedVector3Array=surface.reference_tangents
			var sample_keys: PackedInt32Array=surface.sample_keys
			var sample_cache: Dictionary=samples[side]
			var arrays: Array=surface.arrays.duplicate()
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT]!=null else PackedFloat32Array()
			for index in vertices.size():
				var point: Vector3=reference_points[index]
				var key: int=sample_keys[index]
				if not sample_cache.has(key):sample_cache[key]=stock.sample_page(profiles[side],point.x)
				var sample: Vector4=sample_cache[key]
				point=Vector3(sample.x,point.y,sample.y+point.z-face_z)
				vertices[index]=inverse*point
				if normals.size()>index:
					var normal: Vector3=reference_normals[index];normal.x=(normal.x-sample.w*normal.z)/sample.z
					normals[index]=(inverse.basis*normal).normalized()
				if tangents.size()>index*4+2:
					var tangent: Vector3=reference_tangents[index];tangent.z+=sample.w*tangent.x;tangent.x*=sample.z
					tangent=(inverse.basis*tangent).normalized()
					for axis in 3: tangents[index*4+axis]=tangent[axis]
			arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
			if not tangents.is_empty(): arrays[Mesh.ARRAY_TANGENT]=tangents
			RenderingServer.mesh_add_surface_from_arrays(mesh,RenderingServer.PRIMITIVE_TRIANGLES,arrays)
			var material: RID=surface.material
			if node is Label3D:
				var surface_index:=RenderingServer.mesh_get_surface_count(mesh)-1
				material=RenderingServer.mesh_surface_get_material(node.get_base(),surface_index)
			RenderingServer.mesh_surface_set_material(mesh,RenderingServer.mesh_get_surface_count(mesh)-1,material)
		RenderingServer.instance_set_base(printed.instance,mesh)

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		for printed: Dictionary in _print_surfaces: RenderingServer.free_rid(printed.mesh)

func _claim(tag: String) -> bool:
	if not super._claim(tag): return false
	_contact_mode(true)
	if tag in ["body","turn"]: shelf_slot=-1
	if tag=="body" and shelf.supports_inspected_stock(self):set_physics_process(false)
	_before_opening=opening
	_cover_blocked=false
	return true

func _release() -> void:
	var changed:=not is_equal_approx(opening,_before_opening)
	super._release()
	if shelf_slot<0: shelf.try_place_book(self)
	if shelf_slot>=0: freeze=true;sleeping=true
	_contact_mode(freeze)
	if changed: shelf.library_stock_changed(self)

func cover_grip() -> Dictionary:
	if not shelf.supports_inspected_stock(self):return grip()
	return {"owner":shelf,"part":left,"frame":self,"kind":"hinge","axis":Vector3.DOWN,
		"minimum":0.,"maximum":PI,"minimum_lever":.025,
		"constraint_feedback":func(): return "blocked" if _cover_blocked else "",
		"change_origin":func(): return global_position,
		"read":func(): return opening,
		"write":func(value: float):
			if _held and _hand_tag=="cover": _open(value),
		"begin":func(): return _claim("cover"),
		"owns":func(): return _held and _hand_tag=="cover",
		"end":_release}

func _open(proposed: float) -> void:
	if not is_finite(proposed): return
	_cover_blocked=false
	var target:=clampf(proposed,0.,PI)
	var steps:=maxi(1,ceili(absf(target-opening)/.02))
	var before:=opening
	var accepted:=before
	var accepted_groups: Dictionary={}
	for index in range(1,steps+1):
		var angle:=lerpf(before,target,float(index)/steps)
		var groups: Dictionary=stock.posed_gatherings(stock_id,angle)
		var clear:=true
		for role: String in groups:
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=groups[role].shape
			query.transform=global_transform*groups[role].pose
			query.exclude=[get_rid()];query.margin=.00001;query.collision_mask=collision_mask
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): clear=false;break
		if not clear:
			_cover_blocked=true;break
		accepted=angle;accepted_groups=groups
	# Queries use absolute proposed native hulls and exclude this body. Preserve
	# every sweep step, then update glyphs, render weights and contacts once.
	if not accepted_groups.is_empty(): _apply_opening(accepted,accepted_groups)
	note_spread_read(title_id,opening)

static func note_spread_read(title: String, angle: float) -> bool:
	if angle<READ_OPENING or not SPREAD_KNOWLEDGE.has(title): return false
	return RealityState.grant_knowledge(str(SPREAD_KNOWLEDGE[title]))

func _apply_opening(value: float, groups: Dictionary={}) -> void:
	opening=value
	left.transform=stock.left_pose(stock_id,opening)
	var weights: PackedFloat32Array=stock.opening_weights(opening)
	for draw: MeshInstance3D in _native_draws:
		for key in draw.get_blend_shape_count(): draw.set_blend_shape_value(key,weights[key])
	if groups.is_empty(): groups=stock.posed_gatherings(stock_id,opening)
	for role: String in groups:
		var solid: CollisionShape3D=_group_solids[role]
		solid.shape=groups[role].shape;solid.transform=groups[role].pose
	_contact_mode(freeze)
	if _cover_target!=null:
		_sync_cover_target()
	if construction.has("spine_frames"):
		var step:=clampf(opening,0.,PI)*8./PI;var low:=floori(step);var high:=mini(low+1,8)
		var a: Array=construction.spine_frames[low];var b: Array=construction.spine_frames[high]
		var first:=Transform3D(Basis(Quaternion(a[3],a[4],a[5],a[6])),Vector3(a[0],a[1],a[2]))
		var second:=Transform3D(Basis(Quaternion(b[3],b[4],b[5],b[6])),Vector3(b[0],b[1],b[2]))
		_spine.transform=first.interpolate_with(second,step-low)
	if opening>.04 and not _pages_ready: _print_pages()
	for sheet: Node3D in _sheets: sheet.visible=opening>.04 and _print_ready
	_warp_print()

func _contact_mode(compact: bool) -> void:
	# The combined envelope is cheap for hand sweeps. Godot's dynamic solver
	# jitters on this densely sampled convex hull; released stock uses the
	# original three native physical groups, which settle without forced sleep.
	var closed:=compact and is_zero_approx(opening)
	_closed_solid.disabled=not closed
	_solids.clear()
	if closed: _solids.append(_closed_solid)
	for solid: CollisionShape3D in _group_solids.values():
		solid.disabled=closed
		if not closed: _solids.append(solid)

func book_snapshot() -> Dictionary: return {"body":stock_snapshot(),"opening":opening,"slot":shelf_slot}

static func valid_book(value: Variant) -> bool:
	return value is Dictionary and value.size() in [2,3] and valid_stock(value.get("body")) \
		and (not value.has("slot") or (typeof(value.slot) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value.slot)) and value.slot>=-1 and float(value.slot)==floorf(float(value.slot)))) \
		and typeof(value.get("opening")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value.opening)) \
		and float(value.opening)>=0. and float(value.opening)<=PI

func restore_book(value: Dictionary) -> void:
	end_floating_view()
	shelf_slot=-1
	freeze=true
	_apply_opening(float(value.opening))
	restore_stock(value.body)
	shelf_slot=int(value.get("slot",-1))
	if shelf_slot>=0: park_in_slot(shelf_slot,shelf.book_slots[shelf_slot])
	elif not value.has("slot"): shelf.try_place_book(self)
	_contact_mode(freeze)
	if not freeze and bool(value.body.sleeping): start_at_rest()
