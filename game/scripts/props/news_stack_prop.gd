class_name NewsStackProp
extends Node3D
## The kept newspapers as one physical stack on the floor beside the 4B bookshelf
## (Lily, 2026-11-06): the valise carries one paper at a time, and at home the
## paper is laid on the stack by hand. The stack's height follows the count: a
## few piles of folded newsprint, each a single box, never an object per issue and
## never a cap on how many are kept. NewspaperCatalog stays the collection
## authority; the stack is every kept paper except the one still in the case.
##
## RUL-013: when the case holds a paper, it waits on the stack's front edge as
## though just taken out; a click takes it, motion slides it back onto the pile,
## and once it is square on the pile it is deposited. The next click lets go.

const PER_PILE := 120
const SHEET := 0.0032
const FOLDED := Vector2(0.30, 0.42)
const PILE_GAP := 0.36
const SLIDE := 0.22
const ACROSS_AT := 0.9
const SLIDE_PIXELS := 180.0
const POLL_SECONDS := 0.5
const MetreUV := preload("res://scripts/building/v2_metre_box_uv.gd")

var catalog: NewspaperCatalog
var piles: Array[MeshInstance3D] = []
var arriving: MeshInstance3D
var _paper: StandardMaterial3D
var _pile_heights: Array[float] = []
var _slide := 0.0
var _held := false
var _deposited := false
var _shown_count := -1
var _shown_transit := "?"
var _poll := 0.0


func configure(source: NewspaperCatalog) -> void:
	catalog = source


func _ready() -> void:
	add_to_group("news_stacks")
	_paper = _paper_material()
	arriving = MeshInstance3D.new()
	arriving.name = "ArrivingPaper"
	arriving.mesh = _charted(Vector3(FOLDED.x, 0.012, FOLDED.y))
	add_child(arriving)
	preload("res://scripts/props/manipulation_area.gd").install(arriving, _grip)
	_refresh()


## Every kept paper but the one still in the case.
func count() -> int:
	if catalog == null:
		return 0
	var kept := catalog.collected().size()
	var transit := PaperPocket.transit_news()
	if transit != "" and (RealityState.data.get(NewspaperCatalog.STATE_KEY, []) as Array).has(transit):
		kept -= 1
	return maxi(kept, 0)


func pile_height(index: int) -> float:
	var n := count()
	var in_pile := clampi(n - index * PER_PILE, 0, PER_PILE)
	return in_pile * SHEET


func top_height() -> float:
	var n := count()
	return 0.0 if n == 0 else pile_height(int(ceil(float(n) / PER_PILE)) - 1)


func _refresh() -> void:
	var n := count()
	var needed := int(ceil(float(n) / PER_PILE))
	while piles.size() < needed:
		var pile := MeshInstance3D.new()
		pile.name = "Pile%d" % piles.size()
		add_child(pile)
		piles.append(pile)
		_pile_heights.append(-1.0)
	for index in piles.size():
		var h := pile_height(index)
		piles[index].visible = h > 0.0
		if h > 0.0:
			# The chart is rebuilt only when this pile's height changes.
			if not is_equal_approx(_pile_heights[index], h):
				piles[index].mesh = _charted(Vector3(FOLDED.x, h, FOLDED.y))
				_pile_heights[index] = h
			piles[index].position = Vector3(index * PILE_GAP, h * 0.5, 0.0)
	_shown_count = n
	_shown_transit = PaperPocket.transit_news()
	arriving.visible = _shown_transit != "" and not _deposited
	_pose()


## The paper on the front edge of the newest pile, then slid back square onto it.
func _pose() -> void:
	var last := maxi(piles.size() - 1, 0) if count() > 0 else 0
	arriving.position = Vector3(last * PILE_GAP, top_height() + 0.006, SLIDE - _slide)


func _grip() -> Dictionary:
	return {"owner": self, "part": arriving, "frame": self, "kind": "slide", "axis": -global_basis.z.normalized(),
		"minimum": 0.0, "maximum": SLIDE, "gesture_travel_px": SLIDE_PIXELS, "gesture_screen_axis": Vector2.UP,
		"read": func(): return _slide,
		"write": func(value: float):
			# Once deposited the paper is part of the pile: further motion is inert until the release click.
			if _held and not _deposited:
				_slide = value
				_pose()
				if _slide >= SLIDE * ACROSS_AT:
					_deposit(),
		"owns": func(): return _held,
		"begin": func():
			if _held or not arriving.visible:
				return false
			_held = true
			return true,
		"end": func():
			_held = false
			if _deposited:
				_deposited = false
				_slide = 0.0
				_refresh()}


## The paper leaves the case's transport slot and joins the stack; the save records it.
## The grip stays latched (RUL-013): the hand keeps the squared paper until the next primary click lets go, so
## nothing here cancels the grab from inside its own write callback.
func _deposit() -> void:
	if not PaperPocket.file_news():
		return
	_deposited = true
	_slide = SLIDE
	_pose()


func _process(delta: float) -> void:
	if not _held and _slide > 0.0:
		_slide = maxf(_slide - 0.8 * delta, 0.0)
		_pose()
	_poll -= delta
	if _poll <= 0.0 and not _held:
		_poll = POLL_SECONDS
		if count() != _shown_count or PaperPocket.transit_news() != _shown_transit:
			_refresh()


## Catalogue paper at its metre scale (RUL-012): on metre-charted UVs its grain keeps one density however tall a pile grows.
func _paper_material() -> StandardMaterial3D:
	var finish := MatLib.get_mat("paper").duplicate() as StandardMaterial3D
	finish.uv1_triplanar = false
	finish.uv1_scale = Vector3.ONE / float(MatLib.SETS["paper"][3])
	finish.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return finish


## A box of folded newsprint charted in metres, the material on its surface.
func _charted(size: Vector3) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	box.material = _paper
	return MetreUV.chart(box)
