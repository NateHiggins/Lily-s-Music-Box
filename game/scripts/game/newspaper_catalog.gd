class_name NewspaperCatalog
extends Node
## The two daily papers (design/ORISON_NEWSPAPERS_2026-10-23.md): a year of
## front pages, loaded by literal path, read by date from the campaign clock,
## collected on the campaign document.
##
## The Record and the Speaker are paper. Nothing here carries a signal: the
## catalogue answers what is on the rack today and what the player has kept.

const PAPERS_PATH := "res://data/newspapers/papers.json"
## Literal paths, not a directory scan, so the reader gate can see which file
## each field read belongs to. First and second halves of each month.
const SLICE_PATHS: Array[String] = [
	"res://data/newspapers/1928-11a.json",
	"res://data/newspapers/1928-11b.json",
	"res://data/newspapers/1928-12a.json",
	"res://data/newspapers/1928-12b.json",
	"res://data/newspapers/1929-01a.json",
	"res://data/newspapers/1929-01b.json",
	"res://data/newspapers/1929-02a.json",
	"res://data/newspapers/1929-02b.json",
	"res://data/newspapers/1929-03a.json",
	"res://data/newspapers/1929-03b.json",
	"res://data/newspapers/1929-04a.json",
	"res://data/newspapers/1929-04b.json",
	"res://data/newspapers/1929-05a.json",
	"res://data/newspapers/1929-05b.json",
	"res://data/newspapers/1929-06a.json",
	"res://data/newspapers/1929-06b.json",
	"res://data/newspapers/1929-07a.json",
	"res://data/newspapers/1929-07b.json",
	"res://data/newspapers/1929-08a.json",
	"res://data/newspapers/1929-08b.json",
	"res://data/newspapers/1929-09a.json",
	"res://data/newspapers/1929-09b.json",
	"res://data/newspapers/1929-10a.json",
	"res://data/newspapers/1929-10b.json",
	"res://data/newspapers/1929-11a.json",
]
const ADS_PATH := "res://data/newspapers/advertisements.json"
const CARTOONS_PATH := "res://data/newspapers/cartoons.json"
## How many boxed advertisements the back of the sheet carries.
const ADS_PER_PAGE := 6
## How six advertisements fill a page; the panel lays them out in this order.
const AD_PLANS := [["T", "S", "S", "W", "W", "S"], ["W", "S", "T", "S", "S", "W"], ["S", "S", "S", "W", "S", "B"]]
const PAPER_IDS: Array[String] = ["record", "speaker"]
## The back page, where an issue has one: what each paper runs behind its front.
const BACK_COLUMNS := 4
const BACK_KINDS := {
	"record": ["news", "notices", "sport", "weather", "markets", "classified"],
	"speaker": ["news", "sport", "pun_derby", "ask_operator", "listening_lady", "classified"],
}
const FIRST_DATE := "1928-11-10"
const LAST_DATE := "1929-11-09"
## The rack keeps a few days; older issues are gone with the ice men.
const RACK_DAYS := 4
const MONTH_NAMES := ["January", "February", "March", "April", "May", "June", "July",
		"August", "September", "October", "November", "December"]
const STATE_KEY := "newspapers_collected"
## The sky the papers noticed: phenomena.json press lines, printed the next morning.
const SkyPhenomena := preload("res://scripts/building/sky_phenomena.gd")

var papers: Dictionary = {}
var issues: Dictionary = {}   # "YYYY-MM-DD" -> issue dictionary (record, speaker, weekday)
var dates: Array[String] = []
var errors: Array[String] = []
var _ads: Array[Dictionary] = []
var _firms: Dictionary = {}  # firm name -> identity and contact lines
var _cartoons: Dictionary = {}  # "YYYY-MM-DD" -> the Speaker's weekly cartoon
var _clock: CampaignClock
var _sky := SkyPhenomena.new()


func _ready() -> void:
	add_to_group("newspaper_catalog")
	if issues.is_empty():
		load_all()


func load_all() -> void:
	errors.clear()
	_load_papers()
	_load_slices()
	_load_advertising()
	if not _sky.load_schedule():
		for problem in _sky.errors: errors.append("sky phenomena: %s" % problem)


## --- reading ----------------------------------------------------------------

