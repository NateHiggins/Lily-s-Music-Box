class_name PaperPocket
extends RefCounted
## The papers the player carries in the case, collected or bought (Lily, 2026-11-06): newspapers and LILITH comics
## from the stand, and the evidence folder's letters from box 4B and written finds from the clue carriers.
## (Formerly "the linen pocket".) LILITH's issues are game/data/comics.json, by Lily's rulings comic_in_game and
## comic_location: the stand sells it, and only the script, never the private art, is in this repository.
## It owns one thing, which newspapers ride in the pocket rather than lie on the
## 4B shelf. NewspaperCatalog stays the owner of which papers are kept at all, and
## the mail box of which letters were taken; letters are read from the mail
## catalogue, so a taken letter is always in the pocket and nothing is copied.
##
## The case carries exactly one newspaper (Lily, 2026-11-06): the paper bought at the stand rides in its transport
## slot until it is laid on the stack beside the 4B bookshelf by hand (NewsStackProp). NewspaperCatalog stays the
## collection authority: every kept paper is in its list, in transport or on the stack.

const KEY := "paper_pocket"
const MAIL_CATALOG := "res://data/mail_catalog.json"
const COMICS := "res://data/comics.json"

static var _letters: Array = []
static var _comics: Dictionary = {}


static func book() -> Dictionary:
	if not RealityState.data.has(KEY) or not valid(RealityState.data[KEY]):
		RealityState.data[KEY] = {"version": 1, "news": [], "comics": [], "evidence": []}
	for list: String in ["comics", "evidence"]:
		if not RealityState.data[KEY].has(list):
			RealityState.data[KEY][list] = []
	var news: Array = RealityState.data[KEY].news
	if news.size() > 1:
		# An older save carried several: the newest issue stays in transport, the others are on the stack already
		# (they are all in the kept list), so nothing is deleted or duplicated.
		var newest: Array = news.duplicate()
		newest.sort_custom(func(a, b): return str(a).split(":")[1] + str(a) > str(b).split(":")[1] + str(b))
		news.clear()
		news.append(newest[0])
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] \
			or float(value.version) != 1.0 or value.get("news") is not Array:
		return false
	for key: Variant in value.news:
		if key is not String or str(key).split(":").size() != 2:
			return false
	if value.has("comics"):
		if value.comics is not Array:
			return false
		for id: Variant in value.comics:
			if id is not String or issue(str(id)).is_empty():
				return false
	if value.has("evidence"):
		if value.evidence is not Array:
			return false
		for found: Variant in value.evidence:
			if found is not Dictionary or found.get("id") is not String or found.get("title") is not String or found.get("body") is not String:
				return false
	return true


## A written find kept in the evidence folder (a clue carrier's note), once. Uncommitted: the find commits it.
static func file_evidence(id: String, title: String, body: String) -> bool:
	if id == "" or body.strip_edges() == "" or book().evidence.any(func(found): return str(found.id) == id):
		return false
	book().evidence.append({"id": id, "title": title, "body": body})
	return true


## LILITH as the stand sells it (game/data/comics.json): the series and its issues.
static func comics() -> Dictionary:
	if _comics.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMICS))
		_comics = parsed if parsed is Dictionary and int(parsed.get("schema_version", 0)) == 1 and parsed.get("issues") is Array else {"issues": []}
	return _comics


## The stand's item that a comic is paid as.
static func comic_item() -> String:
	return str(comics().get("item", "lilith_comic"))


static func issue(id: String) -> Dictionary:
	for found: Variant in comics().issues:
		if found is Dictionary and str(found.get("id", "")) == id:
			return found
	return {}


## The issues on sale by a date (an issue stays on the rack after its Saturday), oldest first.
static func comics_on_sale(date: String) -> Array:
	return comics().issues.filter(func(found): return found is Dictionary and str(found.get("on_sale", "9999")) <= date)


static func has_comic(id: String) -> bool:
	return id in book().comics


## Uncommitted: the purchase commits it with the sale. A comic stays in the pocket; the shelf keeps newspapers only.
static func tuck_comic(id: String) -> bool:
	if issue(id).is_empty() or has_comic(id):
		return false
	book().comics.append(id)
	return true


## The paper in transport, as "<paper>:<date>", or "" when the slot is empty.
static func transit_news() -> String:
	var news: Array = book().news
	return str(news[0]) if not news.is_empty() else ""


static func has_room_for_news() -> bool:
	return book().news.is_empty()


## Uncommitted: the sale that keeps the paper commits both. Refused when the slot is full.
static func tuck_news(key: String) -> bool:
	if not has_room_for_news():
		return false
	book().news.append(key)
	return true


## The paper in transport laid on the apartment stack (NewsStackProp's deposit). True when one was there.
static func file_news() -> bool:
	var news: Array = book().news
	if news.is_empty():
		return false
	news.clear()
	RealityState.commit()
	return true


static func _mail_letters() -> Array:
	if _letters.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAIL_CATALOG))
		var deliveries: Array = parsed.get("deliveries", []) if parsed is Dictionary else []
		_letters = deliveries.filter(func(item): return item is Dictionary and str(item.get("kind", "")) == "letter")
	return _letters


## What the case holds, as {"kind", "title", ...}, each kind front first: comics ("comic", newest issue first,
## for the comics pocket), letters ("letter", latest taken first, for the evidence folder) and newspapers ("news",
## newest first, for the newspaper pocket). News carries "paper" and "date"; a letter or a comic carries "id",
## "heading" and "body" for the reader.
static func contents(catalog: NewspaperCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var held: Array = book().comics.duplicate()
	held.sort_custom(func(a, b): return int(issue(str(a)).get("number", 0)) > int(issue(str(b)).get("number", 0)))
	for id: Variant in held:
		var found := issue(str(id))
		out.append({"kind": "comic", "id": str(id), "number": int(found.get("number", 0)),
				"title": "No. %d: %s" % [int(found.get("number", 0)), str(found.get("title", ""))],
				"heading": str(comics().get("series", "")),
				"body": "%s.\nOn sale Saturday %s. Five cents." % [str(comics().get("tagline", "")), str(found.get("on_sale", ""))]})
	if catalog != null:
		var news: Array[Dictionary] = []
		for key: Variant in book().news:
			var parts := str(key).split(":")
			if catalog.is_collected(parts[0], parts[1]):
				news.append({"kind": "news", "paper": parts[0], "date": parts[1],
						"title": "%s, %s" % [str(catalog.paper(parts[0]).get("name", parts[0])), catalog.short_date(parts[1])]})
		news.sort_custom(func(a, b): return str(a.date) > str(b.date))
		out.append_array(news)
	var taken: Array = RealityState.data.get("mail_taken", [])
	var seen := {}
	for index in range(taken.size() - 1, -1, -1):
		if seen.has(str(taken[index])):
			continue
		seen[str(taken[index])] = true
		for letter: Dictionary in _mail_letters():
			if str(letter.get("id", "")) == str(taken[index]):
				out.append({"kind": "letter", "id": str(letter.id), "title": str(letter.get("title", "")),
						"heading": "BOX 4B — LETTER", "body": str(letter.get("body", ""))})
	# Written finds, the latest first, in the same folder.
	var finds: Array = book().evidence.duplicate()
	finds.reverse()
	for found: Variant in finds:
		out.append({"kind": "letter", "id": str(found.id), "title": str(found.title), "heading": "FOUND — KEPT AS EVIDENCE",
				"body": str(found.body)})
	return out
