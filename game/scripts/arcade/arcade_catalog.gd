class_name ArcadeCatalog
extends RefCounted
## The row, as the compiler last left it.
##
## `arcade_cabinets.json` is written by `tools/build_arcade.py` in the world
## compiler repository and copied here whole. Nothing in this project edits it:
## it is a build output, and the compiler is the only thing entitled to an
## opinion about what is on the row.
##
## The one field worth reading twice is `gameplay_identical`. The compiler sets
## it only after running `worldc invariance` across every package in the catalog
## and finding byte-identical gameplay - same colliders, same transforms, same
## waves, same weapon numbers. Twelve cabinets, twelve genres, one game.

const DIR := "res://assets/arcade"
const FILE := "arcade_cabinets.json"

var cabinets: Array[Dictionary] = []
var scene_id := ""
var scene_hash := ""
var gameplay_identical := false


static func load_catalog(directory := DIR) -> ArcadeCatalog:
	var path := directory.path_join(FILE)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ArcadeCatalog: no catalog at %s; the arcade will be empty" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ArcadeCatalog: %s is not a JSON object" % path)
		return null

	var document: Dictionary = parsed
	var catalog := ArcadeCatalog.new()
	catalog.scene_id = String(document.get("scene_id", ""))
	catalog.scene_hash = String(document.get("scene_hash", ""))
	catalog.gameplay_identical = bool(document.get("gameplay_identical", false))
	for entry in (document.get("cabinets", []) as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			catalog.cabinets.append(entry)

	if not catalog.gameplay_identical:
		# Worth saying out loud. If this is ever false the cabinets have stopped
		# being the same game, which is the only thing the arcade is about.
		push_warning(
			"ArcadeCatalog: %s does not certify identical gameplay across its cabinets"
			% path
		)
	return catalog


func by_id(cabinet_id: String) -> Dictionary:
	for cabinet in cabinets:
		if String(cabinet.get("cabinet_id", "")) == cabinet_id:
			return cabinet
	return {}


func size() -> int:
	return cabinets.size()


## The cabinet at `index`, wrapping. A row is laid out by walking the catalog, so
## an arcade with more slots than cabinets repeats rather than leaving gaps.
func at(index: int) -> Dictionary:
	if cabinets.is_empty():
		return {}
	return cabinets[posmod(index, cabinets.size())]


## The catalog reordered so that consecutive cabinets claim different genres.
##
## The catalog is sorted by id, which is right for a build output and wrong for a
## room: a bar with two machines in it took the first two entries and got two
## horror games standing side by side, which reads as one product line rather
## than as an industry. Walking genre-first spreads them, so a row of two is a
## sports title next to a flight sim and the joke is legible at any row size.
##
## Deterministic - no shuffling. The same catalog always lays out the same way.
func spread() -> Array[Dictionary]:
	var remaining := cabinets.duplicate()
	var ordered: Array[Dictionary] = []
	var used_genres: Dictionary = {}
	while not remaining.is_empty():
		var taken := -1
		for i in remaining.size():
			if not used_genres.has(String(remaining[i].get("claimed_genre", ""))):
				taken = i
				break
		if taken < 0:
			# Every genre is spoken for; start the cycle again.
			used_genres.clear()
			taken = 0
		used_genres[String(remaining[taken].get("claimed_genre", ""))] = true
		ordered.append(remaining[taken])
		remaining.remove_at(taken)
	return ordered
