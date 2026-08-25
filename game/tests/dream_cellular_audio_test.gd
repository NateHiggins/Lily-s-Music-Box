extends Node
## MBIO-5: the sound layer is bounded presentation downstream of biology.

var checks := 0
var failures := 0


func _ready() -> void:
	var director := DreamEcologyDirector.new()
	add_child(director)
	director.setup(8501)
	var pool: DreamCellularAudioPool = director.cellular_audio
	_check("one encroachment owns exactly four reusable voices",
			pool != null and int(pool.census().voices) == 4
			and pool.find_children("*", "AudioStreamPlayer3D", true, false).size() == 4)
	var configured := true
	for voice in pool._voices:
		configured = configured \
				and voice.attenuation_model \
						== AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE \
				and is_equal_approx(voice.max_distance,
						DreamCellularAudioPool.MAX_DISTANCE_M) \
				and is_equal_approx(voice.unit_size,
						DreamCellularAudioPool.UNIT_SIZE_M)
	_check("every pooled voice has finite inverse-distance attenuation", configured)

	director.emit_mechanical_packet(1, Vector3.ZERO, 2.0, 0.8,
			DreamEcologyDirector.Carrier.IMPULSE, Vector3.RIGHT, 2.0,
			DreamEcologyDirector.Substrate.FLOOR, 2.0)
	_check("raw mechanical input is silent before a cell accepts it",
			int(pool.census().presented) == 0)

	var facts_before := int(director.signal_census().emitted)
	director.emit_signal_packet(2, DreamEcologyDirector.SrcClass.PALP,
			DreamEcologyDirector.Fn.RECOGNIZE, Vector3(1, 0, 0), 1.0, 0.7,
			DreamEcologyDirector.Chem.ELECTRIC, 1.0, 1.0)
	director.emit_signal_packet(3, DreamEcologyDirector.SrcClass.CILIA,
			DreamEcologyDirector.Fn.PULSE, Vector3(2, 0, 0), 1.0, 0.8,
			DreamEcologyDirector.Chem.VASCULAR, 1.0, 1.0)
	director.emit_signal_packet(4, DreamEcologyDirector.SrcClass.ARCHITECTURE,
			DreamEcologyDirector.Fn.TRANSPORT, Vector3(3, 0, 0), 1.0, 0.6,
			DreamEcologyDirector.Chem.VASCULAR, 1.0, 1.0)
	director.emit_signal_packet(5, DreamEcologyDirector.SrcClass.HERO_LIMB,
			DreamEcologyDirector.Fn.SECRETE, Vector3(4, 0, 0), 1.0, 0.9,
			DreamEcologyDirector.Chem.SECRETION, 1.0, 1.0)
	var census: Dictionary = pool.census()
	_check("four cellular facts map to channel, cilia, relay and vesicle",
			int(census.presented) == 4 and int(census.by_kind.get(&"channel", 0)) == 1
			and int(census.by_kind.get(&"cilia", 0)) == 1
			and int(census.by_kind.get(&"relay", 0)) == 1
			and int(census.by_kind.get(&"vesicle", 0)) == 1)
	_check("the four sources occupy the four voices without allocating nodes",
			int(census.busy) == 4 and int(census.stolen) == 0
			and pool.find_children("*", "AudioStreamPlayer3D", true, false).size() == 4)
	_check("each event remains positional at its biological source",
			pool._voices[0].global_position == Vector3(1, 0, 0)
			and pool._voices[3].global_position == Vector3(4, 0, 0))

	for i in 8:
		pool.present(&"channel", Vector3(float(i), 1.0, 0.0), 0.5)
	census = pool.census()
	_check("a burst steals deterministically inside the four-voice ceiling",
			int(census.voices) == 4 and int(census.busy) == 4
			and int(census.stolen) == 8)
	var signals_before_sound := var_to_bytes(director.signal_census())
	pool.present(&"relay", Vector3.ZERO, 1.0)
	_check("audio presentation cannot feed the mechanical or chemical ring",
			signals_before_sound == var_to_bytes(director.signal_census())
			and int(director.signal_census().emitted) == facts_before + 4)
	var presented_before := int(pool.census().presented)
	_check("an unknown recorded key remains silence",
			not pool.present(&"unrecorded_cell", Vector3.ZERO, 1.0)
			and int(pool.census().presented) == presented_before
			and int(pool.census().unknown) == 1)
	_finish()


func _check(label: String, ok: bool) -> void:
	checks += 1
	print("[MBIO-5] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _finish() -> void:
	print("[MBIO-5] %d/%d PASS" % [checks - failures, checks])
	PropAudio.clear_cache()
	for child in get_children():
		remove_child(child)
		child.free()
	get_tree().quit(0 if failures == 0 else 1)
