extends "res://tests/v2_hose_save_bench.gd"
## Same saved-state negatives and legacy contract through the production factory.
func _install_hose(native: RefCounted,actor: Node3D) -> Node3D:
	if not check(native.mount_hose_deployment(),"production deployment factory installs all eight native hoses"):
		print(native.errors);return null
	var total:=0.
	for reference: WeakRef in native.stations.values():
		var cabinet: Node3D=reference.get_ref()
		var hose: Node3D=cabinet._live_hose
		check(is_instance_valid(hose) and hose.visual_follow_enabled,"installed visual hose owner: "+str(cabinet.name))
		check(not hose.deployed and not hose.is_processing() and not hose.is_physics_processing(),"stored hose has no cloth/fluid CPU callback: "+str(cabinet.name))
		check(not hose.contact.ready and hose.tether.rig==null and hose._receiving_stock.is_empty(),"production omits numerical contact and cloth setup: "+str(cabinet.name))
		check(cabinet.valid_mechanism(cabinet.mechanism_snapshot()),"installed initial household payload validates: "+str(cabinet.name))
		total+=hose.setup_ms
	print("PRODUCTION HOSE SETUP: stations=",native.stations.size()," total_ms=",total)
	return actor._live_hose
