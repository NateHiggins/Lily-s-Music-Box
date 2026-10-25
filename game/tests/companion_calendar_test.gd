extends Node
## INERT domain diagnostic, not typing/world/save qualification.
const Conversation = preload("res://scripts/device/companion_conversation.gd")
const Witness = preload("res://scripts/device/companion_calendar_context.gd")
const Weather = preload("res://scripts/game/campaign_weather.gd")
const Service = preload("res://scripts/building/live_weather_service.gd")
var checks: Array[Dictionary] = []

func check(ok: bool, label: String) -> void:
	checks.append({"name":label, "passed":ok})
	if not ok: push_error(label)

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):
		driver.set_frozen_for_tests(true)
	var clock := CampaignClock.new()
	var catalog := NewspaperCatalog.new()
	add_child(catalog)
	var dialogue := Conversation.new()
	clock.configure_date(1928, 11, 10, 359)
	var conditions := Service.presentation(Weather.snapshot(clock.local_datetime()))
	var selection := {"paper":"record", "date":"1928-11-10"}
	var base := {"objective":"Keep this exact instruction.", "inventory":["Spanner"]}
	var original := base.duplicate(true)
	var before := Witness.enrich(base, clock, "campaign-calendar", conditions, catalog, selection)
	check(not before.has("newspaper_report"), "morning page withheld at 05:59")
	check(not str(before.get("weather_report", "")).contains("Forecast:"), "unissued first forecast is withheld")
	clock.configure_date(1928, 11, 10, 360)
	var morning := Witness.enrich(base, clock, "campaign-calendar", conditions, catalog, selection)
	check(str(morning.get("newspaper_report", "")).contains("Count of Tuesday"), "published selected morning headline is supplied verbatim")
	check(str(morning.get("newspaper_comment_id", "")) == "news_comment_votes", "dated lead selects an opinion about counting")
	check(str(morning.get("weather_report", "")).contains("Forecast:") and base == original, "issued forecast included without changing base context")
	check(dialogue.respond_calendar("help", base, clock, "campaign-calendar", conditions, catalog, selection).text == base.objective, "calendar entry point preserves work authority")
	check(dialogue.respond_calendar("newspaper", base, clock, "campaign-calendar", conditions, catalog, selection).text.contains("second tally"), "calendar entry point integrates authored news commentary")
	selection.paper = "speaker"
	check(not Witness.enrich(base, clock, "campaign-calendar", conditions, catalog, selection).has("newspaper_report"), "evening paper withheld at 06:00")
	clock.configure_date(1928, 11, 10, 1020)
	check(str(Witness.enrich(base, clock, "campaign-calendar", conditions, catalog, selection).get("newspaper_report", "")).contains("Hoover wins"), "evening paper appears at 17:00")
	selection.date = "1928-11-11"
	check(not Witness.enrich(base, clock, "campaign-calendar", conditions, catalog, selection).has("newspaper_report"), "future issue never leaks through archive access")
	selection = {"paper":"record", "date":"1928-11-10"}
	clock.configure_date(1928, 11, 11, 0)
	var yesterday := Witness.enrich(base, clock, "campaign-calendar", conditions, catalog, selection)
	check(str(yesterday.get("newspaper_comment_id", "")) == "news_comment_old" and str(yesterday.get("newspaper_report", "")).contains("10 November 1928"), "old paper keeps its own date and historical framing")
	var stale := morning.duplicate(true)
	var override := Witness.enrich(stale, clock, "open-meteo", conditions)
	check(not override.has("weather_report") and not override.has("newspaper_report"), "override and absent active page clear stale dated witnesses")
	clock.configure_date(1929, 11, 10, 720)
	check(not Witness.enrich(base, clock, "campaign-calendar", conditions).has("weather_report"), "authored year does not repeat")
	check(Witness.weather_comment({"month":7}, {"snow_intensity":1.0}) == "weather_comment_snow", "observed condition outranks seasonal expectation")
	check(Witness.news_comment("record", {"headline":"Office opens"}) == "news_comment_record", "ice topic does not match inside office")
	var failures := 0
	for record: Dictionary in checks:
		if not record.passed: failures += 1
	var out := OS.get_environment("SHOT_DIR")
	if out.is_empty(): out = "user://tests/companion_calendar"
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("companion_calendar_diagnostic.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"evidence_class":"INERT", "checks":checks, "failures":failures}, "\t"))
	catalog.queue_free()
	get_tree().quit(0 if failures == 0 else 1)
