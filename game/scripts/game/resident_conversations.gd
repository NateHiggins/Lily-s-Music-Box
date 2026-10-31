class_name ResidentConversations
extends Node
## Threshold conversations with the people of the building.
##
## The seventeen authored trees in res://data/dialogue/ (see
## design/ORISON_DIALOGUE_DRAFTS_2026-10-22.md) share one CaseDialoguePanel.
## This node picks the entry for a resident from what the player has earned,
## runs the tree, and files what the conversation produced:
##
##   - a choice's `flag` becomes a campaign-wide knowledge flag on RealityState
##     (RealityState.grant_knowledge), so a thing learnt in 4A can unlock a
##     reply in 5B;
##   - trust accrues per resident (RealityState.add_resident_trust), which is
##     what moves a resident from first_stable to real_talk to integration;
##   - a `requires` list is honoured against the knowledge flags; an
##     `evidence` choice is offered only while the player stands in the
##     resident's own flat; `infer` is presentation only (the authored trust
##     cost is already on the choice).
##
## WHAT IT NEVER DOES. It never activates, stabilises or resolves a case
## (Bible IV.1: six residents carry cases; the rest are tenants without a
## chapter). For a resident whose case record is enabled and already in play,
## a recorded flag is also passed to RealityCases.record_conversation so the
## existing case machinery sees it; for everyone else the flags stay in the
## knowledge store. Mina's canon tree is owned by MinaCaseGameplay and is not
## loaded here.

signal conversation_started(resident_id: String, entry_id: String)
signal conversation_ended(resident_id: String)

## Literal paths, not a directory scan, so the reader gate can see which file
## each field read belongs to.
const TREE_PATHS: Array[String] = [
	"res://data/dialogue/cal_dwyer.json",
	"res://data/dialogue/cam_ortiz.json",
	"res://data/dialogue/evelyn_marsh.json",
	"res://data/dialogue/iris_bell.json",
	"res://data/dialogue/jonah_price.json",
	"res://data/dialogue/juno_kells.json",
	"res://data/dialogue/lena_ortiz.json",
	"res://data/dialogue/mae_kessler.json",
	"res://data/dialogue/malcolm_reed.json",
	"res://data/dialogue/nadia_quell.json",
	"res://data/dialogue/noel_price.json",
	"res://data/dialogue/omar_bell.json",
	"res://data/dialogue/peter_wren.json",
	"res://data/dialogue/rhea_sato.json",
	"res://data/dialogue/sacha_reed.json",
	"res://data/dialogue/teresa_vale.json",
	"res://data/dialogue/transient_guests.json",
]
const SCHEDULES_PATH := "res://data/resident_schedules.json"
## Handheld field notes (Bible VIII.5.l, design/DIRECT_MANIPULATION_2026-10-12.md):
## opaque messages on the service set's slip printer, each printed once per
## campaign and only while the radio is powered. They never explain how to
## operate a thing (the cursor does that). Thirty columns; illustrations are
## crude on purpose; {unit} is replaced with the apartment number.
const NOTES_PATH := "res://data/field_notes.json"
const NOTE_PREFIX := "note:"
## Dated opinions (design/ORISON_NEWSPAPERS_2026-10-23.md §7): what a resident
## thinks of the news while it is news. Literal paths for the reader gate.
const OPINION_PATHS: Array[String] = [
	"res://data/opinions/cal_dwyer.json",
	"res://data/opinions/cam_ortiz.json",
	"res://data/opinions/evelyn_marsh.json",
	"res://data/opinions/iris_bell.json",
	"res://data/opinions/jonah_price.json",
	"res://data/opinions/juno_kells.json",
	"res://data/opinions/lena_ortiz.json",
	"res://data/opinions/mae_kessler.json",
	"res://data/opinions/malcolm_reed.json",
	"res://data/opinions/nadia_quell.json",
	"res://data/opinions/noel_price.json",
	"res://data/opinions/omar_bell.json",
	"res://data/opinions/peter_wren.json",
	"res://data/opinions/rhea_sato.json",
	"res://data/opinions/sacha_reed.json",
	"res://data/opinions/teresa_vale.json",
	"res://data/opinions/transient_guests.json",
]
const OPINION_PREFIX := "op:"
const OPINION_MENU := "op_menu"
## The mystery threads (design/ORISON_MYSTERY_DIALOGUE_2026-10-30.md): dated,
## houred and earned topics on the same panel. Flags are what the player knows,
## never what a resident knows, and they move no trust and touch no case.
## Literal paths for the reader gate.
const MYSTERY_PATHS: Array[String] = [
	"res://data/mystery/adela_voss.json",
	"res://data/mystery/cal_dwyer.json",
	"res://data/mystery/cam_ortiz.json",
	"res://data/mystery/emil_voss.json",
	"res://data/mystery/evelyn_marsh.json",
	"res://data/mystery/h_vantry.json",
	"res://data/mystery/iris_bell.json",
	"res://data/mystery/jonah_price.json",
	"res://data/mystery/juno_kells.json",
	"res://data/mystery/lena_ortiz.json",
	"res://data/mystery/mae_kessler.json",
	"res://data/mystery/malcolm_reed.json",
	"res://data/mystery/mina_vale.json",
	"res://data/mystery/mr_ewald.json",
	"res://data/mystery/nadia_quell.json",
	"res://data/mystery/noel_price.json",
	"res://data/mystery/omar_bell.json",
	"res://data/mystery/patrolman.json",
	"res://data/mystery/peter_wren.json",
	"res://data/mystery/rhea_sato.json",
	"res://data/mystery/sacha_reed.json",
	"res://data/mystery/teresa_vale.json",
	"res://data/mystery/transient_guests.json",
]
const MYSTERY_FLAG_PREFIX := "m_"
const MYSTERY_HEARD_PREFIX := "mt:"
const MYSTERY_MENU := "mystery_menu"
const PLAYTEST_ENV := "ORISON_MYSTERY_PLAYTEST"
const ERRAND_ASK := "errand:ask"
const ERRAND_THANKS := "errand:thanks"
const ERRAND_WAIT := "errand:wait"
const GIFT_PREFIX := "gift:"

