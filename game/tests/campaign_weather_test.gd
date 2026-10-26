extends Node
const Manager := preload("res://scripts/building/WeatherManager.gd")
const Service := preload("res://scripts/building/live_weather_service.gd")
var failures: Array[String]=[]
var checks:=0

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
	print("[WEATHER CALENDAR %s] %s"%["PASS" if ok else "FAIL",label])

func _ready() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled=false
	OS.set_environment("WEATHER_SIMULATE","")
	check(CampaignWeather.load_calendar(),"authored calendar loads: "+CampaignWeather.error)
	_living_year()
	var start:=Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00")
	var profiles: Dictionary={}
	for offset in 365:
		var date:=Time.get_datetime_dict_from_unix_time(start+offset*86400)
		date.hour=15
		var raw:=CampaignWeather.snapshot(date)
		var normalized:=Service.presentation(raw)
		check(not raw.is_empty() and str(raw.source)=="campaign-calendar" and not normalized.is_empty(),
			"dated weather and normalized rendering input "+CampaignWeather.date_key(date))
		for anchor: Dictionary in CampaignWeather.day(CampaignWeather.date_key(date)).frames:
			profiles[str(anchor.weather_code)]=true
	check(profiles.size()>=7,"year contains at least seven observable weather regimes")
	check(CampaignWeather.snapshot({"year":1928,"month":2,"day":29}).is_empty(),"outside authored year never loops or invents dated news")
	check(CampaignWeather.timeline("1928-11-10T05:59",20).is_empty(),"no bulletin before opening issue time")
	var morning:=CampaignWeather.timeline("1928-11-10T06:00",20)
	check(morning.size()==1 and str(morning[0].issued_at)=="1928-11-10T06:00","morning bulletin appears at its issue minute")
	var evening:=CampaignWeather.timeline("1928-11-10T17:00",20)
	check(evening.size()==2 and str(evening[-1].valid_from)=="1928-11-11T06:00","evening forecast has an explicit next-day validity")
	var history:=CampaignWeather.timeline("1929-04-16T17:00",2)
	check(history.size()==2 and str(history[0].prediction)!=str(history[1].prediction) \
		and str(history[-1].revision)!="","wrong forecast remains beside a later correction")
	for entry: Dictionary in history:
		check(str(entry.issued_at)<="1929-04-16T17:00" and str(entry.get("observation","")).contains("degrees F."),"as-of timeline carries local observation and no future-issued bulletin")
	var clock:=CampaignClock.new()
	clock.configure_date(1929,7,11,1305)
	var a:=CampaignWeather.snapshot(clock.local_datetime())
	check(int(a.weather_code)==95 and float(a.rain_mm)>0,"July thunderstorm is tied to authored clock minute")
	var saved: Dictionary=RealityState.data.campaign_clock.duplicate(true)
	clock.advance_to(90)
	RealityState.data.campaign_clock=saved
	var restored:=CampaignClock.new()
	check(CampaignWeather.snapshot(restored.local_datetime())==a,"new clock owner after state restoration reproduces weather without wall-clock ramp")
	clock=restored
	clock.configure_date(1928,12,31,1439)
	a=CampaignWeather.snapshot(clock.local_datetime())
	clock.advance_to(1)
	var b:=CampaignWeather.snapshot(clock.local_datetime())
	check(str(b.observed_at).begins_with("1929-01-01") and absf(float(a.temperature_c)-float(b.temperature_c))<.2,"civil year rollover stays continuous")
	var source:=FileAccess.get_file_as_string("res://shaders/queens_weather_sky.gdshader")
	check(not source.is_empty(),"integrated sky owner remains installed")
	var director:=DayNightDirector.new()
	var sky:=ShaderMaterial.new()
	sky.shader=load("res://shaders/queens_weather_sky.gdshader")
	var manager:=Manager.new()
	manager.configure(clock,director,sky)
	add_child(manager)
	manager.set_process(false)
	manager._process(1)
	var expected:=Service.presentation(CampaignWeather.snapshot(clock.local_datetime()))
	check(manager.source=="campaign-calendar" and is_equal_approx(float(manager.current.temperature_c),float(expected.temperature_c)) \
		and int(manager.current.weather_code)==int(expected.weather_code),"production manager samples calendar through the existing normalization owner")
	manager.receive_snapshot(Service.simulated_snapshot("rain"))
	manager._process(1)
	check(manager.source!="campaign-calendar","explicit observation override remains an observation override")
	manager._fallback("fixture network failure")
	manager._process(1)
	check(manager.source=="campaign-calendar","failed observation restores the dated calendar")
	clock.configure_date(1929,8,6,900)
	manager._process(1)
	check(float(manager._calendar_events.hail)>0 and float(manager.current.rain_intensity)>0,"authored hail drives the same cloud and precipitation state")
	clock.configure_date(1929,9,19,900)
	manager._process(1)
	check(int(manager._calendar_events.formation)==3,"authored rare sky selection reaches the extension event seam")
	var catalog:=NewspaperCatalog.new();add_child(catalog)
	var original: Dictionary=catalog.issues["1929-04-16"].record.duplicate(true)
	var page:=catalog.issue("record","1929-04-16")
	check(page.has("weather_report") and catalog.issues["1929-04-16"].record==original,"paper receives dated report without mutating authored front-page owner")
	clock.configure_date(1928,11,10,359)
	check(NewsRackProp.offers_for(catalog,"1928-11-10",true).is_empty(),"production rack withholds reports before first publication")
	clock.configure_date(1928,11,10,360)
	check(NewsRackProp.offers_for(catalog,"1928-11-10",true).size()==1 and not catalog.published_now("speaker","1928-11-10"),"morning rack cannot disclose the evening forecast")
	clock.configure_date(1928,11,10,1020)
	check(NewsRackProp.offers_for(catalog,"1928-11-10",true).size()==2,"evening edition enters the physical rack at its issue time")
	clock.configure_date(1928,11,11,0)
	check(catalog.published_now("speaker","1928-11-10") and not catalog.published_now("record","1928-11-11"),"yesterday's reports remain available before today's publication")
	var conversations:=ResidentConversations.new();add_child(conversations)
	var profile:=ResidentWeather.profile("lena_ortiz")
	check(str(profile.get("wet","")).contains("lining"),"weather comments retain resident-specific vocabulary")
	var normalized:=Service.presentation(Service.simulated_snapshot("rain"))
	var note:=ResidentWeather.observation("lena_ortiz",{"year":1929,"month":4,"day":16},normalized,0)
	check(str(note.line).contains("Rain") and not str(note.line).contains(str(profile.trend)),"fresh campaign gets a present observation without claimed multi-day experience")
	var dark:=ResidentWeather.observation("iris_bell",{"year":1929,"month":9,"day":19},Service.presentation(Service.simulated_snapshot("clear")),0,false)
	check(str(dark.line).contains("dark") and not str(dark.line).contains("patch of sky"),"night remarks use the existing celestial state instead of praising sunlight")
	var flags_before: Dictionary=RealityState.data.duplicate(true)
	var tree:={"entries":{"first_stable":"home"},"nodes":{"home":{"line":"Hello.","choices":[]}}}
	manager.source="campaign-calendar";manager.current=normalized
	var with_weather:=conversations.with_weather("lena_ortiz",tree)
	check(with_weather.nodes.size()==2 and tree.nodes.size()==1 and RealityState.data==flags_before,"conversation adds a restrained optional remark without changing trust, case or knowledge")
	manager.source="open-meteo"
	check(conversations.with_weather("lena_ortiz",tree)==tree,"calendar remarks do not contradict explicit live-weather override")
	var before_weather: Dictionary=RealityState.data.duplicate(true)
	conversations._record("cal_dwyer","wx:cal_dwyer:fixture:wet",9)
	var after_weather: Dictionary=RealityState.data.duplicate(true)
	before_weather.erase("knowledge_flags");after_weather.erase("knowledge_flags")
	check(before_weather==after_weather and RealityState.has_knowledge("wx:cal_dwyer:fixture:wet"),"hearing weather records only existing memory, even for a case resident and nonzero caller trust")
	# Render the integrated paper, using its real reading surface and scroll container.
	var out_dir:=OS.get_environment("SHOT_DIR")
	if out_dir.is_empty(): out_dir="user://campaign_weather_test"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if DisplayServer.get_name()!="headless":
		var panel:=NewspaperPanel.new();add_child(panel)
		panel.open(null,catalog,"record","1929-04-16")
		for frame in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(out_dir.path_join("weather_report.png"))==OK,"render weather reporting on the actual newspaper surface")
		panel.close()
	var result:={"evidence_class":"INERT","scope":"calendar, forecast as-of, manager, newspaper and dialogue diagnostic; no full-world runtime qualification",
		"checks":checks,"failures":failures,"calendar_sha256":FileAccess.get_sha256(CampaignWeather.PATH)}
	FileAccess.open(out_dir.path_join("calendar_test.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	manager.queue_free();director.free();catalog.queue_free();conversations.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _living_year() -> void:
	var library:=preload("res://scripts/building/living_sky.gd")
	check(library.load_library(),"ten-genus and fifty-scenario library validates")
	var start:=Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00")
	var seen: Dictionary={};var regimes: Dictionary={};var eligible_counts: Dictionary={}
	var invalid: Array[String]=[];var replay: Array[String]=[]
	var started:=Time.get_ticks_usec()
	for day_index in 365:
		for hour in [6,12,18]:
			var date:=Time.get_datetime_dict_from_unix_time(start+day_index*86400+hour*3600)
			var conditions:=Service.presentation(CampaignWeather.snapshot(date))
			var state: Dictionary=library.sample(date,conditions,1928)
			if state.is_empty():invalid.append(str(date));continue
			regimes[state.regime]=true
			for layer: Dictionary in state.layers:
				if not (layer.offset_km as Vector2).is_finite() or not (layer.wind as Vector2).is_finite() or float(layer.coverage)<0 or float(layer.coverage)>1: invalid.append(str(date))
				if float(layer.coverage)>.03:seen[layer.genus]=int(seen.get(layer.genus,0))+1
			for id: int in state.eligible_scenarios:eligible_counts[str(id)]=int(eligible_counts.get(str(id),0))+1
			if absf(float(state.combined_coverage)-float(conditions.cloud_total))>.0002:invalid.append("coverage union "+str(date))
			if float(state.dew_point_c)>float(conditions.temperature_c)+.001:invalid.append("dew point "+str(date))
			if day_index%31==0:replay.append(JSON.stringify(state))
	check(invalid.is_empty(),"all1095 annual daylight/shoulder samples retain finite layers, optical coverage and dew point bounds: "+str(invalid.slice(0,3)))
	check(seen.size()==10,"all ten genera actually have eligible nonzero annual layers: "+str(seen.keys()))
	check(regimes.size()>=6,"annual calendar retains multiple coherent regimes: "+str(regimes.keys()))
	var second: Array[String]=[]
	for day_index in range(364,-1,-1):
		if day_index%31!=0:continue
		for hour in [18,12,6]:
			var date:=Time.get_datetime_dict_from_unix_time(start+day_index*86400+hour*3600)
			second.push_front(JSON.stringify(library.sample(date,Service.presentation(CampaignWeather.snapshot(date)),1928)))
	check(replay==second,"reverse date visits and fresh interpretation reproduce exact cloud identity, advection and evolution")
	var date:=Time.get_datetime_dict_from_unix_time(start+60*86400+86399)
	var a:=CampaignWeather.cloud_transport(date)
	var b:=CampaignWeather.cloud_transport(Time.get_datetime_dict_from_unix_time(start+61*86400))
	check(a.distance_to(b)<.04,"cloud transport remains continuous across midnight")
	var clear:=Service.presentation(Service.simulated_snapshot("clear"))
	var zero: Dictionary=library.sample(date,clear,1928)
	check(zero.layers.all(func(layer):return float(layer.coverage)==0.0),"literal clear weather has no ordinary cloud layer")
	check(not library.eligible("snow_stock",clear,12,0),"wind cannot invent loose ground snow")
	check(not library.eligible("ineligible",clear,12),"Queens does not select tropical trade-wind recipes")
	var extension:=preload("res://scripts/building/queens_weather_extension.gd").new()
	var conditions:=Service.presentation(CampaignWeather.snapshot(date))
	extension.receive_conditions(conditions,CampaignWeather.date_key(date),1928,CampaignWeather.events(CampaignWeather.snapshot(date)))
	extension.sample_calendar(date,CampaignWeather.cloud_transport(date))
	var frozen:=[extension.weights,extension.wetness,extension.phase,extension.fog_offset,extension.formation_strength]
	for frame in 240:extension.advance(1.0/30.0,true)
	check(frozen==[extension.weights,extension.wetness,extension.phase,extension.fog_offset,extension.formation_strength],"paused campaign leaves precipitation, wetness, morphology and motion unchanged across render frames")
	var reconstructed:=preload("res://scripts/building/queens_weather_extension.gd").new()
	reconstructed.receive_conditions(conditions,CampaignWeather.date_key(date),1928,CampaignWeather.events(CampaignWeather.snapshot(date)))
	reconstructed.sample_calendar(date,CampaignWeather.cloud_transport(date))
	check(frozen==[reconstructed.weights,reconstructed.wetness,reconstructed.phase,reconstructed.fog_offset,reconstructed.formation_strength],"fresh weather instance reconstructs the same calendar state without hidden save history")
	var out_dir:=OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():out_dir="user://campaign_weather_test"
	DirAccess.make_dir_recursive_absolute(out_dir)
	FileAccess.open(out_dir.path_join("living_year.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"1095 deterministic state samples; not a rendered annual gallery or runtime acceptance", "samples":1095,"genera":seen,"regimes":regimes,"eligible_scenarios":eligible_counts,"invalid":invalid,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0},"\t"))
