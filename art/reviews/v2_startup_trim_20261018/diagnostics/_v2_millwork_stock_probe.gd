extends "res://scripts/building/orison_v2_blockout.gd"
func _ready() -> void:
	layout=_load_layout(layout_path)
	_validate_layout()
	if not failures.is_empty():return
	_build_palette()
	_build_spaces()
func _build_spaces() -> void:
	var dims: Dictionary = layout.dimensions
	var clear_h := float(dims.clear_height)
	var slab_t := float(dims.slab_thickness)
	var soffits:=preload("res://scripts/building/orison_v2_platform_soffits.gd")
	var floor_owners: Array[Dictionary]=soffits.ceiling_owners(layout,level_y,space_geometry_exclusions,show_ceilings)
	# Platforms retain their already accepted underside ownership. Room slabs
	# fill only exposed gaps, and earlier room slabs own overlapping footprints.
	for platform: Dictionary in layout.get("platforms",[]):floor_owners.append_array(soffits.floor_owners(platform,layout,level_y))
	for space: Dictionary in layout.spaces:
		var rect: Array = space.rect
		var y := float(level_y[space.level])
		var cls := str(space.get("class", "unresolved"))
		var parent := Node3D.new()
		parent.name = str(space.id)
		parent.set_meta("purpose", str(space.get("purpose", "")))
		parent.set_meta("room_id", str(space.id))
		add_child(parent)
		if str(space.id) in space_geometry_exclusions:
			parent.set_meta("geometry_owned_by_exterior", true)
			continue
		if not bool(space.get("no_floor", false)):
			_build_slab(parent, "Floor", rect, y - slab_t * .5, slab_t, cls, true)
			if production_materials:
				soffits.append(parent.get_node("Floor"),space,layout,level_y,floor_owners,architectural_materials.material_for("Ceiling",cls),true)
				floor_owners.append_array(soffits.floor_owners(space,layout,level_y))
		if show_ceilings and not bool(space.get("no_ceiling", false)):
			_build_slab(parent, "Ceiling", rect, y + clear_h + slab_t * .5, slab_t, cls, false)
		if not bool(space.get("open_shell", false)):
			# Open stair volumes have no ceiling slab to close the 200 mm
			# storey band. Their walls must continue to the next walking level.
			var wall_h := float(dims.floor_to_floor) if bool(space.get("no_ceiling", false)) else clear_h
			_build_space_outline(parent, str(space.id), rect, y, wall_h, cls,
					space.get("wall_sides", ["south", "north", "west", "east"]))
			for index in space.get("wall_extensions", []).size():
				var extension: Dictionary = space.wall_extensions[index]
				var side := str(extension.side)
				var edge := _wall_edge(rect, side)
				_wall_with_openings(parent, str(space.id), side.capitalize() + "Extension%02d" % index,
						"z" if side in ["west","east"] else "x", edge.x,
						float(extension.start), float(extension.end), y, wall_h,
						float(layout.dimensions.partition_wall), cls)