func paper(paper_id: String) -> Dictionary:
	return papers.get(paper_id, {})


## The advertisements on the back of this paper's sheet today. The advertisers
## buy space by the season, so the same day always carries the same boxes.
func ads_for(paper_id: String, date: String) -> Array[Dictionary]:
	var chosen: Array[Dictionary] = []
	var seed_value := absi(hash(date + paper_id))
	var pools := {}
	for ad in _ads:
		if str(ad.paper) == paper_id or str(ad.paper) == "both":
			if not pools.has(ad.size):
				pools[ad.size] = []
			pools[ad.size].append(ad)
	var used := {}
	for size: String in AD_PLANS[ad_plan_for(paper_id, date)]:
		var pool: Array = pools.get(size, [])
		if pool.is_empty():
			continue
		chosen.append(pool[(seed_value + int(used.get(size, 0))) % pool.size()])
		used[size] = int(used.get(size, 0)) + 1
	return chosen


## The firm an advertisement names: who it is and how to reach it.
func firm_for(ad: Dictionary) -> Dictionary:
	return _firms.get(str(ad.get("firm", "")), {})


## Which of AD_PLANS shapes this page's advertising.
func ad_plan_for(paper_id: String, date: String) -> int:
	return absi(hash(date + paper_id)) % AD_PLANS.size()


## The weekly cartoon, where this issue has one: {image, caption}.
func cartoon_for(paper_id: String, date: String) -> Dictionary:
	if paper_id != "speaker":
		return {}
	return _cartoons.get(date, {})


func has_issue(date: String) -> bool:
	return issues.has(date)


func issue(paper_id: String, date: String) -> Dictionary:
	var page: Dictionary = issues.get(date, {}).get(paper_id, {}).duplicate(true)
	if not page.is_empty():
		var report := CampaignWeather.press_report(date,paper_id)
		if not report.is_empty(): page["weather_report"] = report
	return page


func weekday(date: String) -> String:
	return str(issues.get(date, {}).get("weekday", ""))


## "Saturday 10 November 1928", from the issue's own weekday.
func long_date(date: String) -> String:
	var parts := date.split("-")
	if parts.size() != 3:
		return date
	var month := clampi(int(parts[1]) - 1, 0, 11)
	return "%s %d %s %s" % [weekday(date), int(parts[2]), MONTH_NAMES[month], parts[0]]


func short_date(date: String) -> String:
	var parts := date.split("-")
	if parts.size() != 3:
		return date
	var month := clampi(int(parts[1]) - 1, 0, 11)
	return "%s %d %s" % [weekday(date).left(3), int(parts[2]), MONTH_NAMES[month].left(3)]


## Today's date on the campaign clock, as the papers print it. Empty when the
## clock is not bound (a bare test) or the year of papers has run out.
func today() -> String:
	if _clock == null:
		_clock = CampaignClock.new()
	if not _clock.bind_state():
		return ""
	var local := _clock.local_datetime()
	if local.is_empty():
		return ""
	var date := "%04d-%02d-%02d" % [int(local.year), int(local.month), int(local.day)]
	return date if issues.has(date) else ""


## The dates on the rack: today and the few days before it that were printed.
func on_sale(date := "") -> Array[String]:
	var anchor := date if date != "" else today()
	var out: Array[String] = []
	if anchor == "" or not issues.has(anchor):
		return out
	var index := dates.find(anchor)
	for i in range(index, maxi(-1, index - RACK_DAYS), -1):
		out.append(dates[i])
	return out


## Production rack gate; archive/authoring access remains a pure dated query.
func published_now(paper_id: String, date: String) -> bool:
	if not papers.has(paper_id) or not issues.has(date): return false
	if _clock==null: _clock=CampaignClock.new()
	var local:=_clock.local_datetime()
	if local.is_empty(): return false
	var current_date:=CampaignWeather.date_key(local)
	if date!=current_date: return date<current_date
	return int(local.hour)*60+int(local.minute)>=(360 if paper_id=="record" else 1020)
## What the sky did yesterday, as this issue reports it: {headline, record, speaker}.
func sky_notices(date: String) -> Array[Dictionary]:
	return _sky.press_for_issue(date)


## --- the collection ----------------------------------------------------------

