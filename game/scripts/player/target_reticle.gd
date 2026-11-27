extends Control
## Presentation only. The hand supplies the selected part, its constraint
## feedback and how that constraint reads on screen. Nothing here owns state.
##
## Four readings, drawn as paper-and-ink marks with a dark keyline:
##   idle      a small hollow ring
##   available a glyph for how the aimed part is worked (dial, slide, take, tap)
##   grabbed   a live gauge of the held part's travel
##   limit / blocked   an ink burst at the stop, with a short shake
const FONT: Font = TelegramStyle.BOLD_FONT
const INK := Color(.09,.075,.06,.92)
const PAPER := Color(.95,.91,.80,.96)
const HELD := Color(.96,.78,.36,.98)
const STOPPED := Color(.95,.60,.40,.98)
const DIM := Color(.95,.91,.80,.30)
const IMPACT_SECONDS := .22

var state := "idle"
var inspectable := false
var transform_axis: int=-1
var transform_rotating:=false
## archetype, direction, fraction, label, ends, tint; see constrained_grab.guide().
var guide: Dictionary = {}
var tap := false
var travel_sign := 0
var _impact := 0.0
var _shown: Array = []
var _pill_style := StyleBoxFlat.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	_pill_style.bg_color = INK
	_pill_style.set_corner_radius_all(9)
	_pill_style.set_border_width_all(2)

func present(next_state: String, can_inspect: bool, at: Vector2,axis: int=-1,rotating:=false,next_guide: Dictionary={}) -> void:
	position = at
	visible = next_state != "hidden"
	var fraction: float=float(next_guide.get("fraction",-1.))
	var previous: float=float(guide.get("fraction",-1.))
	if next_state in ["grabbed","limit","blocked"] and fraction>=0. and previous>=0. and not is_equal_approx(fraction,previous):
		travel_sign=1 if fraction>previous else -1
	if next_state in ["idle","available","hidden"]: travel_sign=0
	if next_state in ["limit","blocked"] and state=="grabbed":
		_impact=IMPACT_SECONDS
		set_process(true)
	# Redraw on what is drawn, not on every sub-pixel of travel.
	var shown: Array=[next_state,can_inspect,axis,rotating,next_guide.get("archetype",""),next_guide.get("label",""),
		snappedf(fraction,.004),(next_guide.get("direction",Vector2.ZERO) as Vector2).snapped(Vector2(.02,.02)),
		next_guide.get("tint",Color(0,0,0,0)),travel_sign]
	guide=next_guide
	if shown==_shown:return
	_shown=shown
	state = next_state
	inspectable = can_inspect
	transform_axis=axis;transform_rotating=rotating
	queue_redraw()

## A legacy semantic prompt is under the aim point: one click works it.
func set_tap(on: bool) -> void:
	if tap==on:return
	tap=on
	queue_redraw()

func _process(delta: float) -> void:
	_impact=maxf(0.,_impact-delta)
	if _impact<=0.:set_process(false)
	queue_redraw()

func _tint(fallback: Color) -> Color:
	var colour: Color=guide.get("tint",Color(0,0,0,0))
	return Color(colour.r,colour.g,colour.b,.98) if colour.a>0. else fallback

func _stroke(a: Vector2,b: Vector2,colour: Color,width:=2.) -> void:
	draw_line(a,b,INK,width+3.,true)
	draw_line(a,b,colour,width,true)

func _curve(radius: float,from: float,to: float,colour: Color,width:=2.,keyline:=true) -> void:
	if is_equal_approx(from,to):return
	var points:=maxi(6,int(absf(to-from)*radius*.35))
	if keyline:draw_arc(Vector2.ZERO,radius,from,to,points,INK,width+3.,true)
	draw_arc(Vector2.ZERO,radius,from,to,points,colour,width,true)

func _head(tip: Vector2,direction: Vector2,size: float,colour: Color) -> void:
	var side:=direction.orthogonal()*size*.62
	var back:=tip-direction*size
	var shape:=PackedVector2Array([tip,back+side,back-side])
	draw_colored_polygon(shape,colour)
	shape.append(tip)
	draw_polyline(shape,INK,1.6,true)

func _stop_bar(at: Vector2,direction: Vector2,colour: Color) -> void:
	var side:=direction.orthogonal()*6.
	_stroke(at+side,at-side,colour,2.5)

func _chevrons(at: Vector2,direction: Vector2,colour: Color) -> void:
	var side:=direction.orthogonal()*5.
	for index in 2:
		var tip:=at+direction*(float(index)*7.+5.)
		_stroke(tip-direction*5.+side,tip,colour,2.)
		_stroke(tip-direction*5.-side,tip,colour,2.)

