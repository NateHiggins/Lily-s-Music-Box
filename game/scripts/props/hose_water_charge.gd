extends RefCounted
## Small fill/drain response, not a hydraulic or cloth simulation.
## The cabinet owns controls, connections and persistence; this derives output.
const FILL_SECONDS:=2.5
const DRAIN_SECONDS:=4.
var fill:=0.
var pressure:=0.
var spray:=0.
var changing:=false

func advance(delta: float,supply: float,lever: float,path_made_up: bool) -> bool:
	if not is_finite(delta) or delta<=0. or not is_finite(supply) or not is_finite(lever):return false
	var before:=Vector3(fill,pressure,spray)
	supply=clampf(supply,0.,1.);lever=clampf(lever,0.,1.)
	if not path_made_up:
		fill=move_toward(fill,0.,delta/DRAIN_SECONDS)
		pressure=move_toward(pressure,0.,delta*3.)
	elif supply>0.:
		fill=move_toward(fill,1.,delta*supply/FILL_SECONDS)
		# The supply opening meters filling, not the shut nozzle's static
		# pressure. Throttling a full line must not vent its trapped charge.
		pressure=move_toward(pressure,fill*(1.-lever*.2),delta*2.)
	elif lever>0.:
		fill=move_toward(fill,0.,delta*lever/DRAIN_SECONDS)
		pressure=move_toward(pressure,0.,delta*lever*2.)
	# Closing both controls traps the charge; opening the lever drains it.
	spray=lever*pressure if path_made_up else 0.
	changing=not before.is_equal_approx(Vector3(fill,pressure,spray))
	return changing

func snapshot() -> Dictionary:return {"fill":fill,"pressure":pressure}

func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size()!=2:return false
	for key: String in ["fill","pressure"]:
		if typeof(value.get(key)) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value[key])) or float(value[key])<0. or float(value[key])>1.:return false
	return float(value.pressure)<=float(value.fill)+.0001

func restore(value: Dictionary) -> void:
	fill=float(value.fill);pressure=float(value.pressure);spray=0.;changing=false
