extends Node
## Integer cents, idempotent tips and quiet goodwill. RealityState owns disk I/O.
const KEY := "caretaker_economy"
const MONTH := 43200.0
const RENT := 500
var clock := CampaignClock.new()
var orders: WorkOrders

static func whole(value: Variant, low := 0, high := 1000000000) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value)==floor(float(value)) and float(value)>=low and float(value)<=high

static func valid(value: Variant) -> bool:
	if value is not Dictionary: return false
	for key in ["version", "cash", "rent_paid", "started", "tips", "goodwill", "care"]:
		if not value.has(key): return false
	if not whole(value.version,1,1) or not whole(value.cash) or not whole(value.rent_paid): return false
	if typeof(value.started) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value.started)) or value.started<0: return false
	for key in ["tips", "goodwill", "care"]:
		if value[key] is not Dictionary: return false
	for key in value.tips:
		if key is not String or not whole(value.tips[key]): return false
	for key in value.goodwill:
		var r: Variant = value.goodwill[key]
		if key is not String or r is not Dictionary or not whole(r.get("value"),0,100) \
			or not whole(r.get("day"),-1,10000000): return false
	for key in value.care:
		var r: Variant = value.care[key]
		if key is not String or r is not Dictionary or r.get("kind") not in ["water","hinge","slide"] \
			or r.get("unit") is not String or r.get("request") is not String: return false
		for field in ["due","last"]:
			if typeof(r.get(field)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(r[field])) or r[field]<-1: return false
		if r.due<0 or r.due<=r.last or not whole(r.get("cycle")): return false
	return true

func setup(work: WorkOrders) -> bool:
	if not clock.bind_state() or RealityState.save_write_blocked: return false
	_ensure_book()
	if not valid(RealityState.data[KEY]): return false
	orders = work
	orders.job_stage_changed.connect(_job_changed)
	RealityState.snapshot_preparing.connect(_settle_jobs)
	return true

func _ensure_book() -> void:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"version":1,"cash":100,"rent_paid":0,
			"started":clock.elapsed_minutes(),"tips":{},"goodwill":{},"care":{}}
		# Migrating an old campaign must not retrospectively mint past tips.
		for identity: String in RealityState.data.get("maintenance_jobs",{}):
			if RealityState.data.maintenance_jobs[identity].get("stage","")=="closed":
				RealityState.data[KEY].tips["job:"+identity] = 0

func book() -> Dictionary:
	_ensure_book()
	return RealityState.data.get(KEY,{})

func affection(client: String) -> int:
	var score := int(book().goodwill.get(client,{"value":0}).value)
	# Case trust stays with its existing owner; care never resolves a case.
	for state: Dictionary in RealityState.data.get("cases",{}).values():
		if state.get("resident_id","")==client: score += int(state.get("trust",0))*5
	return clampi(score,0,100)

func appreciate(client: String) -> void:
	if client.is_empty(): return
	var day := int(clock.elapsed_minutes()/1440.0)
	var previous: Dictionary = book().goodwill.get(client,{"value":0,"day":-1})
	if int(previous.day)==day: return
	book().goodwill[client] = {"value":mini(100,int(previous.value)+2),"day":day}

func tip(identity: String, client: String, completeness: float, issued: float, persist := true) -> int:
	if RealityState.save_write_blocked or identity.is_empty() or client.is_empty() \
		or book().tips.has(identity) or not is_finite(completeness) or not is_finite(issued): return 0
	var age := maxf(0,clock.elapsed_minutes()-issued)
	var promptness := 1.0 if age<=1440 else .75 if age<=4320 else .5
	var cents := maxi(1,roundi((25.0+affection(client)*.5)*clampf(completeness,0,1)*promptness)) if completeness>0 else 0
	book().tips[identity] = cents
	book().cash = int(book().cash)+cents
	appreciate(client)
	if persist: RealityState.commit()
	return cents

func _job_changed(identity: String, _from: String, to: String, state: Dictionary) -> void:
	if to!="closed" or orders.job_library==null: return
	var job := orders.job_library.job(identity)
	var quality: String = state.get("repair_result",{}).get("quality","poor")
	tip("job:"+identity,str(job.get("resident_id","")),
		{"poor":.35,"fair":.65,"good":1.0}.get(quality,.35),float(state.get("issued_at",clock.elapsed_minutes())))

func _settle_jobs() -> void:
	# WorkOrders commits before its closed signal. Include the tip in that same
	# snapshot so an interruption between the save and signal cannot lose it.
	if orders==null or orders.job_library==null or RealityState.save_write_blocked: return
	for identity: String in RealityState.data.get("maintenance_jobs",{}):
		var state: Dictionary = RealityState.data.maintenance_jobs[identity]
		if state.get("stage","")!="closed" or not orders.job_library.has_job(identity): continue
		var job := orders.job_library.job(identity)
		var quality: String = state.get("repair_result",{}).get("quality","poor")
		tip("job:"+identity,str(job.get("resident_id","")),
			{"poor":.35,"fair":.65,"good":1.0}.get(quality,.35),float(state.get("issued_at",0)),false)

func rent_cycles_due() -> int:
	return maxi(0,int((clock.elapsed_minutes()-float(book().started))/MONTH)-int(book().rent_paid))

func pay_rent() -> bool:
	# One advance instalment is allowed; debt is never interest-bearing.
	var elapsed_cycles := int((clock.elapsed_minutes()-float(book().started))/MONTH)
	if RealityState.save_write_blocked or int(book().cash)<RENT or int(book().rent_paid)>elapsed_cycles: return false
	book().cash = int(book().cash)-RENT
	book().rent_paid = int(book().rent_paid)+1
	RealityState.commit()
	return true

static func money(cents: int) -> String:
	return "$%d.%02d" % [cents/100,cents%100]
