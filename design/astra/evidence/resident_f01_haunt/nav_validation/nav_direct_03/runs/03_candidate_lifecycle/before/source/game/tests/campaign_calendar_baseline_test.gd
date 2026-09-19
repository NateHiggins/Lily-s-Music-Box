extends Node


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var clock := CampaignClock.new()
	clock.bind_state()
	var actual := str(RealityState.data.campaign_clock.get("epoch_date", ""))
	var passed := actual == "1928-11-10" and clock.start_weekday() == "sat"
	print("CAMPAIGN AUTHORED EPOCH: %s actual=%s weekday=%s" % [
			"PASS" if passed else "FAIL", actual, clock.start_weekday()])
	get_tree().quit(0 if passed else 1)