static func key_of(paper_id: String, date: String) -> String:
	return "%s:%s" % [paper_id, date]


func is_collected(paper_id: String, date: String) -> bool:
	return key_of(paper_id, date) in (RealityState.data.get(STATE_KEY, []) as Array)


## Keep a paper. True when it is new to the shelf.
func collect(paper_id: String, date: String) -> bool:
	if not papers.has(paper_id) or not issues.has(date):
		return false
	if not RealityState.data.has(STATE_KEY) or RealityState.data[STATE_KEY] is not Array:
		RealityState.data[STATE_KEY] = []
	var key := key_of(paper_id, date)
	if key in RealityState.data[STATE_KEY]:
		return false
	RealityState.data[STATE_KEY].append(key)
	RealityState.commit()
	return true


## Every kept paper as {"paper": id, "date": date}, newest first.
func collected() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in (RealityState.data.get(STATE_KEY, []) as Array):
		var parts := str(key).split(":")
		if parts.size() == 2 and papers.has(parts[0]) and issues.has(parts[1]):
			out.append({"paper": parts[0], "date": parts[1]})
	out.sort_custom(func(a, b):
		return a.date > b.date if a.date != b.date else a.paper < b.paper)
	return out


## --- loading ---------------------------------------------------------------

func _load_papers() -> void:
	papers.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PAPERS_PATH))
	if parsed is not Dictionary or parsed.get("papers") is not Dictionary:
		errors.append("papers.json unreadable")
		return
	for paper_id in parsed.papers:
		var record: Dictionary = parsed.papers[paper_id]
		for field in ["name", "masthead_line", "edition", "price", "ink"]:
			if str(record.get(field, "")) == "":
				errors.append("papers.json: %s.%s is empty" % [paper_id, field])
		var chair: Variant = record.get("editorial", null)
		if chair != null and (chair is not Dictionary or str(chair.get("title", "")) == ""
				or str(chair.get("byline", "")) == ""):
			errors.append("papers.json: %s.editorial needs a title and byline" % paper_id)
		papers[str(paper_id)] = record
	for paper_id in PAPER_IDS:
		if not papers.has(paper_id):
			errors.append("papers.json names no %s" % paper_id)


func _load_slices() -> void:
	issues.clear()
	dates.clear()
	for path in SLICE_PATHS:
		if not FileAccess.file_exists(path):
			errors.append("newspaper slice missing: %s" % path)
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is not Dictionary or parsed.get("issues") is not Array:
			errors.append("newspaper slice unreadable: %s" % path)
			continue
		for entry in parsed.issues:
			if entry is not Dictionary:
				continue
			var date := str(entry.get("date", ""))
			if date == "" or str(entry.get("weekday", "")) == "":
				errors.append("%s: an issue has no date or weekday" % path)
				continue
			if issues.has(date):
				errors.append("%s: %s printed twice" % [path, date])
				continue
			var ok := true
			for paper_id in PAPER_IDS:
				var where := "%s %s %s" % [path, date, paper_id]
				if not _valid_page(entry.get(paper_id, null), where):
					ok = false
				elif not _valid_back(entry[paper_id].get("back", null), paper_id, where):
					ok = false
			if ok:
				issues[date] = entry
	dates.assign(issues.keys())
	dates.sort()


