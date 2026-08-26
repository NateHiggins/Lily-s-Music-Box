extends Node
## SR7-O focused proof: the seal is not the charge.
##
##     tools/run_godot_serial.ps1 -Scene res://tests/ExtinguisherTest.tscn `
##         -ProjectPath <checkout>/game
##
## The non-implication this suite exists to hold down:
##
##     sealed()    = cap_on AND seal_wired
##     charged()   = acid_present AND bottle_seated
##     will_lift() = loose_cap_free
##
##     sealed() AND charged()  DOES NOT IMPLY  usable()
##
## Everything else here is that one sentence, checked from a different side —
## including the sharpest side, which is that the faulted extinguisher and the
## sound one weigh the same float.

const ExtinguisherScript := preload(
		"res://scripts/props/soda_acid_extinguisher_prop.gd")
const FIRE_LINE_PATH := "res://scripts/props/fire_line_cabinet_prop.gd"

var passed := 0
var failed := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	_as_found()
	_the_non_implication()
	_bottle_present_is_insufficient()
	_seal_intact_is_insufficient()
	_weight_is_insufficient()
	_you_cannot_certify_a_cap_you_have_not_lifted()
	_there_is_no_test()
	_order_is_the_metal()
	_reassembled_and_still_wrong()
	_refusals_are_different_photographs()
	_abort()
	_it_owns_nothing_else()
	_sr7n_is_a_control_not_a_foundation()
	print("[EXTINGUISHER TEST] PASS %d/%d" % [passed, passed + failed])
	if failed > 0:
		print("[EXTINGUISHER TEST] FAIL %d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		print("[EXTINGUISHER TEST] FAILED: %s" % label)


func _unit() -> Node:
	var unit: Node = ExtinguisherScript.new()
	unit.name = "ExtinguisherUnderTest"
	add_child(unit)
	return unit


func _drop(unit: Node) -> void:
	unit.queue_free()


## Work the whole chain from as-found to sound, in the one order the metal
## allows, and hand the unit back still hanging.
func _make_it_work(unit: Node) -> void:
	unit.call("cut_seal")
	unit.call("unscrew_cap")
	unit.call("draw_bottle")
	unit.call("try_loose_cap")
	unit.call("free_loose_cap")
	unit.call("seat_bottle")
	unit.call("screw_cap")
	unit.call("wire_seal")


# --- as found ----------------------------------------------------------------

func _as_found() -> void:
	var unit := _unit()
	# Everything an inspection can see is right. Everything a recharge leaves
	# is right. One thing is wrong and it is inside a bottle inside a cage
	# inside a cap.
	_check("as found: the cap is on", bool(unit.get("cap_on")))
	_check("as found: the seal is wired", bool(unit.get("seal_wired")))
	_check("as found: the bottle is in its cage",
			bool(unit.get("bottle_seated")))
	_check("as found: there is acid in it", bool(unit.get("acid_present")))
	_check("as found: THE LOOSE CAP IS NOT LOOSE",
			not bool(unit.get("loose_cap_free")))
	_check("as found: nobody has lifted it", not bool(unit.get("cap_tested")))
	_check("as found: the tag is blank",
			str(unit.call("tag_reads")) == ExtinguisherScript.TAG_BLANK)
	_check("as found: SEALED", bool(unit.call("sealed")))
	_check("as found: CHARGED", bool(unit.call("charged")))
	_check("as found: THE CAP WILL NOT LIFT",
			not bool(unit.call("will_lift")))
	_check("as found: NOT USABLE", not bool(unit.call("usable")))
	_check("as found: exactly one fault, and it is the loose cap",
			unit.call("faults") == ["loose_cap_free"])
	_check("it answers a look", unit.has_method("interact_prompt")
			and not str(unit.call("interact_prompt")).is_empty())
	_drop(unit)


func _the_non_implication() -> void:
	var unit := _unit()
	# The three predicates are three, and the third reads exactly one fact.
	_check("two seal terms", (ExtinguisherScript.SEAL_TERMS as Array).size() == 2)
	_check("two charge terms",
			(ExtinguisherScript.CHARGE_TERMS as Array).size() == 2)
	_check("one lift term", (ExtinguisherScript.LIFT_TERMS as Array).size() == 1)
	for term in ["cap_on", "seal_wired"]:
		_check("%s is a seal term" % term,
				term in ExtinguisherScript.SEAL_TERMS)
		_check("%s is NOT a lift term" % term,
				term not in ExtinguisherScript.LIFT_TERMS)
	for term in ["acid_present", "bottle_seated"]:
		_check("%s is a charge term" % term,
				term in ExtinguisherScript.CHARGE_TERMS)
		_check("%s is NOT a lift term" % term,
				term not in ExtinguisherScript.LIFT_TERMS)
	_check("loose_cap_free is in neither seal nor charge",
			"loose_cap_free" not in ExtinguisherScript.SEAL_TERMS
			and "loose_cap_free" not in ExtinguisherScript.CHARGE_TERMS)
	# And the predicate's own body, read out of the source, cannot have learned
	# about the seal or the charge behind our backs.
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/soda_acid_extinguisher_prop.gd")
	var body := source.substr(source.find("func will_lift() -> bool:"))
	body = body.substr(0, body.find("func usable"))
	for word in ["seal", "cap_on", "acid", "bottle", "charged", "sealed"]:
		_check("will_lift()'s body never mentions %s" % word, not body.contains(word))
	# The whole point, as an experiment: satisfy both visible predicates and it
	# is still not usable.
	_check("sealed AND charged, together", bool(unit.call("sealed"))
			and bool(unit.call("charged")))
	_check("...and NOT usable", not bool(unit.call("usable")))
	unit.set("loose_cap_free", true)
	_check("free that one cap and it is usable", bool(unit.call("usable")))
	_check("...with the seal and the charge exactly as they were",
			bool(unit.call("sealed")) and bool(unit.call("charged")))
	_drop(unit)


func _bottle_present_is_insufficient() -> void:
	var unit := _unit()
	# The bottle is there, seated, and full. Three separate facts, all true,
	# and the extinguisher is dead.
	_check("the bottle is seated", bool(unit.get("bottle_seated")))
	_check("the bottle has acid in it", bool(unit.get("acid_present")))
	_check("and it is not usable", not bool(unit.call("usable")))
	_check("and it will not be certified", not bool(unit.call("certifiable")))
	# Take the acid away and nothing about the fault changes: the acid was
	# never the reason.
	var lift_before: bool = bool(unit.call("will_lift"))
	unit.set("acid_present", false)
	_check("emptying the bottle does not change will_lift()",
			bool(unit.call("will_lift")) == lift_before)
	_check("but it does break charged()", not bool(unit.call("charged")))
	unit.set("acid_present", true)
	_drop(unit)


func _seal_intact_is_insufficient() -> void:
	var unit := _unit()
	_check("the seal is intact", bool(unit.call("sealed")))
	_check("and it is not usable", not bool(unit.call("usable")))
	_check("signing is refused under an intact seal",
			not bool(unit.call("sign_tag")))
	_check("no record was published", unit.call("last_record").is_empty())
	_check("the tag stayed blank",
			str(unit.call("tag_reads")) == ExtinguisherScript.TAG_BLANK)
	# And a seal cannot be reached past: the cap will not turn under wire.
	_check("the cap will not turn under the wire",
			not bool(unit.call("unscrew_cap")))
	_check("the refusal is the seal", str(unit.call("balk_focus")) == "seal")
	_check("the cap is still on", bool(unit.get("cap_on")))
	_drop(unit)


func _weight_is_insufficient() -> void:
	var broken := _unit()
	var sound := _unit()
	_make_it_work(sound)
	_check("the sound one is usable", bool(sound.call("usable")))
	_check("the broken one is not", not bool(broken.call("usable")))
	# THE SHARPEST CLAIM ON THE SHEET. This fault removes nothing, so the two
	# do not weigh ALMOST the same, they weigh the same float. Asserted as
	# equality rather than as a tolerance, on purpose.
	var broken_lb: float = float(broken.call("heft"))
	var sound_lb: float = float(sound.call("heft"))
	_check("a dead extinguisher and a sound one weigh the SAME (%.4f)"
			% broken_lb, broken_lb == sound_lb)
	_check("and that is the authored gross",
			broken_lb == ExtinguisherScript.GROSS_POUNDS)
	# heft() must not consult a single owned fact.
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/soda_acid_extinguisher_prop.gd")
	var body := source.substr(source.find("func heft_pounds() -> float:"))
	body = body.substr(0, body.find("func certifiable"))
	for word in ["loose_cap_free", "seal_wired", "cap_on", "acid_present",
			"bottle_seated", "if "]:
		_check("heft_pounds() never consults %s" % word,
				not body.contains(word))
	_check("hefting certifies nothing", not bool(broken.call("certifiable")))
	_check("hefting does not count as lifting the cap",
			not bool(broken.get("cap_tested")))
	_drop(broken)
	_drop(sound)


func _you_cannot_certify_a_cap_you_have_not_lifted() -> void:
	var unit := _unit()
	# Force the mechanism sound WITHOUT anybody having put a hand on it: the
	# state a careless inspection would leave behind.
	unit.set("loose_cap_free", true)
	_check("it is usable", bool(unit.call("usable")))
	_check("but nobody lifted the cap", not bool(unit.get("cap_tested")))
	_check("so it is not certifiable", not bool(unit.call("certifiable")))
	_check("and signing is refused", not bool(unit.call("sign_tag")))
	_check("the refusal points at the bottle nobody drew",
			str(unit.call("balk_focus")) == "bottle")
	# Do it by hand and it signs.
	unit.call("cut_seal")
	unit.call("unscrew_cap")
	unit.call("draw_bottle")
	unit.call("try_loose_cap")
	unit.call("seat_bottle")
	unit.call("screw_cap")
	unit.call("wire_seal")
	_check("having lifted it, it is certifiable",
			bool(unit.call("certifiable")))
	_check("and it signs", bool(unit.call("sign_tag")))
	_check("the tag now reads something else",
			str(unit.call("tag_reads")) != ExtinguisherScript.TAG_BLANK)
	_drop(unit)


func _there_is_no_test() -> void:
	var unit := _unit()
	_check("turning it over is refused as found",
			not bool(unit.call("invert")))
	_check("the refusal is the vessel on its hooks",
			str(unit.call("balk_focus")) == "invert")
	_make_it_work(unit)
	_check("a sound one refuses it too", not bool(unit.call("invert")))
	unit.call("sign_tag")
	_check("a signed tag does not unlock it", not bool(unit.call("invert")))
	# There is no discharge anywhere in the apparatus, and no invented
	# pressure to read.
	var source := _code()
	for word in ["discharge", "spray", "psi", "pressure_", "gauge", "empty_it",
			"fire_out", "suppress", "extinguish_fire", "water_level"]:
		_check("no %s anywhere in the apparatus" % word,
				not source.contains(word))
	_drop(unit)


func _order_is_the_metal() -> void:
	var unit := _unit()
	# Three ordering rules, and every one of them is something metal does.
	_check("the cap will not turn under a wired seal",
			not bool(unit.call("unscrew_cap")))
	_check("the bottle cannot be drawn through a shut cap",
			not bool(unit.call("draw_bottle")))
	_check("that refusal is the bottle", str(unit.call("balk_focus")) == "bottle")
	_check("the little cap cannot be reached in the cage",
			not bool(unit.call("try_loose_cap")))
	_check("cut the seal", bool(unit.call("cut_seal")))
	_check("now the cap turns", bool(unit.call("unscrew_cap")))
	_check("now the bottle draws", bool(unit.call("draw_bottle")))
	_check("and now a hand reaches the little cap -- and it will not come",
			not bool(unit.call("try_loose_cap")))
	_check("which is a refusal aimed at that cap",
			str(unit.call("balk_focus")) == "loose")
	_check("and it counts as having looked", bool(unit.get("cap_tested")))
	_check("work it free", bool(unit.call("free_loose_cap")))
	_check("the cap will lift now", bool(unit.call("will_lift")))
	_check("lifting it now succeeds", bool(unit.call("try_loose_cap")))
	# Beyond those three the order is the player's.
	var other := _unit()
	other.call("cut_seal")
	other.call("unscrew_cap")
	other.call("draw_bottle")
	_check("free order: free it without testing first",
			bool(other.call("free_loose_cap")))
	_check("free order: seat it", bool(other.call("seat_bottle")))
	_check("free order: cap", bool(other.call("screw_cap")))
	_check("free order: seal", bool(other.call("wire_seal")))
	_check("free order reaches the same tag", bool(other.call("sign_tag")))
	_check("and the same record",
			bool(other.call("last_record").get("usable", false)))
	_drop(unit)
	_drop(other)


func _reassembled_and_still_wrong() -> void:
	var unit := _unit()
	# A cage screws down as sweetly empty as full. This is a SECOND way for the
	# outside to look finished, discovered by the mechanism rather than
	# authored, and the apparatus does not pretend otherwise.
	unit.call("cut_seal")
	unit.call("unscrew_cap")
	unit.call("draw_bottle")
	unit.call("free_loose_cap")
	_check("the bottle is out on the shelf", bool(unit.get("bottle_drawn")))
	_check("screwing the cap down over an empty cage is permitted",
			bool(unit.call("screw_cap")))
	_check("and a fresh seal goes on it", bool(unit.call("wire_seal")))
	_check("it now LOOKS perfect", bool(unit.call("sealed")))
	_check("the one thing that must move now moves",
			bool(unit.call("will_lift")))
	_check("and it is still not charged", not bool(unit.call("charged")))
	_check("so it is still not usable", not bool(unit.call("usable")))
	_check("and the tag refuses", not bool(unit.call("sign_tag")))
	_check("pointing at the cage nothing is riding in",
			str(unit.call("balk_focus")) == "cage")
	_drop(unit)


func _refusals_are_different_photographs() -> void:
	var unit := _unit()
	var seen: Dictionary = {}
	# Walk every reason this apparatus has for saying no, and collect the piece
	# of metal each one aims at. A refusal that always looks the same teaches
	# nothing, so these have to be six.
	unit.call("sign_tag")                      # never drawn, never lifted
	seen[str(unit.call("balk_focus"))] = true
	unit.call("cut_seal")
	unit.call("unscrew_cap")
	unit.call("sign_tag")                      # the cap is off
	seen[str(unit.call("balk_focus"))] = true
	unit.call("draw_bottle")
	unit.call("try_loose_cap")                 # THE diagnosis
	seen[str(unit.call("balk_focus"))] = true
	unit.call("screw_cap")                     # ... over an empty cage
	unit.call("wire_seal")
	unit.call("sign_tag")                      # nothing is riding in the cage
	seen[str(unit.call("balk_focus"))] = true
	unit.call("cut_seal")
	unit.call("unscrew_cap")
	unit.call("seat_bottle")
	unit.call("screw_cap")
	unit.call("sign_tag")                      # the seal is not wired
	seen[str(unit.call("balk_focus"))] = true
	unit.call("invert")
	seen[str(unit.call("balk_focus"))] = true
	_check("six different refusal poses (%d)" % seen.size(), seen.size() == 6)
	for focus in ["bottle", "cap", "loose", "cage", "seal", "invert"]:
		_check("a refusal aimed at the %s" % focus, seen.has(focus))
	# And two refusals inside one condition are two different pictures.
	var fresh := _unit()
	fresh.call("sign_tag")
	var first := str(fresh.call("balk_focus"))
	fresh.call("invert")
	var second := str(fresh.call("balk_focus"))
	_check("two refusals in the found state differ", first != second)
	_drop(unit)
	_drop(fresh)


func _abort() -> void:
	var unit := _unit()
	var found: Dictionary = unit.call("maintenance_snapshot")
	_check("the snapshot names every owned fact", found.size() == 9)
	_make_it_work(unit)
	var published: Array = []
	var sink := func(record: Dictionary) -> void:
		published.append(record)
	unit.connect("extinguisher_inspected", sink)
	_check("the tag signs", bool(unit.call("sign_tag")))
	_check("one fact was published", published.size() == 1)
	unit.call("restore_maintenance_snapshot", found)
	for key in found.keys():
		_check("abort restores %s" % key, unit.get(key) == found[key])
	_check("abort puts the fault back", not bool(unit.call("usable")))
	_check("abort re-seals it", bool(unit.call("sealed")))
	_check("abort forgets that anybody lifted the cap",
			not bool(unit.get("cap_tested")))
	_check("abort clears the balk", not bool(unit.call("balking")))
	_check("abort CANNOT retract what was published", published.size() == 1)
	_check("and the published fact still says it was usable",
			bool(published[0].get("usable", false)))
	_drop(unit)


# --- it owns nothing else ----------------------------------------------------

## The documentation is allowed to DISCUSS a checklist, an interval or a
## discharge in order to say the apparatus has none. The CODE is not allowed to
## contain one, so every word scan below starts at the first line of code.
func _code() -> String:
	var source := FileAccess.get_file_as_string(
			"res://scripts/props/soda_acid_extinguisher_prop.gd")
	return source.substr(source.find("signal extinguisher_inspected"))


func _it_owns_nothing_else() -> void:
	var source := _code()
	for owner_name in ["WorkOrders", "RealityCases", "RealityState",
			"MaintenanceInventory", "MaintenanceActivityLibrary",
			"FirstShiftDirector", "CoreLoopDirector", "ObjectiveTracker",
			"ScheduleDirector", "SwitchSystem", "WatchStationNetwork",
			"issue_job", "close_job", "acknowledge_job", "activate_case",
			"leaf_state", "dream", "maintenance_items"]:
		_check("the apparatus never reaches %s" % owner_name,
				not source.contains(owner_name))
	for word in ["required", "must_visit", "checklist", "objective",
			"completion", "waypoint", "onboarding", "due_", "overdue",
			"interval", "next_inspection"]:
		_check("the apparatus declares no %s" % word, not source.contains(word))
	# The record says what a hand at this bracket can establish and no more.
	var unit := _unit()
	_make_it_work(unit)
	unit.call("sign_tag")
	var record: Dictionary = unit.call("last_record")
	_check("the record has exactly the authored fields",
			record.keys().size() == ExtinguisherScript.RECORD_FIELDS.size())
	for field in ExtinguisherScript.RECORD_FIELDS:
		_check("the record carries %s" % field, record.has(field))
	for absent in ["who", "by", "watchman", "case_id", "job_id", "order_id",
			"due", "next_due", "interval", "route", "complete", "pressure",
			"discharged", "fire"]:
		_check("the record does not claim %s" % absent, not record.has(absent))
	# It writes down that it was sealed and charged AND that it is usable —
	# the whole argument in one row.
	_check("the record records the seal", bool(record.get("sealed")))
	_check("the record records the charge", bool(record.get("charged")))
	_check("the record records usability", bool(record.get("usable")))
	_drop(unit)


func _sr7n_is_a_control_not_a_foundation() -> void:
	# SR7-O must not lean on SR7-N. Read its file — non-mutatively — and prove
	# there is no shared owner, predicate, signal or record between them.
	var mine := _code()
	var theirs := FileAccess.get_file_as_string(FIRE_LINE_PATH)
	_check("SR7-N's file is still there to read", theirs.length() > 1000)
	for symbol in ["FireLineCabinetProp", "fire_line_cabinet_prop",
			"line_inspected", "line_made_up", "gasket", "coupling",
			"hose_racked", "folds_fresh"]:
		_check("SR7-O never references SR7-N's %s" % symbol,
				not mine.contains(symbol))
	for symbol in ["SodaAcidExtinguisherProp", "extinguisher_inspected",
			"loose_cap_free", "soda_acid"]:
		_check("SR7-N never references SR7-O's %s" % symbol,
				not theirs.contains(symbol))
	# The two signals are different names carrying different vocabularies.
	_check("the two records share no field but the station and the hour",
			ExtinguisherScript.RECORD_FIELDS.has("station_id")
			and ExtinguisherScript.RECORD_FIELDS.has("at_minute")
			and not ExtinguisherScript.RECORD_FIELDS.has("line_made_up"))
