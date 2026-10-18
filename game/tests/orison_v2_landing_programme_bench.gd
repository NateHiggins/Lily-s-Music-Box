extends Node
## INERT source/owner bench. Played circulation requires the production harness.
const Footprints=preload("res://scripts/building/orison_v2_space_footprints.gd")
const Programmes=preload("res://scripts/building/orison_v2_landing_programmes.gd")
const Review=preload("res://tests/orison_v2_landing_programme_review.gd")
const Walk=preload("res://tests/orison_v2_public_landing_walk.gd")
const Contract=preload("res://tests/v2_public_landing_access_contract.gd")
var checks:=0
var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)

func _ready() -> void:
	check(Review!=null,"capture harness compiles before production composition")
	check(Walk!=null,"physical circulation driver compiles before production composition")
	check(Contract!=null,"original spatial contract writer compiles before composition")
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2_blockout.json"))
	var shell:=preload("res://scripts/building/orison_v2_blockout.gd").new()
	shell.layout=layout;shell._validate_layout()
	check(shell.failures.is_empty(),"full schema accepts exact platform ownership without new geometry")
	shell.free()
	var index:=Footprints.room_index(layout)
	var count:=0
	for space: Dictionary in layout.spaces:
		if not space.has("landing_core"):continue
		count+=1
		check(Footprints.programme_errors(layout,space).is_empty(),"supported programme: "+str(space.id))
		check(Footprints.contains_xz(layout,space,Vector2(3.4,2.75)),"north platform belongs to programme: "+str(space.id))
		check(not Footprints.contains_xz(layout,space,Vector2(0,-1.5)),"lift void is not programme floor: "+str(space.id))
		var y:=0.0
		for level: Dictionary in layout.levels:
			if level.id==space.level:y=float(level.y)
		check(Footprints.room_at_index(index,Vector3(3.4,y,2.75),float(layout.dimensions.floor_to_floor))==str(space.id),"live room query selects supported landing: "+str(space.id))
		check(Footprints.room_at_index(index,Vector3(0,y,-1.5),float(layout.dimensions.floor_to_floor))==str(space.landing_core),"shaft retains its core volume authority: "+str(space.id))
		for defect: String in ["missing","foreign","landmark"]:
			var broken: Dictionary=space.duplicate(true)
			if defect=="missing":broken.erase("floor_platforms")
			if defect=="foreign":broken.floor_platforms=["B1_PUBLIC_LANDING_S"]
			if defect=="landmark":broken.programme_anchors=["invented_landmark"]
			check(not Footprints.programme_errors(layout,broken).is_empty(),"invalid ownership refused: "+defect)
			check(not Footprints.contains_xz(layout,broken,Vector2(0,-1.5)),"invalid programme cannot fill a shaft: "+defect)
	check(count==6,"all six occupied floors have actual landing programmes")
	var programme:=Programmes.new()
	check(programme.snapshot().is_empty(),"unmounted owner census is empty")
	programme.teardown();programme.teardown()
	check(programme.snapshot().is_empty(),"owner retirement is idempotent")
	print("V2 LANDING PROGRAMME BENCH ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
