extends Node3D
## Closed source-derived city masses. Existing street, shop and alley owners
## retain their ground, openings and actors; this region adds none of those.
const ASSET := preload("res://assets/props/city_elevations.glb")
const FINISHES := "res://data/orison_v2/exterior/city_elevations.json"
var _clock := CampaignClock.new()
var _clock_hands: Array[Dictionary] = []
var _clock_elapsed := 0.0
var displayed_minute := -1.0
var clock_refresh_usec: Array[int] = []
var clock_pose_publications := 0
var _profile_clock := false

func _ready() -> void:
	_profile_clock=OS.get_environment("SKYWATCH_CLOUD_PROFILE")=="1"
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	if section.is_empty(): return
	position.z = -float(section.source_threshold_z)
	var model := ASSET.instantiate() as Node3D
	add_child(model)
	var placement := preload("res://scripts/building/orison_v2_city_placement.gd").new()
	var materials: Dictionary={}
	var profiles: Dictionary={}
	var finish_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FINISHES))
	assert(int(finish_data.schema)==1)
	var hands: Dictionary={}
	for hand: Dictionary in finish_data.get("clock_hands",[]):
		assert(not hands.has(str(hand.part)))
		hands[str(hand.part)]=hand
	for profile: Dictionary in finish_data.buildings:profiles[str(profile.id)]=profile
	var roof_finishes := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		placement.apply(mesh)
		mesh.set_meta("retained_city_shell",true)
		var key := str(mesh.name).split("__")[-1]
		var building := str(mesh.name).split("__")[0]
		assert(profiles.has(building),"City elevation has no authored finish: "+building)
		var profile: Dictionary=profiles[building]
		var tint_key: Array=profile.wall_tint if key==str(profile.wall_key) else profile.frame_tint if key=="door_paint" else [1,1,1,1]
		var cache_key := key+"|"+str(tint_key)
		assert(MatLib.SETS.has(key),"City material must be catalogued: " + key)
		if not materials.has(cache_key):
			var material:=MatLib.get_mat(key).duplicate() as StandardMaterial3D
			material.uv1_triplanar=false
			material.normal_scale=.65
			if key==str(profile.wall_key):
				var tint: Array=profile.wall_tint
				material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			elif key=="door_paint":
				var tint: Array=profile.frame_tint
				material.albedo_color=Color(tint[0],tint[1],tint[2],tint[3])
			elif key=="mirror_aged":
				# A real closed pane in front of separately built curtains/backing.
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color=Color(.18,.23,.25,.28)
				material.metallic=0.0
				material.roughness=.45
				material.normal_scale=.12
			materials[cache_key]=material
		mesh.material_override=materials[cache_key]
		if key == "galvanized_roof":
			mesh.set_meta("v2_city_roof_source",materials[cache_key])
			mesh.material_override=roof_finishes.material_for(materials[cache_key],"roof")
		var body := StaticBody3D.new()
		body.set_meta("retained_city_shell",true)
		body.name = str(mesh.name)+"Collision"
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_trimesh_shape()
		collision.transform = mesh.transform
		body.add_child(collision)
		model.add_child(body)
		if hands.has(str(mesh.name)):
			var hand: Dictionary=hands[str(mesh.name)]
			var pivot: Array=hand.pivot
			var normal: Array=hand.normal
			var axis:=Vector3(normal[0],normal[1],normal[2])
			var period:=float(hand.period_minutes)
			assert(is_equal_approx(axis.length(),1.) and period in [60.,720.])
			_clock_hands.append({"draw":mesh,"collision":collision,"rest":mesh.transform,
				"pivot":Vector3(pivot[0],pivot[1],pivot[2])+placement.city_offset(str(mesh.name)),"normal":axis,"period":period})
	assert(_clock_hands.size()==hands.size())
	refresh_clock_from_campaign()
	set_process(not _clock_hands.is_empty())
	preload("res://scripts/building/orison_v2_city_masts.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_aerials.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_tanks.gd").mount(self)
	preload("res://scripts/building/orison_v2_city_beacons.gd").mount(self)

func _process(delta: float) -> void:
	_clock_elapsed+=delta
	if _clock_elapsed<.5:return
	_clock_elapsed=fmod(_clock_elapsed,.5)
	refresh_clock_from_campaign()

func refresh_clock_from_campaign() -> bool:
	if not _profile_clock:return _project_clock_from_campaign()
	var started:=Time.get_ticks_usec()
	var result:=_project_clock_from_campaign()
	clock_refresh_usec.append(Time.get_ticks_usec()-started)
	if clock_refresh_usec.size()>1024:clock_refresh_usec.pop_front()
	return result

func _project_clock_from_campaign() -> bool:
	# Read the existing authority; no clock writer, save record or scene uptime.
	if _clock_hands.is_empty() or not _clock.bind_state():return false
	var minute:=_clock.minute_of_day()
	if is_equal_approx(minute,displayed_minute):return true
	displayed_minute=minute
	clock_pose_publications+=1
	for hand: Dictionary in _clock_hands:
		var rotation:=Basis(hand.normal,-TAU*fposmod(minute,float(hand.period))/float(hand.period))
		var turn:=Transform3D(rotation,hand.pivot-rotation*hand.pivot)
		hand.draw.transform=turn*(hand.rest as Transform3D)
		hand.collision.transform=hand.draw.transform
	return true
