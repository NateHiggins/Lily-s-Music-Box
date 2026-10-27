extends Node3D
## Presentation only. Campaign time owns every stroke; no timers survive a seek.
## Bounded minute cache, one bolt/light, two thunder voices; no gameplay damage.
const Calendar := preload("res://scripts/game/campaign_weather.gd")
const SHEET := 0
const GROUND := 1
const CRAWLER := 2
var sky: ShaderMaterial
var director: DayNightDirector
var strokes: Array[Dictionary] = []
var last_strike: Dictionary = {}
var thunder_count := 0
var _minute := -INF
var _forced_storm := false
var _tle_bearing := 0.0
var _tle_seed := 0
var _previous := INF
var _heard: Dictionary = {}
var _pending: Dictionary = {}
var _bolt := MeshInstance3D.new()
var _light := OmniLight3D.new()
var _material := StandardMaterial3D.new()
var _voices: Array[AudioStreamPlayer3D] = []
var _sounds: Array[AudioStreamWAV] = []
var _bolt_id := ""
var _tle_id := ""
var _tle_age := -1
var _tle_slot := -1
var _cache: Dictionary = {}

static func minute_strokes(stamp: float) -> Array[Dictionary]:
	var minute := int(floor(stamp/60.0))*60
	var date := Time.get_datetime_dict_from_unix_time(minute)
	var key := "%04d-%02d-%02dT%02d:%02d" % [date.year,date.month,date.day,date.hour,date.minute]
	var rng := RandomNumberGenerator.new()
	rng.seed=key.hash()
	var result: Array[Dictionary] = []
	var count := rng.randi_range(0,12)
	for i in count:
		# At least 700ms between strokes, including across minute boundaries.
		# Every scheduled bolt fits the single light/mesh pool without being dropped.
		var start_ms := int(float(i)*60000.0/float(count))
		var window_ms := int(float(i+1)*60000.0/float(count))-start_ms-700
		var kind := rng.randf()
		var angle := rng.randf_range(-PI,PI)
		var radius := rng.randf_range(90.0,1600.0)
		var at := Vector3(sin(angle)*radius,0,cos(angle)*radius)
		result.append({"id":key+":"+str(i),"time":float(minute)+float(start_ms+rng.randi_range(0,window_ms))*.001,
			"kind":SHEET if kind<.62 else (GROUND if kind<.90 else CRAWLER),
			"ground":at,"cloud":at+Vector3(rng.randf_range(-150,150),rng.randf_range(700,1200),0),
			"strength":rng.randf_range(.45,1.0),"positive":rng.randf()<.12,"seed":rng.randi()})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.time<b.time)
	return result

static func precipitation_gain(stamp: float) -> float:
	# A separate channel of the same minute hash: adding precipitation must
	# never reorder lightning. Smooth, continuous knots; zero rain stays zero.
	var minute:=int(floor(stamp/60.0))*60
	var knots:=PackedFloat64Array()
	for at: int in [minute,minute+60]:
		var date:=Time.get_datetime_dict_from_unix_time(at)
		var key:="%04d-%02d-%02dT%02d:%02d"%[date.year,date.month,date.day,date.hour,date.minute]
		var rng:=RandomNumberGenerator.new();rng.seed=(key+":precipitation").hash()
		knots.append(rng.randf_range(.84,1.16))
	return lerpf(knots[0],knots[1],smoothstep(0.0,1.0,fposmod(stamp,60.0)/60.0))

static func envelope(age: float) -> float:
	if age<0.0 or age>.65:return 0.0
	return exp(-pow((age-.045)/.035,2.0))+.55*exp(-pow((age-.18)/.055,2.0))

static func thunder_delay(at: Vector3,listener: Vector3) -> float:
	return at.distance_to(listener)/343.0

