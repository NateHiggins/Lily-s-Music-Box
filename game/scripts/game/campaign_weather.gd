class_name CampaignWeather
extends RefCounted
## Pure dated weather/press projection. CampaignClock alone owns elapsed time.
## No network, per-frame scan, new save state, or resident knowledge grants.
const PATH := "res://data/weather/campaign_weather.json"
const Service := preload("res://scripts/building/live_weather_service.gd")
const MONTHS := ["January","February","March","April","May","June","July","August",
	"September","October","November","December"]
const WINDS := ["N.","N.N.E.","N.E.","E.N.E.","E.","E.S.E.","S.E.","S.S.E.",
	"S.","S.S.W.","S.W.","W.S.W.","W.","W.N.W.","N.W.","N.N.W."]
const NUMERIC := ["temperature_c", "relative_humidity", "cloud_total", "cloud_low",
	"cloud_mid", "cloud_high", "wind_speed_kmh", "wind_gusts_kmh", "pressure_hpa",
	"rain_mm", "snowfall_cm", "hail", "cyclone", "severe_storm_threat"]
static var _days: Dictionary = {}
static var _dates: Array[String] = []
static var error := ""
static var _transport_times := PackedFloat64Array()
static var _transport_wind_x := PackedFloat64Array()
static var _transport_wind_y := PackedFloat64Array()
static var _transport_distance_x := PackedFloat64Array()
static var _transport_distance_y := PackedFloat64Array()
static var _cyclone_starts := PackedFloat64Array()
static var _cyclone_ends := PackedFloat64Array()
static var _fallout: Array[Dictionary] = []

static func load_calendar() -> bool:
	if not _days.is_empty(): return true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is not Dictionary or int(parsed.get("schema_version", 0)) != 1 \
			or parsed.get("days") is not Array or str(parsed.get("authorship", "")).is_empty():
		error = "Campaign weather calendar is unreadable"; return false
	var candidate: Dictionary = {}
	var dates: Array[String] = []
	for row: Variant in parsed.days:
		if row is not Dictionary or not valid_day(row):
			error = "Campaign weather calendar has an invalid day"; return false
		var key := str(row.date)
		if candidate.has(key):
			error = "Campaign weather calendar repeats " + key; return false
		candidate[key] = row; dates.append(key)
	dates.sort()
	if dates.size() != 365 or dates[0] != str(parsed.get("first_date", "")) \
			or dates[-1] != str(parsed.get("last_date", "")):
		error = "Campaign weather calendar range is incomplete"; return false
	var previous := 0
	var has_previous := false
	for key: String in dates:
		var stamp:=Time.get_unix_time_from_datetime_string(key+"T00:00:00")
		if Time.get_datetime_string_from_unix_time(stamp).left(10)!=key \
				or (has_previous and stamp-previous!=86400):
			error="Campaign weather calendar has a civil-date gap"; return false
		previous=stamp
		has_previous=true
	var fallout: Array[Dictionary]=[]
	var authored: Variant=parsed.get("fallout_events",[])
	if authored is not Array or authored.size()>8:
		error="Campaign weather has invalid fallout episodes";return false
	for episode: Variant in authored:
		if episode is not Dictionary or not candidate.has(str(episode.get("date",""))) or episode.get("kind") not in ["blood","frogs"]:
			error="Campaign weather has an invalid fallout date/type";return false
		var start_value: Variant=episode.get("start_minute")
		var end_value: Variant=episode.get("end_minute")
		if not (start_value is int or start_value is float) or not (end_value is int or end_value is float):
			error="Campaign weather fallout times must be numeric";return false
		var begin:=float(start_value);var finish:=float(end_value)
		if not is_finite(begin) or not is_finite(finish) or floor(begin)!=begin or floor(finish)!=finish or begin<0 or finish>1440 or finish-begin<2 or finish-begin>120:
			error="Campaign weather fallout window is invalid";return false
		var midnight:=float(Time.get_unix_time_from_datetime_string(str(episode.date)+"T00:00:00"))
		fallout.append({"date":str(episode.date),"kind":str(episode.kind),"start":midnight+begin*60.0,"end":midnight+finish*60.0})
	fallout.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.start<b.start)
	for i in range(1,fallout.size()):
		if float(fallout[i].start)<float(fallout[i-1].end):
			error="Campaign weather fallout episodes overlap";return false
	_days = candidate; _dates = dates; _fallout=fallout; error = ""
	# One small prefix integral alongside the existing validated calendar.
	# No per-frame year scan, new forecast, random weather or save domain.
	_transport_times=PackedFloat64Array()
	_transport_wind_x=PackedFloat64Array();_transport_wind_y=PackedFloat64Array()
	_transport_distance_x=PackedFloat64Array();_transport_distance_y=PackedFloat64Array()
	_cyclone_starts=PackedFloat64Array();_cyclone_ends=PackedFloat64Array()
	var distance_x:=0.0;var distance_y:=0.0
	var cyclone_active:=false
	for key: String in dates:
		var midnight := float(Time.get_unix_time_from_datetime_string(key+"T00:00:00"))
		for frame: Dictionary in _days[key].frames:
			var stamp := midnight + float(frame.minute)*60.0
			# Strength is linearly interpolated between anchors. An episode starts
			# at the preceding zero anchor and ends when strength returns to zero.
			if float(frame.cyclone)>0.0 and not cyclone_active:
				_cyclone_starts.append(_transport_times[-1] if not _transport_times.is_empty() else stamp)
				cyclone_active=true
			elif float(frame.cyclone)<=0.0 and cyclone_active:
				_cyclone_ends.append(stamp);cyclone_active=false
			var angle := deg_to_rad(float(frame.wind_direction_degrees))
			var wind_x := -sin(angle)*float(frame.wind_speed_kmh)/3600.0
			var wind_y := cos(angle)*float(frame.wind_speed_kmh)/3600.0
			if not _transport_times.is_empty():
				var dt:=stamp-_transport_times[-1]
				distance_x+=(_transport_wind_x[-1]+wind_x)*.5*dt
				distance_y+=(_transport_wind_y[-1]+wind_y)*.5*dt
			_transport_times.append(stamp)
			_transport_wind_x.append(wind_x);_transport_wind_y.append(wind_y)
			_transport_distance_x.append(distance_x);_transport_distance_y.append(distance_y)
	if cyclone_active:
		_cyclone_ends.append(float(Time.get_unix_time_from_datetime_string(dates[-1]+"T00:00:00"))+86400.0)
	return true

