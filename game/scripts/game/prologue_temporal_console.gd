extends Node
## One physical command copy. No OS execution, clock application or story facts.
signal accepted(target:Dictionary)
signal finished(completed:bool)
const State:=preload("res://scripts/game/prologue_state.gd")
var carrier:Node
var target:Dictionary={}
var text:=""
var cursor:=0
var active:=false
var returned:=false
var succeeded:=false
var _started:=false
var _internal_copy:=false
var _campaign:Dictionary
var _keys:Array[String]=[]
var _arm_done:=false

func _init() -> void:set_process(false)

func start(owner_carrier:Node,destination:Dictionary) -> bool:
	if _started or not State.valid_target(destination) or not is_instance_valid(owner_carrier):return false
	carrier=owner_carrier
	if not carrier._arm_permitted() or carrier.arm_busy() or carrier.device.teletype.printing:return false
	target=destination.duplicate(true);text=State.date_command(target).trim_prefix("root# ")
	_keys.clear()
	for character:String in text:
		var key:String="SPACE" if character==" " else character.to_upper()
		if not carrier.rig.typing_arm.targets.has(key):return false
		_keys.append(key)
	_keys.append("ENTER")
	var paper:Node=carrier.device.teletype
	_internal_copy=true
	var opened:bool=paper.begin_keyed_copy(self,"TEMPORAL SERVICE","root# ")
	_internal_copy=false
	if not opened:return false
	if not carrier.rig.typing_arm.begin(_keys):paper.abort_keyed_copy(self);return false
	_started=true;active=true;_campaign=RealityState.data
	carrier.rig.typing_arm.key_pressed.connect(_key)
	carrier.rig.typing_arm.finished.connect(_arm_finished)
	paper.keyed_copy_interrupted.connect(_interrupted)
	paper.card_presenting.connect(_foreign_copy)
	set_process(true)
	return true

func _key(key:String) -> void:
	if not active:return
	if not is_same(_campaign,RealityState.data):cancel();return
	if cursor<text.length():
		if key!=_keys[cursor] or not carrier.device.teletype.append_keyed_copy(self,text[cursor]):cancel();return
		cursor+=1
	elif key=="ENTER" and not returned:
		if not carrier.device.finish_keyed_copy(self,"DATE ACCEPTED"):cancel();return
		returned=true
		accepted.emit(target.duplicate(true))
	else:cancel()

func _arm_finished(completed:bool) -> void:
	if not active:return
	if not completed or not returned:cancel();return
	_arm_done=true

func _process(_delta:float) -> void:
	if not active:return
	if not is_same(_campaign,RealityState.data) or not carrier._arm_permitted():cancel();return
	if returned and _arm_done and not carrier.device.teletype.printing:
		active=false;succeeded=true;set_process(false);_disconnect()
		finished.emit(true)

func _interrupted(owner:Node) -> void:
	if owner==self:cancel()

func _foreign_copy(_card:Dictionary,_serial:int) -> void:
	if active and not _internal_copy:cancel()

func cancel() -> void:
	if not active:return
	active=false;set_process(false)
	_disconnect()
	if is_instance_valid(carrier):
		carrier.device.teletype.abort_keyed_copy(self)
		carrier.rig.typing_arm.cancel()
	finished.emit(false)

func _disconnect() -> void:
	if not is_instance_valid(carrier):return
	var arm:Node=carrier.rig.typing_arm;var paper:Node=carrier.device.teletype
	if arm.key_pressed.is_connected(_key):arm.key_pressed.disconnect(_key)
	if arm.finished.is_connected(_arm_finished):arm.finished.disconnect(_arm_finished)
	if paper.keyed_copy_interrupted.is_connected(_interrupted):paper.keyed_copy_interrupted.disconnect(_interrupted)
	if paper.card_presenting.is_connected(_foreign_copy):paper.card_presenting.disconnect(_foreign_copy)

func _exit_tree() -> void:cancel()