## Trust at which a resident moves on from first contact, and at which the one
## quiet integration beat is offered. Mina's case uses its own stages.
const REAL_TALK_TRUST := 3
const INTEGRATION_TRUST := 6

var dialogue: CaseDialoguePanel
var trees: Dictionary = {}
var units: Dictionary = {}
var notes: Dictionary = {}
var opinions: Dictionary = {}   # resident_id -> {hook, hook_line, opinions: [..]}
var mystery: Dictionary = {}    # resident_id -> {meta, entries, threads, nodes}
var errands: ResidentErrands
var gifts: ResidentGifts
## Set only by the playtest panel: read the threads as of this date and minute,
## with held threads open, without moving the clock or anything that reads it.
var playtest_date := ""
var playtest_minute := -1
var playtest_holds := false
var _last_player: Node = null
var _clock: CampaignClock
var errors: Array[String] = []
var _unit_resolver: Callable = Callable()
var _home_resolver: Callable = Callable()
var _active_resident := ""


## `player_unit` answers "which apartment is the player standing in" ("" when
## none); `resident_home` answers "is this resident in their flat right now".
## Both default to permissive answers so the trees can be played in a test.
func setup(panel: CaseDialoguePanel, player_unit := Callable(),
		resident_home := Callable()) -> void:
	dialogue = panel
	_unit_resolver = player_unit
	_home_resolver = resident_home
	if not dialogue.tree_ended.is_connected(_on_tree_ended):
		dialogue.tree_ended.connect(_on_tree_ended)
	_load_units()
	_load_trees()
	_load_notes()
	_load_opinions()
	_load_mystery()
	if OS.get_environment(PLAYTEST_ENV) == "1":
		add_child(preload("res://scripts/game/mystery_playtest.gd").new())


func _ready() -> void:
	add_to_group("resident_conversations")


func has_tree(resident_id: String) -> bool:
	return trees.has(resident_id)


func resident_ids() -> Array:
	var ids := trees.keys()
	ids.sort()
	return ids


func residents_in(unit: String) -> Array:
	var found: Array = []
	for resident_id in units:
		if str(units[resident_id]) == unit:
			found.append(resident_id)
	found.sort()
	return found


func unit_of(resident_id: String) -> String:
	return str(units.get(resident_id, ""))


func is_home(resident_id: String) -> bool:
	if _home_resolver.is_valid():
		return bool(_home_resolver.call(resident_id))
	return true


func player_unit() -> String:
	if _unit_resolver.is_valid():
		return str(_unit_resolver.call())
	return ""


