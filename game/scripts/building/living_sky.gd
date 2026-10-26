extends RefCounted
## Read-only cloud interpretation. WeatherManager, CampaignWeather and the
## existing clock remain authoritative. No HTTP, save domain or weather rolls.
const PATH := "res://data/weather/living_sky.json"
const Calendar := preload("res://scripts/game/campaign_weather.gd")
const ARRANGEMENTS := ["isolated","clustered","cellular","sheet","streets","waves","frontal","towers","fragmented","wind_aligned"]
static var brushes: Dictionary = {}
static var scenarios: Array = []
static var climate_label := ""

static func load_library() -> bool:
	if not brushes.is_empty(): return true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is not Dictionary or data.get("schema_version")!=1 or data.get("genera") is not Array or data.get("scenarios") is not Array: return false
	var found := {}
	for row: Dictionary in data.genera:
		if row.get("id","") in found or str(row.get("id","")) not in ["Ci","Cc","Cs","Ac","As","Ns","Sc","St","Cu","Cb"] or int(row.get("band",-1)) not in [0,1,2]: return false
		for field: String in ["base_km","thickness_km","scale_km","optical_depth"]:
			if not row.get(field) is float and not row.get(field) is int: return false
			if not is_finite(float(row[field])) or float(row[field])<=0.0:return false
		found[str(row.id)]=row
	if found.size()!=10 or data.scenarios.size()!=50: return false
	var ids: Dictionary={}
	for row: Dictionary in data.scenarios:
		var id:=int(row.get("id",0))
		if id<1 or id>50 or ids.has(id):return false
		ids[id]=true
		if not found.has(str(row.get("genus",""))) or str(row.get("arrangement","")) not in ARRANGEMENTS or str(row.get("label","")).is_empty() or str(row.get("eligibility","")).is_empty(): return false
	brushes=found; scenarios=data.scenarios; climate_label=str(data.get("climate","Queens"))
	return true

static func eligible(tag: String,c: Dictionary,hour: float,snow_stock := 0.0) -> bool:
	var rain := float(c.get("rain_intensity",0)); var snow := float(c.get("snow_intensity",0))
	var cover := float(c.get("cloud_total",0)); var wind := float(c.get("wind_speed_kmh",0))
	var humidity := float(c.get("relative_humidity",.5)); var temp := float(c.get("temperature_c",10))
	var wet := rain+snow>.01; var storm := bool(c.get("thunderstorm",false))
	match tag:
		"ineligible": return false
		"clear": return cover<.05 and not wet
		"humid": return cover<.15 and humidity>.7 and not wet
		"high": return float(c.get("cloud_high",0))>.10 and not storm
		"middle": return float(c.get("cloud_mid",0))>.20 and not storm
		"fair": return cover>.05 and cover<.6 and not wet
		"windy": return wind>20 and cover>.2 and not wet
		"broken": return cover>.25 and cover<.88 and not wet
		"overcast": return cover>.8 and not wet
		"multilevel": return float(c.get("cloud_low",0))>.1 and float(c.get("cloud_mid",0))>.1 and float(c.get("cloud_high",0))>.1
		"approach": return cover>.5 and float(c.get("pressure_hpa",1013))<1014 and not wet
		"clearing": return cover>.15 and cover<.75 and wind>12 and not wet
		"convective": return temp>16 and hour>10 and hour<19 and cover>.1 and not wet
		"wet": return rain>.01
		"dry": return cover>.15 and not wet
		"storm": return storm
		"drizzle": return rain>.0 and rain<.25
		"rain": return rain>=.15 and rain<.75
		"heavy": return rain>=.75
		"flurry": return snow>.0 and snow<.4
		"snow": return snow>=.4
		"mixed": return rain>.0 and snow>.0 or int(c.get("provider_weather_id",-1)) in [611,612,613,615,616]
		"freezing": return int(c.get("weather_code",0)) in [66,67] or int(c.get("provider_weather_id",-1))==511
		"fog_calm": return bool(c.get("foggy",false)) and wind<10
		"fog_wind": return bool(c.get("foggy",false)) and wind>=10
		"mist": return bool(c.get("foggy",false))
		"haze": return humidity>.75 and not wet
		"dust": return float(c.get("dust",0))>.05
		"smoke": return not wet and wind<15
		"snow_stock": return snow_stock>.01 and wind>30 and temp<0
	return false

