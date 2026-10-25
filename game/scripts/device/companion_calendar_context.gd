extends RefCounted
## Read-only witness adapter. Call on a deliberate conversation/read action,
## with the existing campaign clock, current WeatherManager source/conditions,
## and the exact newspaper the player is currently reading. Never call collect().
const Intent = preload("res://scripts/device/companion_intent.gd")
const Weather = preload("res://scripts/game/campaign_weather.gd")

static func enrich(base: Dictionary, clock: CampaignClock, source: String,
		conditions: Dictionary, catalog: NewspaperCatalog = null, read_issue: Dictionary = {}) -> Dictionary:
	var result := base.duplicate(true)
	# Do not carry yesterday's witness over a date/override change.
	for field: String in ["weather_report", "weather_comment_id", "newspaper_report", "newspaper_comment_id"]:
		result.erase(field)
	if clock == null: return result
	var date := clock.local_datetime()
	if date.is_empty(): return result
	var key := Weather.date_key(date)
	var as_of := "%sT%02d:%02d" % [key, int(date.get("hour", 0)), int(date.get("minute", 0))]
	if source == "campaign-calendar" and not conditions.is_empty() and not Weather.day(key).is_empty():
		var report := Weather.report_at(as_of)
		var issued := Weather.timeline(as_of, 1)
		if not issued.is_empty():
			var bulletin: Dictionary = issued[0]
			report += "\nIssued " + Weather.print_time(str(bulletin.issued_at)) + " E.S.T.\nForecast: " + str(bulletin.prediction)
			report += "\nValid " + Weather.print_time(str(bulletin.valid_from)) + " to " + Weather.print_time(str(bulletin.valid_until)) + " E.S.T."
			if not str(bulletin.get("revision", "")).is_empty(): report += "\nCorrection: " + str(bulletin.revision)
		result.weather_report = report
		result.weather_comment_id = weather_comment(date, conditions)
	# A dated query alone is not evidence the player read a paper.
	# The caller supplies this selection only from the active reading owner.
	if catalog == null or read_issue.is_empty(): return result
	var paper := str(read_issue.get("paper", ""))
	var issue_date := str(read_issue.get("date", ""))
	if paper not in ["record", "speaker"] or not catalog.published_now(paper, issue_date): return result
	var page := catalog.issue(paper, issue_date)
	if page.is_empty(): return result
	var lead: Dictionary = page.get("lead", {})
	if str(lead.get("headline", "")).is_empty(): return result
	result.newspaper_report = str(catalog.paper(paper).get("name", paper)) + " / " + catalog.long_date(issue_date) + "\n" + str(lead.headline) + "\n" + str(lead.get("deck", ""))
	result.newspaper_comment_id = news_comment(paper, lead) if issue_date == key else "news_comment_old"
	return result

static func weather_comment(date: Dictionary, conditions: Dictionary) -> String:
	# Describe the supplied current conditions, never the day's later maximum.
	if float(conditions.get("snow_intensity", 0)) > .1: return "weather_comment_snow"
	if int(conditions.get("weather_code", 0)) in [95, 96, 99]: return "weather_comment_storm"
	if float(conditions.get("rain_intensity", 0)) > .05: return "weather_comment_wet"
	if bool(conditions.get("foggy", false)): return "weather_comment_fog"
	if float(conditions.get("temperature_c", 12)) >= 29: return "weather_comment_heat"
	if float(conditions.get("temperature_c", 12)) < 5: return "weather_comment_cold"
	var months := ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
	var month := int(date.get("month", 0))
	return "weather_comment_" + str(months[month - 1]) if month >= 1 and month <= 12 else "weather_comment_fair"

static func news_comment(paper: String, lead: Dictionary) -> String:
	# These are opinions about a published lead, never extra plot facts.
	var headline := str(lead.get("headline", "")).to_lower()
	var topics := {
		"pruitt":"pruitt", "clerk takes the stand":"pruitt",
		"silence":"silence", "dead air":"silence",
		"listening act":"listening", "senator puts the walls":"listening",
		"committee":"committee", "hearing":"committee",
		"vote":"votes", "count":"votes", "hoover":"votes", "riverhead":"votes",
		"byrd":"byrd", "ice":"ice", "coal":"coal", "heat":"heat", "rent":"rent"
	}
	for phrase: String in topics:
		if Intent.contains_phrase(Intent.normalize(headline), phrase): return "news_comment_" + str(topics[phrase])
	return "news_comment_" + paper
