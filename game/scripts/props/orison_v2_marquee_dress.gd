extends "res://scripts/props/entrance_marquee_dress.gd"
## Original lamps, fascia legend and one look-point over the fitted knee frames.
func service_wire_card() -> Dictionary:
	return PropServiceWire.card("marquee",{
		"roof_state":"PRISMATIC GLASS TRAY / RAIN SHEDDING",
		"bracket_state":"IRON RETURNS AND PIER KNEE FRAMES SEATED",
		"light_state":"TWO SOFFIT LAMPS / FASCIA WASH LIT",
	})
