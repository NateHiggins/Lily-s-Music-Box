class_name OrisonV2M08ESpatialCues
extends OrisonV2ReadabilityCues
## Development-only architectural light, threshold, and floor cues for M08E.

const SERVICE := Color(0.78, 0.50, 0.16)
const HOME_2B := Color(0.30, 0.58, 0.48)

func _ready() -> void:
	super()
	_portal(Vector3(-3.3, 0.0, -3.85), 0.0, 2.0, 2.35,
			SERVICE, "WATCH STATION")
	_portal(Vector3(9.5, 3.2, -3.25), PI * 0.5, 0.91, 2.13,
			HOME_2B, "2B")
	_portal(Vector3(9.5, -3.2, -0.4), PI * 0.5, 0.91, 2.13,
			SERVICE, "BOILER ROOM")
	_floor_plate(Vector3(5.8, -3.2, -0.95), "B1", SERVICE)
	_band(Vector3(-3.3, 0.012, -4.2), Vector3(2.0, 0.024, 0.16), SERVICE)
	_band(Vector3(7.45, 3.212, -3.25), Vector3(4.1, 0.024, 0.16), HOME_2B)
	_band(Vector3(7.45, -3.188, -0.4), Vector3(4.1, 0.024, 0.16), SERVICE)
	_light(Vector3(-3.3, 2.35, -2.1), SERVICE, 5.5, 2.1)
	_light(Vector3(10.0, 5.25, -3.0), HOME_2B, 5.0, 1.8)
	_light(Vector3(13.2, 5.35, -5.0), HOME_2B, 7.0, 1.6)
	_light(Vector3(7.4, -1.0, -0.4), SERVICE, 5.5, 2.0)
	_light(Vector3(12.4, -0.45, -0.5), SERVICE, 8.0, 4.0)
	_light(Vector3(10.6, -1.0, -2.6), Color(0.55, 0.68, 0.78), 6.0, 2.5)
	_light(Vector3(14.4, 5.15, -3.0), HOME_2B, 4.5, 2.4)
