extends Node
## Offline domain diagnostic; no claim about physical input or world operation.
const Conversation = preload("res://scripts/device/companion_conversation.gd")
const Intent = preload("res://scripts/device/companion_intent.gd")
const Memory = preload("res://scripts/device/companion_memory.gd")
const Provider = preload("res://scripts/device/companion_provider.gd")
var checks: Array[Dictionary] = []

func check(ok: bool, name: String) -> void:
	checks.append({"name":name, "passed":ok})
	if not ok: push_error(name)

func _ready() -> void:
	var dialogue := Conversation.new()
	check(dialogue.errors.is_empty() and dialogue.lines.size() >= 50, "structured library loads at least fifty distinct lines")
	check(Intent.normalize("  WHAT'S...Here?!  ") == "what s here", "case punctuation and spacing normalize")
	check(Intent.parse("Could you look at the brass valve?").intent == "examine", "specific look-at phrase outranks look")
	check(Intent.parse("What am I carrying?").intent == "inventory", "natural inventory phrase")
	check(Intent.parse("please fix the drain").intent == "use", "request recognized without executing it")
	check(Intent.parse("yesterday").intent == "unknown", "verb fragments do not match inside words")
	var context := {"location":"Service hall", "objective":"Inspect the reported radiator.",
		"inventory":["Rubber protectant"], "weather_report":"Rain expected after dusk.",
		"visible":[{"id":"hot", "name":"Hot valve", "aliases":["valve", "hot"], "observation":"The hot valve is open."},
			{"id":"cold", "name":"Cold valve", "aliases":["valve", "cold"], "observation":"The cold valve is closed."}]}
	var original := context.duplicate(true)
	check(dialogue.respond("help", context).text == context.objective, "help uses current objective verbatim")
	check(dialogue.respond("check my bag", context).text.contains("Rubber protectant"), "inventory reads supplied items")
	check(not dialogue.respond("inventory", {}).text.contains("Rubber protectant"), "inventory does not retain stale world facts")
	check(dialogue.respond("forecast", context).text == context.weather_report, "weather uses dated report supplied by owner")
	check(dialogue.respond("examine valve", context).line_id == "clarify", "ambiguous specific parts request clarification")
	check(dialogue.respond("hot", context).text == "The hot valve is open.", "clarification resolves against current visible IDs")
	check(dialogue.respond("inspect it", context).text == "The hot valve is open.", "pronoun resolves last seen object")
	dialogue.respond("examine valve", context)
	check(dialogue.respond("hot", {}).line_id == "target_gone", "vanished clarification cannot leak an observation")
	var boundary: Dictionary = dialogue.respond("open hot valve", context)
	check(boundary.line_id == "action_boundary" and not boundary.has("actions") and context == original, "action requests leave all authoritative state unchanged")
	check(dialogue.respond("where is the vault", context).line_id == "navigation_unknown", "no invented route")
	check(dialogue.respond("are you alive", context).line_id == "alive", "long branch starts")
	check(dialogue.respond("tell me more", context).line_id == "alive_follow", "branch follows natural continuation")
	var snapshot: Dictionary = dialogue.memory.snapshot()
	var restored := Conversation.new()
	check(restored.memory.restore(JSON.parse_string(JSON.stringify(snapshot))), "JSON roundtrip restores bounded memory")
	check(restored.respond("are you alive", {}).line_id == "alive_follow", "branch behavior persists through reload")
	check(restored.respond("Does it matter?", {}).line_id == "alive_matters", "specific follow-up takes authored conversational fork")
	for index in 5: restored.respond("eat the machine", {})
	check(restored.respond("eat it", {}).line_id == "eat_persistent", "persistent impossible request acknowledged")
	check(not restored.event("activation").is_empty() and restored.event("activation").is_empty(), "event lines are once per memory")
	for index in 70: restored.respond("nonsense", {})
	check(restored.memory.history.size() == Memory.LIMIT, "history stays bounded")
	var before: Dictionary = restored.memory.snapshot()
	var invalid := before.duplicate(true)
	invalid.trust = "unlock_everything"
	check(not restored.memory.restore(invalid) and restored.memory.snapshot() == before, "corrupt memory rejection is atomic")
	invalid = before.duplicate(true)
	invalid.counts.bad = INF
	check(not restored.memory.restore(invalid), "nonfinite counters rejected")
	check(not Provider.new().available(), "offline system has no network dependency")
	var ids: Array[String] = ["alive", "alive_follow"]
	check(Provider.valid_selection("alive", ids) and not Provider.valid_selection("invented_unlock", ids), "provider restricted to approved authored IDs")
	var failures := 0
	for record: Dictionary in checks:
		if not record.passed: failures += 1
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty(): out = "user://tests/companion"
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("conversation_diagnostic.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"evidence_class":"INERT", "checks":checks, "failures":failures}, "\t"))
	print("COMPANION OFFLINE DIAGNOSTIC: ", checks.size(), " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
