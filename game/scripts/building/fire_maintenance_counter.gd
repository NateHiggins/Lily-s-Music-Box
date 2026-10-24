extends Node3D
## Native sales presentation and physical stock. Inventory, payment, fire-line
## facts and the household save owner remain outside this presentation owner.
signal manipulation_changed
const Pickup := preload("res://scripts/props/fire_maintenance_pickup.gd")
const Library := preload("res://scripts/props/fire_maintenance_stock_library.gd")
const COLUMN_SPACING_M := .30
const COUNTER_LENGTH_M := .76 # Three 124mm cases with clearance at both ends.
var merchant: MaintenanceShopService
var stock: RefCounted
var pickups: Dictionary = {}
var terminals: Dictionary = {}
var fire_stations: Array[WeakRef] = []
var _hand_node: Node3D
var _pending_inspection_stock: Node3D
var _inspection_stock: Node3D
var _restoring := false
var _passage: WeakRef
var _passage_floors: Array[AABB] = []
var _geometry_dormant := false
var _suspended_stock: Dictionary = {}

func bind_residency(passage: Node3D) -> bool:
	_passage=weakref(passage);_passage_floors.clear()
	for floor: Dictionary in passage.source_layout.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:
			var cell: String="_".join(str(row.get("batch","")).split("_",false))
			if cell=="passage_shell":cell="passage"
			if cell not in passage.CELLS or not str(row.id).ends_with("_floor"):continue
			var rect: Array=row.rect
			var base: float=float(row.z0)+float(row.h)
			_passage_floors.append(AABB(Vector3(rect[0],base-.10,-float(rect[3])),
				Vector3(float(rect[2])-float(rect[0]),3.3,float(rect[3])-float(rect[1]))))
	return not _passage_floors.is_empty() and passage.register_residency_client(self)

func _inside_passage(body: Node3D) -> bool:
	var passage: Node3D=_passage.get_ref() if _passage!=null else null
	if passage==null:return false
	var local: Vector3=passage.to_local(body.global_position)
	for bounds: AABB in _passage_floors:
		if bounds.has_point(local):return true
	return false

func wants_passage_geometry() -> bool:
	for identity: String in pickups:
		var body: RigidBody3D=pickups[identity]
		if body._held or not _inside_passage(body):continue
		if _suspended_stock.has(identity):
			if not bool(_suspended_stock[identity].stock.sleeping):return true
		elif not body.freeze and not body.sleeping:return true
	return false

func passage_geometry_dormant() -> void:
	_geometry_dormant=true
	for identity: String in pickups:
		var body: RigidBody3D=pickups[identity]
		if body._held or body.freeze or not _inside_passage(body):continue
		_suspended_stock[identity]={"stock":body.stock_snapshot(),"cap":body.cap_turn,"parked":false}
		body.freeze_mode=RigidBody3D.FREEZE_MODE_STATIC
		body.freeze=true;body.start_at_rest();body.set_physics_process(false)

func passage_geometry_active() -> void:
	_geometry_dormant=false
	# Native collision bodies publish through the ordinary physics boundary.
	await get_tree().physics_frame;await get_tree().physics_frame
	if not is_inside_tree() or _geometry_dormant:return
	for identity: String in _suspended_stock.keys():
		var body: RigidBody3D=pickups[identity]
		if not body._held:
			var record: Dictionary=_suspended_stock[identity]
			body.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
			body.restore_stock(record.stock);body.freeze=record.parked
			if bool(record.stock.sleeping):body.start_at_rest()
		_suspended_stock.erase(identity)