func _burst(at: Vector2,colour: Color) -> void:
	for index in 8:
		var ray:=Vector2.from_angle(TAU*float(index)/8.+.2)
		_stroke(at+ray*7.,at+ray*(14. if index%2==0 else 10.),colour,2.)

func _word(at: Vector2,text: String,colour: Color,align:=0,size:=13) -> void:
	if text.is_empty():return
	var width:=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var origin:=at+Vector2(-width*.5 if align==0 else (-width if align>0 else 0.),float(size)*.34)
	draw_string_outline(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,5,INK)
	draw_string(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,colour)

func _pill(at: Vector2,text: String,colour: Color) -> void:
	if text.is_empty():return
	var size:=13
	var width:=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_pill_style.border_color=colour
	draw_style_box(_pill_style,Rect2(at.x-width*.5-9.,at.y-10.,width+18.,20.))
	draw_string(FONT,at+Vector2(-width*.5,float(size)*.34),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,PAPER)

func _ends() -> Array:
	var ends: Variant=guide.get("ends",[])
	return ends if ends is Array and ends.size()==2 else ["",""]

func _status() -> String:
	var label:=str(guide.get("label",""))
	var fraction: float=float(guide.get("fraction",-1.))
	if label.is_empty() or fraction<0.:return label
	var ends:=_ends()
	if fraction<=.004 and str(ends[0])!="":return label+"  "+str(ends[0])
	if str(ends[1])=="":return label
	return "%s  %s %d%%"%[label,str(ends[1]),clampi(roundi(fraction*100.),1,100)]

func _draw() -> void:
	if _impact>0.:
		var kick:=_impact/IMPACT_SECONDS*3.5
		draw_set_transform(Vector2(sin(_impact*190.),cos(_impact*150.))*kick)
	var held:=state in ["grabbed","limit","blocked"]
	var archetype:=str(guide.get("archetype",""))
	if state=="idle" or state=="hidden":
		if tap:_draw_tap()
		else:
			draw_arc(Vector2.ZERO,3.6,0,TAU,20,Color(0,0,0,.6),3.,true)
			draw_arc(Vector2.ZERO,3.6,0,TAU,20,Color(PAPER.r,PAPER.g,PAPER.b,.5),1.2,true)
		return
	draw_circle(Vector2.ZERO,2.6,INK)
	draw_circle(Vector2.ZERO,1.3,_tint(HELD) if held else PAPER)
	if transform_axis>=0:
		var tint: Color=[Color(.94,.52,.43),Color(.58,.86,.55),Color(.52,.72,1.)][transform_axis]
		_stroke(Vector2(12,-4),Vector2(12,4),tint,1.5)
	if transform_rotating:_curve(12.,PI*.25,PI*.8,PAPER,1.5)
	if archetype=="dial":_draw_dial(held)
	elif archetype=="slide" and not (guide.get("direction",Vector2.ZERO) as Vector2).is_zero_approx():_draw_slide(held)
	elif archetype=="take":_draw_take(held)
	elif state=="blocked" and not held:
		_stroke(Vector2(-4,-4),Vector2(4,4),STOPPED,1.5)
		_stroke(Vector2(-4,4),Vector2(4,-4),STOPPED,1.5)
	else:
		_curve(5.5 if held else 4.5,0,TAU,_tint(HELD) if held else PAPER,1.5)
		if state=="limit":_burst(Vector2.ZERO,STOPPED)
	if state=="blocked" and held:
		_stroke(Vector2(-5,-5),Vector2(5,5),STOPPED,2.)
		_stroke(Vector2(-5,5),Vector2(5,-5),STOPPED,2.)
		_burst(Vector2.ZERO,STOPPED)
	if inspectable and not held:_draw_lens(Vector2(19,-19))

