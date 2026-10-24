extends Node
## Owner discovery/lifetime only; the actual repair is proved by first-slice input.
class BareRadiator extends RadiatorProp:
	func _ready() -> void:pass
	func _exit_tree() -> void:pass
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("RADIATOR OWNER CHECK: ",label," = ",ok)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	var radiator:=BareRadiator.new();add_child(radiator)
	check(radiator._work_orders_owner()==null,"missing owner safely returns no authority")
	var first:=WorkOrders.new();first.name="WorkOrders";add_child(first)
	check(radiator._work_orders_owner()==first,"late installed existing authority is discovered")
	check(radiator._work_orders_owner()==first,"stable lookup keeps original owner identity")
	remove_child(first)
	check(radiator._work_orders_owner()==null,"detached authority is not reused")
	var second:=WorkOrders.new();second.name="WorkOrders";add_child(second)
	check(radiator._work_orders_owner()==second,"replacement authority is discovered")
	first.free()
	check(radiator._work_orders_owner()==second,"retired old authority cannot replace current one")
	second.queue_free()
	check(radiator._work_orders_owner()==null,"queued authority cannot receive repair proof")
	await get_tree().process_frame
	var third:=WorkOrders.new();third.name="WorkOrders";add_child(third)
	check(radiator._work_orders_owner()==third,"post-retirement owner is discovered")
	third.name="RetiredOrders"
	var fourth:=WorkOrders.new();fourth.name="WorkOrders";add_child(fourth)
	check(radiator._work_orders_owner()==fourth,"renamed former owner does not hide its replacement")
	third.free();fourth.free();radiator.free()
	print("V2 RADIATOR AUTHORITY LOOKUP: ",checks," checks; ",failures," failures")
	get_tree().quit(0 if failures==0 else 1)