## Presentation-only anomalies share the calendar; no forecast, newspaper,
## inventory or save facts are granted. A day rolls once, never every frame.
static func _rolled_fallout(midnight: int,seed_value: int) -> Dictionary:
	var key:=Time.get_datetime_string_from_unix_time(midnight).left(10)
	if not _days.has(key):return {}
	for episode: Dictionary in _fallout:
		if episode.date==key:return {} # Authored windows own their day.
	var rng:=RandomNumberGenerator.new();rng.seed=(key+":fallout-v1:"+str(seed_value)).hash()
	if rng.randf()>=.001:return {}
	var begin:=float(midnight+rng.randi_range(660,1080)*60)
	return {"kind":"blood" if rng.randf()<.5 else "frogs","start":begin,"end":begin+600.0}

static func fallout_at(stamp: float,seed_value: int=1928) -> Dictionary:
	var result:={"blood":0.0,"frogs":0.0,"deposit":0.0}
	if not is_finite(stamp) or not load_calendar():return result
	var midnight:=int(floor(stamp/86400.0))*86400
	var key:=Time.get_datetime_string_from_unix_time(midnight).left(10)
	if not _days.has(key):return result
	var episodes: Array[Dictionary]=_fallout.duplicate()
	for day_offset: int in [-1,0]:
		var rolled:=_rolled_fallout(midnight+day_offset*86400,seed_value)
		if not rolled.is_empty():episodes.append(rolled)
	for episode: Dictionary in episodes:
		var begin:=float(episode.start);var finish:=float(episode.end)
		if stamp<begin or stamp-finish>21600.0:continue
		var level:=smoothstep(begin,begin+60.0,stamp)*(1.0-smoothstep(finish-60.0,finish,stamp))
		if episode.kind=="blood" and level>0.0:
			var present:=Service.presentation(snapshot(Time.get_datetime_dict_from_unix_time(int(floor(stamp)))))
			if float(present.get("rain_intensity",0.0))<=.005:level=0.0
		result[str(episode.kind)]=maxf(float(result[str(episode.kind)]),level)
		if episode.kind=="blood":
			# Reconstruct deposition only from already elapsed rain. A dry seeded
			# date cannot paint surfaces red, and a seek never replays a history.
			var sample_time:=minf(stamp,(begin+finish)*.5)
			var observed:=Service.presentation(snapshot(Time.get_datetime_dict_from_unix_time(int(floor(sample_time)))))
			var rain:=float(observed.get("rain_intensity",0.0))
			if rain>.005:
				var deposited:=clampf((minf(stamp,finish)-begin)/300.0,0.0,1.0)
				result.deposit=maxf(float(result.deposit),deposited*exp(-maxf(0.0,stamp-finish)/1800.0))
	return result

