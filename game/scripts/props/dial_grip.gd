extends RefCounted
## The one sign convention for rotary controls (owner ruling, 2026-11-27).
##
## A knob, valve wheel or cock that calls this is worked by horizontal mouse
## travel alone: right always raises its value (on, open, more) and left always
## lowers it (off, shut, less), from any side of the fixture and wherever on the
## part the hand took hold. The owner's value must therefore rise toward open.
## The mechanism still turns about its own shaft in its physical direction;
## only the hand's gesture is fixed. Limits and permission stay with the owner.
const TRAVEL_PIXELS := 240.0
const HOT := Color(.91,.42,.24)
const COLD := Color(.36,.66,.86)

static func apply(grip: Dictionary,label:="",ends: Array=["OFF","ON"],tint:=Color(0,0,0,0),pixels:=TRAVEL_PIXELS) -> Dictionary:
	if grip.is_empty():return grip
	grip["control"]="dial"
	grip["gesture_screen_axis"]=Vector2.RIGHT
	grip["gesture_travel_px"]=pixels
	grip["label"]=label
	grip["ends"]=ends
	if tint.a>0.:grip["tint"]=tint
	return grip
