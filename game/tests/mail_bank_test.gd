extends Node
## The mail bank as a system: deliveries gate on campaign state, the 4B
## door opens and closes, taking mail records it, and packages carry
## upgrades into RealityState.data.

var failures := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	var bank := MailBankProp.new()
	add_child(bank)
	await get_tree().process_frame

	_check(bank.pending().size() == 2, "day one: two always-deliveries wait")
	_check("2 waiting" in bank.interact_prompt(),
			"the closed door counts its mail")
	bank.interact(null)
	_check(bank.door_open, "interacting opens the 4B door")
	bank._panel.choose(0)  # take the welcome note
	bank._panel.choose(0)  # take the hum notice, offered immediately after
	_check(bank.pending().is_empty(), "both letters taken")
	_check(RealityState.data.get("mail_taken", []).size() == 2,
			"taken ids are recorded against the campaign")
	_check(not bank.door_open, "the door closes itself after the last item")

	# The contact mic ships only after the case's first practical repair.
	RealityCases.activate_case("mina_caption_crisis")
	_check(bank.pending().is_empty(), "no package before the first repair")
	RealityCases.stabilize_case("mina_caption_crisis")
	_check(bank.pending().size() == 1,
			"the contact mic ships after repair one")
	bank.interact(null)
	bank._panel.choose(0)
	_check("contact_mic" in RealityState.data.get("upgrades", []),
			"taking the package grants the upgrade")
	_check(not bank.door_open, "door closed again")

	# Mina's parcel posts on resolution, and leaving mail keeps it waiting.
	var state := RealityState.case_state("mina_caption_crisis")
	state.stage = "resolved"
	state.resolved = true
	_check(bank.pending().size() == 1, "resolution posts Mina's parcel")
	bank.interact(null)
	bank._panel.choose(1)  # leave it for now
	_check(bank.pending().size() == 1, "left mail stays in the box")
	_check(bank.door_open, "the door stays open while mail waits")
	bank.interact(null)
	bank._panel.choose(0)
	_check(bank.pending().is_empty(), "the parcel can be taken later")
	_check(RealityState.data.get("upgrades", []) == ["contact_mic"],
			"a keepsake parcel grants nothing mechanical")

	print("MAIL BANK TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [mail ok] ", label)
	else:
		failures += 1
		printerr("  [MAIL FAIL] ", label)