## Absolute, continuous cloud transport in km. Reopening or visiting dates in
## reverse order gives the same field. Surface weather still owns the wind.
static func cloud_transport(date: Dictionary) -> Vector2:
	var value:=cloud_transport_at(float(Time.get_unix_time_from_datetime_dict(date)))
	return Vector2(value[0],value[1]) if value.size()==2 else Vector2.ZERO

## Read the existing clock without quantizing it through a civil-date dictionary.
static func clock_seconds(clock: CampaignClock) -> float:
	return (clock.absolute_minutes()-float(CampaignClock._ordinal(1970,1,1))*1440.0)*60.0

## Double-precision prefix integral; Vector2 loses metre-scale movement after
## months of transport. No per-frame year scan or additional clock/save owner.
static func cloud_transport_at(stamp: float) -> PackedFloat64Array:
	if not is_finite(stamp) or not load_calendar() or _transport_times.is_empty(): return PackedFloat64Array()
	var i := clampi(_transport_times.bsearch(stamp)-1,0,_transport_times.size()-1)
	var dt := maxf(0.0,stamp-_transport_times[i])
	var acceleration_x:=0.0;var acceleration_y:=0.0
	if i+1<_transport_times.size():
		var span:=_transport_times[i+1]-_transport_times[i]
		acceleration_x=(_transport_wind_x[i+1]-_transport_wind_x[i])/span
		acceleration_y=(_transport_wind_y[i+1]-_transport_wind_y[i])/span
	return PackedFloat64Array([
		_transport_distance_x[i]+_transport_wind_x[i]*dt+acceleration_x*(.5*dt*dt),
		_transport_distance_y[i]+_transport_wind_y[i]*dt+acceleration_y*(.5*dt*dt)])

## Cosmetic age of the currently active authored storm. This does not publish
## alerts, predictions or story knowledge, nor advance any campaign state.
static func cyclone_age_at(stamp: float) -> float:
	if not is_finite(stamp) or not load_calendar():return 0.0
	var i:=_cyclone_starts.bsearch(stamp,true)-1
	return maxf(0.0,stamp-_cyclone_starts[i]) if i>=0 and stamp<_cyclone_ends[i] else 0.0

static func valid_day(row: Dictionary) -> bool:
	for field: String in ["date", "chapter", "story_hook", "kind", "record_ear", "speaker_ear"]:
		if str(row.get(field, "")).is_empty(): return false
	if row.get("frames") is not Array or row.frames.size() < 2 or row.frames.size() > 12 \
			or row.get("bulletins") is not Array or row.bulletins.size() != 2: return false
	var last := -1
	for frame: Variant in row.frames:
		if frame is not Dictionary: return false
		var minute := int(frame.get("minute", -1))
		if minute <= last or minute > 1439: return false
		last = minute
		for field: String in NUMERIC + ["minute", "weather_code", "wind_direction_degrees", "formation"]:
			var value: Variant = frame.get(field)
			if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)): return false
		if float(frame.rain_mm) < 0 or float(frame.snowfall_cm) < 0: return false
		if int(frame.formation) < 0 or int(frame.formation) > 4: return false
	if int(row.frames[0].minute) != 0: return false
	for bulletin: Variant in row.bulletins:
		if bulletin is not Dictionary: return false
		for field: String in ["issued_at", "valid_from", "valid_until", "prediction", "outlook", "confidence"]:
			if str(bulletin.get(field, "")).is_empty(): return false
		if not bulletin.has("revision") or not bulletin.has("issued_minute"): return false
		if str(bulletin.valid_until) <= str(bulletin.valid_from): return false
	return true

