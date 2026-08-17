class_name PassageHoursDirector
extends Node3D
## PS6: the Vantry Arcade after the last ordinary shop closes.
##
## Ten source-authored shopfronts receive internal sliding lattice grilles.
## HARDWARE PAINT remains the one night-service counter because Mina's proved
## maintenance loop must buy a part there at the canonical 03:00 shift.  The
## same state circuit darkens the ten closed bays and wheel-locks all three
## public handcarts.  Coordinates come only from `passage_shop_hours` layout
## markers emitted beside the shopfronts by gen_layout.py.

enum HoursState { OPEN, AFTER_HOURS }

const NIGHT_SERVICE_TRADE := "hardware"
const AFTER_HOURS_START := 120.0   # 02:00, when the Harukiya also empties
const AFTER_HOURS_END := 390.0     # 06:30, before the morning profile settles
const CELL_W := 0.46
const CELL_H := 0.39

var geometry_nodes: Array[GeometryInstance3D] = []
var barrier_shapes: Array[CollisionShape3D] = []
var closed_shop_ids: Array[String] = []
var shop_specs: Array[Dictionary] = []
var _regular_specs: Array[Dictionary] = []
var _night_service_spec: Dictionary = {}
var _closed_grilles: MultiMeshInstance3D
var _folded_regular: MultiMeshInstance3D
var _folded_night_service: MultiMeshInstance3D
var _barrier: StaticBody3D
var _root: Node3D
var _carts: Array[Node3D] = []
var _after_hours := false
var _passage_active := true
var _state := -1
var _accum := 9.0


func build(root: Node3D, layout: Dictionary,
		carts: Array[Node3D]) -> Dictionary:
	name = "PassageHoursDirector"
	_root = root
	_carts = carts
	shop_specs = _shopfront_specs(layout)
	for spec in shop_specs:
		if String(spec.trade) == NIGHT_SERVICE_TRADE:
			_night_service_spec = spec
		else:
			_regular_specs.append(spec)
			closed_shop_ids.append(String(spec.id))
	_closed_grilles = _build_grille_batch(
			"PassageClosedShopGrilles", _regular_specs, false)
	_folded_regular = _build_grille_batch(
			"PassageFoldedShopGrilles", _regular_specs, true)
	_folded_night_service = _build_grille_batch(
			"PassageNightServiceGrille", [_night_service_spec], true)
	_build_barriers()
	if OS.get_environment("PASSAGE_HOURS_OFF") == "1":
		set_process(false)
		apply_for_minute(750.0)
	else:
		apply_for_minute(ScheduleDirector.minute_now())
	print("[PASSAGE HOURS] %d shopfronts, %d close after 02:00, "
			% [shop_specs.size(), _regular_specs.size()]
			+ "HARDWARE PAINT keeps night service")
	return {"shops": shop_specs.size(), "closed": _regular_specs.size(),
			"draws": geometry_nodes.size()}


static func state_for(minute: float) -> HoursState:
	var wrapped := fposmod(minute, 1440.0)
	return HoursState.AFTER_HOURS if wrapped >= AFTER_HOURS_START \
			and wrapped < AFTER_HOURS_END else HoursState.OPEN


func apply_for_minute(minute: float) -> void:
	var next := state_for(minute)
	if int(next) == _state:
		return
	_state = int(next)
	_after_hours = next == HoursState.AFTER_HOURS
	for cart in _carts:
		if is_instance_valid(cart) and cart.has_method(
				"set_after_hours_locked"):
			cart.set_after_hours_locked(_after_hours)
	_apply_shop_lights()
	_refresh_visibility_and_collision()
	print("[PASSAGE HOURS] %s; %d grilles %s" % [
			HoursState.keys()[int(next)], _regular_specs.size(),
			"drawn" if _after_hours else "folded"])


func is_after_hours() -> bool:
	return _after_hours


## Read-only storefront presentation boundary.  Signs may report the same
## state that already owns grilles and lamps without learning the hours rule.
func sign_status_for_trade(trade: String) -> Dictionary:
	if not _after_hours:
		return {"hours_state": "OPEN", "light_state": "LIT"}
	if trade == NIGHT_SERVICE_TRADE:
		return {"hours_state": "NIGHT SERVICE", "light_state": "LIT"}
	return {"hours_state": "CLOSED", "light_state": "DARK"}


func set_passage_active(active: bool) -> void:
	_passage_active = active
	visible = active
	_refresh_visibility_and_collision()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 7.0:
		return
	_accum = 0.0
	apply_for_minute(ScheduleDirector.minute_now())


