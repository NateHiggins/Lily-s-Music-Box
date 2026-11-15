extends RefCounted
## Translate complete rigid native support pairs; actor and electrical owners
## remain elsewhere. Call before mounting the retained cell into the live tree.
const APPLIED_META := "harukiya_fixture_mount_relocations"

static func apply(cell: Node3D, spec: Dictionary) -> bool:
	if cell == null: return false
	var rows: Variant = spec.get("fixture_mount_relocations", [])
	if rows is not Array: return false
	if rows.is_empty(): return true
	var mounts := cell.get_node_or_null("BarFixtureMounts") as Node3D
	if mounts == null: return false
	var previous: Variant = cell.get_meta(APPLIED_META, {})
	if previous is not Dictionary: return false
	var seen: Dictionary = {}
	var changes: Array = []
	for value: Variant in rows:
		if value is not Dictionary: return false
		var id: Variant = value.get("id")
		if id is not String or id.is_empty() or not id.begins_with("F01_BAR_LT_"): return false
		if seen.has(id) or previous.has(id): return false
		if not _point(value.get("source_at")) or not _point(value.get("at")): return false
		seen[id] = true
		var delta: Vector3 = GameBoot.b2g(value.at)-GameBoot.b2g(value.source_at)
		if not delta.is_finite(): return false
		for suffix: String in ["__brass_dull", "__iron_blackened"]:
			var identity: String = id+suffix
			var found: MeshInstance3D = null
			for draw: MeshInstance3D in mounts.find_children("*", "MeshInstance3D", true, false):
				if str(draw.get_meta("bar_fixture_mount_part", "")) != identity: continue
				if found != null: return false
				found = draw
			if found == null or found.mesh == null or not found.transform.is_finite(): return false
			# Source points are cell-frame coordinates. Convert the vector only
			# if imported parent transforms are not identity; never apply b2g twice.
			var parent_frame := Transform3D.IDENTITY
			var cursor := found.get_parent() as Node3D
			while cursor != cell:
				if cursor == null or not cursor.transform.is_finite(): return false
				parent_frame = cursor.transform*parent_frame
				cursor = cursor.get_parent() as Node3D
			if absf(parent_frame.basis.determinant()) < .00000001: return false
			var next: Transform3D = found.transform
			next.origin += parent_frame.basis.inverse()*delta
			if not next.is_finite(): return false
			changes.append({"draw":found,"transform":next})
	# No source node or metadata is changed before every entry/pair validates.
	for change: Dictionary in changes: change.draw.transform = change.transform
	var applied: Dictionary = previous.duplicate(true)
	for value: Dictionary in rows: applied[value.id] = value.duplicate(true)
	cell.set_meta(APPLIED_META, applied)
	return true

static func _point(value: Variant) -> bool:
	if value is not Array or value.size()!=3: return false
	for component: Variant in value:
		if not (component is float or component is int) or not is_finite(float(component)): return false
	return true