static func date_key(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [int(date.get("year", 0)), int(date.get("month", 0)),
		int(date.get("day", date.get("day_of_month", 0)))]

static func day(date: String) -> Dictionary:
	return _days.get(date, {}).duplicate(true) if load_calendar() else {}

static func snapshot(date: Dictionary) -> Dictionary:
	if date.is_empty() or not load_calendar(): return {}
	var key := date_key(date)
	if not _days.has(key): return {} # Explicit seasonal fallback; never replay last year's news.
	var row: Dictionary = _days[key]
	var minute := int(date.get("hour", 0))*60 + float(date.get("minute", 0)) + float(date.get("second", 0))/60.0
	var frames: Array = row.frames
	var a: Dictionary = frames[0]
	var b: Dictionary = frames[-1]
	var b_minute := 1440.0
	var index := _dates.bsearch(key)
	if index + 1 < _dates.size(): b = _days[_dates[index+1]].frames[0]
	for i in frames.size():
		if minute >= float(frames[i].minute): a = frames[i]
		elif float(frames[i].minute) > minute:
			b = frames[i]; b_minute = float(b.minute); break
	var weight := clampf((minute-float(a.minute))/maxf(1.0,b_minute-float(a.minute)),0,1)
	var result: Dictionary = (a if weight < .5 else b).duplicate(true)
	for field: String in NUMERIC: result[field] = lerpf(float(a[field]),float(b[field]),weight)
	result.wind_direction_degrees = fposmod(rad_to_deg(lerp_angle(deg_to_rad(float(a.wind_direction_degrees)),
		deg_to_rad(float(b.wind_direction_degrees)),weight)),360)
	result.source = "campaign-calendar"
	result.observed_at = "%sT%02d:%02d" % [key,int(minute)/60,int(minute)%60]
	result.location = Service.QUEENS.duplicate(true)
	result.precipitation_mm = float(result.rain_mm) + float(result.snowfall_cm)
	result.showers_mm = 0.0
	return result

static func events(snapshot_value: Dictionary) -> Dictionary:
	return {"hail":float(snapshot_value.get("hail",0.0)),
		"cyclone":float(snapshot_value.get("cyclone",0.0)),
		"severe_storm_threat":float(snapshot_value.get("severe_storm_threat",0.0)),
		"formation":int(snapshot_value.get("formation",0))}

## As-of timeline: an issued prediction is retained verbatim after a correction.
## Calling it never gives an NPC/player knowledge of a report.
static func timeline(as_of: String, limit := 4) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not load_calendar() or limit <= 0: return result
	var index := mini(_dates.bsearch(as_of.left(10),true),_dates.size()-1)
	for i in range(index,-1,-1):
		var row: Dictionary = _days[_dates[i]]
		for j in range(row.bulletins.size()-1,-1,-1):
			var bulletin: Dictionary = row.bulletins[j]
			if str(bulletin.issued_at) <= as_of:
				var entry:=bulletin.duplicate(true)
				entry["observation"]=report_at(str(bulletin.issued_at))
				result.push_front(entry)
				if result.size() >= limit: return result
	return result

static func report_at(timestamp: String) -> String:
	var complete:=timestamp+":00" if timestamp.length()==16 else timestamp
	var facts:=snapshot(Time.get_datetime_dict_from_datetime_string(complete,false))
	if facts.is_empty(): return "Observation unavailable."
	var code:=int(facts.weather_code)
	var condition:="fair intervals"
	if code in [95,96,99]: condition="thunder showers"
	elif code in [71,73,75]: condition="snow"
	elif code in [61,63,65]: condition="rain"
	elif code in [45,48]: condition="fog"
	elif code==3: condition="cloudy"
	var bearing: String=WINDS[roundi(float(facts.wind_direction_degrees)/22.5)%16]
	return "%s E.S.T.: %s; %d degrees F.; wind %s %d miles per hour; glass %.2f inches." % [
		print_time(timestamp),condition,roundi(float(facts.temperature_c)*9/5+32),bearing,
		roundi(float(facts.wind_speed_kmh)/1.609344),float(facts.pressure_hpa)*.029529983]

static func print_time(timestamp: String) -> String:
	if timestamp.length()<16: return timestamp
	var month:=int(timestamp.substr(5,2))
	if month<1 or month>12: return timestamp
	var hour:=int(timestamp.substr(11,2))
	var minute:=int(timestamp.substr(14,2))
	return "%d %s %s, %d%s %s"%[int(timestamp.substr(8,2)),MONTHS[month-1],timestamp.left(4),
		12 if hour%12==0 else hour%12,":%02d"%minute if minute!=0 else "","A.M." if hour<12 else "P.M."]

static func press_report(date: String, paper: String) -> Dictionary:
	var row := day(date)
	if row.is_empty(): return {}
	var minute := 360 if paper == "record" else 1020
	var bulletin: Dictionary = row.bulletins[0 if paper == "record" else 1]
	return {"ear":str(row.record_ear if paper == "record" else row.speaker_ear),
		"observation":report_at(str(bulletin.issued_at)),
		"issued_at":str(bulletin.issued_at),"valid_from":str(bulletin.valid_from),
		"valid_until":str(bulletin.valid_until),"prediction":str(bulletin.prediction),
		"outlook":str(bulletin.outlook),"confidence":str(bulletin.confidence),
		"revision":str(bulletin.revision),"chapter":str(row.chapter),
		"story_hook":str(row.story_hook),"timeline":timeline("%sT%02d:%02d"%[date,minute/60,minute%60],2)}
