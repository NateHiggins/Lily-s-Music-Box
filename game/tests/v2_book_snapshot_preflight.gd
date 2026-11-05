extends Node
## Native Variant serialization preflight only: no production world instantiation.
var Subject: Script
const EXPECTED_SOURCE_LF_SHA256="763ae4a0350c01dbc2051b186658b4adcc4278759b354cd91a328f20d272d158"
var failures: Array[String]=[]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Subject=load("res://tests/v2_book_inspection_return_world.gd")
	if Subject==null or not Subject.can_instantiate():
		print("BOOK SNAPSHOT PREFLIGHT: REFUSED invalid diagnostic script")
		get_tree().quit(2);return
	var source:=FileAccess.get_file_as_string("res://tests/v2_book_inspection_return_world.gd").replace("\r\n","\n")
	if source.sha256_text()!=EXPECTED_SOURCE_LF_SHA256:
		print("BOOK SNAPSHOT PREFLIGHT: REFUSED wrong diagnostic source")
		get_tree().quit(2);return
	var collider:=StaticBody3D.new();collider.name="RealCollider"
	get_tree().root.add_child(collider)
	if not collider.is_inside_tree():
		print("BOOK SNAPSHOT PREFLIGHT: REFUSED collider did not enter tree")
		collider.free();get_tree().quit(2);return
	# Deliberately include the live collider and a Callable. Its metadata leads
	# back to the SAME dictionary: blindly encoding the Object is unsafe.
	var contact: Dictionary={"collider":collider,"rid":collider.get_rid(),"shape":3,"normal":Vector3.UP,"position":Vector3(1,2,3),"point":Vector3(4,5,6),"motion":Vector3(.01,0,0),"safe":.25,"unsafe":.3}
	collider.set_meta("recursive_contact",contact)
	var descriptor: Dictionary={"owner":collider,"part":collider,"frame":collider,"kind":"free","pickup":true,"hit_position":Vector3(1,2,3),"read":Callable(collider,"get_instance_id")}
	var hit: Dictionary=Subject._park_hit_fields(contact)
	var grip: Dictionary=Subject._park_descriptor_fields(descriptor)
	_check(hit.collider.id==collider.get_instance_id() and hit.collider.path==str(collider.get_path()),"live collider identity/path preserved")
	_check(hit.collider.rid==collider.get_rid().get_id() and hit.rid==collider.get_rid().get_id() and hit.shape==3,"actual RID/shape preserved")
	_check(hit.position==[1.,2.,3.] and hit.point==[4.,5.,6.] and hit.normal==[0.,1.,0.],"explicit vector coordinates preserved")
	_check(grip.part.id==collider.get_instance_id() and grip.kind=="free" and grip.pickup and not grip.has("read"),"descriptor owner identities retained without Callable")
	var payload: Dictionary={"body":hit,"ray":hit,"descriptor":grip}
	_check(_primitive_only(payload,0),"serializer outputs contain only bounded JSON primitives")
	var encoded:=JSON.stringify(payload)
	var decoded: Variant=JSON.parse_string(encoded)
	_check(decoded is Dictionary and decoded.body.collider.id==collider.get_instance_id(),"actual native JSON roundtrip preserves collider ID")
	_check(encoded.length()<4096,"single snapshot is bounded below 4 KiB")
	var empty: Dictionary=Subject._park_hit_fields({})
	_check(not empty.present and empty.collider.is_empty() and empty.position==null and empty.shape==-1,"empty first-hit negative control")
	var blocked: Dictionary=Subject._park_descriptor_fields({"blocked":true})
	_check(blocked.blocked and blocked.part.is_empty(),"blocked normalized descriptor retains uncertainty")
	var unresolved: Dictionary=Subject._park_hit_fields({"unresolved_native_impact":true,"motion":Vector3.ONE,"safe":.1,"unsafe":.2})
	_check(unresolved.unresolved_native_impact and unresolved.motion==[1.,1.,1.] and unresolved.collider.is_empty(),"unresolved impact has no invented collider")
	collider.remove_meta("recursive_contact");contact.clear();descriptor.clear()
	collider.free()
	print("BOOK SNAPSHOT PREFLIGHT: ","PASS" if failures.is_empty() else "FAIL"," checks=10 failures=",failures.size()," bytes=",encoded.length())
	for failure: String in failures:print("FAILED: ",failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:failures.append(label)

func _primitive_only(value: Variant, depth: int) -> bool:
	if depth>8:return false
	if typeof(value) in [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING]:return true
	if value is Array:
		for item: Variant in value:
			if not _primitive_only(item,depth+1):return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _primitive_only(value[key],depth+1):return false
		return true
	return false
