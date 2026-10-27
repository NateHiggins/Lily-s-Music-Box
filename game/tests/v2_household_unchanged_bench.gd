extends Node
## INERT state-contract fixture, not geometry, actual-input or disk qualification.
const Owner:=preload("res://scripts/building/orison_v2_household_state.gd")
class Subject extends Node:
	var angle:=.2
	var validations:=0
	var restores:=0
	var related:=false
	func valid_mechanism(value: Variant) -> bool:
		validations+=1
		return value is Dictionary and value.size()==1 and typeof(value.get("angle")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value.angle)) and value.angle>=0. and value.angle<=1.
	func mechanism_snapshot() -> Dictionary:return {"angle":angle}
	func restore_mechanism(value: Dictionary) -> void:angle=float(value.angle);restores+=1
	func validate_related_records(records: Dictionary) -> bool:
		return not related or records.SUBJECT.value.angle==records.RELATED.value.angle
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"ok":ok,"label":label});print("HOUSEHOLD CACHE: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:run.call_deferred()
func run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var subject:=Subject.new();subject.related=true;add_child(subject)
	var related:=Subject.new();add_child(related)
	var owner:=Owner.new();add_child(owner)
	owner._kinds={"SUBJECT":"mechanism","RELATED":"mechanism"};owner._subjects={"SUBJECT":subject,"RELATED":related}
	var value: Dictionary={"schema_version":1,"records":{"SUBJECT":{"kind":"mechanism","value":{"angle":.2}},"RELATED":{"kind":"mechanism","value":{"angle":.2}}}}
	owner._defaults=value.duplicate(true);RealityState.data[Owner.KEY]=value.duplicate(true)
	check(owner.validate(value,owner._kinds),"initial payload passes the real household validator")
	owner._restore(value);owner._bound=true
	var calls: int=subject.validations;var restores: int=subject.restores
	subject.angle=.73;owner.errors.append("old diagnostic")
	owner._on_state_changed()
	check(subject.validations==calls and subject.restores==restores and subject.angle==.73 and owner.errors.is_empty(),"same owned payload skips validation without rolling back live intermediate motion")
	owner.reuse_unchanged_validation=false;owner._on_state_changed()
	check(subject.validations>calls and subject.restores==restores and subject.angle==.73,"original-order control validates but also preserves live motion")
	owner.reuse_unchanged_validation=true;calls=subject.validations
	RealityState.data=RealityState.data.duplicate(true);owner._on_state_changed()
	check(subject.validations>calls and subject.restores==restores+1 and subject.angle==.2,"equal-valued replacement document still validates and restores")
	RealityState.data[Owner.KEY].records.SUBJECT.value.angle=.4
	RealityState.data[Owner.KEY].records.RELATED.value.angle=.4
	owner._on_state_changed()
	check(not owner._blocked and subject.angle==.4 and related.angle==.4,"changed valid payload restores through the original authority")
	RealityState.data[Owner.KEY].records.SUBJECT.value.angle=2.
	restores=subject.restores;owner._on_state_changed()
	check(owner._blocked and subject.restores==restores and subject.angle==.4,"in-place invalid mutation blocks without restoring invalid state")
	RealityState.data[Owner.KEY]=owner._last_saved.duplicate(true);calls=subject.validations;owner._on_state_changed()
	check(not owner._blocked and subject.validations>calls and subject.restores==restores+1,"blocked recovery validates even when payload equals the last good value")
	RealityState.data[Owner.KEY].records.RELATED.value.angle=.5
	restores=subject.restores;owner._on_state_changed()
	check(owner._blocked and subject.restores==restores,"cross-record inconsistency still fails full related-record validation")
	RealityState.data[Owner.KEY]=owner._last_saved.duplicate(true);owner._on_state_changed()
	RealityState.data[Owner.KEY].schema_version=2;owner._on_state_changed()
	check(owner._blocked,"changed unsupported schema still blocks")
	RealityState.data[Owner.KEY]=owner._last_saved.duplicate(true);owner._on_state_changed()
	subject.angle=.61;related.angle=.61
	check(owner.capture_now() and RealityState.data[Owner.KEY].records.SUBJECT.value.angle==.61,"new live positions still snapshot and validate before publication")
	calls=subject.validations;owner.errors.append("old diagnostic")
	check(not owner.capture_now() and subject.validations==calls and owner.errors.is_empty(),"unchanged live snapshot reuses the validated owned payload")
	owner.reuse_unchanged_validation=false;calls=subject.validations
	check(not owner.capture_now() and subject.validations>calls,"original-order unchanged capture still validates as a paired control")
	owner.reuse_unchanged_validation=true;subject.angle=2.;calls=subject.validations
	check(not owner.capture_now() and subject.validations>calls and RealityState.data[Owner.KEY].records.SUBJECT.value.angle==.61,"invalid new live state cannot reuse cached validation or overwrite saved state")
	# One changed control must not revalidate an unrelated, exactly equal record.
	subject.related=false;subject.angle=.62
	calls=subject.validations;var unrelated_calls: int=related.validations
	check(owner.capture_now() and subject.validations==calls+1 and related.validations==unrelated_calls,"changed capture validates the edited record and reuses the exact unchanged record")
	subject.related=true;subject.angle=.63;calls=related.validations
	check(not owner.capture_now() and related.validations==calls and RealityState.data[Owner.KEY].records.SUBJECT.value.angle==.62,"cross-record disagreement blocks even when the related record reuses individual validation")
	subject.related=false;subject.angle=.64;owner.reuse_unchanged_validation=false
	calls=related.validations
	check(owner.capture_now() and related.validations>calls,"disabled reuse validates every record on a changed capture")
	owner.reuse_unchanged_validation=true;calls=related.validations
	check(owner.validate(owner._last_saved,owner._kinds) and related.validations>calls,"public validation never trusts unchanged records implicitly")
	owner._bound=false;calls=subject.validations;owner._on_state_changed()
	check(subject.validations==calls,"unbound owner does not process campaign events")
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out);FileAccess.open(out.path_join("checks.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures},"\t"))
	print("HOUSEHOLD CACHE: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