func _ready() -> void:
	name="DeterministicLightningManager"
	_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled=true
	_material.disable_fog=true
	_material.emission_energy_multiplier=15.0
	_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	_bolt.name="GroundDischarge"
	_light.name="GroundFlash"
	_bolt.material_override=_material
	_bolt.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.set_meta("surface_role","weather_optics")
	add_child(_bolt);add_child(_light)
	_light.omni_range=150.0
	_light.shadow_enabled=true
	_light.light_volumetric_fog_energy=8.0
	_light.light_cull_mask=1 # World only; exclude composited device and mirror avatar.
	_light.visible=false;_bolt.visible=false
	for i in 2:
		var voice := AudioStreamPlayer3D.new()
		voice.max_distance=6000.0;voice.unit_size=700.0;voice.volume_db=-14.0
		if AudioServer.get_bus_index("SFX")>=0:voice.bus="SFX"
		add_child(voice);_voices.append(voice)
	for i in 3:_sounds.append(_thunder(i+1928))

func _storm_minute(minute: float,fallback: Dictionary,forced: bool) -> bool:
	if forced:return true
	var dated := Calendar.snapshot(Time.get_datetime_dict_from_unix_time(int(minute)))
	if not dated.is_empty():return int(dated.get("weather_code",0)) in [95,96,99]
	return bool(fallback.get("thunderstorm",false))

func sample(stamp: float,conditions: Dictionary,phenomena: Array) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera!=null else Vector3.ZERO
	var minute: float = floor(stamp/60.0)*60.0
	var forced_storm:=false;var plume_enabled:=false
	for entry: Dictionary in phenomena:
		forced_storm=forced_storm or (float(entry.get("level",1.0))>.35 and bool(entry.get("weather",{}).get("thunderstorm",false)))
		plume_enabled=plume_enabled or int(entry.slot)==28
	if minute!=_minute or forced_storm!=_forced_storm:
		_forced_storm=forced_storm
		_minute=minute;strokes.clear()
		for offset in [-60.0,0.0]:
			var at: float=minute+offset
			if not _cache.has(at):_cache[at]=minute_strokes(at)
			if _storm_minute(at,conditions,forced_storm):strokes.append_array(_cache[at])
		for key: float in _cache.keys():
			if absf(key-minute)>60.0:_cache.erase(key)
	var seek := not is_finite(_previous) or stamp<_previous or stamp-_previous>1.0
	if seek:
		_heard.clear();_pending.clear();_tle_age=-1;_tle_id=""
		for voice: AudioStreamPlayer3D in _voices:voice.stop()
	var plume:=0.0
	if plume_enabled:
		for offset in [-60.0,0.0]:
			for stroke: Dictionary in _cache[minute+offset]:plume=maxf(plume,envelope(stamp-float(stroke.time))*float(stroke.strength))
	var active: Dictionary={};var strongest:=0.0
	for stroke: Dictionary in strokes:
		var age := stamp-float(stroke.time)
		var level := envelope(age)*float(stroke.strength)
		if level>strongest:active=stroke;strongest=level
		# Latch distance when witnessed; walking afterward must not move the bang.
		if not seek and float(stroke.time)>_previous and float(stroke.time)<=stamp:
			_pending[stroke.id]={"due":float(stroke.time)+thunder_delay(stroke.ground,eye),"stroke":stroke}
		if age>=0.0 and age<.65 and int(stroke.kind)==GROUND and bool(stroke.positive) and float(stroke.strength)>.85 and _tle_id!=str(stroke.id):
			_tle_id=str(stroke.id);_tle_age=0;_tle_slot=-1
			_tle_bearing=atan2(float(stroke.cloud.x),-float(stroke.cloud.z));_tle_seed=int(stroke.seed)%4093
			var allowed: Array[int]=[]
			for entry: Dictionary in phenomena:
				if int(entry.slot) in [23,24,25,26]:allowed.append(int(entry.slot))
			if not allowed.is_empty():_tle_slot=allowed[int(stroke.seed)%allowed.size()]
	for id: String in _pending.keys():
		var pending: Dictionary=_pending[id]
		if float(pending.due)<=stamp:
			var stroke: Dictionary=pending.stroke
			_heard[id]=true
			var voice: AudioStreamPlayer3D=_voices[thunder_count%2]
			voice.global_position=stroke.ground;voice.stream=_sounds[int(stroke.seed)%3];voice.play()
			thunder_count+=1;_pending.erase(id)
	_previous=stamp
	# Keep audible history bounded by the two minute cache.
	if _heard.size()>24:_heard.clear()
	var suppressed := bool(GameBoot.settings.get("reduce_flashing",false))
	if suppressed:strongest=0.0
	var tint := Color(.72,.48,1.0)
	if float(conditions.get("hail",0.0))>.05 or int(conditions.get("weather_code",0)) in [96,99]:tint=Color(.68,1.0,.30)
	_bolt.visible=false;_light.visible=false
	var crawler:=0.0
	if not active.is_empty() and strongest>.002:
		last_strike=active
		var kind := int(active.kind)
		if kind==GROUND:
			if _bolt_id!=str(active.id):
				_bolt_id=str(active.id);_bolt.mesh=_bolt_mesh(active)
			_bolt.visible=true;_material.albedo_color=tint;_material.emission=tint
			_material.emission_energy_multiplier=15.0*strongest
			_light.global_position=active.ground+Vector3.UP*15.0
			_light.light_color=tint;_light.light_energy=12.0*strongest;_light.visible=true
		if kind==CRAWLER:crawler=strongest
	if sky!=null:
		sky.set_shader_parameter("strike_position",active.get("cloud",Vector3.ZERO)/1000.0)
		sky.set_shader_parameter("flash_intensity",strongest)
		sky.set_shader_parameter("lightning_tint",Vector3(tint.r,tint.g,tint.b))
	if director!=null:director.set_weather_flash(strongest*.45)
	var tle := _tle_slot if _tle_age>=2 and _tle_age<5 and not suppressed else -1
	if _tle_age>=0:_tle_age+=1
	return {"crawler":crawler,"crawler_bearing":atan2(float(active.cloud.x),-float(active.cloud.z)) if not active.is_empty() else 0.0,"tle":tle,"tle_bearing":_tle_bearing,"plume":0.0 if suppressed else plume,"seed":int(active.seed)%4093 if not active.is_empty() else _tle_seed,"age":stamp-float(active.time) if not active.is_empty() else .15,"level":strongest}

