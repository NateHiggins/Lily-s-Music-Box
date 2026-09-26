extends Node
## Physical household service roster. Simple WorkOrders own reported requests.
const Prep := preload("res://scripts/building/orison_v2_prep_cabinet.gd")
var economy: Node
var subjects: Dictionary = {}
var clients: Dictionary = {}
var _elapsed := 0.0
var _defaults: Dictionary = {}
var _syncing := false

func setup(root: Node, wallet: Node) -> bool:
	economy = wallet
	var schedule: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resident_schedules.json"))
	for identity: String in schedule.residents:
		clients[str(schedule.residents[identity].unit)] = identity
	for prop in root.find_children("*","Node",true,false):
		var kind := "water" if prop is TapProp else "hinge" if prop is MedicineCabinetProp else "slide" if prop is Prep else ""
		if kind.is_empty(): continue
		var unit := str(prop.get("unit"))
		if unit.is_empty(): continue
		var identity := str(prop.name)
		if subjects.has(identity): return false
		subjects[identity] = prop
		if not economy.book().care.has(identity):
			economy.book().care[identity] = {"kind":kind,"unit":unit,"last":-1.0,
				"due":economy.clock.elapsed_minutes()+1440.0+float(posmod(identity.hash(),10080)),
				"cycle":0,"request":""}
		var record: Dictionary = economy.book().care[identity]
		if record.kind!=kind or record.unit!=unit: return false
		_defaults[identity] = record.duplicate(true)
	RealityState.state_changed.connect(tick)
	tick()
	# Fix the first due dates in the existing save; rebuilding must not push
	# a never-serviced fixture's first request farther into the future.
	RealityState.commit()
	return not subjects.is_empty()

func find_subject(node: Node) -> Node:
	while node!=null:
		if subjects.get(str(node.name))==node: return node
		node = node.get_parent()
	return null

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed>=2.0:
		_elapsed = 0
		tick()

func tick() -> void:
	if economy==null or RealityState.save_write_blocked or _syncing: return
	_syncing = true
	var now: float = economy.clock.elapsed_minutes()
	for identity: String in subjects:
		if not economy.book().care.has(identity):
			# An older save loaded into a live world starts a fresh care schedule.
			var fresh: Dictionary = _defaults[identity].duplicate(true)
			fresh.last = -1.0
			fresh.due = now+1440.0+float(posmod(identity.hash(),10080))
			fresh.cycle = 0
			fresh.request = ""
			economy.book().care[identity] = fresh
		var record: Dictionary = economy.book().care.get(identity,{})
		if record.is_empty(): continue
		var overdue: bool = now>=float(record.due)
		var prop: Node = subjects[identity]
		if not is_instance_valid(prop) or not prop.is_inside_tree(): continue
		if prop is TapProp: prop.drain_capacity = .18 if overdue else 1.0
		elif prop is MedicineCabinetProp: prop.hinges_oiled = float(record.last)>=0 and not overdue
		elif prop is Prep: prop.track_clean = not overdue
		if overdue and str(record.request).is_empty() and clients.has(record.unit):
			var request := "care:"+identity+":"+str(record.cycle)
			# Install the identity before issue() commits the shared snapshot.
			record.request = request
			if not economy.orders.issue(request, str(record.unit)+" / "+subject_title(prop),
					"Test and service the "+subject_title(prop).to_lower()+".",str(clients[record.unit])):
					record.request = ""
	_syncing = false

func _kind_title(kind: String) -> String:
	return {"water":"DRAIN", "hinge":"CABINET HINGES", "slide":"CABINET TRACK"}[kind]

func subject_title(prop: Node) -> String:
	return str(prop.fixture).replace("_"," ").to_upper()+" DRAIN" if prop is TapProp \
		else "MEDICINE CABINET HINGES" if prop is MedicineCabinetProp else "KITCHEN CABINET TRACK"

func request_lines() -> Array[String]:
	var lines: Array[String] = []
	for identity: String in subjects:
		var record: Dictionary = economy.book().care.get(identity,{})
		if not str(record.get("request","")).is_empty():
			lines.append(str(record.unit)+" / "+subject_title(subjects[identity]))
	lines.sort()
	return lines

func inspection(prop: Node) -> String:
	if prop==null: return "Aim at a water fixture or cabinet within reach."
	var record: Dictionary = economy.book().care[str(prop.name)]
	if prop is TapProp:
		var flow: Dictionary = prop.get_flow_state()
		var warmth := "cold" if float(flow.temperature)<.15 else "warm" if float(flow.temperature)<.5 else "hot"
		return "%s / %s\nHot valve: %s   Cold valve: %s\nWater: %s   Basin: %d%%   Drain: %s" % [record.unit,
			prop.fixture.replace("_"," "),"open" if flow.hot else "closed","open" if flow.cold else "closed",
			warmth if flow.hot or flow.cold else "off",roundi(float(flow.water_level)*100),
			"stoppered" if flow.stopper else "slow" if prop.drain_capacity<.5 else "clear"]
	return "%s / %s\n%s" % [record.unit,_kind_title(record.kind),
		"Quiet and free" if float(record.last)>=0 and economy.clock.elapsed_minutes()<float(record.due) else "Ready for a little care"]

func service(prop: Node, tested: bool) -> Dictionary:
	if not tested or prop==null or not subjects.has(str(prop.name)) or RealityState.save_write_blocked: return {}
	var record: Dictionary = economy.book().care[str(prop.name)]
	var now: float = economy.clock.elapsed_minutes()
	if float(record.last)>=0 and now-float(record.last)<1440: return {"note":"Already attended to today."}
	if prop is TapProp:
		var flow: Dictionary = prop.get_flow_state()
		if prop.fixture=="shower" and not prop.is_curtain_open(): return {"note":"Open the shower curtain to reach the drain."}
		if flow.hot or flow.cold or flow.stopper: return {"note":"Close both valves and open the drain before cleaning."}
	elif prop is MedicineCabinetProp and not prop.is_door_open(): return {"note":"Open the cabinet to reach its hinges."}
	elif prop is Prep and not prop.opened: return {"note":"Open the cabinet to reach the track."}
	var request := str(record.request)
	var issued := now
	if not request.is_empty(): issued = float(RealityState.data.work_orders.get(request,{}).get("issued_at",now))
	record.last = now
	record.due = now+20160.0
	record.cycle = int(record.cycle)+1
	record.request = ""
	var client := str(clients.get(record.unit,""))
	economy.appreciate(client)
	var cents := 0
	if not request.is_empty():
		cents = economy.tip(request,client,1.0,issued,false)
		economy.orders.close(request,"Tested and serviced.")
	tick()
	RealityState.commit()
	return {"note":"Drain cleared." if prop is TapProp else "Hinges oiled." if prop is MedicineCabinetProp else "Track brushed and waxed.","tip":cents}
