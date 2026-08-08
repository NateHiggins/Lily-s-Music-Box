extends Node
## Boots every cabinet in the catalog and checks the row still holds together.
##
##     godot --headless --path game res://tests/ArcadeTest.tscn
##
## Three things are worth failing over:
##
## * every cabinet builds its world and binds its package, with no unresolved
##   references. A cabinet that quietly fell back to graybox looks fine on the
##   screen and means the compiler and this project have drifted apart.
## * every cabinet is running the SAME game. The compiler certifies this with
##   `worldc invariance` before writing the catalog; this re-checks the part
##   that survives into the runtime, which is that they all built the same
##   entity set from the same scene hash.
## * degrading a cabinet changes what is drawn and nothing else. This is the
##   architectural claim the whole project rests on, so it is asserted rather
##   than trusted: fingerprint the colliders and transforms at full skin, drag
##   the dial to full graybox, and fingerprint again.

const CATALOG_DIR := ArcadeCatalog.DIR


func _ready() -> void:
	var failures := 0
	var catalog := ArcadeCatalog.load_catalog(CATALOG_DIR)
	if catalog == null or catalog.size() == 0:
		print("[ARCADE] FAIL no catalog at %s" % CATALOG_DIR)
		get_tree().quit(1)
		return

	print("[ARCADE] catalog: %d cabinets, scene=%s, certified_identical=%s"
			% [catalog.size(), catalog.scene_id, str(catalog.gameplay_identical)])
	if not catalog.gameplay_identical:
		print("[ARCADE] FAIL the catalog does not certify identical gameplay")
		failures += 1

	var fingerprints: Dictionary = {}
	for cabinet in catalog.cabinets:
		var id := String(cabinet.get("cabinet_id", "?"))
		var machine := ArcadeMachine.new()
		add_child(machine)
		if not machine.boot(cabinet, CATALOG_DIR):
			print("[ARCADE] FAIL %s did not boot" % id)
			failures += 1
			machine.queue_free()
			continue

		var entities: int = machine._entities.size()
		var bound := machine.package.bound_count if machine.package != null else 0
		var missing := machine.package.missing_assets.size() if machine.package != null else -1
		var dressed := _fingerprint(machine)

		# The dial is the claim. Everything the skin owns disappears; everything
		# gameplay owns must be untouched.
		machine.degrade = 1.0
		var graybox := _fingerprint(machine)
		machine.degrade = 0.0

		var ok := machine.package != null and missing == 0 and dressed == graybox
		if machine.package == null:
			print("[ARCADE] FAIL %s: no package bound" % id)
			failures += 1
		elif missing != 0:
			print("[ARCADE] FAIL %s: %d unresolved references" % [id, missing])
			failures += 1
		elif dressed != graybox:
			print("[ARCADE] FAIL %s: degrading changed gameplay state" % id)
			failures += 1

		fingerprints[id] = dressed
		print("[ARCADE] %-4s %-24s %-14s %d entities, %d bound, %d unresolved"
				% [
					"ok" if ok else "FAIL",
					String(cabinet.get("title", id)),
					String(cabinet.get("claimed_genre", "")),
					entities,
					bound,
					maxi(missing, 0),
				])
		machine.queue_free()

	# Same game, twelve coats of paint.
	var distinct: Dictionary = {}
	for id in fingerprints:
		distinct[fingerprints[id]] = true
	if distinct.size() > 1:
		print("[ARCADE] FAIL %d distinct gameplay fingerprints across %d cabinets"
				% [distinct.size(), fingerprints.size()])
		failures += 1
	elif fingerprints.size() > 1:
		print("[ARCADE] %d cabinets, 1 gameplay fingerprint" % fingerprints.size())

	print("[ARCADE] %s" % ("PASS" if failures == 0 else "FAIL (%d problems)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


## Everything gameplay owns, and nothing presentation owns.
##
## Deliberately built from the live node tree rather than from the scene file: a
## skin that moved a collider would move it here, and reading the source would
## miss exactly the bug this is looking for.
func _fingerprint(machine: ArcadeMachine) -> String:
	var parts := PackedStringArray()
	var ids := machine._entities.keys()
	ids.sort()
	for id in ids:
		var entity: SwcEntity = machine._entities[id]
		parts.append("%s|%s|%s|%s" % [
			entity.semantic_id,
			entity.semantic_type,
			_v3(entity.position),
			_v3(entity.rotation_degrees),
		])
		for shape in _shapes(entity):
			parts.append("  %s" % shape)
	return "\n".join(parts).sha256_text()


func _shapes(entity: SwcEntity) -> PackedStringArray:
	var out := PackedStringArray()
	for node in entity.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		var described := "?"
		if shape.shape is BoxShape3D:
			described = "box%s" % _v3((shape.shape as BoxShape3D).size)
		elif shape.shape is CylinderShape3D:
			var cylinder := shape.shape as CylinderShape3D
			described = "cyl%.3f,%.3f" % [cylinder.radius, cylinder.height]
		elif shape.shape is SphereShape3D:
			described = "sph%.3f" % (shape.shape as SphereShape3D).radius
		out.append("%s@%s" % [described, _v3(shape.position)])
	out.sort()
	return out


func _v3(value: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [value.x, value.y, value.z]
