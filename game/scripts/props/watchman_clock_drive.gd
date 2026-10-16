extends RefCounted
## Reads the existing house clock; never advances campaign time itself.
var detector: Node3D
var last_minute := 0.0
var spindle_turn := 0.0

func configure(owner: Node3D) -> void:
	detector=owner
	last_minute=detector._house_minute()
	spindle_turn=fposmod(last_minute/1440.0,1.0)

func tick() -> void:
	var now: float=detector._house_minute()
	if not is_finite(now): return
	# A midnight wrap advances normally. Backward loads/clock corrections
	# rebase observation; they never wind the apparatus backward.
	var elapsed := wrapf(now-last_minute,-720.0,720.0)
	last_minute=now
	if elapsed<=0 or not detector.movement_running: return
	spindle_turn=fposmod(spindle_turn+elapsed/1440.0,1.0)
	if detector.dial_seated:
		detector.datum=fposmod(detector.datum+elapsed/1440.0,1.0)
		detector.datum_set=detector.datum_error()<=detector.DATUM_TOLERANCE

func invalidate_proof() -> void:
	detector.proof_first=-1.0
	detector.proof_second=-1.0

func punch() -> bool:
	tick()
	# The punch is fixed to the case. Store its position in the rotating
	# paper's local frame, so a previous hole travels away with that paper.
	var mark := fposmod(detector._dial_angle(),1.0)
	if detector.proof_first<0: detector.proof_first=mark
	else: detector.proof_second=mark
	detector._refresh_mechanism()
	return detector.record_is_honest() and detector.marks_prove_movement()

func snapshot() -> Dictionary:
	return {"spindle_turn":spindle_turn}

func valid(value: Variant) -> bool:
	return value is Dictionary and value.size()==1 		and typeof(value.get("spindle_turn")) in [TYPE_INT,TYPE_FLOAT] 		and is_finite(float(value.spindle_turn)) and value.spindle_turn>=0 and value.spindle_turn<1

func restore(value: Dictionary) -> void:
	last_minute=detector._house_minute()
	spindle_turn=float(value.spindle_turn) if valid(value) else fposmod(last_minute/1440.0,1.0)
