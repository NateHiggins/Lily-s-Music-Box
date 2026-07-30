class_name OrisonOccluders
extends Node3D
## Occlusion culling built from the same wall data everything else comes
## from. The building is mostly opaque masonry, but the renderer had no way
## to know that: standing on the sidewalk it was still drawing four storeys
## of furniture behind the facade.
##
## The one thing an occluder must never do is hide something you can
## actually see. A wall is only solid where it has no opening, so each wall
## contributes boxes for the piers BETWEEN its doors and windows, plus the
## spandrel under each sill and the header above each lintel. Cover a
## doorway with a single wall-sized box and the corridor beyond it pops out
## of existence as you look through — worse than not culling at all.
##
## Occluders are cheap (a box each, CPU-rasterized before draw submission)
## and static, so they are built once and never touched again.

## Openings are widened by this much per side before the solid spans are
## cut, so a sliver of occluder never straddles a reveal and flickers.
const OPENING_PAD := 0.04
## Spans narrower than this aren't worth an occluder's rasterization cost.
const MIN_SPAN := 0.30

var _count := 0


func build(layout: Dictionary) -> int:
	for fl in layout["floors"]:
		for w in fl["walls"]:
			_wall_occluders(w)
		for s in fl["slabs"]:
			_slab_occluder(s)
	return _count


## One wall: solid spans along its length, respecting every opening.
func _wall_occluders(w: Dictionary) -> void:
	var ax: float = float(w["a"][0])
	var ay: float = float(w["a"][1])
	var bx: float = float(w["b"][0])
	var by: float = float(w["b"][1])
	var horizontal: bool = absf(by - ay) < 1e-6
	var length: float = absf(bx - ax) if horizontal else absf(by - ay)
	if length < MIN_SPAN:
		return
	var thickness: float = float(w["t"])
	var height: float = float(w["h"])
	var base: float = float(w["z"])
	var start: float = minf(ax, bx) if horizontal else minf(ay, by)
	var cross: float = ay if horizontal else ax

	# Sort openings along the wall, then walk the gaps between them.
	var holes: Array = []
	for o in w.get("openings", []):
		var ow: float = float(o["w"]) + OPENING_PAD * 2.0
		var at: float = float(o["at"])
		holes.append({
			"lo": at - ow * 0.5, "hi": at + ow * 0.5,
			"sill": float(o.get("sill", 0.0)),
			"head": float(o.get("sill", 0.0)) + float(o["h"]),
		})
	holes.sort_custom(func(p, q): return p["lo"] < q["lo"])

	var cursor := 0.0
	for h in holes:
		var lo: float = maxf(0.0, float(h["lo"]))
		if lo - cursor >= MIN_SPAN:
			_box(start + cursor, start + lo, cross, thickness,
					base, base + height, horizontal)
		# spandrel under the sill and header over the lintel are still solid
		var hi: float = minf(length, float(h["hi"]))
		var sill: float = float(h["sill"])
		var head: float = float(h["head"])
		if sill > MIN_SPAN:
			_box(start + lo, start + hi, cross, thickness,
					base, base + sill, horizontal)
		if height - head > MIN_SPAN:
			_box(start + lo, start + hi, cross, thickness,
					base + head, base + height, horizontal)
		cursor = maxf(cursor, hi)
	if length - cursor >= MIN_SPAN:
		_box(start + cursor, start + length, cross, thickness,
				base, base + height, horizontal)


## Slabs block every sightline between storeys except where they are cut
## for the atrium well, the lift shaft and the chimney.
func _slab_occluder(s: Dictionary) -> void:
	var r: Array = s["rect"]
	var z_top: float = float(s["z_top"])
	var t: float = float(s["t"])
	var spans: Array = [[float(r[0]), float(r[1]), float(r[2]), float(r[3])]]
	for hole in s.get("holes", []):
		var next: Array = []
		for sp in spans:
			next.append_array(_subtract(sp, hole))
		spans = next
	for sp in spans:
		if sp[2] - sp[0] < MIN_SPAN or sp[3] - sp[1] < MIN_SPAN:
			continue
		_emit(GameBoot.b2g([(sp[0] + sp[2]) * 0.5, (sp[1] + sp[3]) * 0.5,
				z_top - t * 0.5]),
				Vector3(sp[2] - sp[0], t, sp[3] - sp[1]))


## Axis-aligned rectangle minus a hole, as up to four surviving strips —
## the same decomposition the Blender build uses to cut slab openings.
func _subtract(sp: Array, hole: Array) -> Array:
	var hx0: float = float(hole[0])
	var hy0: float = float(hole[1])
	var hx1: float = float(hole[2])
	var hy1: float = float(hole[3])
	if hx0 >= sp[2] or hx1 <= sp[0] or hy0 >= sp[3] or hy1 <= sp[1]:
		return [sp]
	var out: Array = []
	var cy0: float = maxf(sp[1], hy0)
	var cy1: float = minf(sp[3], hy1)
	if sp[1] < cy0:
		out.append([sp[0], sp[1], sp[2], cy0])
	if cy1 < sp[3]:
		out.append([sp[0], cy1, sp[2], sp[3]])
	var cx0: float = maxf(sp[0], hx0)
	var cx1: float = minf(sp[2], hx1)
	if sp[0] < cx0:
		out.append([sp[0], cy0, cx0, cy1])
	if cx1 < sp[2]:
		out.append([cx1, cy0, sp[2], cy1])
	return out


func _box(lo: float, hi: float, cross: float, thickness: float,
		z0: float, z1: float, horizontal: bool) -> void:
	if hi - lo < MIN_SPAN or z1 - z0 < MIN_SPAN:
		return
	var mid := (lo + hi) * 0.5
	var bx: float = mid if horizontal else cross
	var by: float = cross if horizontal else mid
	var size := Vector3(hi - lo, z1 - z0, thickness) if horizontal \
			else Vector3(thickness, z1 - z0, hi - lo)
	_emit(GameBoot.b2g([bx, by, (z0 + z1) * 0.5]), size)


func _emit(at: Vector3, size: Vector3) -> void:
	var occ := OccluderInstance3D.new()
	var shape := BoxOccluder3D.new()
	shape.size = size
	occ.occluder = shape
	occ.position = at
	add_child(occ)
	_count += 1