func configure(service: MaintenanceShopService, terminal_parent: Node3D=null) -> bool:
	if not is_inside_tree() or service==null:return false
	merchant=service;stock=Library.new()
	if not stock.load_stock():push_error(stock.error);return false
	if terminal_parent==null:terminal_parent=self
	for index in 3:
		var identity: String=["fire_hose_rubber_protectant","fire_hose_spare_gasket","carbon_transmitter_capsule"][index]
		var x: float=(index-1)*COLUMN_SPACING_M
		var terminal:=preload("res://scripts/props/radio_sale_terminal.gd").new()
		terminal.name="RadioSale_"+identity;terminal_parent.add_child(terminal)
		terminal.global_transform=global_transform*Transform3D(Basis.IDENTITY,Vector3(x,0,.04))
		var fixed:=StaticBody3D.new();fixed.name="TerminalHousing";terminal.add_child(fixed)
		for key: String in ["TerminalShell","TerminalMetal"]:
			var draw: MeshInstance3D=stock.draw(fixed,key)
			var collision:=CollisionShape3D.new();collision.shape=draw.mesh.create_trimesh_shape();fixed.add_child(collision)
		var lever:=Node3D.new();lever.name="SettlementLever";terminal.add_child(lever);stock.draw(lever,"TerminalLever")
		if not terminal.configure(merchant,identity,lever):return false
		terminal.sale_result.connect(_sale_result.bind(identity))
		terminals[identity]=terminal
		var record: Dictionary=merchant.stock_record(identity)
		_letter(terminal,"Merchant","QUEENS MUTUAL",Vector3(0,.056,-.038),.0065)
		var price: String="BUILDING A/C" if index==2 else (str(int(record.price_cents))+" CENTS")
		_letter(terminal,"Price",price,Vector3(0,.035,-.038),.0075)
		_letter(terminal,"Status","",Vector3(0,.022,-.038),.0042)
		_letter(terminal,"Product",str(record.display_name),Vector3(0,.014,-.074),.003)
		if index==2:continue
		var body:=Pickup.new();body.name=identity;body.stock_id=identity;body.item_id=identity;body.shelf=self
		body.position=Vector3(x,.00002,-.19);body.mass=.42 if index==0 else .012
		add_child(body);pickups[identity]=body
		if index==0:
			body.rotation.y=PI
			for key: String in ["Bottle","Label","BottleHinge"]:stock.draw(body,key)
			body.cap=Node3D.new();body.cap.name="CaptiveFlipCap";body.add_child(body.cap)
			body.cap.position=stock.cap_pivot()
			var lid: MeshInstance3D=stock.draw(body.cap,"Cap");lid.position=-body.cap.position
			preload("res://scripts/props/manipulation_area.gd").install(body.cap,body.cap_grip)
			var bottle_solid: ConvexPolygonShape3D=stock.meshes.Bottle.create_convex_shape()
			_add_solid(body,bottle_solid)
			# Glazed stock does not have the felt/book-base friction inherited by
			# the common movable-stock owner. Rubber keeps its original friction.
			body.physics_material_override.friction=.35
			_letter(body,"BottleLabel","RUBBER\nDRESSING",Vector3(0,.071,.0343),.0075)
			body.get_node("BottleLabel").rotation.y=0.
			var turn:=preload("res://scripts/props/manipulation_area.gd").new() as Area3D
			turn.name="BottleShoulderGrip";turn.collision_layer=1;turn.collision_mask=0;turn.monitoring=false
			turn.provider=func():return body.turn_grip(Vector3.RIGHT) if is_inspecting(body) else body.grip()
			body.add_child(turn);turn.add_to_group("functional_interaction_areas")
			var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.016,.020,.010)
			shape.shape=box;shape.position=Vector3(.024,.124,-.016);turn.add_child(shape)
		else:
			stock.draw(body,"Gasket")
			var bounds: AABB=stock.meshes.Gasket.get_aabb()
			for shape: ConvexPolygonShape3D in preload("res://scripts/props/native_annular_collision.gd").build(stock.meshes.Gasket,[bounds.position.y,bounds.end.y],12):_add_solid(body,shape)
			var tin:=StaticBody3D.new();tin.name="SpareWasherTin";add_child(tin);tin.position=Vector3(x,0,-.19)
			var draw: MeshInstance3D=stock.draw(tin,"Tin")
			var solid:=CollisionShape3D.new();solid.shape=draw.mesh.create_trimesh_shape();tin.add_child(solid)
		body.settled.connect(func():if not _restoring:manipulation_changed.emit())
	return true

func _add_solid(body: Node3D, shape: Shape3D) -> void:
	if shape is ConvexPolygonShape3D:shape.margin=.00001
	var solid:=CollisionShape3D.new();solid.shape=shape;body.add_child(solid);body._solids.append(solid)

func _letter(parent: Node3D, label: String, text: String, at: Vector3, em: float) -> void:
	var result:=Label3D.new();result.name=label;result.text=text
	result.font=preload("res://assets/fonts/courier_prime/CourierPrime-Regular.ttf")
	result.font_size=40;result.pixel_size=em/40.;result.position=at;result.rotation.y=PI
	result.outline_size=0;result.modulate=Color(.055,.035,.02) if label in ["BottleLabel","Merchant","Price","Status"] else Color(.84,.78,.61);result.shaded=true
	result.double_sided=false;result.no_depth_test=false;result.alpha_cut=Label3D.ALPHA_CUT_DISCARD
	if label=="BottleLabel":result.shaded=false;result.modulate=Color(.004,.002,.001)
	result.alpha_scissor_threshold=.4
	result.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
	result.alpha_antialiasing_edge=.15
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	parent.add_child(result)
	_matte_letter.call_deferred(result)

func _matte_letter(label: Label3D) -> void:
	if not is_instance_valid(label):return
	var mesh:=label.get_base()
	for surface in RenderingServer.mesh_get_surface_count(mesh):
		RenderingServer.material_set_param(RenderingServer.mesh_surface_get_material(mesh,surface),"specular",0.)

