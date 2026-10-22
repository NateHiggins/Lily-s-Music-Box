extends "res://tests/v2_fire_capacity_rig_programme.gd"
## Separate506-ring candidate. Dense prototype defaults/predicates remain intact.
class CandidateWorldProgramme extends "res://tests/v2_fire_hose_world_contact_programme.gd":
	func _check_native_sections(owner_rig: RefCounted,owner_contact: RefCounted) -> void:
		check(owner_contact.sections.size()==506 and owner_contact.sections.size()==owner_rig.indices.size(),"all506 candidate sections retain32outer and32inner native points")
func _projection_path() -> String:return "res://tests/fixtures/v2_deployable_hose_rig.json"
func _make_world_programme() -> RefCounted:return CandidateWorldProgramme.new()
func _check_native_density() -> void:
	check(rig.indices.size()==506 and rig.indices.size()==rig.rest.size() and absf(rig.strand.total_length-15.24)<.00002,"506 native candidate rings retain the full15.24m strand")
	var widest:=0.
	for distance: float in rig.strand.lengths:widest=maxf(widest,distance)
	check(widest<=.080001,"candidate straight spans are at most80mm and all authored curve rings remain")
	print("FIRE CANDIDATE RESOLUTION: rings=",rig.indices.size()," maximum_interval_m=",widest)
