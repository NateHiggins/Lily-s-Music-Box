class_name ItemUse
extends Node
## What a carried good does when the hand takes it out of the case. The catalogue
## says what each one is for. A use spends one from the stack and may print one
## remark on the set, once. Stopped ears are the only lasting effect: the world goes
## quieter, small faults with it, until the wax comes out after a shift. Nothing here
## opens a door, a clue or a case.

const KEY := "item_use"
const VERBS := {"eat": "EAT IT", "drink": "DRINK IT", "smoke": "SMOKE IT", "medicine": "TAKE IT", "earplugs": "STOP YOUR EARS"}
const REMARKS := {"eat": "m_use_eat", "drink": "m_use_eat", "smoke": "m_use_smoke",
	"medicine": "m_use_medicine", "earplugs": "m_use_earplugs"}
const EARS_MIX := &"stopped_ears"
const EARS_MINUTES := 480.0
const POLL_SECONDS := 2.0
const REMARK_SECONDS := 300.0

var catalogue: ShopCatalogue
var player: PlayerController
var _clock := CampaignClock.new()
var _accumulator := 0.0


func setup(shops: ShopCatalogue, holder: PlayerController) -> void:
	catalogue = shops
	player = holder
	_refresh_ears()


static func valid(value: Variant) -> bool:
	return value is Dictionary and typeof(value.get("ears_until")) in [TYPE_INT, TYPE_FLOAT] \
			and is_finite(float(value.ears_until))


func _book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"ears_until": -1.0}
	return RealityState.data[KEY]


## The catalogue's first record of this good, wherever it was bought.
func record_of(item: String) -> Dictionary:
	for shop_id: String in catalogue.shop_ids():
		var record := catalogue.item(shop_id, item)
		if not record.is_empty():
			return record
	return {}


func use_of(item: String) -> String:
	return str(record_of(item).get("use", ""))


## The words the hand's tag shows when a stack is held off the shelf.
func verb_for(item: String) -> String:
	return str(VERBS.get(use_of(item), "NOTHING TO DO WITH IT"))


func use(item: String) -> bool:
	var kind := use_of(item)
	if not VERBS.has(kind) or (kind == "earplugs" and ears_stopped()):
		return false
	if not PersonInventory.spend_goods(PersonInventory.PLAYER, item):
		return false
	if kind == "earplugs":
		_book().ears_until = _now() + EARS_MINUTES
		RealityState.commit()
		_refresh_ears()
	_remark(str(REMARKS[kind]))
	return true


func _remark(line_id: String) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.carried_device):
		return
	var session: Variant = player.carried_device.get("session")
	if session != null:
		session.queue_event(line_id, REMARK_SECONDS)


func _now() -> float:
	_clock.bind_state()
	return _clock.elapsed_minutes()


func ears_stopped() -> bool:
	return _now() < float(_book().ears_until)


func _refresh_ears() -> void:
	if ears_stopped():
		AudioPolicy.request_mix(EARS_MIX, &"stopped_ears")
	else:
		AudioPolicy.release_mix(EARS_MIX)


func _process(delta: float) -> void:
	_accumulator += delta
	if _accumulator >= POLL_SECONDS:
		_accumulator = 0.0
		_refresh_ears()


func _exit_tree() -> void:
	AudioPolicy.release_mix(EARS_MIX)
