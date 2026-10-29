extends RefCounted
## Source-derived posed context checks; no played access or camera-route grant.

static func exposed_grade_samples(bounds: Array, buildings: Array) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for x_fraction: float in [.1,.5,.9]:
		for z_fraction: float in [.1,.5,.9]:
			var found := false
			for dx: float in [0.,-.035,.035,-.07,.07]:
				for dz: float in [0.,-.035,.035,-.07,.07]:
					var point := Vector3(lerpf(bounds[0],bounds[3],x_fraction+dx),bounds[4],lerpf(bounds[2],bounds[5],z_fraction+dz))
					var covered := false
					for building: Dictionary in buildings:
						var r: Array = building.rect
						if point.x>float(r[0])-.03 and point.x<float(r[2])+.03 and point.z>float(r[1])-.03 and point.z<float(r[3])+.03:
							covered=true
							break
					if covered:continue
					result.append(point)
					found=true
					break
				if found:break
	return result

static func capture_station(space: PhysicsDirectSpaceState3D, horizon: Node3D, stations: Array, bodies: Dictionary, retained_eyes: Array[Vector3], excluded: Array[RID]) -> Dictionary:
	# First prefer an existing retained posed view. A separately labelled source
	# context view is allowed when lower background stock is hidden by near city.
	for pass_index in 2:
		for row: Dictionary in stations:
			var p: Array=row.point
			var n: Array=row.normal
			var point := horizon.to_global(Vector3(p[0],p[2],-p[1]))
			var normal := horizon.global_basis*Vector3(n[0],n[2],-n[1])
			var target := point-normal*float(row.recess_m)
			var candidates: Array[Vector3]=[]
			if pass_index==0:candidates=retained_eyes
			else:candidates.append(target+normal*16.)
			for eye: Vector3 in candidates:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,target-normal*.04,1,excluded))
				if hit.is_empty() or not bodies.has(hit.collider.get_rid()) or hit.position.distance_to(target)>.001:continue
				return {"eye":eye,"target":target,"retained_camera":pass_index==0,"building":row.building}
	return {}


static func placed_fixture(original: Dictionary) -> Dictionary:
	var result: Dictionary = original.duplicate(true)
	var placement := preload("res://scripts/building/orison_v2_city_placement.gd").new()
	for row: Dictionary in result.get("buildings", []):
		var offset: Vector3 = placement.source_offset(str(row.id))
		for key: String in ["main_rect", "original_roof_rect"]:
			if not row.has(key): continue
			for index in 4: row[key][index] += offset.x if index % 2 == 0 else offset.y
	for field: String in ["window_rows", "portals", "roof_samples", "townhouse_details", "court_details", "contacts", "architecture_checks", "roof_details"]:
		for row: Dictionary in result.get(field, []):
			var offset: Vector3 = placement.source_offset(str(row.get("building", row.get("id", ""))))
			for key: String in ["center", "pane_sample", "point", "probe", "void_probe"]:
				if not row.has(key): continue
				for index in 3: row[key][index] += offset[index]
			for point: Array in row.get("footprint", []):
				for index in 3: point[index] += offset[index]
			for point: Array in row.get("outline", []):
				for index in 2: point[index] += offset[index]
			for key: String in ["tower_rect", "rect"]:
				if not row.has(key): continue
				for index in 4: row[key][index] += offset.x if index % 2 == 0 else offset.y
	for row: Dictionary in result.get("clock_hands", []):
		var offset: Vector3 = placement.city_offset(str(row.part))
		for index in 3: row.pivot[index] += offset[index]
	for row: Dictionary in result.get("anchor_seats", []):
		var offset: Vector3 = placement.source_offset(str(row.source_owner))
		for rect: Array in row.pieces:
			for index in 4: rect[index] += offset.x if index % 2 == 0 else offset.y
		row.bottom += offset.z
		row.top += offset.z
	return result