func _shopfront_specs(layout: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for floor in layout.get("floors", []):
		if String(floor.get("id", "")) != "F01":
			continue
		for marker in floor.get("markers", []):
			if String(marker.get("kind", "")) != "passage_shop_hours" \
					or String(marker.get("zone", "")) != "PASSAGE":
				continue
			var p: Array = marker.get("pos", [])
			if p.size() != 3:
				continue
			found.append({
				"id": String(marker.get("id", "")),
				"trade": String(marker.get("trade", "")),
				"shop_name": String(marker.get("shop_name", "")),
				"position": GameBoot.b2g(p),
				"width": float(marker.get("w", 0.0)),
				"height": float(marker.get("h", 2.38)),
			})
	found.sort_custom(func(a, b):
		return (a.position as Vector3).z < (b.position as Vector3).z)
	return found


func _build_grille_batch(label: String, specs: Array,
		folded: bool) -> MultiMeshInstance3D:
	var transforms: Array[Transform3D] = []
	for spec in specs:
		if spec.is_empty():
			continue
		if folded:
			_append_folded_packet(spec, transforms)
		else:
			_append_closed_lattice(spec, transforms)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.026, 1.0, 0.026)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = multimesh
	instance.material_override = MatLib.get_mat("cast_iron",
			Color(0.20, 0.19, 0.17), 0.70)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.add_to_group("passage_hours_geometry")
	add_child(instance)
	geometry_nodes.append(instance)
	return instance


func _append_closed_lattice(spec: Dictionary,
		out: Array[Transform3D]) -> void:
	var centre: Vector3 = spec.position
	var width: float = spec.width
	var height: float = spec.height
	var z0 := centre.z - width * 0.5
	var y0 := centre.y
	var columns := maxi(1, int(ceil(width / CELL_W)))
	var rows := maxi(1, int(ceil(height / CELL_H)))
	var dx := width / float(columns)
	var dy := height / float(rows)
	# The repeating X is the honest scissor mechanism: open area remains high,
	# so a closed arcade still shows its plate glass and dark stock beyond.
	for row in rows:
		for column in columns:
			var a := Vector3(centre.x, y0 + row * dy,
					z0 + column * dx)
			var b := Vector3(centre.x, y0 + (row + 1) * dy,
					z0 + (column + 1) * dx)
			_append_bar(a, b, out)
			_append_bar(Vector3(a.x, a.y, b.z),
					Vector3(b.x, b.y, a.z), out)
	# Recessed side tracks and the lock rail are part of the gate rather than
	# unexplained bars floating over the historic timber shopfront.
	_append_bar(Vector3(centre.x, y0, z0),
			Vector3(centre.x, y0 + height, z0), out)
	_append_bar(Vector3(centre.x, y0, z0 + width),
			Vector3(centre.x, y0 + height, z0 + width), out)
	_append_bar(Vector3(centre.x, y0 + 0.07, z0),
			Vector3(centre.x, y0 + 0.07, z0 + width), out)


func _append_folded_packet(spec: Dictionary,
		out: Array[Transform3D]) -> void:
	var centre: Vector3 = spec.position
	var height: float = spec.height
	var edge := centre.z - float(spec.width) * 0.5 + 0.055
	for i in 7:
		var z := edge + float(i) * 0.022
		_append_bar(Vector3(centre.x, centre.y, z),
				Vector3(centre.x, centre.y + height, z), out)
	for row in 6:
		var y := centre.y + height * (float(row) + 0.5) / 6.0
		_append_bar(Vector3(centre.x, y, edge - 0.018),
				Vector3(centre.x, y, edge + 0.17), out)


func _append_bar(a: Vector3, b: Vector3,
		out: Array[Transform3D]) -> void:
	var delta := b - a
	var length := delta.length()
	if length <= 0.001:
		return
	var angle := atan2(delta.z, delta.y)
	var basis := Basis(Vector3.RIGHT, angle) \
			* Basis.from_scale(Vector3(1.0, length, 1.0))
	out.append(Transform3D(basis, (a + b) * 0.5))


func _build_barriers() -> void:
	_barrier = StaticBody3D.new()
	_barrier.name = "PassageClosedShopBarrier"
	_barrier.collision_layer = 1
	_barrier.collision_mask = 1
	_barrier.add_to_group("passage_hours_barrier")
	add_child(_barrier)
	for spec in _regular_specs:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.10, float(spec.height), float(spec.width))
		var node := CollisionShape3D.new()
		node.name = "Closed_%s" % String(spec.id).trim_prefix(
				"SITE_SHOP_HOURS_")
		node.shape = shape
		var centre: Vector3 = spec.position
		node.position = centre + Vector3(0.0, float(spec.height) * 0.5, 0.0)
		node.disabled = true
		node.set_meta("shop_id", spec.id)
		_barrier.add_child(node)
		barrier_shapes.append(node)


## Every light a shop owns, not just the one over its door.
##
## The sweep used to rewrite SITE_SHOP_HOURS_* -> SITE_SHOP_LT_* and stop
## there, so eleven of the arcade's forty-seven bulbs knew the hour and the
## other twenty-eight did not. At 03:00 the signs read DARK, the grilles were
## drawn across the fronts, and behind them every sales floor and back room
## was still fully lit — a closed shop blazing through its own shutter.
const SHOP_LIGHT_PREFIXES := ["SITE_SHOP_LT_", "SITE_SHOP_IN0_",
		"SITE_SHOP_IN1_", "SITE_SHOP_IN2_", "SITE_SHOP_DARKROOM_"]

