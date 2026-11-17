extends Node
const Dream=preload("res://scripts/dream/dream_maze_root.gd")
func _ready() -> void: run.call_deferred()
func run() -> void:
	var directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty():get_tree().quit(2);return
	var original:Dictionary=RealityState.data
	var persistence:bool=RealityState.persistence_enabled
	var write_blocked:bool=RealityState.save_write_blocked
	RealityState.persistence_enabled=false
	var rows:Array=[]
	var failures:Array=[]
	for spec:Dictionary in [{"label":"annual wrap before six","start":180,"elapsed":365.0*1440.0,"loop":true,"expected":"sat"},{"label":"ordinary midnight","start":1380,"elapsed":240.0,"loop":true,"expected":"sat"},{"label":"initial day uses actual available date","start":180,"elapsed":0.0,"loop":true,"expected":"sat"},{"label":"noon stays today","start":720,"elapsed":365.0*1440.0,"loop":true,"expected":"sat"},{"label":"unprojected Gregorian year","start":180,"elapsed":365.0*1440.0,"loop":false,"expected":"sat"},{"label":"five fifty-nine selects previous day","start":1380,"elapsed":419.0,"loop":true,"expected":"sat"},{"label":"six selects today","start":1380,"elapsed":420.0,"loop":true,"expected":"sun"}]:
		RealityState.reset_campaign_for_tests()
		var clock=CampaignClock.new()
		if not clock.configure_date(1928,11,10,int(spec.start)):failures.append(str(spec.label)+" date fixture")
		if spec.loop:RealityState.data.prologue={"effects":{"clock_applied":true}}
		if not clock.advance_to(float(spec.elapsed)):failures.append(str(spec.label)+" elapsed fixture")
		var before:Dictionary=RealityState.data.duplicate(true)
		var reference:Dictionary=RealityState.data
		var dream=Dream.new()
		var after:String=dream._day_just_lived()
		dream.free()
		if before!=RealityState.data or not is_same(reference,RealityState.data):failures.append(str(spec.label)+" mutated campaign state")
		if after!=spec.expected:failures.append(spec.label)
		rows.append({"case":spec.label,"fixed":after,"expected":spec.expected,"campaign":clock.day_info()})
	var result={"evidence_class":"INERT campaign-date regression diagnostic, not whole-dream qualification","failures":failures,"cases":rows}
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	RealityState.data=original;RealityState.persistence_enabled=persistence;RealityState.save_write_blocked=write_blocked
	print("DREAM DAY SELECTION: ",rows.size()," cases / ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