## Rotary: mouse right always raises the value, left always lowers it.
func _draw_dial(held: bool) -> void:
	var colour:=_tint(HELD if held else PAPER)
	var ends:=_ends()
	var fraction: float=clampf(float(guide.get("fraction",0.)),0.,1.)
	if not held:
		var arc:=19.
		var left:=PI*1.18
		var right:=PI*1.82
		_curve(arc,left,right,colour,2.5)
		if fraction>.004:_head(Vector2.from_angle(left)*arc+Vector2(-5,6),Vector2(-.55,.84).normalized(),9.,PAPER)
		else:_stop_bar(Vector2.from_angle(left)*arc,Vector2.from_angle(left).orthogonal(),PAPER)
		if fraction<.996:_head(Vector2.from_angle(right)*arc+Vector2(5,6),Vector2(.55,.84).normalized(),9.,colour)
		else:_stop_bar(Vector2.from_angle(right)*arc,Vector2.from_angle(right).orthogonal(),colour)
		_word(Vector2(-27,2),str(ends[0]),PAPER,1)
		_word(Vector2(27,2),str(ends[1]),colour,-1)
		_pill(Vector2(0,30),_status(),colour)
		return
	var radius:=30.
	var from:=PI*.80
	var sweep:=PI*1.40
	_curve(radius,from,from+sweep,INK,8.,false)
	_curve(radius,from,from+sweep,DIM,4.,false)
	_curve(radius,from,from+sweep*fraction,colour,4.,false)
	var low:=Vector2.from_angle(from)*radius
	var high:=Vector2.from_angle(from+sweep)*radius
	var needle:=Vector2.from_angle(from+sweep*fraction)*radius
	draw_circle(needle,6.,INK)
	draw_circle(needle,3.6,colour)
	_word(low+Vector2(-12,17),str(ends[0]),colour if fraction<=.004 else PAPER,0)
	_word(high+Vector2(12,17),str(ends[1]),colour if fraction>=.996 else PAPER,0)
	if travel_sign!=0:_chevrons(Vector2(float(travel_sign)*(radius+9.),-4),Vector2(float(travel_sign),0),colour)
	if state=="limit":_burst(high if fraction>=.5 else low,STOPPED)
	_pill(Vector2(0,radius+38.),_status(),colour)

## Linear and hinged: drag along the drawn line; the bright head is the way
## the value rises, exactly as the hand will project it.
func _draw_slide(held: bool) -> void:
	var direction:=(guide.get("direction",Vector2.RIGHT) as Vector2).normalized()
	var colour:=_tint(HELD if held else PAPER)
	var ends:=_ends()
	var fraction: float=float(guide.get("fraction",-1.))
	if not held:
		_stroke(direction*8.,direction*22.,colour,2.5)
		_stroke(-direction*8.,-direction*22.,PAPER,2.5)
		if fraction<0. or fraction<.996:_head(direction*31.,direction,10.,colour)
		else:_stop_bar(direction*24.,direction,colour)
		if fraction<0. or fraction>.004:_head(-direction*31.,-direction,10.,PAPER)
		else:_stop_bar(-direction*24.,direction,PAPER)
		_word(direction*46.,str(ends[1]),colour,0)
		_word(-direction*46.,str(ends[0]),PAPER,0)
		_pill(Vector2(0,34) if absf(direction.y)<.6 else Vector2(0,62),_status(),colour)
		return
	var reach:=34.
	fraction=clampf(fraction,0.,1.)
	draw_line(-direction*reach,direction*reach,INK,8.,true)
	draw_line(-direction*reach,direction*reach,DIM,4.,true)
	var marker:=direction*lerpf(-reach,reach,fraction)
	draw_line(-direction*reach,marker,colour,4.,true)
	draw_circle(marker,6.,INK)
	draw_circle(marker,3.6,colour)
	_word(direction*(reach+16.),str(ends[1]),colour if fraction>=.996 else PAPER,0)
	_word(-direction*(reach+16.),str(ends[0]),colour if fraction<=.004 else PAPER,0)
	if travel_sign!=0:
		var way:=direction*float(travel_sign)
		_chevrons(way*(reach+6.)+direction.orthogonal()*12.,way,colour)
	if state=="limit":_burst(direction*reach if fraction>=.5 else -direction*reach,STOPPED)
	_pill(Vector2(0,34) if absf(direction.y)<.6 else Vector2(0,reach+30.),_status(),colour)

## Loose stock: corner marks close around it once it is in the hand.
func _draw_take(held: bool) -> void:
	var colour:=_tint(HELD if held else PAPER)
	var reach:=7. if held else 10.
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var at:=corner*reach
		_stroke(at,at-Vector2(corner.x*5.,0),colour,2.)
		_stroke(at,at-Vector2(0,corner.y*5.),colour,2.)
	if state=="limit":_burst(Vector2.ZERO,STOPPED)
	if not held:_pill(Vector2(0,28),str(guide.get("label","")),colour)

func _draw_tap() -> void:
	draw_arc(Vector2.ZERO,5.5,0,TAU,24,INK,5.,true)
	draw_arc(Vector2.ZERO,5.5,0,TAU,24,PAPER,2.,true)
	draw_circle(Vector2.ZERO,1.6,PAPER)
	for angle: float in [-PI*.5,-PI*.25,-PI*.75]:
		var ray:=Vector2.from_angle(angle)
		_stroke(ray*10.,ray*15.,PAPER,2.)

func _draw_lens(at: Vector2) -> void:
	draw_arc(at,5.,0,TAU,20,INK,5.,true)
	_stroke(at+Vector2(3.6,3.6),at+Vector2(9,9),PAPER,2.)
	draw_arc(at,5.,0,TAU,20,PAPER,2.,true)
