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
const PAPER_IDS: Array[String] = ["record", "speaker"]
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
	if not _sky.load_schedule():
		for problem in _sky.errors: errors.append("sky phenomena: %s" % problem)


## --- reading ----------------------------------------------------------------

func paper(paper_id: String) -> Dictionary:
	return papers.get(paper_id, {})


func has_issue(date: String) -> bool:
	return issues.has(date)


func issue(paper_id: String, date: String) -> Dictionary:
	return issues.get(date, {}).get(paper_id, {})


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
				if not _valid_page(entry.get(paper_id, null), "%s %s %s" % [path, date, paper_id]):
					ok = false
			if ok:
				issues[date] = entry
	dates.assign(issues.keys())
	dates.sort()


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
