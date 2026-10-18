extends "res://scripts/building/orison_v2_runtime_root.gd"

func _profile_mark(label: String) -> void:
	var events: Array=Engine.get_meta("v2_startup_profile",[])
	events.append({"label":label,"us":Time.get_ticks_usec()})
	Engine.set_meta("v2_startup_profile",events)
func _ready() -> void:
	_profile_mark("orison_v2_runtime_root._ready:enter")
	# Refuse the source boundary before creating campaign services, imported
	# geometry or any actor. Child _ready errors cannot close startup for us.
	_profile_mark("orison_v2_runtime_root._ready:3 if not preload(\"res://scripts/building/orison_v2_street_frame.gd\").valid_source_header(_read_street_")
	if not preload("res://scripts/building/orison_v2_street_frame.gd").valid_source_header(_read_street_frame()):
		startup_failed = true
		startup_failure_reason = "missing or invalid street coordinate frame"
		return
	var started := Time.get_ticks_usec()
	_profile_mark("orison_v2_runtime_root._ready:8 var contact_precision := preload(\"res://scripts/building/orison_v2_contact_precision.gd\").new()")
	var contact_precision := preload("res://scripts/building/orison_v2_contact_precision.gd").new()
	contact_precision.name="V2ContactPrecision"
	_profile_mark("orison_v2_runtime_root._ready:10 add_child(contact_precision)")
	add_child(contact_precision)
	campaign_clock = CampaignClock.new()
	_profile_mark("orison_v2_runtime_root._ready:12 if not campaign_clock.bind_state():")
	if not campaign_clock.bind_state():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: valid campaign calendar required")
		return
	frame_contract = FrameContract.load_default()
	_profile_mark("orison_v2_runtime_root._ready:17 if not frame_contract.errors.is_empty():")
	if not frame_contract.errors.is_empty():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: invalid shared-frame contract: %s" %
				[frame_contract.errors])
		return
	corruption_lineages = LineageRegistry.new()
	_profile_mark("orison_v2_runtime_root._ready:23 if not corruption_lineages.load_registry():")
	if not corruption_lineages.load_registry():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: invalid corruption lineage registry")
		return
	add_to_group("building_root")
	add_to_group("orison_v2_runtime")
	_profile_mark("orison_v2_runtime_root._ready:29 var atmosphere := Atmosphere.new()")
	var atmosphere := Atmosphere.new()
	atmosphere.name = "WakingAtmosphere"
	_profile_mark("orison_v2_runtime_root._ready:31 add_child(atmosphere)")
	add_child(atmosphere)
	day_night_director = atmosphere.director
	_blockout = BLOCKOUT.instantiate()
	_blockout.set_script(load("res://tests/_v2_startup_profile_blockout.gd"))
	_blockout.show_clearance_anchors = false
	_blockout.show_reservation_volumes = false
	_blockout.production_materials = true
	_exterior_resolver = ExteriorResolver.load_default()
	_connection = WorldConnection.prepare(
			WorldConnection.read_object(_blockout.layout_path),
			WorldConnection.read_object(ExteriorCell.GEOMETRY_PATH),
			_exterior_resolver, WorldConnection.read_object(WorldConnection.CONFIG_PATH))
	if _connection.is_empty():
		_blockout.free()
		_blockout = null
		startup_failed = true
		push_error("ORISON V2 RUNTIME: front-door world connection refused")
		return
	_blockout.transform = _connection.interior_transform
	_blockout.space_geometry_exclusions.assign([_connection.excluded_space, "F01_REAR_APRON"])
	_profile_mark("orison_v2_runtime_root._ready:50 add_child(_blockout)")
	add_child(_blockout)
	_profile_mark("orison_v2_runtime_root._ready:51 if not _blockout.failures.is_empty():")
	if not _blockout.failures.is_empty():
		startup_failed = true
		return
	layout = _blockout.layout
	_profile_mark("orison_v2_runtime_root._ready:55 var service_alley := preload(\"res://scripts/building/orison_v2_service_alley.gd\").new()")
	var service_alley := preload("res://scripts/building/orison_v2_service_alley.gd").new()
	service_alley.name = "ServiceAlley"
	_blockout.add_child(service_alley)
	for level: Dictionary in layout.get("levels", []):
		floor_nodes[str(level.id)] = _blockout
	adapter = Adapter.new(_blockout)
	_profile_mark("orison_v2_runtime_root._ready:61 if not adapter.resolves_required_uniquely():")
	if not adapter.resolves_required_uniquely():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: unresolved or duplicate required anchor")
		return
	_profile_mark("orison_v2_runtime_root._ready:65 var cues := CUES.new()")
	var cues := CUES.new()
	cues.show_bed_context = false
	cues.show_terminal_context = false
	cues.show_floor_context = false
	cues.show_portal_masses = false
	cues.show_route_bands = false
	cues.show_light_pools = false  # Accord 15: every lumen has a fixture; the cue pools are development aids
	_blockout.add_child(cues)
	_profile_mark("orison_v2_runtime_root._ready:73 var wayfinding := preload(\"res://scripts/building/orison_v2_wayfinding.gd\").new()")
	var wayfinding := preload("res://scripts/building/orison_v2_wayfinding.gd").new()
	wayfinding.name = "Wayfinding"
	_blockout.add_child(wayfinding)
	_profile_mark("orison_v2_runtime_root._ready:76 if not wayfinding.mount(_blockout.layout):")
	if not wayfinding.mount(_blockout.layout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: incomplete stair wayfinding")
		return
	_profile_mark("orison_v2_runtime_root._ready:80 if not adapter.install_acoustic_overrides([")
	if not adapter.install_acoustic_overrides([
			"F02_A_MAIN_VANTRY_POINT", "F02_A_MONITOR_01",
			"F04_B_MONITOR_01", "F03_B_RADIATOR_01"]):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: acoustic binding failed")
		return
	_profile_mark("orison_v2_runtime_root._ready:86 _compose_authorities()")
	_compose_authorities()
	if startup_failed:
		return
	elevator = preload("res://scripts/building/orison_v2_elevator.gd").new().mount(adapter, layout)
	if elevator == null:
		startup_failed = true
		push_error("V2 passenger lift could not be composed")
		return
	_profile_mark("orison_v2_runtime_root._ready:94 var lift_drive := preload(\"res://scripts/building/orison_v2_lift_drive.gd\").new()")
	var lift_drive := preload("res://scripts/building/orison_v2_lift_drive.gd").new()
	var porter_board := adapter.resolve("LobbyPorterBoard") as OtisProp
	if porter_board==null or not porter_board.bind_native_lift(elevator as OrisonElevator):
		startup_failed=true
		push_error("V2 porter dispatch could not bind the passenger lift")
		return
	_profile_mark("orison_v2_runtime_root._ready:100 if not lift_drive.configure(elevator as OrisonElevator) or not adapter.mount_consumer(\"ROOF_LIFT_DRI")
	if not lift_drive.configure(elevator as OrisonElevator) or not adapter.mount_consumer("ROOF_LIFT_DRIVE",lift_drive):
		lift_drive.free()
		startup_failed = true
		push_error("V2 guarded lift drive could not be composed")
		return
	_profile_mark("orison_v2_runtime_root._ready:105 if not preload(\"res://scripts/building/orison_v2_ventilation.gd\").new().mount(adapter,layout):")
	if not preload("res://scripts/building/orison_v2_ventilation.gd").new().mount(adapter,layout):
		startup_failed = true
		push_error("V2 shared ventilation could not be composed")
		return
	_profile_mark("orison_v2_runtime_root._ready:109 var roof_drainage:=preload(\"res://scripts/building/orison_v2_roof_drainage.gd\").new()")
	var roof_drainage:=preload("res://scripts/building/orison_v2_roof_drainage.gd").new()
	_profile_mark("orison_v2_runtime_root._ready:110 if not roof_drainage.mount(self):")
	if not roof_drainage.mount(self):
		startup_failed=true
		push_error("ORISON V2 RUNTIME: roof drainage refused: %s" % [roof_drainage.errors])
		return
	_profile_mark("orison_v2_runtime_root._ready:114 var fixed_lighting := preload(\"res://scripts/building/orison_v2_native_fixed_lighting.gd\").new()")
	var fixed_lighting := preload("res://scripts/building/orison_v2_native_fixed_lighting.gd").new()
	_profile_mark("orison_v2_runtime_root._ready:115 if not fixed_lighting.mount(self):")
	if not fixed_lighting.mount(self):
		startup_failed = true
		push_error("V2 native fixed lighting refused: %s" % [fixed_lighting.errors])
		return
	adapter.root.set_meta("v2_native_fixed_lighting_factory", fixed_lighting)
	_profile_mark("orison_v2_runtime_root._ready:120 var front_lighting := preload(\"res://scripts/building/orison_v2_native_front_lighting.gd\").new()")
	var front_lighting := preload("res://scripts/building/orison_v2_native_front_lighting.gd").new()
	_profile_mark("orison_v2_runtime_root._ready:121 if not front_lighting.mount(self):")
	if not front_lighting.mount(self):
		startup_failed = true
		push_error("V2 front lighting refused: %s" % [front_lighting.errors])
		return
	adapter.root.set_meta("v2_native_front_lighting_factory",front_lighting)
	_profile_mark("orison_v2_runtime_root._ready:126 var work_lights := preload(\"res://scripts/building/orison_v2_native_service_work_lights.gd\").new()")
	var work_lights := preload("res://scripts/building/orison_v2_native_service_work_lights.gd").new()
	_profile_mark("orison_v2_runtime_root._ready:127 if not work_lights.mount(self,fixed_lighting,adapter.root.get_meta(\"v2_native_service_instruments\"))")
	if not work_lights.mount(self,fixed_lighting,adapter.root.get_meta("v2_native_service_instruments")):
		startup_failed=true
		push_error("V2 service work lights refused: %s" % [work_lights.errors])
		return
	adapter.root.set_meta("v2_native_service_work_lights",work_lights)
	_profile_mark("orison_v2_runtime_root._ready:132 var cage_apertures := preload(\"res://scripts/building/orison_v2_cage_light_apertures.gd\").new()")
	var cage_apertures := preload("res://scripts/building/orison_v2_cage_light_apertures.gd").new()
	_profile_mark("orison_v2_runtime_root._ready:133 if not cage_apertures.setup(self,light_rig):")
	if not cage_apertures.setup(self,light_rig):
		startup_failed=true
		push_error("V2 native cage-light aperture refused: %s" % [cage_apertures.errors])
		return
	adapter.root.set_meta("v2_cage_light_apertures",cage_apertures)
	_profile_mark("orison_v2_runtime_root._ready:138 var lamp_air := preload(\"res://scripts/building/orison_v2_lamp_atmosphere.gd\").new()")
	var lamp_air := preload("res://scripts/building/orison_v2_lamp_atmosphere.gd").new()
	lamp_air.name = "LampAtmosphere"
	_profile_mark("orison_v2_runtime_root._ready:140 add_child(lamp_air)")
	add_child(lamp_air)
	_profile_mark("orison_v2_runtime_root._ready:141 if not lamp_air.setup(player, atmosphere.environment):")
	if not lamp_air.setup(player, atmosphere.environment):
		startup_failed = true
		push_error("V2 lamp optical state could not be restored")
		return
	_profile_mark("orison_v2_runtime_root._ready:145 preload(\"res://scripts/building/orison_v2_owner_building_finishes.gd\").new().apply(self)")
	preload("res://scripts/building/orison_v2_owner_building_finishes.gd").new().apply(self)
	_profile_mark("orison_v2_runtime_root._ready:146 preload(\"res://scripts/building/v2_legacy_material_stock.gd\").apply(self)")
	preload("res://scripts/building/v2_legacy_material_stock.gd").apply(self)
	_profile_mark("orison_v2_runtime_root._ready:147 var embedded_stock := preload(\"res://scripts/building/v2_embedded_surface_stock.gd\").new()")
	var embedded_stock := preload("res://scripts/building/v2_embedded_surface_stock.gd").new()
	embedded_stock.name = "V2EmbeddedSurfaceStock"; add_child(embedded_stock)
	_profile_mark("orison_v2_runtime_root._ready:149 var uv_policy := preload(\"res://scripts/building/orison_v2_uv_material_policy.gd\").new()")
	var uv_policy := preload("res://scripts/building/orison_v2_uv_material_policy.gd").new()
	uv_policy.name = "V2UVMaterialPolicy"; add_child(uv_policy)
	uv_policy.setup(self)
	atmosphere.bind_weather(self)
	_profile_mark("orison_v2_runtime_root._ready:153 _compose_debug_controls()")
	_compose_debug_controls()
	get_node("CaretakerNotebook").debug = building_debug
	_profile_mark("orison_v2_runtime_root._ready:155 var room_reflections := preload(\"res://scripts/building/orison_v2_room_reflections.gd\").new()")
	var room_reflections := preload("res://scripts/building/orison_v2_room_reflections.gd").new()
	room_reflections.name="V2RoomReflections"
	_profile_mark("orison_v2_runtime_root._ready:157 add_child(room_reflections)")
	add_child(room_reflections)
	_profile_mark("orison_v2_runtime_root._ready:158 if not room_reflections.setup(self):")
	if not room_reflections.setup(self):
		startup_failed=true
		push_error("V2 room reflection layout could not be composed")
		return
	startup_ms = float(Time.get_ticks_usec() - started) / 1000.0
	print("[ORISON V2 RUNTIME] ready startup_ms=%.3f" % startup_ms)

	_profile_mark("orison_v2_runtime_root._ready:end")
func _compose_authorities() -> void:
	_profile_mark("orison_v2_runtime_root._compose_authorities:enter")
	objective_tracker = ObjectiveTracker.new()
	objective_tracker.name = "ObjectiveTracker"
	objective_tracker.presentation_enabled = false
	_profile_mark("orison_v2_runtime_root._compose_authorities:4 add_child(objective_tracker)")
	add_child(objective_tracker)
	work_orders = WorkOrders.new()
	work_orders.name = "WorkOrders"
	work_orders.setup(objective_tracker)
	work_orders.bind_job_library(MaintenanceJobLibrary.load_default())
	_profile_mark("orison_v2_runtime_root._compose_authorities:9 add_child(work_orders)")
	add_child(work_orders)
	maintenance_inventory = MaintenanceInventory.new()
	maintenance_inventory.name = "MaintenanceInventory"
	maintenance_inventory.setup()
	_profile_mark("orison_v2_runtime_root._compose_authorities:13 add_child(maintenance_inventory)")
	add_child(maintenance_inventory)
	_profile_mark("orison_v2_runtime_root._compose_authorities:14 _compose_vantry()")
	_compose_vantry()
	_profile_mark("orison_v2_runtime_root._compose_authorities:15 var mail_bank := MailBankProp.new()")
	var mail_bank := MailBankProp.new()
	mail_bank.set_meta("v2_mail_bank_visuals", true)
	_profile_mark("orison_v2_runtime_root._compose_authorities:17 _mount(\"LobbyMailBank\", mail_bank)")
	_mount("LobbyMailBank", mail_bank)
	_profile_mark("orison_v2_runtime_root._compose_authorities:18 if not mail_bank.get_meta(\"v2_native_mail_bank\", false):")
	if not mail_bank.get_meta("v2_native_mail_bank", false):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: native mail bank mount failed")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:22 _mount(\"LobbyPorterBoard\", OtisProp.new())")
	_mount("LobbyPorterBoard", OtisProp.new())
	_profile_mark("orison_v2_runtime_root._compose_authorities:23 var tank_ballcock := RoofTankBallcockProp.new()")
	var tank_ballcock := RoofTankBallcockProp.new()
	tank_ballcock.prop_type = "tank_ballcock"
	_profile_mark("orison_v2_runtime_root._compose_authorities:25 _mount(\"ROOF_TANK_BALLCOCK\", tank_ballcock)")
	_mount("ROOF_TANK_BALLCOCK", tank_ballcock)
	_profile_mark("orison_v2_runtime_root._compose_authorities:26 _compose_service_round_props()")
	_compose_service_round_props()
	if startup_failed: return
	_profile_mark("orison_v2_runtime_root._compose_authorities:28 if not DomesticDoors.new().mount(adapter, layout):")
	if not DomesticDoors.new().mount(adapter, layout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: domestic door mounting refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:32 if not preload(\"res://scripts/building/orison_v2_upper_floor_doors.gd\").new().mount(adapter, layout)")
	if not preload("res://scripts/building/orison_v2_upper_floor_doors.gd").new().mount(adapter, layout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: upper floor door mounting refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:36 var fittings := DomesticFittings.new()")
	var fittings := DomesticFittings.new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:37 if not fittings.mount(adapter):")
	if not fittings.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: domestic fittings refused: %s" % [fittings.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:41 var completion := preload(\"res://scripts/building/orison_v2_completion_interiors.gd\").new()")
	var completion := preload("res://scripts/building/orison_v2_completion_interiors.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:42 if not completion.mount(adapter,layout,self):")
	if not completion.mount(adapter,layout,self):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: remaining interiors refused: %s" % [completion.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:46 preload(\"res://scripts/building/orison_v2_reading_furniture.gd\").mount(adapter,layout)")
	preload("res://scripts/building/orison_v2_reading_furniture.gd").mount(adapter,layout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:47 preload(\"res://scripts/building/orison_v2_public_furnishings.gd\").mount(adapter,layout)")
	preload("res://scripts/building/orison_v2_public_furnishings.gd").mount(adapter,layout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:48 preload(\"res://scripts/building/orison_v2_door_casings.gd\").mount(adapter,layout)")
	preload("res://scripts/building/orison_v2_door_casings.gd").mount(adapter,layout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:49 preload(\"res://scripts/building/orison_v2_window_joinery.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_window_joinery.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:50 preload(\"res://scripts/building/orison_v2_exterior_masonry.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_exterior_masonry.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:51 preload(\"res://scripts/building/orison_v2_front_restoration.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_front_restoration.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:52 preload(\"res://scripts/building/orison_v2_fire_repairs.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_fire_repairs.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:53 preload(\"res://scripts/building/orison_v2_roof_edge_support.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_edge_support.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:54 preload(\"res://scripts/building/orison_v2_roof_bulkhead_caps.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_bulkhead_caps.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:55 preload(\"res://scripts/building/orison_v2_roof_service_weathering.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_service_weathering.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:56 preload(\"res://scripts/building/orison_v2_light_court_structure.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_light_court_structure.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:57 preload(\"res://scripts/building/orison_v2_light_court_skylight.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_light_court_skylight.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:58 preload(\"res://scripts/building/orison_v2_court_roof_bridge.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_court_roof_bridge.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:59 preload(\"res://scripts/building/orison_v2_roof_public_weathering.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_public_weathering.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:60 preload(\"res://scripts/building/orison_v2_roof_base_flashings.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_base_flashings.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:61 preload(\"res://scripts/building/orison_v2_roof_membrane.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_membrane.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:62 preload(\"res://scripts/building/orison_v2_front_court_roof.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_front_court_roof.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:63 preload(\"res://scripts/building/orison_v2_foundations.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_foundations.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:64 preload(\"res://scripts/building/orison_v2_ceiling_top_closures.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_ceiling_top_closures.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:65 preload(\"res://scripts/building/orison_v2_ground_core_transfer.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_ground_core_transfer.gd").mount(_blockout)
	# Dossier slice 52: positional wear decals in the baths and halls.
	_profile_mark("orison_v2_runtime_root._compose_authorities:67 if not preload(\"res://scripts/building/orison_v2_positional_wear.gd\").mount(_blockout):")
	if not preload("res://scripts/building/orison_v2_positional_wear.gd").mount(_blockout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: positional wear refused")
	_profile_mark("orison_v2_runtime_root._compose_authorities:70 preload(\"res://scripts/building/orison_v2_rear_wing_a_support.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_rear_wing_a_support.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:71 preload(\"res://scripts/building/orison_v2_rear_wing_c_support.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_rear_wing_c_support.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:72 preload(\"res://scripts/building/orison_v2_first_upper_hall_seats.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_first_upper_hall_seats.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:73 preload(\"res://scripts/building/orison_v2_upper_wall_seats.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_upper_wall_seats.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:74 preload(\"res://scripts/building/orison_v2_remaining_upper_transfers.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_remaining_upper_transfers.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:75 preload(\"res://scripts/building/orison_v2_house_tank.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_house_tank.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:76 preload(\"res://scripts/building/orison_v2_roof_coping.gd\").mount(_blockout)")
	preload("res://scripts/building/orison_v2_roof_coping.gd").mount(_blockout)
	_profile_mark("orison_v2_runtime_root._compose_authorities:77 if not preload(\"res://scripts/building/orison_v2_basement.gd\").new().mount(adapter):")
	if not preload("res://scripts/building/orison_v2_basement.gd").new().mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: basement services refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:81 if not _compose_hot_water():")
	if not _compose_hot_water():
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:83 var furniture := DomesticFurniture.new()")
	var furniture := DomesticFurniture.new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:84 if not preload(\"res://scripts/building/orison_v2_laundry.gd\").new().mount(adapter):")
	if not preload("res://scripts/building/orison_v2_laundry.gd").new().mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: laundry mounting refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:88 if not furniture.mount(adapter):")
	if not furniture.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: furniture refused: %s" % [furniture.errors])
		return
	# All replacement fittings/furniture now exist. Standalone gray-box scenes
	# retain their masses; the playable apartment has one physical owner per use.
	for identity in ["F02_B_FABRIC_TABLE_MASS", "F02_B_KITCHEN_RUN_MASS",
			"F02_B_BED_MASS", "F02_B_STORAGE_MASS", "F02_B_BATH_MASS"]:
		_retire_blockout_fixture(identity)
	if startup_failed:
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:99 var lighting := RoomLighting.new()")
	var lighting := RoomLighting.new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:100 if not lighting.mount(adapter, self):")
	if not lighting.mount(adapter, self):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: room lighting refused: %s" % [lighting.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:104 if not lighting.mount_roof(adapter,self):")
	if not lighting.mount_roof(adapter,self):
		startup_failed=true
		push_error("ORISON V2 RUNTIME: roof plant lighting refused: %s" % [lighting.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:108 if not preload(\"res://scripts/building/orison_v2_reading_nook.gd\").mount(adapter):")
	if not preload("res://scripts/building/orison_v2_reading_nook.gd").mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: original reading nook refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:112 var task_lamps := preload(\"res://scripts/building/orison_v2_task_lamp_installations.gd\").new()")
	var task_lamps := preload("res://scripts/building/orison_v2_task_lamp_installations.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:113 if not task_lamps.mount(adapter):")
	if not task_lamps.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: fitted task lamps refused: %s" % [task_lamps.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:117 var lamp_supply := preload(\"res://scripts/building/orison_v2_task_lamp_supply.gd\").new()")
	var lamp_supply := preload("res://scripts/building/orison_v2_task_lamp_supply.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:118 if not lamp_supply.mount(adapter):")
	if not lamp_supply.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: task-lamp supply refused: %s" % [lamp_supply.errors])
		return
	adapter.root.set_meta("v2_task_lamp_supply",lamp_supply)
	light_rig = LightRig.new()
	light_rig.name = "LightRig"
	light_rig.glow_intensity = get_node("WakingAtmosphere").environment.glow_intensity
	get_node("WakingAtmosphere").add_child(light_rig)
	_profile_mark("orison_v2_runtime_root._compose_authorities:127 var telephone := HouseSwitchboardProp.new()")
	var telephone := HouseSwitchboardProp.new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:128 var line := HouseTelephoneNetwork.new()")
	var line := HouseTelephoneNetwork.new()
	line.name = "HouseTelephoneNetwork"
	_profile_mark("orison_v2_runtime_root._compose_authorities:130 add_child(line)")
	add_child(line)
	line.register_endpoint({"id": "F02_A_TELEPHONE", "extension": "2A"})
	telephone.bind_line(line)
	_profile_mark("orison_v2_runtime_root._compose_authorities:133 _mount(\"F01_HOUSE_TELEPHONE_BOARD\", telephone)")
	_mount("F01_HOUSE_TELEPHONE_BOARD", telephone)
	_profile_mark("orison_v2_runtime_root._compose_authorities:134 _mount(\"LobbyServiceDumbwaiter\", DumbwaiterProp.new())")
	_mount("LobbyServiceDumbwaiter", DumbwaiterProp.new())
	_profile_mark("orison_v2_runtime_root._compose_authorities:135 var terminal := preload(\"res://scripts/building/orison_v2_native_signal_terminal.gd\").new()")
	var terminal := preload("res://scripts/building/orison_v2_native_signal_terminal.gd").new()
	terminal.prop_type = "signal_terminal"
	_profile_mark("orison_v2_runtime_root._compose_authorities:137 _mount(\"F04_B_MONITOR_01\", terminal)")
	_mount("F04_B_MONITOR_01", terminal)
	_profile_mark("orison_v2_runtime_root._compose_authorities:138 if not terminal.native_ready:")
	if not terminal.native_ready:
		startup_failed = true
		push_error("ORISON V2 RUNTIME: native signal terminal refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:142 if not preload(\"res://scripts/building/orison_v2_task_lamp_installations.gd\").fit_terminal(adapter, ")
	if not preload("res://scripts/building/orison_v2_task_lamp_installations.gd").fit_terminal(adapter, terminal):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: task lamp/terminal fit refused")
		return
	player = PlayerController.new()
	player.name = "Player"
	player.position = _connection.arrival.position
	_profile_mark("orison_v2_runtime_root._compose_authorities:149 add_child(player)")
	add_child(player)
	_profile_mark("orison_v2_runtime_root._compose_authorities:150 if not _compose_exterior():")
	if not _compose_exterior():
		startup_failed = true
		push_error("ORISON V2 RUNTIME: exterior composition failed")
		return
	vantry_points.bind_player(player)
	service_set_carrier = ServiceSetCarrier.new()
	service_set_carrier.name = "ServiceSetCarrier"
	service_set_carrier.setup(player, player.camera, work_orders)
	player.carried_device = service_set_carrier
	player.set_lamp_enabled(true)
	call_interface = CallInterface.new()
	call_interface.name = "CallInterface"
	call_interface.world = _blockout
	_profile_mark("orison_v2_runtime_root._compose_authorities:163 add_child(call_interface)")
	add_child(call_interface)
	_profile_mark("orison_v2_runtime_root._compose_authorities:164 if not _compose_call_station(terminal):")
	if not _compose_call_station(terminal):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: invalid support desk anchors")
		return
	virus_director = VirusSoundDirector.new()
	virus_director.name = "VirusSoundDirector"
	virus_director.setup(self)
	_profile_mark("orison_v2_runtime_root._compose_authorities:171 add_child(virus_director)")
	add_child(virus_director)
	first_shift_director = FirstShiftDirector.new()
	first_shift_director.name = "FirstShiftDirector"
	first_shift_director.setup(self, objective_tracker, virus_director, work_orders)
	_profile_mark("orison_v2_runtime_root._compose_authorities:175 add_child(first_shift_director)")
	add_child(first_shift_director)
	_bind_first_shift_station()
	mina_gameplay = MinaCaseGameplay.new()
	mina_gameplay.name = "MinaCaseGameplay"
	mina_gameplay.setup(objective_tracker, work_orders)
	_profile_mark("orison_v2_runtime_root._compose_authorities:180 add_child(mina_gameplay)")
	add_child(mina_gameplay)
	_profile_mark("orison_v2_runtime_root._compose_authorities:181 if not preload(\"res://scripts/building/orison_v2_case_one_placement.gd\").new().mount(adapter, mina_g")
	if not preload("res://scripts/building/orison_v2_case_one_placement.gd").new().mount(adapter, mina_gameplay):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: incomplete case-one placement")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:185 var surface_props := preload(\"res://scripts/building/orison_v2_surface_props.gd\").new()")
	var surface_props := preload("res://scripts/building/orison_v2_surface_props.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:186 if not surface_props.mount(adapter):")
	if not surface_props.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: surface props refused: %s" % [surface_props.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:190 var bath_details := preload(\"res://scripts/building/orison_v2_bath_details.gd\").new()")
	var bath_details := preload("res://scripts/building/orison_v2_bath_details.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:191 if not bath_details.mount(adapter):")
	if not bath_details.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: bathroom details refused: %s" % [bath_details.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:195 var radios := preload(\"res://scripts/building/orison_v2_radios.gd\").new()")
	var radios := preload("res://scripts/building/orison_v2_radios.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:196 if not radios.mount(adapter):")
	if not radios.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: household radios refused: %s" % [radios.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:200 var projectors := preload(\"res://scripts/building/orison_v2_projectors.gd\").new()")
	var projectors := preload("res://scripts/building/orison_v2_projectors.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:201 if not projectors.mount(adapter):")
	if not projectors.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: apartment projectors refused: %s" % [projectors.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:205 var media_supply := preload(\"res://scripts/building/orison_v2_media_ac_supply.gd\").new()")
	var media_supply := preload("res://scripts/building/orison_v2_media_ac_supply.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:206 if not media_supply.mount(adapter):")
	if not media_supply.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: media AC supply refused: %s" % [media_supply.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:210 var battery_supply := preload(\"res://scripts/building/orison_v2_media_battery_supply.gd\").new()")
	var battery_supply := preload("res://scripts/building/orison_v2_media_battery_supply.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:211 if not battery_supply.mount(adapter):")
	if not battery_supply.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: media battery supply refused: %s" % [battery_supply.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:215 var accessories := preload(\"res://scripts/building/orison_v2_household_accessories.gd\").new()")
	var accessories := preload("res://scripts/building/orison_v2_household_accessories.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:216 if not accessories.mount(adapter):")
	if not accessories.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: household accessories refused: %s" % [accessories.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:220 var bookshelves := preload(\"res://scripts/building/orison_v2_bookshelves.gd\").new()")
	var bookshelves := preload("res://scripts/building/orison_v2_bookshelves.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:221 if not bookshelves.mount(adapter):")
	if not bookshelves.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: bookshelves refused: %s" % [bookshelves.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:225 var fire_service := preload(\"res://scripts/building/orison_v2_native_fire_service.gd\").new()")
	var fire_service := preload("res://scripts/building/orison_v2_native_fire_service.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:226 if not fire_service.mount(adapter,_blockout.layout):")
	if not fire_service.mount(adapter,_blockout.layout):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: fire service refused: %s" % [fire_service.errors])
		return
	adapter.root.set_meta("v2_native_fire_service",fire_service)
	_profile_mark("orison_v2_runtime_root._compose_authorities:231 var electrical_service := preload(\"res://scripts/building/orison_v2_native_electrical_service.gd\").n")
	var electrical_service := preload("res://scripts/building/orison_v2_native_electrical_service.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:232 if not electrical_service.mount(adapter):")
	if not electrical_service.mount(adapter):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: electrical service refused: %s" % [electrical_service.errors])
		return
	adapter.root.set_meta("v2_native_electrical_service",electrical_service)
	_profile_mark("orison_v2_runtime_root._compose_authorities:237 var electrical_connections := preload(\"res://scripts/building/orison_v2_native_electrical_connection")
	var electrical_connections := preload("res://scripts/building/orison_v2_native_electrical_connections.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:238 if not electrical_connections.mount(self,electrical_service):")
	if not electrical_connections.mount(self,electrical_service):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: electrical connections refused: %s" % [electrical_connections.errors])
		return
	adapter.root.set_meta("v2_native_electrical_connections",electrical_connections)
	_profile_mark("orison_v2_runtime_root._compose_authorities:243 var roof_supply := preload(\"res://scripts/building/orison_v2_roof_lighting_supply.gd\").new()")
	var roof_supply := preload("res://scripts/building/orison_v2_roof_lighting_supply.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:244 if not roof_supply.mount(self, electrical_service):")
	if not roof_supply.mount(self, electrical_service):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: roof lighting supply refused: %s" % [roof_supply.errors])
		return
	adapter.root.set_meta("v2_native_roof_lighting_supply", roof_supply)
	_profile_mark("orison_v2_runtime_root._compose_authorities:249 var front_supply := preload(\"res://scripts/building/orison_v2_front_lighting_supply.gd\").new()")
	var front_supply := preload("res://scripts/building/orison_v2_front_lighting_supply.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:250 if not front_supply.mount(self,electrical_service):")
	if not front_supply.mount(self,electrical_service):
		startup_failed = true
		push_error("V2 front supply refused: %s" % [front_supply.errors])
		return
	adapter.root.set_meta("v2_native_front_lighting_supply",front_supply)
	_profile_mark("orison_v2_runtime_root._compose_authorities:255 var front_trim := preload(\"res://scripts/building/orison_v2_front_trim_fittings.gd\").new()")
	var front_trim := preload("res://scripts/building/orison_v2_front_trim_fittings.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:256 if not front_trim.mount(self):")
	if not front_trim.mount(self):
		startup_failed = true
		push_error("V2 front trim fittings refused: %s" % [front_trim.errors])
		return
	adapter.root.set_meta("v2_native_front_trim_fittings",front_trim)
	_profile_mark("orison_v2_runtime_root._compose_authorities:261 var service_instruments := preload(\"res://scripts/building/orison_v2_native_service_instruments.gd\")")
	var service_instruments := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:262 if not service_instruments.mount(self):")
	if not service_instruments.mount(self):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: service instrument fabrication refused: %s" % [service_instruments.errors])
		return
	adapter.root.set_meta("v2_native_service_instruments",service_instruments)
	_profile_mark("orison_v2_runtime_root._compose_authorities:267 var bar_instruments := preload(\"res://scripts/building/orison_v2_native_service_instruments.gd\").new")
	var bar_instruments := preload("res://scripts/building/orison_v2_native_service_instruments.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:268 if not bar_instruments.mount(self,bar_instruments.BAR_PATH):")
	if not bar_instruments.mount(self,bar_instruments.BAR_PATH):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: bar instrument fabrication refused: %s" % [bar_instruments.errors])
		return
	adapter.root.set_meta("v2_native_bar_instruments",bar_instruments)
	for identity in ["F01_WATCHMAN_DETECTOR_BODY","F01_NIGHT_REGISTER_BODY",
			"F01_SIGNAL_REGISTER_BODY","F01_TOUR_KEY_GUARD_BODY"]:
		_retire_blockout_fixture(identity)
	mirror_renderer = PlanarMirrorRenderer.new()
	_profile_mark("orison_v2_runtime_root._compose_authorities:277 add_child(mirror_renderer)")
	add_child(mirror_renderer)
	mirror_renderer.setup(player.camera)
	chirp_hunt = ChirpHunt.new()
	chirp_hunt.name = "ChirpHunt"
	_profile_mark("orison_v2_runtime_root._compose_authorities:281 add_child(chirp_hunt)")
	add_child(chirp_hunt)
	chirp_hunt.setup(vantry_points, work_orders, maintenance_inventory)
	var shell := get_tree().get_first_node_in_group("campaign_shell")
	var resolver := Callable(adapter, "resolve_return_anchor")
	if shell != null and shell.is_ancestor_of(self):
		core_loop = shell.call("bind_waking_services", work_orders, player, layout,
				null, null, resolver) as CoreLoopDirector
	else:
		core_loop = CoreLoopDirector.new()
		core_loop.name = "CoreLoopDirector"
		add_child(core_loop)
		core_loop.setup(work_orders, player, layout, resolver)
	mina_gameplay.bind_wake(core_loop)
	first_shift_director.bind_opening_report_offer(
			Callable(core_loop, "offer_opening_report"))
	service_round = ServiceRoundDirector.new()
	service_round.name = "ServiceRoundDirector"
	_profile_mark("orison_v2_runtime_root._compose_authorities:298 add_child(service_round)")
	add_child(service_round)
	service_round.setup(work_orders, _blockout, player, service_set_carrier)
	open_shift_ecosystem = preload("res://scripts/game/open_shift_radiator_ecosystem.gd").new()
	open_shift_ecosystem.name = "OpenShiftRadiatorEcosystem"
	_profile_mark("orison_v2_runtime_root._compose_authorities:302 add_child(open_shift_ecosystem)")
	add_child(open_shift_ecosystem)
	var open_shift_radiator := _blockout.get_node_or_null(
			ServiceRoundDirector.RADIATOR_ID) as RadiatorProp
	if open_shift_radiator:
		open_shift_radiator.bind_inventory(maintenance_inventory)
	_profile_mark("orison_v2_runtime_root._compose_authorities:307 _compose_observation_ledger()")
	_compose_observation_ledger()
	_profile_mark("orison_v2_runtime_root._compose_authorities:308 preload(\"res://scripts/building/orison_v2_furnishing_clearance.gd\").apply(self)")
	preload("res://scripts/building/orison_v2_furnishing_clearance.gd").apply(self)
	_profile_mark("orison_v2_runtime_root._compose_authorities:309 if not preload(\"res://scripts/building/orison_v2_window_treatments.gd\").mount(self):")
	if not preload("res://scripts/building/orison_v2_window_treatments.gd").mount(self):
		startup_failed=true;push_error("V2 window treatments refused");return
	mina_routine = preload("res://scripts/characters/orison_v2_mina_routine.gd").new()
	mina_routine.name = "MinaRoutine"
	_profile_mark("orison_v2_runtime_root._compose_authorities:313 add_child(mina_routine)")
	add_child(mina_routine)
	_profile_mark("orison_v2_runtime_root._compose_authorities:314 if not mina_routine.setup(self):")
	if not mina_routine.setup(self):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: Mina route composition refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:318 if not preload(\"res://scripts/building/orison_v2_case_one_placement.gd\").new().mount_captions(adapte")
	if not preload("res://scripts/building/orison_v2_case_one_placement.gd").new().mount_captions(adapter,mina_routine.actor):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: case caption subjects missing")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:322 var remote_captions := preload(\"res://scripts/cases/orison_v2_remote_caption_display.gd\").new()")
	var remote_captions := preload("res://scripts/cases/orison_v2_remote_caption_display.gd").new()
	remote_captions.name = "MinaRemoteCaptions"
	remote_captions.adapter = adapter
	_profile_mark("orison_v2_runtime_root._compose_authorities:325 add_child(remote_captions)")
	add_child(remote_captions)
	shop_simulation = ShopSimulation.new()
	shop_simulation.name = "ShopSimulation"
	_profile_mark("orison_v2_runtime_root._compose_authorities:328 add_child(shop_simulation)")
	add_child(shop_simulation)
	_profile_mark("orison_v2_runtime_root._compose_authorities:329 if not shop_simulation.setup(campaign_clock, resident_presence,")
	if not shop_simulation.setup(campaign_clock, resident_presence,
			exterior_cell.shop_bucket_registry, Callable(exterior_cell, "refresh_shop_presentation")):
		startup_failed = true
		return
	open_shift_ecosystem.setup(work_orders, open_shift_radiator,
			service_round, Callable(campaign_clock, "absolute_minutes"),
			observation_ledger, null, Callable(), "campaign_absolute_minutes")
	safety_net = SafetyNet.new()
	safety_net.name = "SafetyNet"
	safety_net.setup(player)
	safety_net.anchor = _connection.arrival.position
	_profile_mark("orison_v2_runtime_root._compose_authorities:340 add_child(safety_net)")
	add_child(safety_net)
	household_state = HouseholdState.new()
	household_state.name = "HouseholdState"
	_profile_mark("orison_v2_runtime_root._compose_authorities:343 add_child(household_state)")
	add_child(household_state)
	_profile_mark("orison_v2_runtime_root._compose_authorities:344 if not household_state.bind(adapter, get_node(\"V2RoomSwitches\") as SwitchSystem):")
	if not household_state.bind(adapter, get_node("V2RoomSwitches") as SwitchSystem):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: household save refused: %s" % [household_state.errors])
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:348 var economy := preload(\"res://scripts/game/caretaker_economy.gd\").new()")
	var economy := preload("res://scripts/game/caretaker_economy.gd").new()
	economy.name = "CaretakerEconomy"
	_profile_mark("orison_v2_runtime_root._compose_authorities:350 add_child(economy)")
	add_child(economy)
	_profile_mark("orison_v2_runtime_root._compose_authorities:351 var care := preload(\"res://scripts/building/orison_v2_caretaking.gd\").new()")
	var care := preload("res://scripts/building/orison_v2_caretaking.gd").new()
	care.name = "Caretaking"
	_profile_mark("orison_v2_runtime_root._compose_authorities:353 add_child(care)")
	add_child(care)
	_profile_mark("orison_v2_runtime_root._compose_authorities:354 if not economy.setup(work_orders) or not care.setup(_blockout,economy):")
	if not economy.setup(work_orders) or not care.setup(_blockout,economy):
		startup_failed = true
		push_error("ORISON V2 RUNTIME: caretaker ledger refused")
		return
	_profile_mark("orison_v2_runtime_root._compose_authorities:358 var notebook := preload(\"res://scripts/ui/caretaker_notebook.gd\").new()")
	var notebook := preload("res://scripts/ui/caretaker_notebook.gd").new()
	notebook.name = "CaretakerNotebook"
	notebook.player = player
	notebook.care = care
	notebook.economy = economy
	_profile_mark("orison_v2_runtime_root._compose_authorities:363 add_child(notebook)")
	add_child(notebook)
	_profile_mark("orison_v2_runtime_root._compose_authorities:364 preload(\"res://scripts/building/orison_v2_owner_finishes.gd\").new().apply_service_actors(self)")
	preload("res://scripts/building/orison_v2_owner_finishes.gd").new().apply_service_actors(self)

	_profile_mark("orison_v2_runtime_root._compose_authorities:end")
