extends Node
## The loud test the punchlist asks for: "wall art misplacement family -
## full placement audit + a loud test".
##
## It drives the REAL WallArtLaw over every room in the building and then
## judges what the law accepted, using geometry read from the layout and from
## the builder rather than from the law's own constants. That independence is
## the point. The blinds blocker survived a previous fix because the
## verification measured the axis that had just been repaired; a wall-art test
## that asserted `RAIL_TOP` against `RAIL_TOP` would fail the same way.
##
## Numbers here come from the two authorities that actually build the thing:
##   * the wall records in building_layout.json (`a`, `b`, `t`, `openings`,
##     `wainscot`, `wains_side`)
##   * build_orison.py, which tops the dado at 1.32, caps it to 1.36 and
##     rides a bullnose bead at dado_top + 0.035
##
## No literal from wall_art_law.gd is imported.

const LAYOUT := "res://data/building_layout.json"
## build_orison.py:2902 dado_top, :2946 cap, :2958 bead at dado_top + 0.035.
## The highest thing a piece must clear on a dado wall is the bead.
const REAL_RAIL_TOP := 1.355
## A hook must stand off the plaster, but not float in the room.
const MIN_STANDOFF := 0.02
const MAX_STANDOFF := 0.25
const EXPECTED_CHECKS := 7

var failures := 0
var checks := 0
var _finished := false
## Per-defect tallies. Reported as counts because "how many" is the thing a
## reviewer needs, and a single boolean would hide a regression from 2 to 40.
var tally := {}
var samples := {}
var accepted := 0
var refused := 0


