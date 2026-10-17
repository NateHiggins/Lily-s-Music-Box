extends RefCounted
## Physical completion of the existing job, using its original lifecycle owner.
## Lobby/boiler comparison callbacks are fixtures here, not played route proof.

func _aim(bench: Node3D,prop: Node3D,player: Node3D,part: Node3D,offset: Vector3) -> void:
	var at: Vector3=part.global_position+prop.global_basis*Vector3(0,0,-.045)
	player.camera.global_position=at+prop.global_basis*offset
	player.camera.look_at(at)
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame

func _valve(bench: Node3D,prop: Node3D,player: Node3D,driver: Node3D,value: float,failures: Array) -> void:
	await _aim(bench,prop,player,prop._wheel,Vector3(0,.15,-.35))
	driver._click(player)
	if not player._grab.active() or not prop._supply_held:
		failures.append("repair actual supply grip");return
	driver._drag_to(player,value*TAU*3.5)
	driver._click(player)
	if absf(prop.supply_position-value)>.00001:failures.append("repair actual supply travel")
	print("REPAIR SUPPLY goal=",value," actual=",prop.supply_position)

func run(bench: Node3D,prop: Node3D,player: Node3D,driver: Node3D,codec: Node,failures: Array) -> void:
	var original: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	# Independent scenario: restore the actual earned custody record captured
	# before the preceding bench deliberately tested an already-used liner.
	var original_inventory: Dictionary=prop.inventory.serialize()
	if not prop.inventory.restore(bench._packing_before_use):failures.append("repair restores earlier earned packing custody fixture")
	var previous_balance: HeatBalance=prop._balance
	var heat := HeatBalance.new()
	heat.configure({"floors":[{"markers":[{"kind":"radiator","id":prop.graph_node_id,"unit":"2B"},
		{"kind":"radiator","id":"NEIGHBOR","unit":"3B"}]}]})
	prop.bind_heat_balance(heat)
	prop.set_pitch(.35)
	var fixture: Dictionary=codec.snapshot()
	var settings: Dictionary=fixture.records.F02_B_RADIATOR_01.value
	settings.service_progress=.4
	settings.supply_position=0.0
	settings.packing_spread=0.0;settings.packing_out=0.0
	settings.packing={"station":0}
	settings.vent_cap={"loose":false,"turn":0.0}
	if not codec.validate(fixture,codec._kinds):failures.append("repair starting physical fixture validates");return
	codec._restore(fixture)
	var orders := WorkOrders.new()
	orders.name="WorkOrders"
	bench.add_child(orders)
	orders.setup(null)
	orders.bind_job_library(MaintenanceJobLibrary.load_default())
	var round := ServiceRoundDirector.new()
	bench.add_child(round)
	round.work_orders=orders
	prop.maintenance_completed.connect(round._on_radiator_completed)
	prop.physical_action.connect(round._on_radiator_observed)
	var result := {"count":0,"consumed":0}
	var completed := func(_data: Dictionary): result.count+=1
	var consumed := func(_id: String): result.consumed+=1
	prop.maintenance_completed.connect(completed)
	prop.inventory.part_consumed.connect(consumed)
	if not orders.issue_job(ServiceRoundDirector.JOB_ID,"reported") or not orders.acknowledge_job(ServiceRoundDirector.JOB_ID):
		failures.append("repair uses existing issued and acknowledged lifecycle")
	var before: Dictionary=prop.mechanism_snapshot()
	prop.apply_maintenance_result({"mechanism_patch":{"vent_grade":2,"supply_position":1.0}})
	if not bench._same_payload(before,prop.mechanism_snapshot()) or result.count!=0:failures.append("legacy completion cannot operate V2 or award repair")
	var ecosystem := OpenShiftRadiatorEcosystem.new()
	bench.add_child(ecosystem)
	ecosystem.setup(orders,prop,round,func():return 187.0)
	ecosystem.set_process(false)
	ecosystem.porter.consider("neglected radiator fixture",180.0)
	ecosystem.porter.advance_to(187.0)
	if ecosystem.porter.state().acted_at<0 or prop.supply_position>.02:failures.append("porter actually performs prior shutoff through original actor")
	await _aim(bench,prop,player,prop.native_rig.header_nut,Vector3(-.45,.20,-.30))
	driver._click(player)
	var space := InputEventKey.new()
	space.keycode=KEY_SPACE;space.physical_keycode=KEY_SPACE;space.pressed=true
	player._unhandled_input(space)
	if not player.inspecting() or "radiator_airbound" not in orders.job_state(ServiceRoundDirector.JOB_ID).get("evidence",[]):
		failures.append("actual Space inspection records original radiator evidence")
	player.end_inspection()
	await _aim(bench,prop,player,prop.native_rig.header_nut,Vector3(-.45,.20,-.30))
	driver._click(player)
	if not player._grab.active():failures.append("repair actual retainer grip")
	else:
		driver._drag_to(player,0.0)
		driver._click(player)
	if prop.native_service_progress>.001:failures.append("reverse retainer motion seals returned packing")
	await _valve(bench,prop,player,driver,1.0,failures)
	ecosystem.porter.advance_to(188.0)
	if prop.supply_position<.98:failures.append("past porter action does not hold the physical valve shut forever")
	await bench.get_tree().create_timer(.15).timeout
	if result.count!=0 or orders.job_stage(ServiceRoundDirector.JOB_ID)!="acknowledged":failures.append("healthy physical settings cannot bypass comparisons")
	round._on_board_completed({})
	round._on_boiler_completed({})
	if orders.job_stage(ServiceRoundDirector.JOB_ID)!="repairable":failures.append("original comparison callbacks finish diagnosis")
	heat.set_boiler_output(0.0)
	await bench.get_tree().create_timer(.15).timeout
	if prop._native_repair_seconds!=0.0 or result.count!=0:failures.append("no steam cannot prove a repair")
	heat.set_boiler_output(1.0)
	await _valve(bench,prop,player,driver,.42,failures)
	await bench.get_tree().create_timer(.15).timeout
	if prop._native_repair_seconds!=0.0 or result.count!=0:failures.append("partial one-pipe valve cannot prove a repair")
	await _valve(bench,prop,player,driver,1.0,failures)
	# Wait for the real float to reach its needle seat; do not set its lift.
	for index in 240:
		if prop.native_vent_cap._float_lift>=.0054:break
		await bench.get_tree().create_timer(.02).timeout
	if result.count!=0:failures.append("needle closure alone does not bypass sustained proof")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	await bench.get_tree().create_timer(.6).timeout
	codec._restore(saved)
	if prop._native_repair_seconds!=0.0:failures.append("restoration discards transient repair proof")
	await bench.get_tree().create_timer(1.0).timeout
	if result.count!=0:failures.append("restored mechanism must prove itself again")
	await bench.get_tree().create_timer(5.5).timeout
	if result.count!=1 or orders.job_stage(ServiceRoundDirector.JOB_ID)!="repaired" or prop.open_shift_condition!="repaired":
		failures.append("sustained real steam completes through ServiceRound and WorkOrders")
	if result.consumed!=1 or not prop.inventory.is_consumed(prop.PACKING_ITEM) or prop.native_packing.station!=0:
		failures.append("returned physical packing transfers its existing custody once")
	await bench.get_tree().create_timer(.2).timeout
	if result.count!=1 or result.consumed!=1:failures.append("completion and packing transfer do not repeat")
	await _valve(bench,prop,player,driver,.42,failures)
	ecosystem.situation.observe_interference("wrong_valve")
	var later: Dictionary=prop.mechanism_snapshot()
	ecosystem._reconstruct_physical_state()
	if not bench._same_payload(later,prop.mechanism_snapshot()) or prop.open_shift_condition!="repaired":
		failures.append("completed job reconstruction preserves later physical changes despite old porter/interference history")
	prop.maintenance_completed.disconnect(completed)
	prop.physical_action.disconnect(round._on_radiator_observed)
	prop.maintenance_completed.disconnect(round._on_radiator_completed)
	prop.inventory.part_consumed.disconnect(consumed)
	prop.inventory.restore(original_inventory)
	prop.bind_heat_balance(previous_balance)
	codec._restore(original)
	ecosystem.free();round.free();orders.free()
	print("RADIATOR PHYSICAL REPAIR HAND PASS COMPLETE; results ",result)
