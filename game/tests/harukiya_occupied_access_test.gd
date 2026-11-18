extends "res://tests/harukiya_occupied_services_test.gd"
## Focused occupied access renewal; inherited mass/game contracts remain NOT_RUN.
func _required_service_contracts() -> Array:
	return ["occupied_gallery_backstage_access","occupied_service_custody"]

func _opposition_programme() -> void:
	# Parent construction/seating/safety stays intact. Do not call its mass programme.
	stage="focused_access_player_refuge"
	var route: Node3D=routes.nadia_quell
	world.player.set_mouse_released(false)
	var approach: PackedInt64Array=route.graph.get_id_path(int(route.identities.street),int(route.identities.bar_pool_interaction))
	if not _check(not approach.is_empty(),"original player has connected focused access refuge route"):return
	for point: int in approach:
		if not await _walk_player(route.graph.get_point_position(point),str(route.identities.find_key(point))):return
	if not _check(_all_occupied() and _queue_drained(),"focused access starts with original18 occupied and queues drained"):return
	entry_door=world.bar_region.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if not _check(is_instance_valid(entry_door),"actual original entry door retained for focused safety observer"):return
	entry_door_id=entry_door.get_instance_id()
	programme_started=Time.get_ticks_msec()
	service_started=Time.get_ticks_msec()
	service_active=true
	service_civil=clock.day_info().duplicate(true)
	service_node="pool_interaction"
	service_people.clear()
	for identity: String in routes:
		service_people[identity]={"owner":routes[identity].get_instance_id(),"actor":routes[identity].actor.get_instance_id()}
	if not _check(service_people.size()==18,"exact18 original occupied access witnesses"):return
	details.services={"started_after_mass_return":false,"mass_programme_executed":false,"seconds_limit":SERVICE_SECONDS,"civil":service_civil,"minute":clock.minute_of_day(),"before":_crowd_snapshot(),"legs":[],"games":{},"captures":[],"inputs":"original directional player walking only; counter and game input not replayed"}
	if _service_context():await _occupied_access()
	if failures.is_empty():
		_check(_service_context() and _queue_drained() and squeeze_witness.snapshot().active.is_empty(),"focused occupied access ends with exact18, drained queues and no active squeeze")
		details.services.after=_crowd_snapshot()
		_contract("occupied_service_custody",failures.is_empty())
	service_active=false

func _decorate_result(result: Dictionary) -> void:
	super._decorate_result(result)
	result.suite="HarukiyaOccupiedAccessTest"
	result.scope="Focused renewal: inherited exact original18 prebirth construction and real Stacy/Lily staff, frozen pre-death Friday21:00, original player walks street-to-pool refuge then actual occupied backstage/stage/gallery/pool route with inherited native-support observation and continuous occupied identity/safety checks. Drained passage/squeeze and preview cleanup required. Mass departures/returns, counter response, darts and pool actions are NOT replayed or promoted; their original NOT_RUN fields remain. No natural attendance, new whole-cast cloth fit, cost, save/Continue, play or artistic acceptance claim."
	result.fixture.mass_programme_executed=false
	result.fixture.required_contracts=_required_service_contracts()
	result.fixture.focused_renewal=true