func _compose_exterior() -> bool:
	_profile_mark("orison_v2_runtime_root._compose_exterior:enter")
	shop_service = MaintenanceShopService.new()
	shop_service.name = "MaintenanceShopService"
	_profile_mark("orison_v2_runtime_root._compose_exterior:3 add_child(shop_service)")
	add_child(shop_service)
	shop_service.setup(maintenance_inventory, work_orders)
	_profile_mark("orison_v2_runtime_root._compose_exterior:5 if not shop_service.is_valid():")
	if not shop_service.is_valid():
		return false
	exterior_cell = ExteriorCell.new()
	exterior_cell.name = "StreetAndBodega"
	_profile_mark("orison_v2_runtime_root._compose_exterior:9 if not exterior_cell.configure_dependencies({\"player\": player,")
	if not exterior_cell.configure_dependencies({"player": player,
			"work_orders": work_orders, "maintenance_inventory": maintenance_inventory,
			"shop_service": shop_service, "spatial_resolver": _exterior_resolver,
			"geometry_source": _connection.geometry}):
		exterior_cell.free()
		exterior_cell = null
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:16 add_child(exterior_cell)")
	add_child(exterior_cell)
	if exterior_cell.startup_failed:
		return false
	if preload("res://scripts/building/orison_v2_bodega_frontage.gd").mount(exterior_cell,_blockout.architectural_materials)==null:
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:21 var front_pavement:=preload(\"res://scripts/building/orison_v2_front_pavement.gd\").new()")
	var front_pavement:=preload("res://scripts/building/orison_v2_front_pavement.gd").new()
	front_pavement.name="FrontPavement"
	_blockout.add_child(front_pavement)
	_profile_mark("orison_v2_runtime_root._compose_exterior:24 var ground:=preload(\"res://scripts/building/orison_v2_ground.gd\").new()")
	var ground:=preload("res://scripts/building/orison_v2_ground.gd").new()
	ground.name="Ground"
	_blockout.add_child(ground)
	_profile_mark("orison_v2_runtime_root._compose_exterior:27 var city_foundations:=preload(\"res://scripts/building/orison_v2_city_foundations.gd\").new()")
	var city_foundations:=preload("res://scripts/building/orison_v2_city_foundations.gd").new()
	city_foundations.name="CityFoundations"
	_blockout.add_child(city_foundations)
	_profile_mark("orison_v2_runtime_root._compose_exterior:30 var receiving := preload(\"res://scripts/building/orison_v2_bodega_receiving.gd\").new()")
	var receiving := preload("res://scripts/building/orison_v2_bodega_receiving.gd").new()
	receiving.name = "BodegaReceiving"
	_profile_mark("orison_v2_runtime_root._compose_exterior:32 if not receiving.configure(exterior_cell):")
	if not receiving.configure(exterior_cell):
		receiving.free()
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:35 add_child(receiving)")
	add_child(receiving)
	if receiving.startup_failed: return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:37 var bodega_power:=preload(\"res://scripts/building/orison_v2_bodega_power.gd\").new()")
	var bodega_power:=preload("res://scripts/building/orison_v2_bodega_power.gd").new()
	bodega_power.name="BodegaPower"
	_profile_mark("orison_v2_runtime_root._compose_exterior:39 if not bodega_power.configure(exterior_cell):")
	if not bodega_power.configure(exterior_cell):
		bodega_power.free()
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:42 add_child(bodega_power)")
	add_child(bodega_power)
	if bodega_power.startup_failed:return false
	if preload("res://scripts/building/orison_v2_bodega_fittings.gd").mount(exterior_cell,_blockout.architectural_materials)==null:
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:46 var street_boundaries := StreetBoundaries.new()")
	var street_boundaries := StreetBoundaries.new()
	street_boundaries.name = "StreetBoundaries"
	_profile_mark("orison_v2_runtime_root._compose_exterior:48 add_child(street_boundaries)")
	add_child(street_boundaries)
	passage_region = PassageRegion.new()
	passage_region.name = "VantryArcade"
	_profile_mark("orison_v2_runtime_root._compose_exterior:51 if not passage_region.configure(shop_service):")
	if not passage_region.configure(shop_service):
		passage_region.free()
		passage_region = null
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:55 add_child(passage_region)")
	add_child(passage_region)
	if passage_region.startup_failed:
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:58 if not passage_region.enable_residency(player, _blockout, layout):")
	if not passage_region.enable_residency(player, _blockout, layout):
		return false
	bar_region = BarRegion.new()
	bar_region.name = "Harukiya"
	_profile_mark("orison_v2_runtime_root._compose_exterior:62 add_child(bar_region)")
	add_child(bar_region)
	if bar_region.startup_failed:
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:65 if not passage_region.receiving_row.bind_registered_graph():")
	if not passage_region.receiving_row.bind_registered_graph():
		return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:67 var city_shells := preload(\"res://scripts/building/orison_v2_city_shells.gd\").new()")
	var city_shells := preload("res://scripts/building/orison_v2_city_shells.gd").new()
	city_shells.name = "CityShells"
	_profile_mark("orison_v2_runtime_root._compose_exterior:69 add_child(city_shells)")
	add_child(city_shells)
	_profile_mark("orison_v2_runtime_root._compose_exterior:70 if not preload(\"res://scripts/building/orison_v2_front_facade.gd\").mount(self):return false")
	if not preload("res://scripts/building/orison_v2_front_facade.gd").mount(self):return false
	if preload("res://scripts/building/orison_v2_street_paving_details.gd").mount(self) == null:return false
	_profile_mark("orison_v2_runtime_root._compose_exterior:72 var signage := preload(\"res://scripts/building/orison_v2_native_signage.gd\").new()")
	var signage := preload("res://scripts/building/orison_v2_native_signage.gd").new()
	_profile_mark("orison_v2_runtime_root._compose_exterior:73 if not signage.install(self):")
	if not signage.install(self):
		push_error("V2 SIGNAGE: %s" % [signage.errors])
		return false
	adapter.root.set_meta("v2_native_signage",signage)
	return bool(exterior_cell.set_route_guides_visible(false).get("ok", false))

	_profile_mark("orison_v2_runtime_root._compose_exterior:end")