func _ready() -> void:
	print("[WALLART] START")
	_watchdog()
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(LAYOUT))
	if parsed is not Dictionary:
		printerr("[WALLART] cannot read layout")
		get_tree().quit(1)
		return
	var layout: Dictionary = parsed
	for key in ["backing", "orientation", "run_overhang", "buried",
			"opening", "furniture", "dado"]:
		tally[key] = 0
		samples[key] = ""
	_sweep(layout)
	_report()
	_finished = true
	print("DREAM-FREE WALL ART TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(50.0, true, false, true).timeout
	if not _finished:
		printerr("[WALLART] WATCHDOG — FAIL")
		get_tree().quit(1)


## Ask the law for a hook in every room, on every face, then judge what it
## handed back.
func _sweep(layout: Dictionary) -> void:
	WallArtLaw.clear_reservations()
	for fl in layout.get("floors", []):
		for room in fl.get("rooms", []):
			if str(room.get("kind", "")) in ["roof", "courtyard"]:
				continue
			for want in ["north", "south", "east", "west"]:
				var spot: Dictionary = WallArtLaw.legal_spot(
						fl, room, want, 0.5, 1.60)
				if not bool(spot.get("ok", false)):
					refused += 1
					continue
				accepted += 1
				_judge(fl, room, spot)


func _judge(fl: Dictionary, room: Dictionary, spot: Dictionary) -> void:
	var wall_name := str(spot.wall)
	var px := float(spot.x)
	var py := float(spot.y)
	var hz := float(spot.height)
	var want_horizontal := wall_name in ["north", "south"]
	var rid := str(room.get("id", "?"))

	var best: Dictionary = {}
	var best_d := 1e9
	for w in fl.get("walls", []):
		var ax := float(w["a"][0])
		var ay := float(w["a"][1])
		var bx := float(w["b"][0])
		var by := float(w["b"][1])
		var horizontal := absf(by - ay) < 0.001
		var t := float(w.get("t", 0.12))
		var cl := ay if horizontal else ax
		var pc := py if horizontal else px
		var d := absf(pc - cl)
		if d > t * 0.5 + MAX_STANDOFF + 0.05:
			continue
		# the hook must also lie within the wall's own run
		var along := px if horizontal else py
		var lo := minf(ax, bx) if horizontal else minf(ay, by)
		var hi := maxf(ax, bx) if horizontal else maxf(ay, by)
		if along < lo - 0.05 or along > hi + 0.05:
			continue
		if d < best_d:
			best_d = d
			best = w

	if best.is_empty():
		_hit("backing", "%s/%s: no wall within reach of the hook" % [rid, wall_name])
		return

	var ax2 := float(best["a"][0])
	var ay2 := float(best["a"][1])
	var bx2 := float(best["b"][0])
	var by2 := float(best["b"][1])
	var horizontal2 := absf(by2 - ay2) < 0.001
	var t2 := float(best.get("t", 0.12))
	var cl2 := ay2 if horizontal2 else ax2

	# 1. ORIENTATION: a north-facing piece must hang on an east-west wall.
	if horizontal2 != want_horizontal:
		_hit("orientation", "%s/%s: hung at right angles to its own backing"
				% [rid, wall_name])

	# 2. BURIED: the hook must stand clear of the plaster FACE, which is half
	#    a thickness off the centreline -- not off the room rect, whose edges
	#    mean different things for envelope and partition walls.
	var rect: Array = room.rect
	var room_c := (float(rect[1]) + float(rect[3])) * 0.5 if horizontal2 \
			else (float(rect[0]) + float(rect[2])) * 0.5
	var pc2 := py if horizontal2 else px
	var inward := 1.0 if room_c > cl2 else -1.0
	var face := cl2 + inward * t2 * 0.5
	var standoff := (pc2 - face) * inward
	if standoff < MIN_STANDOFF:
		_hit("buried", "%s/%s: hook %.3f m from the face (t %.2f)"
				% [rid, wall_name, standoff, t2])
	elif standoff > MAX_STANDOFF:
		_hit("buried", "%s/%s: hook floats %.3f m off the wall"
				% [rid, wall_name, standoff])

	# 3. RUN OVERHANG: the PIECE, not its centre hook, must fit in the run.
	var half_w := 0.38
	var along2 := px if horizontal2 else py
	var lo2 := minf(ax2, bx2) if horizontal2 else minf(ay2, by2)
	var hi2 := maxf(ax2, bx2) if horizontal2 else maxf(ay2, by2)
	if along2 - half_w < lo2 - 0.001 or along2 + half_w > hi2 + 0.001:
		_hit("run_overhang", "%s/%s: piece overhangs its wall by %.3f m"
				% [rid, wall_name,
				maxf(lo2 - (along2 - half_w), (along2 + half_w) - hi2)])

	# 4. OPENINGS: nothing hangs across a door or window.
	var half_h := 0.36
	for o in best.get("openings", []):
		var oat := lo2 + float(o.get("at", 0.0))
		if absf(along2 - oat) > float(o.get("w", 0.0)) * 0.5 + half_w:
			continue
		var sill := float(o.get("sill", 0.0))
		if sill <= hz + half_h and sill + float(o.get("h", 0.0)) >= hz - half_h:
			_hit("opening", "%s/%s: piece crosses a %s"
					% [rid, wall_name, str(o.get("type", "opening"))])
			break

	# 5. DADO: only refuse on the face that actually carries the band.
	#    build_orison puts a tiled dado on `wains_side` alone, precisely so
	#    the room next door keeps its plaster.
	if bool(best.get("wainscot", false)) and hz - half_h < REAL_RAIL_TOP:
		var side: Variant = best.get("wains_side")
		var on_banded_face := true
		if side != null and str(side) != "":
			on_banded_face = (float(side) > 0.0) == (inward > 0.0)
		if on_banded_face:
			_hit("dado", "%s/%s: piece crosses the dado at %.2f"
					% [rid, wall_name, hz - half_h])

	# 6. FURNITURE, including the assembly records the law cannot see.
	if _asm_blocks(fl, px, py, hz, half_w, half_h):
		_hit("furniture", "%s/%s: piece intersects an assembly prop"
				% [rid, wall_name])


## The law's furniture_blocks handles `rect` and `p0`/`p1` and stops there.
## 702 of the building's 6766 furniture records carry neither: they are `asm`
## entries with `at`/`W`/`D`/`H`, and every one of them is invisible to the
## collision test. This is the half the law never sees.
func _asm_blocks(fl: Dictionary, px: float, py: float, hz: float,
		half_w: float, half_h: float) -> bool:
	for fu in fl.get("furniture", []):
		if fu.has("rect") or fu.has("p0"):
			continue
		if not fu.has("asm") or not fu.has("at"):
			continue
		var at: Array = fu["at"]
		var z0 := float(fu.get("z0", 0.0))
		var z1 := z0 + float(fu.get("H", fu.get("h", 0.0)))
		if hz + half_h < z0 or hz - half_h > z1:
			continue
		var hw := float(fu.get("W", 0.3)) * 0.5 + half_w
		var hd := float(fu.get("D", 0.3)) * 0.5 + half_w
		if absf(px - float(at[0])) <= hw and absf(py - float(at[1])) <= hd:
			return true
	return false


func _hit(key: String, detail: String) -> void:
	tally[key] = int(tally[key]) + 1
	if str(samples[key]) == "":
		samples[key] = detail


func _report() -> void:
	print("[WALLART] the law accepted %d hooks and refused %d"
			% [accepted, refused])
	for key in ["backing", "orientation", "buried", "run_overhang",
			"opening", "furniture", "dado"]:
		var n := int(tally[key])
		print("   %-13s %4d   %s" % [key, n, samples[key]])
		_check("no %s violations" % key, n == 0)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [wallart ok] ", label)
	else:
		failures += 1
		printerr("  [WALLART FAIL] ", label)