## A knock at an apartment door. Whoever is home answers; two residents
## alternate by who has been spoken to less. Returns a field slip only when
## nobody answers, so the carried set files the silence and nothing else.
func knock(unit: String, player: Node = null) -> Dictionary:
	_last_player = player
	var candidates: Array = []
	for resident_id in residents_in(unit):
		if is_home(resident_id):
			candidates.append(resident_id)
	candidates.sort_custom(func(a, b):
		return RealityState.conversation_visits(a) < RealityState.conversation_visits(b))
	for resident_id in candidates:
		if start(resident_id):
			return {}
	# The first unanswered knock is the handheld note about hours; the slip
	# is the printed thing itself, so the note is marked filed on return.
	if note_pending("first_knock_unanswered"):
		RealityState.grant_knowledge(NOTE_PREFIX + "first_knock_unanswered")
		return field_note("first_knock_unanswered", unit)
	return {"title": "UNIT %s" % unit,
			"body": "KNOCKED STOP NO ANSWER STOP",
			"condition": "DOOR CLOSED / NOBODY HOME",
			"stamp": "SERVICE NOTE"}


## Begin a resident's conversation at the entry they have earned. False when
## the resident has no authored tree here (Mina, and anyone unauthored), in
## which case an enabled case still receives the ordinary interaction.
func start(resident_id: String) -> bool:
	if dialogue == null or dialogue.attention_active():
		return false
	if not trees.has(resident_id):
		var case_id := RealityCases.case_for_resident(resident_id)
		if case_id != "" and bool(RealityCases.definition(case_id).get("enabled", false)):
			RealityCases.interact_with_resident(resident_id)
			return true
		return false
	var tree: Dictionary = with_gifts(resident_id, with_errand(resident_id, with_weather(resident_id,with_opinions(resident_id,
			with_mystery(resident_id, trees[resident_id], today(), minute_now()), today()))))
	var entry_id := entry_for(resident_id)
	var entries: Dictionary = tree.get("entries", {})
	var node_id := str(entries.get(entry_id, entries.get("first_stable", "")))
	if node_id == "" or not tree.get("nodes", {}).has(node_id):
		errors.append("%s: entry '%s' names no node" % [resident_id, entry_id])
		return false
	_active_resident = resident_id
	RealityState.record_conversation_visit(resident_id)
	if entry_id == "integration":
		RealityState.grant_knowledge(_integration_flag(resident_id))
	RealityState.commit()
	dialogue.run_tree(tree, node_id,
			func(flag: String, trust: int): _record(resident_id, flag, trust),
			Callable(),
			{"available": func(choice: Dictionary): return _available(resident_id, choice),
			 "on_node_flag": func(flag: String): _record(resident_id, flag, 0)})
	conversation_started.emit(resident_id, entry_id)
	return true


## Which door of the tree opens for this resident now. Case residents whose
## case is resolved get the resolved beat; everyone else earns their way up
## by trust, and a soured first contact falls back.
func entry_for(resident_id: String) -> String:
	var case_id := RealityCases.case_for_resident(resident_id)
	if case_id != "" and bool(RealityState.case_state(case_id).get("resolved", false)):
		return "resolved"
	var trust := RealityState.resident_trust(resident_id)
	var visits := RealityState.conversation_visits(resident_id)
	if RealityState.has_knowledge(_integration_flag(resident_id)):
		return "resolved"
	if trust >= INTEGRATION_TRUST:
		return "integration"
	if trust >= REAL_TALK_TRUST:
		return "real_talk"
	if visits > 0 and trust < 0:
		return "fallback"
	return "first_stable"


func _integration_flag(resident_id: String) -> String:
	return "%s:integration" % resident_id


func _available(resident_id: String, choice: Dictionary) -> bool:
	for flag in choice.get("requires", []):
		if not RealityState.has_knowledge(str(flag)):
			return false
	if choice.has("evidence") and player_unit() != unit_of(resident_id):
		return false
	return true


func _record(resident_id: String, flag: String, trust: int) -> void:
	if flag == ERRAND_ASK:
		errands.ask(resident_id)
		return
	if flag == ERRAND_THANKS:
		errands.deliver(resident_id)
		return
	if flag == ERRAND_WAIT:
		return
	if flag.begins_with(GIFT_PREFIX):
		gifts.give(resident_id, flag.trim_prefix(GIFT_PREFIX))
		return
	if flag.begins_with("wx:") or flag.begins_with(MYSTERY_FLAG_PREFIX) \
			or flag.begins_with(MYSTERY_HEARD_PREFIX):
		RealityState.grant_knowledge(flag)
		RealityState.commit()
		return
	if flag != "":
		RealityState.grant_knowledge(flag)
	if trust != 0:
		RealityState.add_resident_trust(resident_id, trust)
	var case_id := RealityCases.case_for_resident(resident_id)
	if case_id != "" and flag != "":
		var definition := RealityCases.definition(case_id)
		var state := RealityState.case_state(case_id)
		if bool(definition.get("enabled", false)) \
				and str(state.get("stage", "unseen")) not in ["unseen", "resolved"]:
			RealityCases.record_conversation(case_id, flag, trust)
			return
	RealityState.commit()


