class_name DreamMicrobiologyMechanics
extends RefCounted
## Private memory for an organ's substrate-borne disturbance receptor.

const IMPULSE := 1 << 0
const SCRAPE := 1 << 1
const HUM := 1 << 2


static func state() -> Dictionary:
	return {"response": 0.0, "refractory": 0.0, "carrier": 0,
			"direction": Vector3.ZERO, "last_src": -2147483648,
			"last_born": -1.0, "received": 0}


static func carrier_bit(carrier: int) -> int:
	match carrier:
		DreamEcologyDirector.Carrier.IMPULSE:
			return IMPULSE
		DreamEcologyDirector.Carrier.SCRAPE:
			return SCRAPE
		DreamEcologyDirector.Carrier.HUM:
			return HUM
	return 0


static func advance(receptor: Dictionary, delta: float) -> void:
	receptor.refractory = maxf(0.0, float(receptor.refractory) - delta)
	receptor.response = move_toward(float(receptor.response), 0.0, delta * 1.8)


static func accept(receptor: Dictionary, packet: Dictionary, carrier_mask: int,
		substrate: int) -> bool:
	if int(packet.get("family", -1)) != DreamEcologyDirector.Chem.MECHANICAL:
		return false
	var packet_substrate := int(packet.get("substrate",
			DreamEcologyDirector.Substrate.ANY))
	if packet_substrate != DreamEcologyDirector.Substrate.ANY \
			and packet_substrate != substrate:
		return false
	if (carrier_mask & carrier_bit(int(packet.get("carrier", 0)))) == 0:
		return false
	# Born is the director's monotonic clock. Once this membrane has considered
	# a wave, it cannot become novel merely because refractory time elapsed.
	if float(packet.born) <= float(receptor.last_born):
		return false
	if float(receptor.refractory) > 0.0:
		receptor.last_src = int(packet.src_id)
		receptor.last_born = float(packet.born)
		return false
	receptor.response = clampf(float(packet.strength), 0.0, 1.0)
	receptor.refractory = 0.26 if int(packet.carrier) \
			== DreamEcologyDirector.Carrier.IMPULSE else 0.42
	receptor.carrier = int(packet.carrier)
	var direction: Vector3 = packet.get("direction", Vector3.ZERO)
	receptor.direction = direction.normalized() \
			if direction.length_squared() > 0.0001 else Vector3.ZERO
	receptor.last_src = int(packet.src_id)
	receptor.last_born = float(packet.born)
	receptor.received = int(receptor.received) + 1
	return true
