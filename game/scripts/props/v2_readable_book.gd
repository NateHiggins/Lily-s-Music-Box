extends "res://scripts/props/v2_library_movable.gd"
## A binding opens at its authored featured gathering, without a reading panel.
const SERIF := preload("res://assets/fonts/eb_garamond/EBGaramond[wght].ttf")
const ITALIC := preload("res://assets/fonts/eb_garamond/EBGaramond-Italic[wght].ttf")
const HAND := preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
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
var _left_solids: Array[CollisionShape3D] = []
var printed_labels: Array[Label3D] = []
var _sheets: Array[Node3D] = []
var _pages_ready := false
var _heading_font: FontVariation

func _ready() -> void:
	super._ready()
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
		var moving: bool=str(stock.data.parts[identity].role)=="left"
		stock.draw(left if moving else self,identity)
	for role: String in stock.gathering_hulls[stock_id]:
		var shape:=CollisionShape3D.new();shape.name=role+"GatheringSolid";shape.shape=stock.gathering_hulls[stock_id][role]
		shape.transform=stock.gathering_poses[stock_id][role]
		add_child(shape);_solids.append(shape)
		if role=="left": _left_solids.append(shape)
	_print()
	preload("res://scripts/props/manipulation_area.gd").install(left,cover_grip)
	_corner("TurnForeedge",.82,Vector3.UP)
	_corner("RollForeedge",.16,Vector3.BACK)

