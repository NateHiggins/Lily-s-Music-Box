extends "res://tests/v2_bathroom_finishing_review.gd"
## INERT combined-world diagnostic. Reuse installed validators; no new runtime grant.
func _init() -> void:route_label="V2 MAIN INTEGRATION WORLD"
func _route() -> void:
	await super._route()
	var retirement:=preload("res://tests/v2_arcade_retirement_review.gd").new()
	retirement.batch_mode=true;retirement.set_meta("shared_world_validation",true);add_child(retirement)
	var result: Dictionary=await retirement.validate_in_world(world)
	for failure: String in result.failures:_require(false,"retirement: "+failure)
	_require(int(result.checks)>900 and result.failures.is_empty(),"current News finish and arcade retirement validators execute in the merged world")
	retirement.queue_free()
	_require(is_instance_valid(world.conversations) and world.conversations.errors.is_empty(),"main resident-conversation owner still mounts with valid trees")
	_require(is_instance_valid(world.period_traffic),"main period-traffic authority mounts beside the V2 repairs")
	_require(world.passage_region.find_child("NewsStand",true,false)!=null,"main newspaper counter remains available after cabinet retirement")
	var output:=OS.get_environment("SHOT_DIR")
	FileAccess.open(output.path_join("integration_world.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Combined existing bathroom input/geometry and News/retirement diagnostics; main owner-presence checks are not played dialogue, newspaper or traffic qualification","retirement_checks":result.checks,"failures":failures},"\t"))
