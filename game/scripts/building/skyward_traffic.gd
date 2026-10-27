extends Node3D
## Passive alternate-history trade. Presentation samples the existing calendar;
## no accumulated journeys, RNG stream, save record or weather/time ownership.
const Traffic := preload("res://scripts/building/orison_v2_street_traffic.gd")
const DATA := "res://data/orison_v2/exterior/skyward_liner.json"
var table: Dictionary
var frame := Transform3D.IDENTITY
var hull: MeshInstance3D
var propellers: Array[MeshInstance3D]=[]
var last_sample: Dictionary={}

func configure(world_frame: Transform3D) -> void:
	frame=world_frame
	table=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	assert(table.schema=="orison.skyward-liner.v1")
	assert(table.classification=="FICTIONAL_PERIOD_ADAPTATION")
	var finishes := {}
	for finish: Dictionary in table.finishes:
		assert(MatLib.SETS.has(str(finish.catalog_key)))
		assert(finish.tint is Array and finish.tint.size()==4)
		assert(is_finite(float(finish.normal)) and float(finish.normal)>=0.)
		assert(is_finite(float(finish.roughness)) and float(finish.roughness)>=0.)
		finishes[finish.id]=Traffic.stock_material(finish)
	var meshes := Traffic.stock_meshes(table.stock,finishes)
	assert(meshes.has("liner") and meshes.has("propeller"))
	var length := (meshes.liner as Mesh).get_aabb().size.x
	# Mooring hardware projects beyond the stated envelope length.
	assert(length>=float(table.length_m)*.99 and length<float(table.length_m)+1.,"Native liner length disagrees with its source table")
	hull=MeshInstance3D.new();hull.name="PassengerLiner";hull.mesh=meshes.liner;add_child(hull)
	hull.set_meta("v2_skyward_stock",true)
	# Ordinary sun/moon shadows and world depth; no second sun or light mask
	# shortcut. Real shadow coverage still needs occupied-world verification.
	for mount: Array in table.propeller_mounts:
		var prop := MeshInstance3D.new();prop.name="DrivenPropeller";prop.mesh=meshes.propeller
		prop.position=Vector3(mount[0],mount[1],mount[2]);hull.add_child(prop);propellers.append(prop)
	hide()

static func sample(minutes: float,conditions: Dictionary) -> Dictionary:
	if not is_finite(minutes):return {"active":false}
	var day := int(floor(minutes/1440.))
	var seed := posmod(day*1103515245+12345,2147483647)
	var minute := fposmod(minutes,1440.)
	var jitter := float(posmod(seed,31)-15)
	var departures := [510.,720.,960.,1200.]
	for i in departures.size():
		var phase := (minute-float(departures[i])-jitter)/16.
		if phase<0. or phase>1.:continue
		if float(conditions.get("wind_speed_kmh",0.))>50. or float(conditions.get("precipitation_intensity",0.))>.55:
			return {"active":false,"weather_hold":true}
		var t := phase if i%2==0 else 1.-phase
		var a := Vector3(-650,105,-160);var b := Vector3(-250,112,-75)
		var c := Vector3(250,108,-75);var d := Vector3(650,116,-160)
		var p := a*pow(1.-t,3)+b*3.*t*pow(1.-t,2)+c*3.*t*t*(1.-t)+d*t*t*t
		p.y+=float(posmod(seed,19))
		var tangent := (b-a)*3.*pow(1.-t,2)+(c-b)*6.*t*(1.-t)+(d-c)*3.*t*t
		if i%2!=0:tangent=-tangent
		var forward := tangent.normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var up := side.cross(forward).normalized()
		return {"active":true,"phase":phase,"flight":i,"day":day,"pose":Transform3D(Basis(forward,up,side),p),"propeller_angle":fposmod(minutes*60.*15.,TAU)}
	return {"active":false}

func update(clock: CampaignClock,conditions: Dictionary) -> void:
	last_sample=sample(clock.absolute_minutes(),conditions)
	visible=bool(last_sample.active)
	if not visible:return
	global_transform=frame
	hull.transform=last_sample.pose
	for prop in propellers:prop.rotation.x=float(last_sample.propeller_angle)