func _sale_result(accepted: bool, _identity: String) -> void:
	var terminal: Node3D=terminals[_identity]
	var flag:=terminal.get_node("Status") as Label3D
	flag.text={"paid":"SETTLED","no_carrier":"NO CARRIER","insufficient_funds":"NO CREDIT",
		"awaiting_order":"AWAIT ORDER","save_unavailable":"RECORD FAULT",
		"terminal_unavailable":"LINE CLOSED"}.get(terminal.last_status,"REFUSED")
	_matte_letter.call_deferred(flag)
	var player:=get_tree().get_first_node_in_group("player_controller") as PlayerController
	if player!=null:
		var record: Dictionary=merchant.stock_record(_identity)
		var price: String="BUILDING ACCOUNT" if not record.has("price_cents") else (str(int(record.price_cents))+" CENTS")
		player.present_service_note(terminal,{"title":"QUEENS MUTUAL / SETTLEMENT",
			"body":str(record.display_name).to_upper()+" / "+price,
			"condition":flag.text,"stamp":"COUNTER COPY"})
	if accepted:manipulation_changed.emit()

func claim_library_hand(part: Node3D, _tag: String) -> bool:
	if is_instance_valid(_hand_node) or not can_take(part):return false
	_suspended_stock.erase(str(part.item_id))
	_hand_node=part;part.set_physics_process(true);return true

func can_take(part: Node3D) -> bool:
	return merchant!=null and merchant.inventory.has_item(str(part.item_id))

func pickup_withdrawal_for(_part: Node3D) -> Vector3:
	# Lift then withdraw off the front edge before following a downward-aimed
	# hand pose. Otherwise the first diagonal move drives stock into its top.
	return -global_basis.z*.26

func release_library_hand(part: Node3D, _changed: bool) -> void:
	if _hand_node!=part:return
	_hand_node=null
	part.set_physics_process(bool(part._floating))
	if not _restoring:manipulation_changed.emit()

func supports_inspected_stock(body: Node3D) -> bool:
	return body==_inspection_stock or body==_pending_inspection_stock

func is_inspecting(body: Node3D) -> bool:return body==_inspection_stock

func inspection_view_for(part: Node3D) -> Dictionary:
	_pending_inspection_stock=null
	var cursor:=part
	while cursor!=null and cursor!=self:
		if cursor in pickups.values():_pending_inspection_stock=cursor;break
		cursor=cursor.get_parent() as Node3D
	return inspection_view()

func inspection_view() -> Dictionary:
	var camera:=get_viewport().get_camera_3d()
	return {"from":camera.global_position,"at":camera.global_position-camera.global_basis.z,"fov":45.}

func inspection_started() -> void:
	_inspection_stock=_pending_inspection_stock;_pending_inspection_stock=null
	if _inspection_stock!=null:_inspection_stock.begin_static_inspection(get_viewport().get_camera_3d().global_transform)

func inspection_ended() -> void:
	if _inspection_stock!=null:
		_inspection_stock.end_static_inspection();_inspection_stock.freeze=false
	_inspection_stock=null;_pending_inspection_stock=null

func apply_dressing(body: Node3D, contact: Vector3) -> void:
	if not merchant.inventory.has_item("fire_hose_rubber_protectant"):return
	for reference: WeakRef in fire_stations:
		var actor: Node3D=reference.get_ref()
		if actor!=null and actor.has_method("try_dress_gasket") and actor.global_position.distance_to(body.global_position)<1.:
			actor.try_dress_gasket(merchant.inventory,contact)

func mechanism_snapshot() -> Dictionary:
	var records: Dictionary={}
	for identity: String in pickups:
		var body: Node3D=pickups[identity]
		# The static inspection hold is transient. Loading its physical pose must
		# resume gravity, rather than leave the purchased stock frozen in midair.
		var supported: bool=body._held or body==_inspection_stock or body==_pending_inspection_stock
		var physical: Dictionary=body.stock_snapshot()
		if supported:physical.sleeping=false
		var parked: bool=body.freeze and not supported
		records[identity]=_suspended_stock[identity].duplicate(true) if _suspended_stock.has(identity) else {"stock":physical,"cap":body.cap_turn,"parked":parked}
	return records

func valid_mechanism(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=pickups.size():return false
	for identity: String in pickups:
		var record: Variant=value.get(identity)
		if record is not Dictionary or record.size()!=3 or record.get("parked") is not bool \
				or not Pickup.valid_stock(record.get("stock")) \
				or typeof(record.get("cap")) not in [TYPE_INT,TYPE_FLOAT] \
				or not is_finite(float(record.cap)) or float(record.cap)<0. or float(record.cap)>Pickup.CAP_TRAVEL:return false
	return true

func restore_mechanism(value: Dictionary) -> void:
	if _hand_node!=null or not valid_mechanism(value):return
	_restoring=true
	_suspended_stock.clear()
	for identity: String in pickups:
		var body: Node3D=pickups[identity];var record: Dictionary=value[identity]
		body.freeze_mode=RigidBody3D.FREEZE_MODE_KINEMATIC
		body.restore_stock(record.stock);body.freeze=record.parked
		if body.cap!=null:body.set_cap(float(record.cap))
	if _geometry_dormant:passage_geometry_dormant()
	_restoring=false