func _load_advertising() -> void:
	_ads.clear()
	_cartoons.clear()
	_firms.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADS_PATH))
	if parsed is not Dictionary or parsed.get("ads") is not Array or parsed.get("firms") is not Dictionary:
		errors.append("advertisements unreadable: %s" % ADS_PATH)
	else:
		_firms = parsed.firms
		for firm_name in _firms:
			for field in ["mark", "mark_shape", "id_line", "address", "telephone", "hours", "slogan"]:
				if _firms[firm_name] is not Dictionary or not _firms[firm_name].has(field):
					errors.append("%s: firm %s has no %s" % [ADS_PATH, firm_name, field])
		for ad in parsed.ads:
			if ad is Dictionary and ad.has("order") and str(ad.order) == "":
				errors.append("%s: %s has an empty order" % [ADS_PATH, ad.get("headline", "")])
			if ad is Dictionary and ((ad.has("items") and ad.items is not Array)
					or (ad.has("offer") and str(ad.offer) == "") or (ad.has("signed") and str(ad.signed) == "")):
				errors.append("%s: %s has a malformed items, offer or signed" % [ADS_PATH, ad.get("headline", "")])
			if ad is not Dictionary or not _firms.has(str(ad.get("firm", ""))) \
					or str(ad.get("headline", "")) == "" or str(ad.get("body", "")) == "" \
					or str(ad.get("paper", "")) not in ["record", "speaker", "both"] \
					or not NewspaperAd.has_style(str(ad.get("style", ""))) \
					or str(ad.get("size", "")) not in ["S", "W", "T", "B"] \
					or not ResourceLoader.exists(str(ad.get("image", ""))):
				errors.append("%s: an advertisement needs a known firm, style and size, headline, body, paper and an image that exists" % ADS_PATH)
				continue
			_ads.append(ad)
	parsed = JSON.parse_string(FileAccess.get_file_as_string(CARTOONS_PATH))
	if parsed is not Dictionary or parsed.get("cartoons") is not Array:
		errors.append("cartoons unreadable: %s" % CARTOONS_PATH)
		return
	for cartoon in parsed.cartoons:
		if cartoon is not Dictionary or str(cartoon.get("date", "")) == "" \
				or str(cartoon.get("caption", "")) == "" or not ResourceLoader.exists(str(cartoon.get("image", ""))):
			errors.append("%s: a cartoon needs date, caption and an image that exists" % CARTOONS_PATH)
			continue
		_cartoons[str(cartoon.date)] = cartoon


## An issue's optional back page: four typed columns and a one-line foot.
## Absent is ordinary; present and malformed is a startup message.
func _valid_back(back: Variant, paper_id: String, where: String) -> bool:
	if back == null:
		return true
	if back is not Dictionary:
		errors.append("%s: back page is not an object" % where)
		return false
	var ok := true
	var columns: Variant = back.get("columns", null)
	if columns is not Array or columns.size() != BACK_COLUMNS:
		errors.append("%s: back page wants %d columns" % [where, BACK_COLUMNS])
		ok = false
	else:
		for column in columns:
			if column is not Dictionary or str(column.get("headline", "")) == "" \
					or str(column.get("body", "")) == "":
				errors.append("%s: a back-page column needs headline and body" % where)
				ok = false
			elif str(column.get("kind", "")) not in BACK_KINDS[paper_id]:
				errors.append("%s: no back-page column kind %s" % [where, column.get("kind", "")])
				ok = false
	var foot := str(back.get("foot", ""))
	if foot == "" or "\n" in foot:
		errors.append("%s: back-page foot must be one line" % where)
		ok = false
	return ok


## The authored front page, checked at load so a broken file is a startup
## message and not a blank rack. Every field the panel prints is named here.
func _valid_page(page: Variant, where: String) -> bool:
	if page is not Dictionary:
		errors.append("%s: no front page" % where)
		return false
	var ok := true
	if str(page.get("ear", "")) == "":
		errors.append("%s: ear is empty" % where)
		ok = false
	var lead: Variant = page.get("lead", null)
	if lead is not Dictionary or str(lead.get("headline", "")) == "" \
			or str(lead.get("deck", "")) == "" or str(lead.get("body", "")) == "":
		errors.append("%s: lead needs headline, deck and body" % where)
		ok = false
	var columns: Variant = page.get("columns", null)
	if columns is not Array or columns.size() != 3:
		errors.append("%s: three columns expected" % where)
		ok = false
	else:
		for column in columns:
			if column is not Dictionary or str(column.get("headline", "")) == "" \
					or str(column.get("body", "")) == "":
				errors.append("%s: a column needs headline and body" % where)
				ok = false
	if not str(page.get("wire", "")).begins_with("LATE WIRE:"):
		errors.append("%s: wire must begin LATE WIRE:" % where)
		ok = false
	# The Speaker's Saturday editorial (design/ORISON_LILITH_2026-10-24.md).
	var editorial: Variant = page.get("editorial", null)
	if editorial != null and (editorial is not Dictionary or str(editorial.get("headline", "")) == ""
			or str(editorial.get("body", "")) == ""):
		errors.append("%s: an editorial needs headline and body" % where)
		ok = false
	return ok
