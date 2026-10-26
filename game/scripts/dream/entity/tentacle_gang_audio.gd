extends RefCounted
## Finite tissue events, located at the moving anatomy or retreat seam.
enum Motif { ADHESION, CILIA, FLUID, CREAK, MINERAL, CHAMBER, SUCTION, EXHALE }
static func emit_at(parent: Node3D, point: Vector3, kind: int, seed_id: int) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var seconds: float = [.22,.32,.28,.40,.09,.20,.65,.38][kind]
	var samples := int(seconds*stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	var random := RandomNumberGenerator.new()
	random.seed = seed_id
	var filtered := 0.0
	for i in samples:
		var t := float(i)/stream.mix_rate
		var envelope := sin(PI*float(i)/samples)*exp(-t*4.0)
		var frequency: float = [180,900,130,72,2100,105,90,240][kind]
		filtered = lerpf(filtered,random.randf_range(-1,1),.4 if kind in [Motif.CILIA,Motif.MINERAL] else .14)
		var pressure := sin(TAU*(frequency*t-frequency*.35*t*t))
		var grain := .5+.5*sin(TAU*31*t) if kind==Motif.CREAK else 1.0
		var noise_mix := .85 if kind in [Motif.ADHESION,Motif.CILIA,Motif.EXHALE] else .35
		if kind==Motif.MINERAL: envelope *= exp(-t*65)
		var value := clampf((filtered*noise_mix+pressure*(1-noise_mix)*.35)*envelope*grain,-1,1)
		bytes.encode_s16(i*2,int(value*16000))
	stream.data = bytes
	source.stream = stream
	source.volume_db = -30.0 if kind in [Motif.CILIA,Motif.FLUID,Motif.CREAK] else -24.0
	source.max_distance = 4.0
	parent.add_child(source)
	source.global_position = point
	source.finished.connect(source.queue_free)
	source.play()
	return source
