extends "res://tests/orison_v2_radio_battery_test.gd"
func _check_battery_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	super._check_battery_details(world,fixture)
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var model: Node3D=cell.get_node("RadioBattery")
	var fitted: Dictionary={};var results: Array=[];var rack: String=fixture.assemblies[0].id
	for row: Dictionary in fixture.fitted_records:fitted[str(row.id)]=row
	for index in 4:
		var left: Dictionary=fitted["storm_shop_radio_service_wet_cell"+str(index)];var right: Dictionary=fitted["storm_shop_radio_service_wet_cell"+str(index+1)]
		var a:=Vector3((left.rect[0]+left.rect[2])*.5+.05,1.324,-(left.rect[1]+left.rect[3])*.5)
		var b:=Vector3((right.rect[0]+right.rect[2])*.5-.05,1.324,-(right.rect[1]+right.rect[3])*.5)
		for end in 2:
			var endpoint:=a if end==0 else b;var inset:=endpoint.lerp(b if end==0 else a,.01)
			var entry: Dictionary={"link":index,"end":end,"endpoint":[endpoint.x,endpoint.y,endpoint.z],"inset":[inset.x,inset.y,inset.z]}
			for spec: Array in [["endpoint_wire", "__series_wire",endpoint,false],["inset_wire","__series_wire",inset,false],["endpoint_post_top","__terminal_metal",endpoint,true],["endpoint_post_bottom","__terminal_metal",endpoint,false],["inset_post_top","__terminal_metal",inset,true],["inset_post_bottom","__terminal_metal",inset,false]]:
				var hit:=_vertical_battery_ray(world,model,rack+str(spec[1]),spec[2],spec[3])
				if hit.is_empty():entry[spec[0]]={}
				else:
					var p: Vector3=cell.to_local(hit.position);entry[spec[0]]={"position":[p.x,p.y,p.z]}
			results.append(entry)
	FileAccess.open("C:/PleaseRemainOnTheLine/tmp/v2-finish-review/radio-battery-ray-results.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","samples":results},"\t"))