func _bolt_mesh(stroke: Dictionary) -> ArrayMesh:
	var rng := RandomNumberGenerator.new();rng.seed=int(stroke.seed)
	var vertices := PackedVector3Array()
	var start: Vector3=stroke.cloud;var finish: Vector3=stroke.ground
	var prior := start
	for i in range(1,33):
		var next := start.lerp(finish,float(i)/32.0)
		if i<32:next+=Vector3(rng.randf_range(-24,24),rng.randf_range(-8,8),rng.randf_range(-24,24))
		_ribbon(vertices,prior,next,1.0)
		if i%5==0:
			var branch := prior
			for j in 4:
				var tip := branch+Vector3(rng.randf_range(-70,70),-rng.randf_range(12,45),rng.randf_range(-40,40))
				_ribbon(vertices,branch,tip,.45);branch=tip
		prior=next
	var arrays := [];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func _ribbon(vertices: PackedVector3Array,a: Vector3,b: Vector3,width: float) -> void:
	# Crossed ribbons remain legible from every rooftop without camera-facing mutation.
	for axis: Vector3 in [Vector3.RIGHT,Vector3.FORWARD]:
		var w := axis*width
		vertices.append_array(PackedVector3Array([a-w,b-w,b+w,a-w,b+w,a+w]))

static func _thunder(seed_value: int) -> AudioStreamWAV:
	# Three tiny deterministic PCM rumbles, built once; no audio synthesis per frame.
	var rng := RandomNumberGenerator.new();rng.seed=seed_value
	var bytes := PackedByteArray();bytes.resize(22050*4*2)
	var low:=0.0
	for i in 22050*4:
		var t:=float(i)/22050.0
		low=lerpf(low,rng.randf_range(-1,1),.08)
		var value: float=(low*.8+sin(t*TAU*43.0)*.08)*exp(-t*.9)*minf(1.0,t*25.0)
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*28000.0))
	var wav := AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=22050;wav.data=bytes
	return wav
