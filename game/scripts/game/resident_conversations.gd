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

## Trust at which a resident moves on from first contact, and at which the one
## quiet integration beat is offered. Mina's case uses its own stages.
const REAL_TALK_TRUST := 3
const INTEGRATION_TRUST := 6

var dialogue: CaseDialoguePanel
var trees: Dictionary = {}
var units: Dictionary = {}
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
func knock(unit: String, _player: Node = null) -> Dictionary:
	var candidates: Array = []
	for resident_id in residents_in(unit):
		if is_home(resident_id):
			candidates.append(resident_id)
	candidates.sort_custom(func(a, b):
		return RealityState.conversation_visits(a) < RealityState.conversation_visits(b))
	for resident_id in candidates:
		if start(resident_id):
			return {}
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
	var tree: Dictionary = trees[resident_id]
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
	RealityState.commit()
	conversation_ended.emit(resident_id)


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