func _on_tree_ended() -> void:
	if _active_resident == "":
		return
	var resident_id := _active_resident
	_active_resident = ""
	if note_pending("first_conversation"):
		file_note("first_conversation", _last_player)
	RealityState.commit()
	conversation_ended.emit(resident_id)


## --- field notes ---------------------------------------------------------

func note_pending(note_id: String) -> bool:
	return notes.has(note_id) and not RealityState.has_knowledge(NOTE_PREFIX + note_id)


## The card as the printer receives it: title, body, condition, stamp.
func field_note(note_id: String, unit := "") -> Dictionary:
	var note: Dictionary = notes.get(note_id, {})
	if note.is_empty():
		return {}
	return {"title": str(note.get("title", "")).replace("{unit}", unit),
		"body": str(note.get("body", "")).replace("{unit}", unit),
		"condition": str(note.get("condition", "")),
		"stamp": str(note.get("stamp", "SERVICE NOTE"))}


## Print a note on the player's carried service set. Device power governs
## its messages: an unpowered set prints nothing and the note stays pending.
func file_note(note_id: String, player: Node) -> bool:
	if not note_pending(note_id) or player == null or not is_instance_valid(player):
		return false
	var device: Variant = player.get("carried_device")
	if device == null or not is_instance_valid(device) \
			or not device.has_method("print_telegram_card") \
			or not device.has_method("radio_is_powered"):
		return false
	if not bool(device.call("radio_is_powered")):
		return false
	if not bool(device.call("print_telegram_card", field_note(note_id))):
		return false
	RealityState.grant_knowledge(NOTE_PREFIX + note_id)
	return true


## --- opinions ------------------------------------------------------------

func with_weather(resident_id: String, tree: Dictionary) -> Dictionary:
	var manager := get_tree().get_first_node_in_group("weather_manager")
	if manager==null or str(manager.get("source"))!="campaign-calendar": return tree
	if _clock==null: _clock=CampaignClock.new()
	var director: DayNightDirector=manager.get("director")
	var sunlit:=true
	if director!=null:
		var sun: Vector3=director.resolved_profile().get("sun_direction",Vector3.UP)
		sunlit=sun.y>0.0
	var note := ResidentWeather.observation(resident_id,_clock.local_datetime(),
		manager.get("current"),_clock.elapsed_minutes(),sunlit)
	if note.is_empty() or RealityState.has_knowledge(str(note.id)): return tree
	var copy := tree.duplicate(true)
	var home := str(copy.entries.get(entry_for(resident_id),copy.entries.get("first_stable","")))
	copy.nodes[str(note.id)]={"line":str(note.line),"flag":str(note.id),
		"choices":[{"label":"...","goto":home}],"silence_goto":home}
	for entry: Variant in copy.entries.values():
		var node: Dictionary=copy.nodes.get(str(entry),{})
		if node.is_empty(): continue
		var choices: Array=node.get("choices",[])
		choices.append({"label":str(note.topic),"goto":str(note.id)})
		node["choices"]=choices
	return copy

## The campaign date as YYYY-MM-DD, or "" when no clock is bound (a bare test).
func today() -> String:
	if playtest_date != "":
		return playtest_date
	if _clock == null:
		_clock = CampaignClock.new()
	if not _clock.bind_state():
		return ""
	var local := _clock.local_datetime()
	if local.is_empty():
		return ""
	return "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]