static func sample(date: Dictionary,c: Dictionary,seed_value := 1928,transport_override := Vector2(INF,INF)) -> Dictionary:
	if not load_library(): return {}
	var seconds := float(Time.get_unix_time_from_datetime_dict(date))
	var elapsed := seconds-float(Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00"))
	var hour := float(date.get("hour",0))+float(date.get("minute",0))/60.0
	var cover := clampf(float(c.get("cloud_total",0)),0,1)
	var rain := float(c.get("rain_intensity",0)); var snow := float(c.get("snow_intensity",0))
	var storm := bool(c.get("thunderstorm",false)); var fog := bool(c.get("foggy",false))
	var temp := float(c.get("temperature_c",10)); var rh := clampf(float(c.get("relative_humidity",.5)),.01,1)
	var pressure := float(c.get("pressure_hpa",1013)); var wind := float(c.get("wind_speed_kmh",0))
	var previous: Dictionary = Calendar.snapshot(Time.get_datetime_dict_from_unix_time(int(seconds)-21600)) if not transport_override.is_finite() else {}
	var pressure_tendency := pressure-float(previous.get("pressure_hpa",pressure))
	var previous_wet := float(previous.get("rain_mm",0))+float(previous.get("snowfall_cm",0))>.02
	var regime := "settled"
	if storm: regime="convective"
	elif snow>.01: regime="winter_precipitation"
	elif rain>.01: regime="frontal_passage"
	elif fog or cover>.85: regime="persistent_low_cloud"
	elif cover<.8 and (previous_wet or pressure_tendency>.8): regime="post_frontal"
	elif (pressure<1014 or pressure_tendency<-.8) and cover>.5: regime="frontal_approach"
	elif wind>20 and cover<.75: regime="post_frontal"
	elif rh>.75: regime="humid"
	var low := "Cb" if storm else ("St" if fog else ("Sc" if cover>.5 or temp<8 else "Cu"))
	var mid := "Ns" if rain+snow>.01 and not storm else ("As" if cover>.75 else "Ac")
	var high := "Cs" if cover>.65 else ("Cc" if pressure>1020 and temp<12 else "Ci")
	var genera := [low,mid,high]
	var fractions := Vector3(float(c.get("cloud_low",cover)),float(c.get("cloud_mid",0)),float(c.get("cloud_high",0)))
	# Optical union, not addition. Reconcile strata to the observation's total.
	var tau := 0.0
	for i in 3: tau-=log(maxf(.0001,1.0-clampf(fractions[i],0,.9999)))
	if tau<.0001: fractions=Vector3(cover,0,0)
	else:
		var gain := -log(maxf(.0001,1.0-cover))/tau
		for i in 3: fractions[i]=1.0-pow(maxf(.0001,1.0-clampf(fractions[i],0,.9999)),gain)
	if cover<=.0001: fractions=Vector3.ZERO
	var precise:=Calendar.cloud_transport_at(seconds) if not transport_override.is_finite() else PackedFloat64Array([transport_override.x,transport_override.y])
	var transport:=Vector2(precise[0],precise[1]) if precise.size()==2 else Vector2.ZERO
	var bearing := deg_to_rad(float(c.get("wind_direction_degrees",0)))
	var surface := Vector2(-sin(bearing),cos(bearing))*wind/3.6
	var layers: Array[Dictionary] = []
	var layout := int(posmod(seed_value,65521))
	var gamma := log(rh)+17.625*temp/(243.04+temp)
	var dew_point := 243.04*gamma/(17.625-gamma)
	# Shape identity stays stable throughout the year; evolution is continuous.
	for band in 3:
		var brush: Dictionary=brushes[genera[band]]
		var shear: float = [0.0,.31,-.44][band]
		var speed: float = [1.0,1.45,2.1][band]
		var jet: Vector2=[Vector2.ZERO,Vector2(1.8,-.6),Vector2(5,2)][band]
		var velocity: Vector2 = surface.rotated(shear)*speed+jet/3.6
		var thickness := float(brush.thickness_km)
		if genera[band]=="Cu": thickness=lerpf(.45,2.1,smoothstep(8,27,temp)*maxf(.1,sin((hour-6)/12*PI)))
		var pattern := "sheet" if genera[band] in ["St","Ns","As","Cs"] else ("wind_aligned" if band==2 else ("streets" if wind>20 else "clustered"))
		if genera[band] in ["Ac","Sc"] and wind>12 and wind<=20:pattern="waves"
		if regime=="frontal_approach" and band==1:pattern="frontal"
		var base := float(brush.base_km)
		if genera[band] in ["Cu","Cb"]:base=clampf(.125*(temp-dew_point),.60,2.4)
		layers.append({"id":"cloud_%d"%band,"genus":genera[band],"coverage":fractions[band],
			"base_km":base,"thickness_km":thickness,"scale_km":float(brush.scale_km),
			"optical_depth":float(brush.optical_depth),"arrangement":pattern,"wind":velocity,
			"shape_seed":layout+band*179})
	var candidates: Array[int] = []
	var selected: Dictionary = {}
	for row: Dictionary in scenarios:
		if eligible(str(row.eligibility),c,hour):
			candidates.append(int(row.id))
			# Classify the weather-derived composition, never reroll its geometry
			# at midnight to satisfy a recipe or annual diversity quota.
			if row.genus in genera and (selected.is_empty() or str(row.arrangement)==str(layers[genera.find(row.genus)].arrangement)): selected=row
	var result: Dictionary={"mode":"curated-year","climate":climate_label,"regime":regime,"simulation_seconds":elapsed,"layers":layers,
		"pressure_tendency_hpa_6h":pressure_tendency,
		"combined_coverage":1.0-(1.0-fractions.x)*(1.0-fractions.y)*(1.0-fractions.z),
		"dew_point_c":dew_point,"surface_wind":surface,
		"aerosol_density":clampf(.12+rh*.14-float(c.get("rain_intensity",0))*.08,.05,.4),
		"eligible_scenarios":candidates,"scenario_id":int(selected.get("id",0)),"scenario_label":str(selected.get("label","Clear atmosphere"))}
	move_fields(result,date,transport,precise)
	return result

## Cheap continuous motion between one-second morphology publications.
static func move_fields(state: Dictionary,date: Dictionary,transport: Vector2,precise := PackedFloat64Array(),elapsed_override := INF) -> void:
	if state.is_empty(): return
	var elapsed: float=elapsed_override if is_finite(elapsed_override) else float(Time.get_unix_time_from_datetime_dict(date))-float(Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00"))
	var x: float=precise[0] if precise.size()==2 else transport.x
	var y: float=precise[1] if precise.size()==2 else transport.y
	state.simulation_seconds=elapsed
	for band in 3:
		var shear: float=[0.0,.31,-.44][band]
		var speed: float=[1.0,1.45,2.1][band]
		var jet: Vector2=[Vector2.ZERO,Vector2(1.8,-.6),Vector2(5,2)][band]
		var dx:=(x*cos(shear)-y*sin(shear))*speed+float(jet.x)*(elapsed/3600.0)
		var dy:=(x*sin(shear)+y*cos(shear))*speed+float(jet.y)*(elapsed/3600.0)
		state.layers[band].offset_km=Vector2(dx,dy)
		state.layers[band].offset_precise=PackedFloat64Array([dx,dy])
		state.layers[band].evolution=elapsed/2400.0+float(band)*7.31

static func publish(material: ShaderMaterial,state: Dictionary) -> void:
	if not state.has("layers") or state.layers.size()!=3:return
	for i in 3:
		var layer: Dictionary=state.layers[i]
		var kind: int=["Ci","Cc","Cs","Ac","As","Ns","Sc","St","Cu","Cb"].find(layer.genus)
		var detailed: PackedFloat64Array=layer.get("offset_precise",PackedFloat64Array([layer.offset_km.x,layer.offset_km.y]))
		var x:=-detailed[0]/maxf(float(layer.scale_km),.1)
		var y:=-detailed[1]/maxf(float(layer.scale_km),.1)
		var arrangement:=ARRANGEMENTS.find(layer.arrangement)
		var sx:=.035 if kind==0 else (.125 if kind in [2,4,5,7] else (.025 if kind==1 else .065))
		var sy:=.11 if kind==0 else sx*(.32 if arrangement in [4,9] and kind not in [2,4,5,7] else 1.0)
		material.set_shader_parameter("living_layer_%d"%i,Vector4(layer.coverage,layer.base_km,layer.thickness_km,kind))
		# Each periodic coordinate is reduced in double precision BEFORE upload.
		# Reducing the whole world offset would jump unrelated noise frequencies.
		material.set_shader_parameter("living_motion_%d"%i,Vector4(fposmod(x*sx,1.0),fposmod(y*sy,1.0),fposmod(float(layer.evolution)*.001,1.0),layer.shape_seed))
		material.set_shader_parameter("living_drift_%d"%i,Vector4(fposmod(x*.043,1.0),fposmod(y*.043,1.0),fposmod(x*.22 if kind==0 else y*2.2,TAU),fposmod(x*.16,TAU)))
		material.set_shader_parameter("living_brush_%d"%i,Vector4(layer.scale_km,layer.optical_depth,arrangement,(layer.wind as Vector2).angle()))
	material.set_shader_parameter("living_enabled",true)
	material.set_shader_parameter("living_aerosol",float(state.aerosol_density))