func _corner(label: String, fraction: float, axis: Vector3) -> void:
	var target:=preload("res://scripts/props/manipulation_area.gd").new() as Area3D
	target.name=label
	target.provider=func(): return turn_grip(axis)
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
	result.font=HAND if str(construction.binding)=="lace pamphlet" else (ITALIC if label.begins_with("Annotation") else (_heading_font if label in ["Chapter","CoverTitle"] else SERIF))
	result.font_size=40;result.pixel_size=em/40.
	result.width=width/result.pixel_size
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	result.vertical_alignment=VERTICAL_ALIGNMENT_TOP
	result.outline_size=0;result.modulate=colour
	result.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	result.shaded=true;result.double_sided=false;result.no_depth_test=false
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
	var foil:=Color(.12,.085,.05) if str(construction.material)=="paper" else Color(.73,.64,.42)
	_letter(left,"CoverTitle",str(entry.title),Vector3(.013,height*.76,thickness*.5+.00006),width-.026,.006,foil)
	_letter(left,"CoverAuthor",str(entry.author),Vector3(.013,height*.37,thickness*.5+.00006),width-.026,.0042,foil)
	_letter(left,"Edition",str(entry.year),Vector3(.013,height*.20,thickness*.5+.00006),width-.026,.0038,foil)
	if thickness>.01:
		for row in [["SpineTitle",str(entry.title),thickness*.13,.0045],["SpineAuthor",str(entry.author),-thickness*.20,.0028]]:
			var measure:=SERIF.get_string_size(str(row[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,40).x
			var em:=minf(float(row[3]),(height-.025)*40./maxf(measure,1.))
			var label:=_letter(self,str(row[0]),str(row[1]),Vector3(-.00206,.012,float(row[2])),height-.024,em,foil)
			label.rotation=Vector3(0,-PI*.5,PI*.5)
func _print_pages() -> void:
	_pages_ready=true
	var width:=float(construction.width)
	var height:=float(construction.height)
	var ink:=Color(.008,.007,.006)
	var design: Dictionary=stock.data.page_designs[title_id]
	var style:=str(design.style)
	var facing_plate: bool=spread.right.has("illustration")
	for side: String in ["left","right"]:
		var parent: Node3D=left if side=="left" else self
		var sheet:=Node3D.new()
		sheet.name=side.capitalize()+"PrintedSpread"
		parent.add_child(sheet)
		_sheets.append(sheet)
		if side=="left":
			sheet.transform=Transform3D(Basis(Vector3.UP,PI),Vector3(width,0,float(construction.left_page_z)))
		else: sheet.position.z=float(construction.right_page_z)
		var content: Dictionary=spread[side]
		_letter(sheet,"RunningTitle",str(entry.author) if side=="left" else str(entry.title),Vector3(.012,height*.96,.00003),width-.024,.0031,ink)
		var rule: MeshInstance3D=stock.draw(sheet,str(stock.data.typography.running_rule))
		rule.position=Vector3(width*.5,height*.915,.00003)
		var chapter:=_letter(sheet,"Chapter",str(content.heading).to_upper() if style in ["manual","register","prospectus"] else str(content.heading),Vector3(.012,height*.85,.00003),width-.024,.0052,ink)
		if style in ["prospectus","verse","botanical","literary","pamphlet"]: chapter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;chapter.position.x=width*.5
		var folio:=_letter(sheet,"PageNumber",str(int(spread.page)+(1 if side=="right" else 0)),Vector3(width*.5,.012,.00003),.025,.003,ink)
		folio.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if side=="left" or not facing_plate:
			var body_em:=.0054 if style=="verse" else .0052
			var body:=_letter(sheet,"BodyText",str(content.body),Vector3(.012,height*.72,.00003),width-.024,body_em,ink)
			if side=="left" and facing_plate:
				var used: float=body.font.get_multiline_string_size(body.text,HORIZONTAL_ALIGNMENT_LEFT,body.width,body.font_size).y*body.pixel_size
				var note_top: float=body.position.y-used-.009
				_letter(sheet,"AnnotationHeading",str(design.annotation_heading),Vector3(.014,note_top,.00003),width-.028,.0030,Color(.018,.016,.014))
				_letter(sheet,"AnnotationText",str(spread.right.body),Vector3(.014,note_top-.007,.00003),width-.028,.0045,Color(.018,.016,.014))
		if content.has("illustration"):
			var illustration: Dictionary=stock.data.illustrations[str(content.illustration)]
			var plate:=stock.draw(sheet,str(illustration.part)) as MeshInstance3D
			plate.position+=Vector3(width*.5,height*.55,.00004)
			plate.set_meta("printed_illustration",str(content.illustration))
			plate.set_meta("declared_print_width",float(illustration.width))
			plate.set_meta("declared_print_height",float(illustration.height))
			if side=="right":
				var caption:=_letter(sheet,"PlateCaption",str(design.caption),Vector3(.014,plate.position.y-float(illustration.height)*.5-.006,.00013),width-.028,.0038,ink)
				caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.position.x=width*.5

func _claim(tag: String) -> bool:
	if not super._claim(tag): return false
	_before_opening=opening
	return true

func _release() -> void:
	var changed:=not is_equal_approx(opening,_before_opening)
	super._release()
	if changed: shelf.library_stock_changed(self)

func cover_grip() -> Dictionary:
	return {"owner":shelf,"part":left,"frame":self,"kind":"hinge","axis":Vector3.DOWN,
		"minimum":0.,"maximum":PI,"minimum_lever":.025,
		"change_origin":func(): return global_position,
		"read":func(): return opening,
		"write":func(value: float):
			if _held and _hand_tag=="cover": _open(value),
		"begin":func(): return _claim("cover"),
		"owns":func(): return _held and _hand_tag=="cover",
		"end":_release}

func _open(proposed: float) -> void:
	if not is_finite(proposed): return
	var target:=clampf(proposed,0.,PI)
	var steps:=maxi(1,ceili(absf(target-opening)/.02))
	var before:=opening
	for index in range(1,steps+1):
		var angle:=lerpf(before,target,float(index)/steps)
		var candidate:=Transform3D(Basis(Vector3.DOWN,angle),Vector3.ZERO)
		var clear:=true
		for shape: CollisionShape3D in _left_solids:
			var query:=PhysicsShapeQueryParameters3D.new()
			query.shape=shape.shape
			query.transform=global_transform*candidate*left.transform.affine_inverse()*shape.transform
			query.exclude=[get_rid()];query.margin=.00001;query.collision_mask=collision_mask
			if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): clear=false;break
		if not clear: break
		_apply_opening(angle)
	note_spread_read(title_id,opening)

static func note_spread_read(title: String, angle: float) -> bool:
	if angle<READ_OPENING or not SPREAD_KNOWLEDGE.has(title): return false
	return RealityState.grant_knowledge(str(SPREAD_KNOWLEDGE[title]))

func _apply_opening(value: float) -> void:
	var previous:=left.transform
	opening=value
	left.rotation.y=-opening
	for shape: CollisionShape3D in _left_solids: shape.transform=left.transform*previous.affine_inverse()*shape.transform
	if opening>.04 and not _pages_ready: _print_pages()
	for sheet: Node3D in _sheets: sheet.visible=opening>.04

func book_snapshot() -> Dictionary: return {"body":stock_snapshot(),"opening":opening}

static func valid_book(value: Variant) -> bool:
	return value is Dictionary and value.size()==2 and valid_stock(value.get("body")) \
		and typeof(value.get("opening")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value.opening)) \
		and float(value.opening)>=0. and float(value.opening)<=PI

func restore_book(value: Dictionary) -> void:
	freeze=true
	_apply_opening(float(value.opening))
	restore_stock(value.body)