## The fixture a closed shop leaves burning, chosen from where it stands.
##
## Marker positions, read from the layout rather than assumed: the aisle runs
## at x 14-16, the shopfront threshold at 16.5-17.1, and then IN0 at 17.95 --
## about 1.4 m inside the glass, at 2.92 m. IN1 and IN2 are at 20.5-23.05,
## which is stock and rear. LT at 16.54 is OUTSIDE the glass line: it is the
## fascia, and a fascia light is advertising.
##
## So a closed shop puts out its sign and keeps one light burning inside the
## front, which is both what a night security light IS and the thing that can
## be seen from the aisle through goods, glass and drawn grille. It also feeds
## the layered sightline V2 was accepted on, from the dark side.
const NIGHT_SECURITY_FIXTURE := "SITE_SHOP_IN0_"

## How much of it burns, by trade. Owner ruling 2026-08-17: "light the closed
## shops as realism determines. when instructions collide, favor realism."
##
## Realism does not mean a uniform bulb in every shop -- that is just the
## blazing shutter of `38aba16` at lower wattage. It means what each trade
## would really leave on at three in the morning, and the answer is graded by
## what is inside worth watching:
##
##   pawn      a strongroom trade; the display light is effectively insurance
##   druggist  night bell and a locked poisons cabinet; the traditional lamp
##   locksmith keys, blanks and a safe: a security trade watching itself
##   funeral   a chapel of rest keeps a low vigil light, which is custom
##             rather than security, and reads warmer and dimmer for it
##   news      tobacco behind the counter is the stock worth taking
##   diner     the counter light every luncheonette leaves for the cleaner
##   photo     film and cameras, but the DARKROOM stays dark -- it is a
##             darkroom, and a lit one is a ruined shelf of paper
##   radio     a workshop of other people's sets, half of them in pieces
##   laundry   other people's shirts; nobody breaks in for shirts
##   cobbler   the same, with lasts
##
## HARDWARE PAINT is absent deliberately: it is NIGHT_SERVICE_TRADE and stays
## fully lit and open, which no security light should be confused with.
const NIGHT_SECURITY_GAIN := {
	"pawn": 0.35,
	"druggist": 0.30,
	"locksmith": 0.25,
	"funeral": 0.22,
	"news": 0.20,
	"diner": 0.20,
	"photo": 0.18,
	"radio": 0.15,
	"laundry": 0.12,
	"cobbler": 0.12,
}


func _apply_shop_lights() -> void:
	if _root == null:
		return
	for spec in shop_specs:
		# The node suffix is the shopfront's NAME (PAWNBROKER); `spec.trade`
		# is its TRADE (pawn). They are not the same key and the security
		# table is keyed by the trade.
		var suffix := String(spec.id).replace("SITE_SHOP_HOURS_", "")
		var trade := String(spec.trade)
		var trading := not _after_hours or trade == NIGHT_SERVICE_TRADE
		var night_gain: float = NIGHT_SECURITY_GAIN.get(trade, 0.0)
		for prefix in SHOP_LIGHT_PREFIXES:
			var fixture := _root.get_node_or_null(
					NodePath(prefix + suffix)) as LightFixtureProp
			if fixture == null:
				continue
			var gain := 1.0
			if not trading:
				gain = night_gain if prefix == NIGHT_SECURITY_FIXTURE \
						else 0.0
			fixture.set_state_gain(gain)
			# A security light burns, so unlike a switched-off bulb it does
			# enter the rig's ranking -- but it declines the shadow slot that
			# ranking would buy it. A 12-35% bulb behind a drawn grille has no
			# business throwing an architectural shadow down the nave. This is
			# an image decision and not a budget one: measured over a full
			# station run these lights cost nothing outside the noise band.
			fixture.wants_shadow = trading
			# Still gated on the gain, not on the hour. An unpowered fixture
			# is kept out of the ranking entirely, which is what stops a dark
			# bulb holding a shadow slot (`bbdeb78`).
			fixture.set_powered(gain > 0.0)


func _refresh_visibility_and_collision() -> void:
	if _closed_grilles:
		_closed_grilles.visible = _passage_active and _after_hours
	if _folded_regular:
		_folded_regular.visible = _passage_active and not _after_hours
	if _folded_night_service:
		_folded_night_service.visible = _passage_active
	var closed_and_owned := _passage_active and _after_hours
	for shape in barrier_shapes:
		shape.set_deferred("disabled", not closed_and_owned)
	if _barrier:
		_barrier.collision_layer = 1 if closed_and_owned else 0
		_barrier.collision_mask = 1 if closed_and_owned else 0