## The opinions a resident would raise today: inside their window, not yet
## heard, and with every `requires` flag known (earlier opinions grant
## op:<id>, so views can build on views).
func active_opinions(resident_id: String, date: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if date == "":
		return out
	for opinion in (opinions.get(resident_id, {}).get("opinions", []) as Array):
		if date < str(opinion.get("from", "")) or date > str(opinion.get("until", "")):
			continue
		if RealityState.has_knowledge(OPINION_PREFIX + str(opinion.id)):
			continue
		var ready := true
		for flag in opinion.get("requires", []):
			if not RealityState.has_knowledge(str(flag)):
				ready = false
		if ready:
			out.append(opinion)
	return out


## A working copy of the tree with today's opinions grafted on: every entry
## node gains the resident's hook reply, which leads to the one opinion or to a
## short menu of them; each opinion node grants op:<id> on arrival and its
## replies answer once, then the conversation resumes at the door.
func with_opinions(resident_id: String, tree: Dictionary, date: String) -> Dictionary:
	var active := active_opinions(resident_id, date)
	if active.is_empty():
		return tree
	var record: Dictionary = opinions[resident_id]
	var copy: Dictionary = tree.duplicate(true)
	var nodes: Dictionary = copy.nodes
	var entries: Dictionary = copy.get("entries", {})
	var home := str(entries.get(entry_for(resident_id), entries.get("first_stable", "")))
	var hook_goto := OPINION_PREFIX + str(active[0].id)
	if active.size() > 1:
		var menu := {"line": str(record.get("hook_line", "Which part?")), "choices": [],
			"silence_goto": home}
		for opinion in active:
			menu.choices.append({"label": str(opinion.get("topic", opinion.id)),
					"goto": OPINION_PREFIX + str(opinion.id)})
		nodes[OPINION_MENU] = menu
		hook_goto = OPINION_MENU
	for opinion in active:
		var node_id := OPINION_PREFIX + str(opinion.id)
		var node := {"line": str(opinion.line), "flag": node_id, "choices": [],
			"silence_goto": home}
		if str(opinion.get("silence_reply", "")) != "":
			nodes[node_id + ":s"] = {"line": str(opinion.silence_reply),
					"choices": [{"label": "...", "goto": home}], "silence_goto": home}
			node.silence_goto = node_id + ":s"
		var replies: Array = opinion.get("choices", [])
		for i in replies.size():
			var reply: Dictionary = replies[i]
			var reply_id := "%s:r%d" % [node_id, i]
			var choice := {"label": str(reply.label), "goto": reply_id}
			for key in ["trust", "flag", "requires", "infer"]:
				if reply.has(key):
					choice[key] = reply[key]
			node.choices.append(choice)
			nodes[reply_id] = {"line": str(reply.reply),
					"choices": [{"label": "...", "goto": home}], "silence_goto": home}
		nodes[node_id] = node
	for entry_name in entries:
		var entry_node: Dictionary = nodes.get(str(entries[entry_name]), {})
		if entry_node.is_empty():
			continue
		var choices: Array = entry_node.get("choices", [])
		if choices.any(func(c): return str(c.get("goto", "")) == hook_goto):
			continue
		choices.append({"label": str(record.get("hook", "You've seen the paper.")), "goto": hook_goto})
		entry_node["choices"] = choices
	return copy


## --- errands ---------------------------------------------------------------

## A copy of the tree with the day's errand on it: a list to take down, or a bag to
## hand over. Nothing happens until the reply is chosen: arriving at the node files
## its flag, and _record passes that to the errand.
func with_errand(resident_id: String, tree: Dictionary) -> Dictionary:
	if errands == null or not errands.ready():
		return tree
	var topic := ""
	var node_id := ""
	var line := ""
	if errands.can_deliver(resident_id):
		topic = "I brought your groceries."
		node_id = ERRAND_THANKS
		line = "Put them down there. That's the lot. Thank you."
	elif errands.can_ask(resident_id):
		topic = "Need anything from the shops?"
		node_id = ERRAND_ASK
		line = "%s. If you're going anyway." % errands.list_words(resident_id)
	elif errands.has_open(resident_id):
		topic = "What was it you needed?"
		node_id = ERRAND_WAIT
		line = "The same as I said. It hasn't changed."
	if topic == "":
		return tree
	var copy: Dictionary = tree.duplicate(true)
	var entries: Dictionary = copy.get("entries", {})
	var home := str(entries.get(entry_for(resident_id), entries.get("first_stable", "")))
	copy.nodes[node_id] = {"line": line, "flag": node_id, "choices": [{"label": "...", "goto": home}], "silence_goto": home}
	for entry: Variant in entries.values():
		var node: Dictionary = copy.nodes.get(str(entry), {})
		if node.is_empty():
			continue
		var choices: Array = node.get("choices", [])
		if not choices.any(func(c): return str(c.get("goto", "")) == node_id):
			choices.append({"label": topic, "goto": node_id})
		node["choices"] = choices
	return copy


## A copy of the tree offering what the player carries that can be given. One gift
## a day. Nothing changes hands until the reply is chosen.
func with_gifts(resident_id: String, tree: Dictionary) -> Dictionary:
	if gifts == null:
		return tree
	var offers := gifts.offers(resident_id)
	if offers.is_empty():
		return tree
	var copy: Dictionary = tree.duplicate(true)
	var entries: Dictionary = copy.get("entries", {})
	var home := str(entries.get(entry_for(resident_id), entries.get("first_stable", "")))
	for offer: Dictionary in offers:
		copy.nodes[GIFT_PREFIX + str(offer.id)] = {"line": "For me? Well. Thank you.",
			"flag": GIFT_PREFIX + str(offer.id), "choices": [{"label": "...", "goto": home}], "silence_goto": home}
	for entry: Variant in entries.values():
		var node: Dictionary = copy.nodes.get(str(entry), {})
		if node.is_empty():
			continue
		var choices: Array = node.get("choices", [])
		for offer: Dictionary in offers:
			var goto_id := GIFT_PREFIX + str(offer.id)
			if not choices.any(func(c): return str(c.get("goto", "")) == goto_id):
				choices.append({"label": "I brought you %s." % str(offer.name).to_lower(), "goto": goto_id})
		node["choices"] = choices
	return copy


## --- mystery threads -----------------------------------------------------

## The campaign minute of the day, or -1 when no clock is bound.
func minute_now() -> int:
	if playtest_minute >= 0:
		return playtest_minute
	if _clock == null:
		_clock = CampaignClock.new()
	if not _clock.bind_state():
		return -1
	var local := _clock.local_datetime()
	if local.is_empty():
		return -1
	return int(local.hour) * 60 + int(local.minute)


static func _clock_minute(value: String) -> int:
	var parts := value.split(":")
	return int(parts[0]) * 60 + int(parts[1])


## The threads a person would open now: inside the dates and hours, every
## `requires` known, not yet heard, and not held for another owner's canon.
func active_threads(resident_id: String, date: String, minute: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if date == "":
		return out
	for thread in (mystery.get(resident_id, {}).get("threads", []) as Array):
		if date < str(thread.from) or date > str(thread.until):
			continue
		if thread.has("hold") and not playtest_holds:
			continue
		if RealityState.has_knowledge(MYSTERY_HEARD_PREFIX + str(thread.id)):
			continue
		if thread.has("hours"):
			if minute < _clock_minute(str(thread.hours[0])) or minute > _clock_minute(str(thread.hours[1])):
				continue
		var ready := true
		for flag in thread.get("requires", []):
			if not RealityState.has_knowledge(str(flag)):
				ready = false
		var any_of: Array = thread.get("requires_any", [])
		if not any_of.is_empty() and not any_of.any(func(flag): return RealityState.has_knowledge(str(flag))):
			ready = false
		if ready:
			out.append(thread)
	return out


## A working copy of the tree with the open threads grafted on: every entry node
## gains each thread's topic, and arriving at its root marks it heard. A thread
## ends the conversation where its own nodes end.
func with_mystery(resident_id: String, tree: Dictionary, date: String, minute: int) -> Dictionary:
	var active := active_threads(resident_id, date, minute)
	if active.is_empty():
		return tree
	var copy: Dictionary = tree.duplicate(true)
	_graft_thread_nodes(resident_id, copy, active)
	var entries: Dictionary = copy.get("entries", {})
	for entry_name in entries:
		var entry_node: Dictionary = copy.nodes.get(str(entries[entry_name]), {})
		if entry_node.is_empty():
			continue
		var choices: Array = entry_node.get("choices", [])
		for thread in active:
			if not choices.any(func(c): return str(c.get("goto", "")) == str(thread.root)):
				choices.append({"label": str(thread.topic), "goto": str(thread.root)})
		entry_node["choices"] = choices
	return copy


func _graft_thread_nodes(resident_id: String, into: Dictionary, active: Array[Dictionary]) -> void:
	var source: Dictionary = mystery[resident_id].nodes
	for node_id in source:
		into.nodes[node_id] = (source[node_id] as Dictionary).duplicate(true)
	for thread in active:
		var root: Dictionary = into.nodes[str(thread.root)]
		var flags: Array = root.get("flags", [])
		flags.append(MYSTERY_HEARD_PREFIX + str(thread.id))
		root["flags"] = flags


## Open a person's threads with no door tree behind them, from a menu of their
## topics. False when nothing is open. Adela, Emil, Mr. Ewald, Vantry and the
## patrolman have no door in the world yet, so this is how they are read.
func start_mystery(resident_id: String) -> bool:
	if dialogue == null or dialogue.attention_active():
		return false
	var active := active_threads(resident_id, today(), minute_now())
	if active.is_empty():
		return false
	var tree := {"meta": (mystery[resident_id].meta as Dictionary).duplicate(), "nodes": {}}
	_graft_thread_nodes(resident_id, tree, active)
	var menu := {"line": "...", "choices": []}
	for thread in active:
		menu.choices.append({"label": str(thread.topic), "goto": str(thread.root)})
	tree.nodes[MYSTERY_MENU] = menu
	_active_resident = resident_id
	dialogue.run_tree(tree, MYSTERY_MENU,
			func(flag: String, trust: int): _record(resident_id, flag, trust),
			Callable(),
			{"available": func(choice: Dictionary): return _available(resident_id, choice),
			 "on_node_flag": func(flag: String): _record(resident_id, flag, 0)})
	conversation_started.emit(resident_id, MYSTERY_MENU)
	return true


func _load_mystery() -> void:
	mystery.clear()
	for path in MYSTERY_PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is not Dictionary or str(parsed.get("meta", {}).get("resident_id", "")) == "":
			errors.append("mystery tree unreadable: %s" % path)
			continue
		if _valid_mystery(parsed, path):
			mystery[str(parsed.meta.resident_id)] = parsed


func _valid_mystery(doc: Dictionary, path: String) -> bool:
	var ok := true
	var nodes: Dictionary = doc.get("nodes", {})
	for field in ["speaker_default", "voice_prefix", "voice_status", "status", "notes"]:
		if str(doc.meta.get(field, "")) == "":
			errors.append("%s: meta.%s is empty" % [path, field])
			ok = false
	for entry in doc.get("entries", {}):
		if not nodes.has(str(doc.entries[entry])):
			errors.append("%s: entry %s names a missing node" % [path, entry])
			ok = false
	for thread in doc.get("threads", []):
		for field in ["id", "from", "until", "topic", "source", "root"]:
			if str(thread.get(field, "")) == "":
				errors.append("%s: a thread has no %s" % [path, field])
				ok = false
		if not nodes.has(str(thread.get("root", ""))):
			errors.append("%s: thread %s root is missing" % [path, thread.get("id", "")])
			ok = false
		if thread.has("hours") and (thread.hours is not Array or thread.hours.size() != 2):
			errors.append("%s: thread %s hours is not a pair" % [path, thread.get("id", "")])
			ok = false
		if thread.has("hold") and str(thread.hold) == "":
			errors.append("%s: thread %s hold names nothing" % [path, thread.get("id", "")])
			ok = false
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		if str(node.get("line", "")) == "":
			errors.append("%s: node %s has no line" % [path, node_id])
			ok = false
		if node.has("bank") and str(node.bank) == "":
			errors.append("%s: node %s bank is empty" % [path, node_id])
			ok = false
		if node.has("speaker") and str(node.speaker) == "":
			errors.append("%s: node %s speaker is empty" % [path, node_id])
			ok = false
		if node.has("silence_goto") and not nodes.has(str(node.silence_goto)):
			errors.append("%s: node %s silence_goto is missing" % [path, node_id])
			ok = false
		for choice in node.get("choices", []):
			if str(choice.get("label", "")) == "":
				errors.append("%s: node %s has an unlabelled choice" % [path, node_id])
				ok = false
			if choice.has("goto") and not nodes.has(str(choice.goto)):
				errors.append("%s: node %s goto '%s' is missing" % [path, node_id, choice.goto])
				ok = false
	return ok


func _load_opinions() -> void:
	opinions.clear()
	for path in OPINION_PATHS:
		if not FileAccess.file_exists(path):
			continue   # authored per resident as the year's papers land
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is not Dictionary or str(parsed.get("resident_id", "")) == "" \
				or parsed.get("opinions") is not Array:
			errors.append("opinions unreadable: %s" % path)
			continue
		if _valid_opinions(parsed, path):
			opinions[str(parsed.resident_id)] = parsed


func _valid_opinions(record: Dictionary, path: String) -> bool:
	var ok := true
	if str(record.get("hook", "")) == "":
		errors.append("%s: hook is empty" % path)
		ok = false
	var seen: Dictionary = {}
	for opinion in record.opinions:
		if opinion is not Dictionary:
			errors.append("%s: an opinion is not an object" % path)
			ok = false
			continue
		var id := str(opinion.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("%s: opinion id missing or repeated: %s" % [path, id])
			ok = false
		seen[id] = true
		for field in ["from", "until", "topic", "line"]:
			if str(opinion.get(field, "")) == "":
				errors.append("%s: opinion %s has no %s" % [path, id, field])
				ok = false
		if str(opinion.get("from", "")) > str(opinion.get("until", "")):
			errors.append("%s: opinion %s ends before it starts" % [path, id])
			ok = false
		if opinion.has("requires") and opinion.requires is not Array:
			errors.append("%s: opinion %s requires is not a list" % [path, id])
			ok = false
		for reply in opinion.get("choices", []):
			if reply is not Dictionary or str(reply.get("label", "")) == "" \
					or str(reply.get("reply", "")) == "":
				errors.append("%s: opinion %s has a reply without label or reply" % [path, id])
				ok = false
	return ok


## --- loading ------------------------------------------------------------

func _load_units() -> void:
	units.clear()
	var schedules: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(SCHEDULES_PATH))
	if schedules is not Dictionary or schedules.get("residents") is not Dictionary:
		errors.append("resident schedules unreadable; no doors know their tenants")
		return
	for resident_id in schedules.residents:
		units[str(resident_id)] = str(schedules.residents[resident_id].get("unit", ""))


func _load_notes() -> void:
	notes.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
	if parsed is not Dictionary or parsed.get("notes") is not Dictionary:
		errors.append("field notes unreadable: %s" % NOTES_PATH)
		return
	for note_id in parsed.notes:
		var note: Dictionary = parsed.notes[note_id]
		if str(note.get("title", "")) == "" or str(note.get("body", "")) == "":
			errors.append("field note %s has no title or body" % note_id)
			continue
		notes[str(note_id)] = note


func _load_trees() -> void:
	trees.clear()
	for path in TREE_PATHS:
		if not FileAccess.file_exists(path):
			errors.append("dialogue tree missing: %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is not Dictionary:
			errors.append("dialogue tree is not an object: %s" % path)
			continue
		var tree: Dictionary = parsed
		var meta: Dictionary = tree.get("meta", {})
		var resident_id := str(meta.get("resident_id", ""))
		if resident_id == "":
			# Case trees name their case; the resident comes from the case record.
			var case_id := str(meta.get("case_id", ""))
			resident_id = str(RealityCases.definition(case_id).get("resident_id", ""))
		if resident_id == "":
			errors.append("dialogue tree names no resident: %s" % path)
			continue
		if not _valid_tree(tree, path):
			continue
		trees[resident_id] = tree


## The authored contract, checked at load so a broken tree is a startup
## message and not a dead door. Every field the writers may use is named here.
func _valid_tree(tree: Dictionary, path: String) -> bool:
	var ok := true
	var meta: Dictionary = tree.get("meta", {})
	for field in ["speaker_default", "voice_prefix", "voice_status", "notes"]:
		if str(meta.get(field, "")) == "":
			errors.append("%s: meta.%s is empty" % [path, field])
			ok = false
	var entries: Dictionary = tree.get("entries", {})
	var nodes: Dictionary = tree.get("nodes", {})
	for entry in ["first_stable", "real_talk", "integration", "resolved", "fallback"]:
		if not nodes.has(str(entries.get(entry, ""))):
			errors.append("%s: entry %s names a missing node" % [path, entry])
			ok = false
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		if str(node.get("line", "")) == "":
			errors.append("%s: node %s has no line" % [path, node_id])
			ok = false
		if node.has("role") and str(node.role) == "":
			errors.append("%s: node %s has an empty role" % [path, node_id])
			ok = false
		if node.has("action") and str(node.action) == "":
			errors.append("%s: node %s has an empty action" % [path, node_id])
			ok = false
		if node.has("silence_goto") and not nodes.has(str(node.silence_goto)):
			errors.append("%s: node %s silence_goto is missing" % [path, node_id])
			ok = false
		if node.has("silence_flag") and str(node.silence_flag) == "":
			errors.append("%s: node %s silence_flag is empty" % [path, node_id])
			ok = false
		if node.has("silence_trust") and typeof(node.silence_trust) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s: node %s silence_trust is not a number" % [path, node_id])
			ok = false
		if node.has("flag") and str(node.flag) == "":
			errors.append("%s: node %s flag is empty" % [path, node_id])
			ok = false
		if node.has("flags"):
			if node.flags is not Array or node.flags.is_empty() \
					or node.flags.any(func(f): return str(f) == ""):
				errors.append("%s: node %s flags is not a list of names" % [path, node_id])
				ok = false
		for choice in node.get("choices", []):
			if str(choice.get("label", "")) == "":
				errors.append("%s: node %s has an unlabelled choice" % [path, node_id])
				ok = false
			if choice.has("goto") and not nodes.has(str(choice.goto)):
				errors.append("%s: node %s goto '%s' is missing" % [path, node_id, choice.goto])
				ok = false
			if choice.has("trust") and typeof(choice.trust) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("%s: node %s has a non-numeric trust" % [path, node_id])
				ok = false
			if choice.has("flag") and str(choice.flag) == "":
				errors.append("%s: node %s has an empty flag" % [path, node_id])
				ok = false
			if choice.has("requires") and choice.requires is not Array:
				errors.append("%s: node %s requires is not a list" % [path, node_id])
				ok = false
			if choice.has("evidence") and str(choice.evidence) == "":
				errors.append("%s: node %s evidence names nothing" % [path, node_id])
				ok = false
			if choice.has("infer") and choice.infer is not bool:
				errors.append("%s: node %s infer is not a boolean" % [path, node_id])
				ok = false
	return ok
