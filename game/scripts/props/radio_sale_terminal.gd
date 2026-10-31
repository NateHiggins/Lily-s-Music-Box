extends Node3D
## Mechanical settlement stroke. The merchant service owns the quote, money
## authorization and delivery; this part owns only its bounded hand travel.
signal sale_result(accepted: bool)
const TRAVEL := .040
var merchant: Object
var item_id := ""
var lever: Node3D
var target_area: Area3D
var travel := 0.0
var _held := false
var _attempted := false
var _lever_origin := Vector3.ZERO
var last_status := ""

func configure(service: Object, identity: String,
		moving_lever: Node3D) -> bool:
	if service==null or not service.has_method("transact") \
			or service.stock_record(identity).is_empty() or moving_lever==null:return false
	merchant=service;item_id=identity;lever=moving_lever;_lever_origin=lever.position
	target_area=preload("res://scripts/props/manipulation_area.gd").install(lever,grip)
	return target_area.get_child_count()>0

func grip() -> Dictionary:
	if merchant==null or lever==null or _locked():return {}
	return {"owner":self,"part":lever,"frame":self,"kind":"slide","axis":Vector3.BACK,
		"minimum":0.,"maximum":TRAVEL,"gesture_travel_px":140.,"gesture_screen_axis":Vector2.DOWN,
		"read":func():return travel,
		"write":func(value: float):
			if _held:_move(value),
		"begin":func():
			if _held:return false
			_held=true;_attempted=false;return true,
		"owns":func():return _held,
		"end":func():_held=false}

func _locked() -> bool:
	return merchant.sale_locked(item_id) if merchant.has_method("sale_locked") else merchant.inventory.has_item(item_id)

func _move(value: float) -> void:
	if not is_finite(value):return
	travel=clampf(value,0.,TRAVEL)
	lever.position=_lever_origin+Vector3.BACK*travel
	if travel<.001:_attempted=false
	if travel<TRAVEL-.000001 or _attempted:return
	_attempted=true
	var record: Dictionary=merchant.stock_record(item_id)
	last_status=merchant.transaction_status(item_id)
	var accepted: bool=merchant.transact(item_id,str(record.shop_id))
	if accepted:last_status="paid"
	sale_result.emit(accepted)

func _physics_process(delta: float) -> void:
	# Passive spring return is independent of payment and never retries a sale.
	if _held or travel<=0.:return
	travel=move_toward(travel,0.,delta*.10)
	if lever!=null:lever.position=_lever_origin+Vector3.BACK*travel
