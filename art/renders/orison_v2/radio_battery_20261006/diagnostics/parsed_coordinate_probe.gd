extends SceneTree
func _initialize() -> void:
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	# The original generator layout, not the projected V2 layout.
	layout=JSON.parse_string(FileAccess.get_file_as_string("C:/PleaseRemainOnTheLine/art/data/building_layout.json"))
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_battery.json"))
	var rows: Array=layout.floors.filter(func(row):return row.id=="F01")[0].furniture
	var counter: Dictionary=rows.filter(func(row):return row.id=="storm_shop_radio_service_counter_top")[0]
	var bench: Dictionary=rows.filter(func(row):return row.id=="storm_shop_radio_service_bench_top")[0]
	var original_rack: Dictionary=fixture.original_records[0]
	var dx: float=float(counter.rect[2])+.15-float(original_rack.rect[0]);var dy: float=float(bench.rect[1])-.72-float(original_rack.rect[3])
	var results: Array=[]
	for index in fixture.original_records.size():
		var original: Dictionary=fixture.original_records[index];var fitted: Dictionary=fixture.fitted_records[index];var expected: Dictionary=original.duplicate(true)
		expected.rect[0]+=dx;expected.rect[2]+=dx;expected.rect[1]+=dy;expected.rect[3]+=dy
		var deltas: Array=[];var maximum:=0.
		for component in 4:
			var delta: float=float(fitted.rect[component])-float(expected.rect[component]);deltas.append(delta);maximum=maxf(maximum,absf(delta))
		var unchanged:=fitted.duplicate(true);unchanged.erase("rect");var original_fields:=original.duplicate(true);original_fields.erase("rect")
		assert(unchanged==original_fields and maximum<1e-12)
		results.append({"id":original.id,"strict_dictionary_equal":fitted==expected,"expected":expected.rect,"fitted":fitted.rect,"coordinate_deltas_m":deltas,"maximum_difference_m":maximum,"nonplacement_fields_exact":unchanged==original_fields})
	FileAccess.open("C:/PleaseRemainOnTheLine/tmp/v2-finish-review/radio-battery-json-diagnostic.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","samples":results},"\t"))
	print("PLACEMENT SERIALIZATION PROBE: eleven preserved records; exact non-placement fields; max coordinate difference below 1e-12m")
	quit(0)
