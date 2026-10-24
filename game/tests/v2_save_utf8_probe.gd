extends Node
## INERT candidate diagnostic; Python strict UTF-8 is the independent oracle.
const Storage := preload("res://scripts/game/reality_save_storage.gd")
const Probe := preload("res://tests/save_stage_storage_probe.gd")
func _ready() -> void:
	var out := OS.get_environment("SHOT_DIR")
	var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("oracle.json")))
	var original := Storage.new()
	var probe := Probe.new()
	var failures: Array = []
	var tested := 0
	var bits := Marshalls.base64_to_raw(cases.two_byte_valid_bits)
	for code in 65536:
		var bytes := PackedByteArray([code >> 8, code & 255])
		var expected := bool(bits[code >> 3] & (1 << (code & 7)))
		if original._valid_utf8_full(bytes) != expected or probe.sparse_utf8(bytes) != expected:
			failures.append(bytes.hex_encode())
		tested += 1
	for row: Dictionary in cases.cases:
		var bytes: PackedByteArray = str(row.hex).hex_decode()
		if original._valid_utf8_full(bytes) != bool(row.valid) or probe.sparse_utf8(bytes) != bool(row.valid):
			failures.append(row.hex)
		tested += 1
	# Keep acceptance identical beyond the fast path's allocation bound and at
	# a NUL before malformed bytes. These controls exercise full-buffer fallback.
	for length in [1048575,1048576,1048577]:
		for tail: PackedByteArray in [PackedByteArray(), "é".to_utf8_buffer(), PackedByteArray([255]), PackedByteArray([0,255])]:
			var bytes := "a".repeat(length).to_utf8_buffer();bytes.append_array(tail)
			var expected := tail.is_empty() or tail=="é".to_utf8_buffer()
			if original._valid_utf8_full(bytes)!=expected or probe.sparse_utf8(bytes)!=expected:failures.append("large_%d_%s"%[length,tail.hex_encode()])
			tested+=1
	var samples: Array = []
	for label: String in ["ascii", "sparse", "dense", "nul"]:
		var bytes := ("a".repeat(180000) + ("café — 水" if label == "sparse" else "")).to_utf8_buffer()
		if label == "dense": bytes = "café — 水".repeat(20000).to_utf8_buffer()
		if label == "nul": bytes.append(0); bytes.append_array("é".to_utf8_buffer())
		for phase in 4:
			var times: Array = []
			for sample in 8:
				var started := Time.get_ticks_usec()
				var valid := probe.sparse_utf8(bytes) if phase % 2 == 1 else original._valid_utf8_full(bytes)
				times.append(Time.get_ticks_usec()-started)
				if not valid: failures.append(label)
			samples.append({"kind":label,"bytes":bytes.size(),"fast":phase%2==1,"times_usec":times})
	FileAccess.open(out.path_join("utf8_probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","tested":tested,"failures":failures,"samples":samples},"\t"))
	print("UTF8 PROBE: ", "PASS" if failures.is_empty() else "FAIL", " tested=",tested," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
