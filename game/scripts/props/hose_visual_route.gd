extends RefCounted
## Deliberate visual approximation: no masses, self-contact or resting tick.
## Stock length bounds endpoint reach; unused cloth is represented by floor slack.
var limited:=false
var reach_m:=0.
var last_length_m:=0.

func build(tip: Vector3,back: Vector3,anchor: Vector3,count: int,stock_m: float,up: Vector3,floor_height: float) -> PackedVector3Array:
	if count<4 or stock_m<=.2 or not tip.is_finite() or not anchor.is_finite() or not back.is_finite() or back.length_squared()<.5:return PackedVector3Array()
	# Reserve a short rigid socket lead. This is a reach allowance, not a
	# material solver: cloth may overlap scenery where that keeps input smooth.
	reach_m=stock_m-.15
	limited=tip.distance_to(anchor)>=reach_m-.001
	tip=anchor+(tip-anchor).limit_length(reach_m)
	var lead: Vector3=tip+back.normalized()*.06
	var delta: Vector3=anchor-lead
	var side: Vector3=delta.cross(up).normalized()
	if side.length_squared()<.5:side=back.cross(up).normalized()
	if side.length_squared()<.5:side=Vector3.RIGHT
	var points:=PackedVector3Array();points.resize(count);points[0]=tip
	# Drape toward the floor and show a little lateral slack near the source.
	# The amount fades continuously as the endpoint reaches full payout.
	var slack: float=maxf(0.,stock_m-tip.distance_to(anchor))
	var lateral: float=minf(1.,slack*.12)
	last_length_m=0.
	for i in range(1,count):
		var t: float=float(i-1)/float(count-2)
		var p: Vector3=lead.lerp(anchor,t)
		var floor_drop: float=minf(maxf(0.,p.dot(up)-floor_height),slack*.25)
		p-=up*floor_drop*sin(PI*t)
		p+=side*sin(TAU*t)*sin(PI*t)*lateral
		points[i]=p
		last_length_m+=points[i].distance_to(points[i-1])
	# Trigonometric endpoints have a tiny floating-point residue. The source
	# port is an exact fixed datum, including across save/rebuild comparisons.
	points[-1]=anchor
	return points
