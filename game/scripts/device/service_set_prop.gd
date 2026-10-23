class_name ServiceSetProp
extends Node3D
## Native Vantry 28-R. Existing radio, WorkOrders and message authorities;
## one physical instrument, with no duplicate procedural body behind it.

const DEVICE_LAYER := 2
const BODY := Vector3(0.214, 0.193, 0.11)
## The inspection beam leaves the attached lamp down local -Z.
const LAMP_AT := Vector3(-0.079, 0.069, -0.079)

const PHENOLIC := Color("211711")
const PHENOLIC_EDGE := Color("35251a")
const BLACKENED := Color("24211d")
const BRASS := Color("79623a")
const BRASS_WORN := Color("a58b58")
const CERAMIC := Color("d3c7a7")
const GLASS_DARK := Color("160f0a")
const AMBER := Color("ff9d24")
const GREEN := Color("65d07d")
const RED := Color("e35a42")
const LAMP_WARM := Color("ffd08a")

var radio_powered := true
var lamp_enabled := true
var _optical_lens := false
var _optical_color := Color.WHITE
var _optical_emission := 0.0
var order_open := false
var incoming_call := false

var _work_orders: WorkOrders
var _aerial: Node3D
var _lamp_lever: Node3D
var _order_material: StandardMaterial3D
var _net_material: StandardMaterial3D
var _lamp_indicator_material: StandardMaterial3D
var _lamp_glass_material: StandardMaterial3D
var _receipt_root: Node3D
var _receipt_label: Label3D
var _receipt_tween: Tween
var _printer_tick: AudioStreamPlayer
var _printer_feed: AudioStreamPlayer
var printed_count := 0
var teletype: Node3D


func _ready() -> void:
	teletype = preload("res://scripts/device/mechanical_teletype.gd").new()
	teletype.name = "MechanicalTeletype"
	add_child(teletype)
	_receipt_root = teletype
	_receipt_label = teletype.ink
	# Keep existing optical/report seams bound to the actual native parts.
	_aerial=teletype._aerial;_lamp_lever=teletype.lamp_switch
	_lamp_glass_material=teletype.torch_lens.get_active_material(0)
	_order_material=teletype._jewels[0].get_active_material(0)
	_net_material=teletype._jewels[1].get_active_material(0)
	_lamp_indicator_material=teletype._jewels[2].get_active_material(0)
	_printer_tick=teletype._tick;_printer_feed=teletype._feed
	_isolate_meshes(self)
	_apply_state(false)


func bind_work_orders(orders: WorkOrders) -> void:
	_work_orders = orders
	if _work_orders == null:
		return
	if not _work_orders.job_stage_changed.is_connected(_on_job_stage_changed):
		_work_orders.job_stage_changed.connect(_on_job_stage_changed)
	if not _work_orders.order_issued.is_connected(_on_simple_order_changed):
		_work_orders.order_issued.connect(_on_simple_order_changed)
	if not _work_orders.order_activated.is_connected(_on_simple_order_changed):
		_work_orders.order_activated.connect(_on_simple_order_changed)
	if not _work_orders.order_closed.is_connected(_on_simple_order_changed):
		_work_orders.order_closed.connect(_on_simple_order_changed)
	if not RealityState.state_changed.is_connected(_refresh_order):
		RealityState.state_changed.connect(_refresh_order)
	_refresh_order()


func set_radio_powered(on: bool, animate := true) -> void:
	if radio_powered == on and _aerial != null:
		_apply_state(animate)
		return
	radio_powered = on
	if teletype != null: teletype.powered=on
	_apply_state(animate)


func toggle_radio_power() -> void:
	set_radio_powered(not radio_powered)


func set_incoming_call(waiting: bool) -> void:
	incoming_call = waiting
	if waiting and teletype != null:
		teletype.present({"title":"LINE REQUEST","body":"L. ORTIZ / 2B\nTHE LINE IS WAITING."},printed_count)
	_apply_state(false)


## A powered set prints the full field copy onto persistent physical paper.
## The physical printer is the carried presentation of the supplied facts.
func print_telegram_card(message: Variant) -> bool:
	if not radio_powered or teletype == null:
		return false
	printed_count += 1
	var card: Dictionary = message if message is Dictionary else {"title":str(message)}
	teletype.present(card,printed_count)
	return true


func _play_feed() -> void:
	if _printer_feed and _printer_feed.stream:
		_printer_feed.play()


func set_lamp_enabled(on: bool, animate := true) -> void:
	if lamp_enabled == on and _lamp_lever != null:
		_apply_state(animate)
		return
	lamp_enabled = on
	_apply_state(animate)

func set_lamp_optical_output(color: Color, emission: float) -> void:
	_optical_lens = true
	_optical_color = color
	_optical_emission = maxf(0.0,emission)
	if teletype:teletype.set_optical_output(color,_optical_emission)


func _on_job_stage_changed(_job_id: String, _from_stage: String,
		_to_stage: String, _state: Dictionary) -> void:
	_refresh_order()


func _on_simple_order_changed(_order_id: String, _order: Dictionary) -> void:
	_refresh_order()


func _refresh_order() -> void:
	order_open = _work_orders != null and _work_orders.has_open_work()
	_apply_state(false)


func _apply_state(animate: bool) -> void:
	if teletype==null:return
	teletype.powered=radio_powered
	teletype.set_controls(radio_powered,lamp_enabled,order_open or incoming_call,animate)
	if _optical_lens:teletype.set_optical_output(_optical_color,_optical_emission)


func _isolate_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(node as GeometryInstance3D).layers = 1 << (DEVICE_LAYER - 1)
	for child in node.get_children():
		_isolate_meshes(child)
