class_name DreamFaunaDirector
extends Node3D
## FA1/FA2: one presentation-only density owner; no collision, light, shadow or save.

const MAX_INSTANCES := 96
const TICK_S := 1.0 / 3.0
const HUSH_RADIUS := 4.0
const FAUNA_SHADER := preload("res://shaders/dream_fauna.gdshader")
const LIFECYCLE := preload("res://scripts/dream/dream_organelle_lifecycle.gd")
const WINE := Color("55152f")
const GOLD := Color(0.72, 0.40, 0.09)
const EMERALD := Color(0.180, 0.404, 0.360)
const CARNELIAN := Color(0.451, 0.098, 0.106)
const LAPIS := Color(0.145, 0.216, 0.463)
const FAUNA_DARK_GLOW := 0.10
## FA-V4 inspection. Index = `family_motif`, the same tag the molten collector
## reads; a label is presentation vocabulary, never a new owner.
##
## DO-1: these name the ORGANELLE FUNCTION each family performs for the one
## body, not a species in a food web. The earlier set -- crop, grazer,
## detritivore, courtship, predator -- described five independent animals
## eating and mating with each other, which the organelle ruling
## (`design/DREAM_ORGANELLE_COMMUNICATION.md`) forbids. The densities behind
## them never modelled separate creatures; only the words did.
const FAMILY_LABELS := ["Gilder's Button (allocation)", "Tessellate (uptake)",
		"Wine Anemone (reclamation)", "Ribbonette (signalling)",
		"The Loupe (inhibition)"]
## CT-1: atlas folder per family_motif, and how many times the atlas repeats
## along (body_t) and around (angle) the creature.
const SKIN_DIRS := {0: "gilders_button", 1: "tessellate", 2: "wine_anemone",
		3: "ribbonette", 4: "the_loupe"}
const SKIN_REPEAT := {0: Vector2(1.0, 1.0), 1: Vector2(1.0, 1.0),
		2: Vector2(2.0, 1.0), 3: Vector2(3.0, 1.0), 4: Vector2(1.0, 1.0)}
## Angular slack past an instance's own bounding radius: about 3.4 degrees,
## so a crosshair that brushes a creature still names it without a collider.
const INSPECT_CONE_TAN := 0.06

## LC-3A — ANALYTICAL COHORT ADDRESSES.
##
## A realized slot needs a name that later receptors can hold without anybody
## instancing a node for it. The name is derived, not stored: room key, family
## motif, slot index and cohort generation are all facts the director already
## computes every refresh, so the same slot re-derives the same address for as
## long as that cohort lives, and a genuinely new generation renames it.
##
## No Node, Object, collision body, agent, route or save identity is created by
## any of this. `_cohorts` below holds one integer per realized slot purely to
## notice the generation EDGE; it is not a second realization record.
const ADDRESS_SEPARATOR := "/"
const ADDRESS_GENERATION := "#"

## Staggering. Two low-discrepancy strides -- the golden-ratio conjugate along
## slots and sqrt(5)-2 across families -- so no two slots in a room share a
## phase and no family pulses in lockstep with another. Irrational strides are
## the point: any rational one puts slots back in step at a fixed period.
const COHORT_SLOT_STRIDE := 0.6180339887498949
const COHORT_FAMILY_STRIDE := 0.2360679774997897

## LC-4A — VISIT-PERSISTENT STAIN MEMORY, BOUNDED.
##
## A stain is a mechanical impression, not geometry: room, position, motif, the
## analytical address of the cohort that died, and a two-value genome trace.
## Repeated deaths at one address COALESCE into that one impression rather than
## growing a corpse list, so the record is bounded by realized slots and not by
## elapsed time. Both caps evict deterministically (oldest generation first,
## then motif, then slot) so two identical runs evict identically.
##
## They survive room streaming, they are keyed by room so a revisit returns the
## same impressions, and they die with the director. They never reach
## `RealityState`, the room plan, maze data or any Resource.
const STAIN_PER_ROOM_CAP := 24
const STAIN_TOTAL_CAP := 96

## LC-3B — THE STAGE, ON THE ONLY BITS THE GPU KEEPS EXACTLY.
##
## `INSTANCE_CUSTOM` is four floats and all four are already spent. FA-V4
## measured that the Compatibility renderer stores them as half-floats and
## truncates the mantissa, so only the HIGH byte of each packed pair survives
## exactly. The flag byte is such a high byte, and bits 0-5 are named; bits 6
## and 7 were free.
##
## Two bits is not eight stages, but it does not have to be: BIRTHING and
## REABSORBING already sort the eight into three groups, and no group holds
## more than four. So the pair below is a sub-index WITHIN the group its
## existing flags select, and the whole stage survives the half-float path
## without a new channel, a new batch or a second submission record.
##
##   neither flag : 0 folded   1 mature   2 exchange   3 senescent
##   BIRTHING     : 0 bud      1 juvenile
##   REABSORBING  : 0 shed     1 stain
const STAGE_STREAM_SHIFT := 6
const STAGE_STREAM_MASK := 0b11000000

## LC-4B — HOW MANY IMPRESSIONS A ROOM MAY SHOW AT ONCE.
##
## The memory is already bounded at 24 a room; this is the narrower ceiling on
## how many of them are SUBMITTED, because every one spends an instance from
## the shared 96 and the living tissue must not be crowded out by its own
## dead. Impressions beyond it are still remembered, just not drawn.
const STAIN_SUBMIT_PER_ROOM := 4

var rooms: DreamRoomBuilder
var player: Node3D
var pursuer: Node3D
var exposure: DreamExposureField
var frozen := false
var _clock := 0.0
var _buttons: MultiMeshInstance3D
var _tessellates: MultiMeshInstance3D
var _anemones: MultiMeshInstance3D
var _ribbonettes: MultiMeshInstance3D
var _loupe: MultiMeshInstance3D
var _material_bindings: Node3D
var _census := {"buttons": 0, "tessellates": 0, "rooms": 0,
		"anemones": 0, "ribbonettes": 0, "loupe": 0,
		"hushed": 0, "submerged": 0}
var _signature := ""
var _room_signatures: Dictionary = {}
var _densities: Dictionary = {}
## What each batch was last handed, by batch name: {"xforms", "custom"}.
## FA-V4 inspection reads THIS rather than the MultiMesh buffer, because the
## renderer's readback is not a contract (the headless dummy renderer answers
## identity/default for every instance). It is the director's own record of
## its own submission, at most MAX_INSTANCES rows, never a node.
var _records: Dictionary = {}
## LC-3A: `"<room>/<motif>/<slot>" -> last observed generation`. One integer per
## realized slot, used only to notice that a cohort completed a life. Bounded by
## MAX_INSTANCES; never a node, never saved.
var _cohorts: Dictionary = {}
## LC-4A: `room_key -> Array[Dictionary]` of coalesced stain impressions.
## Deliberately NOT cleared by `_sync_densities`: a room leaving the live pocket
## must not forget what died in it during this visit.
var _stains: Dictionary = {}
var _stain_total := 0
var _stains_recorded := 0
var _stains_evicted := 0

func setup(room_owner: DreamRoomBuilder, body: Node3D, tenant: Node3D,
		exposure_owner: DreamExposureField) -> void:
	name = "DreamFaunaDirector"
	rooms = room_owner; player = body; pursuer = tenant; exposure = exposure_owner
	_material_bindings = Node3D.new()
	_material_bindings.name = "FaunaMaterialBindings"
	add_child(_material_bindings)
	_buttons = _make_batch("GildersButtons", DreamFaunaParts.buttons(), WINE,
			EMERALD, 0.03, 1.8, 0.0, true)
	_tessellates = _make_batch("Tessellates", DreamFaunaParts.tessellates(),
			WINE, EMERALD, 0.10, 1.8, 1.0, true)
	_anemones = _make_batch("WineAnemones", DreamFaunaParts.anemones(),
			WINE, LAPIS, 0.055, 0.55, 2.0, true)
	(_anemones.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(
			"gold_gain", 0.85)
	_ribbonettes = _make_batch("Ribbonettes", DreamFaunaParts.ribbonettes(),
			WINE, LAPIS, 0.085, 0.45, 3.0, true)
	(_ribbonettes.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(
			"gold_gain", 0.85)
	_loupe = _make_batch("TheLoupe", DreamFaunaParts.loupe(), WINE, CARNELIAN,
			0.035, 0.08, 4.0, true)
	(_loupe.multimesh.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter(
			"gold_gain", 0.75)
	refresh()

func _physics_process(delta: float) -> void:
	if frozen or rooms == null: return
	_clock += delta
	if _clock >= TICK_S:
		_clock -= TICK_S
		advance_fixed()
		refresh()

func advance_fixed() -> void:
	var live := rooms.live_rooms()
	_sync_densities(live)
	for room in live:
		var key := str(room.get("key", ""))
		var state: Dictionary = _densities[key]
		var r: Array = room.rect
		var centre := Vector3((r[0]+r[2])*0.5, 0.0, (r[1]+r[3])*0.5)
		var frame := _birth_frame(key, centre)
		var retained := exposure.room_exposure(key) if exposure != null else 0.0
		var lamp_pool := 1.0 if player != null and minf(
				player.global_position.distance_to(centre),
				player.global_position.distance_to(frame)) < 5.0 else 0.0
		var target := clampf(0.12 + retained*0.62 + lamp_pool*0.35, 0.0, 1.0)
		state.allocation = move_toward(float(state.allocation), target, 0.16)
		var previous := float(state.uptake)
		var recruited := maxf(0.0, float(state.allocation)-0.28)*0.28
		var shed := 0.025 + maxf(0.0, 0.32-float(state.allocation))*0.22
		var reclamation_target := maxf(0.0, previous-0.42)*0.82
		state.reclamation = move_toward(float(state.reclamation),
				reclamation_target, 0.075)
		var reclaimed := float(state.reclamation)*0.028
		state.uptake = clampf(previous+recruited-shed-reclaimed, 0.0, 1.0)
		state.reclaimable = clampf(float(state.reclaimable)*0.78
				+ maxf(0.0, previous-float(state.uptake))+reclaimed*0.8, 0.0, 1.0)
		var cycle: Dictionary = state.ether_cycle
		var lifecycle: Dictionary = state.lifecycle
		var diversity := fposmod(float(room.get("decay", 0.0))
				+ float(lifecycle.get("generation", 0)) * 0.17, 1.0)
		var environment := {
			"food": float(cycle.ethermoss),
			"ether": float(cycle.ether),
			"density": float(state.uptake),
			"diversity": diversity,
			"same_compatibility": 1.0 - absf(
					float(state.allocation) - float(state.uptake)),
			"cross_compatibility": clampf(float(state.reclaimable)
					+ diversity * 0.72, 0.0, 1.0),
			"stress": 1.0 - retained,
		}
		state.lifecycle = LIFECYCLE.advance(lifecycle, environment, TICK_S)
		var stage := int((state.lifecycle as Dictionary).stage)
		state.ether_cycle = LIFECYCLE.advance_ether_cycle(cycle, {
			"light": maxf(retained, lamp_pool),
			"activity": float(state.uptake),
			"senescence": 1.0 if stage >= LIFECYCLE.Stage.SENESCENT else 0.0,
			"reclamation": float(state.reclamation),
		}, TICK_S)
		_densities[key] = state

func freeze_for_capture() -> void:
	frozen = true
	if _buttons: _buttons.visible = false
	if _tessellates: _tessellates.visible = false
	if _anemones: _anemones.visible = false
	if _ribbonettes: _ribbonettes.visible = false
	if _loupe: _loupe.visible = false

func refresh() -> void:
	var button_xforms: Array[Transform3D] = []
	var tess_xforms: Array[Transform3D] = []
	var button_custom: Array[Color] = []
	var tess_custom: Array[Color] = []
	var anemone_xforms: Array[Transform3D] = []
	var ribbon_xforms: Array[Transform3D] = []
	var loupe_xforms: Array[Transform3D] = []
	var anemone_custom: Array[Color] = []
	var ribbon_custom: Array[Color] = []
	var loupe_custom: Array[Color] = []
	# LC-3A. One address per realized slot, in submission order, plus the
	# derived life it was submitted with. Parallel to the arrays above and
	# stored on the same record; not a second realization owner.
	var button_addr: Array[String] = []
	var tess_addr: Array[String] = []
	var anemone_addr: Array[String] = []
	var ribbon_addr: Array[String] = []
	var loupe_addr: Array[String] = []
	var button_life: Array[Dictionary] = []
	var tess_life: Array[Dictionary] = []
	var anemone_life: Array[Dictionary] = []
	var ribbon_life: Array[Dictionary] = []
	var loupe_life: Array[Dictionary] = []
	var hushed_count := 0
	var stain_marks := 0
	var submerged_count := 0
	var loupe_room: Dictionary = {}
	var loupe_strength := 0.0
	var live := rooms.live_rooms()
	_sync_densities(live)
	_room_signatures.clear()
	# RefCounted's dictionary does not promise an order. Slot order is visual
	# identity for a MultiMesh, so name the order explicitly before a cap can
	# make insertion history observable.
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("key", "")) < str(b.get("key", "")))
	for room in live:
		var button_start := button_xforms.size()
		var tess_start := tess_xforms.size()
		var anemone_start := anemone_xforms.size()
		var ribbon_start := ribbon_xforms.size()
		var r: Array = room.rect
		var centre := Vector3((r[0]+r[2])*0.5, 0.0, (r[1]+r[3])*0.5)
		var frame := _birth_frame(str(room.get("key", "")), centre)
		var hush := pursuer != null and minf(
				pursuer.global_position.distance_to(centre),
				pursuer.global_position.distance_to(frame)) < HUSH_RADIUS
		var lineage: Dictionary = room.get("lineage", {})
		var phase := fposmod(float(lineage.get("phase", 0.0)), TAU) / TAU
		var room_key := str(room.get("key", ""))
		var state: Dictionary = _densities[room_key]
		var room_life: Dictionary = state.lifecycle
		var allotted := float(state.allocation)
		var button_count := 1 + int(round(allotted * 3.0))
		var tess_count := 1 + int(round(float(state.uptake) * 4.0))
		var anemone_count := 1 + int(round(
				(1.0-allotted+float(state.reclaimable))*1.4))
		var ribbon_count := int(round(maxf(0.0,float(state.uptake)-0.28)*2.4))
		if hush:
			hushed_count += tess_count+ribbon_count+anemone_count
		for i in button_count:
			if button_xforms.size() >= MAX_INSTANCES: break
			var a := phase * TAU + float(i) * 2.094
			var at := centre + Vector3(cos(a)*0.72, 0.025, sin(a)*0.72)
			button_xforms.append(Transform3D(Basis().scaled(
					Vector3(0.20, 0.035, 0.20)), at))
			var b_life := cohort_state(room_life, 0, i)
			var b_hue := _genome(phase, i,
					_genome_salt(0.37, int(b_life.reproduction)))
			var b_pattern := _genome(phase, i,
					_genome_salt(0.71, int(b_life.reproduction)))
			button_life.append(b_life)
			button_addr.append(_observe_cohort(room_key, 0, i, at,
					int(b_life.generation), Vector2(b_hue, b_pattern)))
			button_custom.append(DreamFaunaChannels.encode(phase, allotted,
					allotted,
					DreamFaunaChannels.FLAG_PEARL_COLONY | int(b_life.stream_flags), 0.0,
					b_hue, b_pattern))
		# LC-4B — WHAT DIED HERE, THROUGH THIS ROOM'S OWN GILDER ALLOCATION.
		# No new batch, no new node and no new budget: an impression spends a
		# button and stops at the shared ceiling like everything else. The
		# living tissue is submitted first, so a room crowded with its own
		# dead loses marks before it loses organs.
		for impression in stain_presentation(room_key):
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
			var mark: Dictionary = _stain_submission(impression)
			button_xforms.append(mark.xform)
			button_custom.append(mark.custom)
			button_life.append({"stage": LIFECYCLE.Stage.STAIN, "stain": true,
					"deaths": int(impression.deaths),
					"generation": int(impression.generation)})
			button_addr.append(stain_address(impression))
			stain_marks += 1
		for i in tess_count:
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
			var a := phase*TAU + float(i)*1.37
			var radius := 0.20 if hush else 0.95 + float(i%2)*0.28
			# Uptake tissue appears at a real landed birth-frame, then spreads
			# toward where the body has allotted most. Hush reverses that path
			# and submerges it into the frame-foot rather than inventing a
			# second escape owner.
			var spread_at := centre + Vector3(cos(a)*radius, 0.14, sin(a)*radius)
			var emergence := clampf(allotted * 1.35 - float(i) * 0.08, 0.0, 1.0)
			var at := frame.lerp(spread_at, emergence)
			if hush:
				at = frame + Vector3(0.0, -0.18, 0.0)
				submerged_count += 1
			var size := 0.82 + 0.08 * float(i % 3)
			tess_xforms.append(Transform3D(Basis().scaled(
					Vector3(size, size * 0.72, size)), at))
			var t_life := cohort_state(room_life, 1, i)
			var tess_flags := DreamFaunaChannels.FLAG_HUSH if hush else 0
			tess_flags |= int(t_life.stream_flags)
			var t_hue := _genome(phase, i,
					_genome_salt(1.13, int(t_life.reproduction)))
			var t_pattern := _genome(phase, i,
					_genome_salt(1.79, int(t_life.reproduction)))
			tess_life.append(t_life)
			tess_addr.append(_observe_cohort(room_key, 1, i, at,
					int(t_life.generation), Vector2(t_hue, t_pattern)))
			tess_custom.append(DreamFaunaChannels.encode(phase+float(i)*0.11,
					allotted, emergence, tess_flags, 0.0 if hush else 1.0,
					t_hue, t_pattern))
		for i in anemone_count:
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
			var side := Vector3(-sin(phase*TAU),0.0,cos(phase*TAU))
			var at := frame.lerp(centre,0.18)+side*(float(i)-0.5)*0.32
			at.y = -0.12 if hush else 0.10
			if hush: submerged_count += 1
			anemone_xforms.append(Transform3D(Basis().scaled(Vector3.ONE*1.12),at))
			var a_life := cohort_state(room_life, 2, i)
			var anemone_flags := DreamFaunaChannels.FLAG_HUSH if hush else 0
			anemone_flags |= int(a_life.stream_flags)
			var a_hue := _genome(phase, i,
					_genome_salt(2.11, int(a_life.reproduction)))
			var a_pattern := _genome(phase, i,
					_genome_salt(2.73, int(a_life.reproduction)))
			anemone_life.append(a_life)
			anemone_addr.append(_observe_cohort(room_key, 2, i, at,
					int(a_life.generation), Vector2(a_hue, a_pattern)))
			anemone_custom.append(DreamFaunaChannels.encode(phase+float(i)*0.09,
					1.0-allotted, float(state.reclaimable), anemone_flags,
					0.0 if hush else 1.0, a_hue, a_pattern))
		for i in ribbon_count:
			if _total_instances(button_xforms,tess_xforms,anemone_xforms,
					ribbon_xforms,loupe_xforms) >= MAX_INSTANCES: break
			var a := phase*TAU+float(i)*PI
			var at := centre+Vector3(cos(a)*0.54,0.12,sin(a)*0.54)
			if hush: at=frame+Vector3(0.0,-0.20,0.0); submerged_count+=1
			ribbon_xforms.append(Transform3D(Basis(Vector3.UP,a).scaled(
					Vector3.ONE*(1.18+float(i)*0.06)),at))
			var r_life := cohort_state(room_life, 3, i)
			var ribbon_flags := DreamFaunaChannels.FLAG_SIGNALLING
			if hush: ribbon_flags |= DreamFaunaChannels.FLAG_HUSH
			ribbon_flags |= int(r_life.stream_flags)
			var r_hue := _genome(phase, i,
					_genome_salt(3.17, int(r_life.reproduction)))
			var r_pattern := _genome(phase, i,
					_genome_salt(3.91, int(r_life.reproduction)))
			ribbon_life.append(r_life)
			ribbon_addr.append(_observe_cohort(room_key, 3, i, at,
					int(r_life.generation), Vector2(r_hue, r_pattern)))
			ribbon_custom.append(DreamFaunaChannels.encode(phase+float(i)*0.17,
					float(state.uptake), allotted, ribbon_flags,
					0.0 if hush else 1.0, r_hue, r_pattern))
		if float(state.reclamation)>loupe_strength:
			loupe_strength=float(state.reclamation)
			loupe_room={"centre":centre,"frame":frame,"phase":phase,"hush":hush,
					"key":room_key,"life":room_life}
		var room_rows: Array[String] = []
		for i in range(button_start, button_xforms.size()):
			room_rows.append("b:%s:%s" % [button_xforms[i].origin, button_custom[i]])
		for i in range(tess_start, tess_xforms.size()):
			room_rows.append("t:%s:%s" % [tess_xforms[i].origin, tess_custom[i]])
		for i in range(anemone_start,anemone_xforms.size()):
			room_rows.append("a:%s:%s"%[anemone_xforms[i].origin,anemone_custom[i]])
		for i in range(ribbon_start,ribbon_xforms.size()):
			room_rows.append("r:%s:%s"%[ribbon_xforms[i].origin,ribbon_custom[i]])
		_room_signatures[str(room.get("key", ""))] = "|".join(room_rows)
	if loupe_strength>=0.14 and not loupe_room.is_empty() and _total_instances(
			button_xforms,tess_xforms,anemone_xforms,ribbon_xforms,loupe_xforms)<MAX_INSTANCES:
		var at:Vector3=loupe_room.frame.lerp(loupe_room.centre,0.68)
		if bool(loupe_room.hush): at=loupe_room.frame+Vector3(0.0,-0.38,0.0); submerged_count+=1; hushed_count+=1
		loupe_xforms.append(Transform3D(Basis(Vector3.UP,float(loupe_room.phase)*TAU),at))
		var l_life := cohort_state(loupe_room.life, 4, 0)
		var loupe_flags := DreamFaunaChannels.FLAG_CAMERA_TRACKER
		if bool(loupe_room.hush): loupe_flags |= DreamFaunaChannels.FLAG_HUSH
		loupe_flags |= int(l_life.stream_flags)
		var l_hue := _genome(float(loupe_room.phase), 0,
				_genome_salt(4.19, int(l_life.reproduction)))
		var l_pattern := _genome(float(loupe_room.phase), 0,
				_genome_salt(4.83, int(l_life.reproduction)))
		loupe_life.append(l_life)
		loupe_addr.append(_observe_cohort(str(loupe_room.key), 4, 0, at,
				int(l_life.generation), Vector2(l_hue, l_pattern)))
		loupe_custom.append(DreamFaunaChannels.encode(float(loupe_room.phase),loupe_strength,
				loupe_strength, loupe_flags,
				0.0 if bool(loupe_room.hush) else 1.0,
				l_hue, l_pattern))
	_apply(_buttons, button_xforms, button_custom, button_addr, button_life)
	_apply(_tessellates, tess_xforms, tess_custom, tess_addr, tess_life)
	_apply(_anemones,anemone_xforms,anemone_custom,anemone_addr,anemone_life)
	_apply(_ribbonettes,ribbon_xforms,ribbon_custom,ribbon_addr,ribbon_life)
	_apply(_loupe,loupe_xforms,loupe_custom,loupe_addr,loupe_life)
	_signature = _realization_signature(button_xforms, button_custom,
			tess_xforms, tess_custom)+_realization_signature(anemone_xforms,
			anemone_custom,ribbon_xforms,ribbon_custom)+str(loupe_xforms)+str(loupe_custom)
	_census = {"buttons":button_xforms.size(), "tessellates":tess_xforms.size(),
			"anemones":anemone_xforms.size(),"ribbonettes":ribbon_xforms.size(),
			"loupe":loupe_xforms.size(),"rooms":live.size(),"hushed":hushed_count,
			"submerged":submerged_count,"stain_marks":stain_marks}

func _total_instances(a:Array,b:Array,c:Array,d:Array,e:Array)->int:
	return a.size()+b.size()+c.size()+d.size()+e.size()

func _birth_frame(room_key: String, fallback: Vector3) -> Vector3:
	if rooms == null:
		return fallback
	# The body is geometry already owned by the live room. Reading its published
	# metadata cannot keep the room alive and creates no fauna-specific maze seam.
	for body in get_tree().get_nodes_in_group("dream_lineage_bodies"):
		if str(body.get_meta("room_key", "")) != room_key:
			continue
		var frames: Array = body.get_meta("birth_frames", [])
		if not frames.is_empty():
			return frames[0]
	return fallback

func census() -> Dictionary: return _census.duplicate(true)

func density_snapshot() -> Dictionary: return _densities.duplicate(true)

func realization_signature() -> String: return _signature

func room_signature(room_key: String) -> String:
	return str(_room_signatures.get(room_key, ""))

## --- LC-3A: analytical identity -------------------------------------------

## The address of one cohort. Pure formatting; it allocates nothing and looks
## nothing up.
static func cohort_address(room_key: String, motif: int, slot: int,
		generation: int) -> String:
	return "%s%s%d%s%d%s%d" % [room_key, ADDRESS_SEPARATOR, motif,
			ADDRESS_SEPARATOR, slot, ADDRESS_GENERATION, generation]


## The stable part of an address -- everything except the generation. Two
## cohorts that occupied the same slot in the same room share this and differ
## only after the "#".
static func cohort_lineage(room_key: String, motif: int, slot: int) -> String:
	return "%s%s%d%s%d" % [room_key, ADDRESS_SEPARATOR, motif,
			ADDRESS_SEPARATOR, slot]


static func parse_cohort_address(address: String) -> Dictionary:
	var hash_at := address.rfind(ADDRESS_GENERATION)
	if hash_at < 0:
		return {}
	var head := address.substr(0, hash_at)
	var generation := address.substr(hash_at + 1)
	if not generation.is_valid_int():
		return {}
	var slot_at := head.rfind(ADDRESS_SEPARATOR)
	if slot_at < 0:
		return {}
	var motif_at := head.rfind(ADDRESS_SEPARATOR, slot_at - 1)
	if motif_at < 0:
		return {}
	var motif := head.substr(motif_at + 1, slot_at - motif_at - 1)
	var slot := head.substr(slot_at + 1)
	if not motif.is_valid_int() or not slot.is_valid_int():
		return {}
	return {"room_key": head.substr(0, motif_at), "motif": int(motif),
			"slot": int(slot), "generation": int(generation),
			"lineage": head}


## Where this slot sits in its own life relative to the room's. Deterministic
## in (motif, slot) alone, so it is the same on every refresh and in every
## process.
static func slot_phase_offset(motif: int, slot: int) -> float:
	return fposmod(float(motif) * COHORT_FAMILY_STRIDE
			+ float(slot) * COHORT_SLOT_STRIDE, 1.0)


## BUD and JUVENILE reuse the landed BIRTHING flag; SHED and STAIN reuse
## REABSORBING. No new presentation channel is introduced, and a flag changing
## is not by itself a claim that the stage reads on screen.
## The two spare flag bits for this stage, as the sub-index within whatever
## group `stage_flags` puts it in. Deliberately SEPARATE from `stage_flags`,
## which keeps meaning exactly what it meant: one is the landed semantic
## grouping, this is the presentation stream that rides beside it.
## An impression's name. It ends outside the cohort grammar on purpose:
## `parse_cohort_address` rejects it, so enumeration and lookup keep answering
## about living tissue only, while `_records` still has one name per submitted
## instance the way the addressing contract requires.
static func stain_address(impression: Dictionary) -> String:
	return cohort_address(str(impression.room_key), int(impression.motif),
			int(impression.slot), int(impression.generation)) + "@stain"


static func stage_stream_bits(stage: int) -> int:
	var sub := 0
	match stage:
		LIFECYCLE.Stage.FOLDED, LIFECYCLE.Stage.BUD, LIFECYCLE.Stage.SHED:
			sub = 0
		LIFECYCLE.Stage.MATURE, LIFECYCLE.Stage.JUVENILE, LIFECYCLE.Stage.STAIN:
			sub = 1
		LIFECYCLE.Stage.EXCHANGE:
			sub = 2
		LIFECYCLE.Stage.SENESCENT:
			sub = 3
	return sub << STAGE_STREAM_SHIFT


## Everything the packed flag byte says about one stage: the landed semantic
## group plus the sub-index the shader needs to tell members of it apart.
static func stage_stream_flags(stage: int) -> int:
	return stage_flags(stage) | stage_stream_bits(stage)


## The inverse, so a test can prove the byte the GPU will actually receive
## resolves back to the stage that was submitted.
static func stage_from_stream(flag_byte: int) -> int:
	var sub := (flag_byte & STAGE_STREAM_MASK) >> STAGE_STREAM_SHIFT
	if (flag_byte & DreamFaunaChannels.FLAG_REABSORBING) != 0:
		return LIFECYCLE.Stage.SHED if sub == 0 else LIFECYCLE.Stage.STAIN
	if (flag_byte & DreamFaunaChannels.FLAG_BIRTHING) != 0:
		return LIFECYCLE.Stage.BUD if sub == 0 else LIFECYCLE.Stage.JUVENILE
	if sub == 0:
		return LIFECYCLE.Stage.FOLDED
	return sub + 2


static func stage_flags(stage: int) -> int:
	if stage == LIFECYCLE.Stage.BUD or stage == LIFECYCLE.Stage.JUVENILE:
		return DreamFaunaChannels.FLAG_BIRTHING
	if stage == LIFECYCLE.Stage.SHED or stage == LIFECYCLE.Stage.STAIN:
		return DreamFaunaChannels.FLAG_REABSORBING
	return 0


## One slot's life, derived from the room's. The offset can carry a slot past
## the end of the room's current life, which is exactly the stagger: that slot
## is already one generation ahead. The room's own wrap then keeps the slot's
## progress and generation continuous rather than jumping.
static func cohort_state(room_lifecycle: Dictionary, motif: int,
		slot: int) -> Dictionary:
	var progress := clampf(float(room_lifecycle.get("progress", 0.0)), 0.0, 1.0)
	progress += slot_phase_offset(motif, slot)
	var ahead := 0
	while progress >= 1.0:
		progress -= 1.0
		ahead += 1
	var stage: int = LIFECYCLE.stage_at(progress)
	return {
		"progress": progress,
		"stage": stage,
		"stage_name": LIFECYCLE.stage_name(stage),
		"generation": int(room_lifecycle.get("generation", 0)) + ahead,
		"reproduction": int(room_lifecycle.get("reproduction",
				LIFECYCLE.Reproduction.QUIESCENT)),
		"flags": stage_flags(stage),
		"stream_flags": stage_stream_flags(stage),
		"anatomy_scale": LIFECYCLE.anatomy_scale(stage),
	}


## Reproduction changes the pattern a cohort wears and nothing else. It is
## folded into the genome salt only -- never into count, transform, scale,
## flag, function or any gameplay fact.
static func _genome_salt(base: float, reproduction: int) -> float:
	return base + float(reproduction) * 0.0770


## Notice this realized slot, and notice if the cohort that used to hold it has
## since completed a life. Returns the current address.
func _observe_cohort(room_key: String, motif: int, slot: int, at: Vector3,
		generation: int, genome: Vector2) -> String:
	var lineage := cohort_lineage(room_key, motif, slot)
	var seen := int(_cohorts.get(lineage, -1))
	if seen >= 0 and generation > seen:
		_record_stain(room_key, motif, slot, at,
				cohort_address(room_key, motif, slot, seen), genome,
				generation - seen, generation - 1)
	_cohorts[lineage] = generation
	return cohort_address(room_key, motif, slot, generation)


## --- LC-4A: visit-persistent stain memory ---------------------------------

func _record_stain(room_key: String, motif: int, slot: int, at: Vector3,
		parent: String, genome: Vector2, deaths: int,
		generation: int) -> void:
	var list: Array = _stains.get(room_key, [])
	for impression in list:
		if int(impression.motif) != motif or int(impression.slot) != slot:
			continue
		# Coalesce. One impression per lineage, however many lives end on it.
		impression.deaths = int(impression.deaths) + maxi(1, deaths)
		impression.at = at
		impression.parent = parent
		impression.genome = genome
		impression.generation = generation
		_stains_recorded += 1
		return
	list.append({
		"room_key": room_key,
		"motif": motif,
		"slot": slot,
		"at": at,
		"parent": parent,
		"genome": genome,
		"deaths": maxi(1, deaths),
		"generation": generation,
	})
	_stains[room_key] = list
	_stain_total += 1
	_stains_recorded += 1
	_enforce_stain_caps(room_key)


## Deterministic in every branch: the per-room cap drops this room's oldest, and
## the global cap drops from the largest room (lowest key on a tie) so the same
## run always evicts the same impressions in the same order.
func _enforce_stain_caps(touched_room: String) -> void:
	while int((_stains.get(touched_room, []) as Array).size()) > STAIN_PER_ROOM_CAP:
		_drop_oldest_stain(touched_room)
	while _stain_total > STAIN_TOTAL_CAP:
		var widest := ""
		var widest_size := -1
		var keys: Array = _stains.keys()
		keys.sort()
		for key in keys:
			var size: int = (_stains[key] as Array).size()
			if size > widest_size:
				widest_size = size
				widest = str(key)
		if widest.is_empty() or widest_size <= 0:
			return
		_drop_oldest_stain(widest)


## Total order over impressions: oldest generation first, then motif, then
## slot. Packed into one integer so the comparison cannot depend on Variant
## array-compare semantics.
static func _stain_order(impression: Dictionary) -> int:
	return int(impression.generation) * 1000000 			+ int(impression.motif) * 1000 + int(impression.slot)


func _drop_oldest_stain(room_key: String) -> void:
	var list: Array = _stains.get(room_key, [])
	if list.is_empty():
		return
	var victim := 0
	for i in range(1, list.size()):
		var a: Dictionary = list[i]
		var b: Dictionary = list[victim]
		if _stain_order(a) < _stain_order(b):
			victim = i
	list.remove_at(victim)
	_stain_total -= 1
	_stains_evicted += 1
	if list.is_empty():
		_stains.erase(room_key)
	else:
		_stains[room_key] = list


## --- LC-4B: the impression, submitted -------------------------------------

## Which impressions this room shows, oldest generation first and then by
## lineage. Sorted rather than taken in insertion order so a revisit submits
## them in the same order it did before, whatever order they were recorded in.
func stain_presentation(room_key: String, limit := 0) -> Array:
	var ceiling := limit if limit > 0 else STAIN_SUBMIT_PER_ROOM
	var ordered: Array = (_stains.get(room_key, []) as Array).duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _stain_order(a) < _stain_order(b))
	var out: Array = []
	for impression in ordered:
		if out.size() >= ceiling:
			break
		out.append(impression)
	return out


## A withdrawn organ's memory, as one Gilder's Button instance.
##
## LC-4B ships no batch, no node and no second draw for the dead: the button
## batch is already a flat disc lying on the floor of the room, which is the
## shape a flattened anatomical memory wants. The impression supplies the
## position, the genome trace supplies the pattern, and the packed stage byte
## says STAIN so the shader dresses it as withdrawn tissue rather than as a
## fruiting body.
##
## Nothing here reads a clock. The same impression submits the same transform
## and the same colour on every refresh and after the room streams back.
func _stain_submission(impression: Dictionary) -> Dictionary:
	var motif := int(impression.motif)
	var slot := int(impression.slot)
	var deaths := int(impression.deaths)
	var genome: Vector2 = impression.genome
	# The dead organ's family survives as pattern, not as a channel: there is
	# no free byte for a motif, and the impression must still not look like a
	# button. Motif and lineage bend the stored trace deterministically.
	var hue := fposmod(genome.x + float(motif) * 0.1370 + float(slot) * 0.0170,
			1.0)
	var pattern := fposmod(genome.y + float(motif) * 0.2110, 1.0)
	# How much matter this lineage has returned here, bounded well before the
	# cap so a long-lived slot deepens its mark and never blows it out.
	var richness := clampf(0.30 + float(deaths) * 0.055, 0.0, 0.92)
	# A stable identity phase, from the lineage rather than from time.
	var identity := fposmod(float(motif) * 0.317 + float(slot) * 0.0839
			+ genome.x * 0.41, 1.0)
	var at: Vector3 = impression.at
	# It lies ON the surface the organ died on. The button's own authored
	# proportions are untouched: a stain is a posture of that disc, not a
	# smaller one.
	# Withdrawal relaxes the complete disc outward into a broader anatomical
	# memory. It still spends one Gilder instance and never grows from zero.
	var basis := Basis().scaled(Vector3(0.38, 0.030, 0.38))
	return {
		"xform": Transform3D(basis, at + Vector3(0.0, 0.004, 0.0)),
		"custom": DreamFaunaChannels.encode(identity, richness, richness,
				DreamFaunaChannels.FLAG_PEARL_COLONY
				| stage_stream_flags(LIFECYCLE.Stage.STAIN),
				0.0, hue, pattern),
	}


## --- LC-3A/LC-4A read-only queries ----------------------------------------
## Narrow, bounded and non-mutating. They exist so tests and later LC-5
## receptors can hold an address without anybody instancing a body for it.

## Every address the named batch was last handed, in submission order.
func addresses_for_batch(batch_name: String) -> PackedStringArray:
	var rows: Dictionary = _records.get(batch_name, {})
	var out := PackedStringArray()
	for address in (rows.get("addresses", []) as Array):
		out.append(str(address))
	return out


## Resolve one address against the current submission. Empty when that cohort
## is not currently realized -- an address is a name, not a guarantee.
func cohort_at(address: String) -> Dictionary:
	for batch_name in _records:
		var rows: Dictionary = _records[batch_name]
		var addresses: Array = rows.get("addresses", [])
		var index := addresses.find(address)
		if index < 0:
			continue
		var parsed := parse_cohort_address(address)
		if parsed.is_empty():
			return {}          # a stain impression, not a cohort
		var xforms: Array = rows.get("xforms", [])
		var custom: Array = rows.get("custom", [])
		if index >= xforms.size() or index >= custom.size():
			return {}
		var lives: Array = rows.get("life", [])
		var life: Dictionary = {}
		if index < lives.size():
			life = lives[index]
		return {
			"address": address,
			"batch": batch_name,
			"index": index,
			"room_key": str(parsed.get("room_key", "")),
			"motif": int(parsed.get("motif", -1)),
			"slot": int(parsed.get("slot", -1)),
			"generation": int(parsed.get("generation", -1)),
			"position": (xforms[index] as Transform3D).origin,
			"scale": (xforms[index] as Transform3D).basis.get_scale(),
			"custom_raw": custom[index],
			"channels": DreamFaunaChannels.decode(custom[index]),
			"life": life,
		}
	return {}


## Bounded enumeration. `limit` caps the answer; a non-positive limit means the
## realized ceiling, never "unbounded".
func cohorts_in_room(room_key: String, limit := 0) -> Array:
	return _enumerate_cohorts(room_key, -1, limit)


func cohorts_of_family(motif: int, limit := 0) -> Array:
	return _enumerate_cohorts("", motif, limit)


func _enumerate_cohorts(room_key: String, motif: int, limit: int) -> Array:
	var ceiling := limit if limit > 0 else MAX_INSTANCES
	var out: Array = []
	var batch_names: Array = _records.keys()
	batch_names.sort()
	for batch_name in batch_names:
		var rows: Dictionary = _records[batch_name]
		for address in (rows.get("addresses", []) as Array):
			if out.size() >= ceiling:
				return out
			var parsed := parse_cohort_address(str(address))
			if parsed.is_empty():
				continue
			if not room_key.is_empty() 					and str(parsed.room_key) != room_key:
				continue
			if motif >= 0 and int(parsed.motif) != motif:
				continue
			out.append(cohort_at(str(address)))
	return out


## The impressions this visit remembers for one room. Survives that room
## leaving the live pocket and returns identically on revisit.
func stains_in_room(room_key: String) -> Array:
	return (_stains.get(room_key, []) as Array).duplicate(true)


func stain_census() -> Dictionary:
	var by_room := {}
	var keys: Array = _stains.keys()
	keys.sort()
	for key in keys:
		by_room[key] = (_stains[key] as Array).size()
	return {"total": _stain_total, "rooms": _stains.size(),
			"recorded": _stains_recorded, "evicted": _stains_evicted,
			"per_room_cap": STAIN_PER_ROOM_CAP, "total_cap": STAIN_TOTAL_CAP,
			"by_room": by_room}


func cohort_census() -> Dictionary:
	var addressed := 0
	for batch_name in _records:
		addressed += ((_records[batch_name] as Dictionary).get(
				"addresses", []) as Array).size()
	return {"addressed": addressed, "lineages": _cohorts.size()}


func _sync_densities(live: Array) -> void:
	var keep := {}
	for room in live:
		var key := str(room.get("key", "")); keep[key] = true
		if _densities.has(key): continue
		var lineage: Dictionary = room.get("lineage", {})
		var phase := fposmod(float(lineage.get("phase", 0.0)), TAU)/TAU
		var decay := clampf(float(room.get("decay", 0.0)), 0.0, 1.0)
		_densities[key] = {"allocation":clampf(0.20+phase*0.18-decay*0.08,0.0,1.0),
				"uptake":clampf(0.34+phase*0.16,0.0,1.0),
				"reclamation":0.0,"reclaimable":decay*0.10,
				"ether_cycle":LIFECYCLE.new_ether_cycle(
						0.42-decay*0.06, 0.18+phase*0.08,
						0.30+decay*0.03, 0.10-phase*0.02+decay*0.03),
				"lifecycle":LIFECYCLE.new_record(phase)}
	for key in _densities.keys():
		if not keep.has(key): _densities.erase(key)

func _realization_signature(button_xforms: Array[Transform3D],
		button_custom: Array[Color], tess_xforms: Array[Transform3D],
		tess_custom: Array[Color]) -> String:
	var rows: Array[String] = []
	for i in button_xforms.size():
		rows.append("b:%s:%s" % [button_xforms[i].origin, button_custom[i]])
	for i in tess_xforms.size():
		rows.append("t:%s:%s" % [tess_xforms[i].origin, tess_custom[i]])
	return "|".join(rows)

func _make_batch(label: String, mesh: Mesh, color: Color, jewel: Color,
		gait: float, gait_hz: float, motif: float,
		vertex_channels_ready := false) -> MultiMeshInstance3D:
	var material := ShaderMaterial.new(); material.shader = FAUNA_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("gold_color", GOLD)
	material.set_shader_parameter("jewel_color", jewel)
	material.set_shader_parameter("gait_amount", gait)
	material.set_shader_parameter("gait_hz", gait_hz)
	material.set_shader_parameter("family_motif", motif)
	material.set_shader_parameter("fauna_dark_glow", FAUNA_DARK_GLOW)
	material.set_shader_parameter("vertex_channels_ready",
			1.0 if vertex_channels_ready else 0.0)
	# CT-1: the family's skin atlas, composed from the cases' plates. Absent
	# atlases (or FAUNA_SKINS=0) leave the procedural skin exactly as it was.
	var skin_dir := "res://assets/dream/fauna_skins/%s/" % SKIN_DIRS.get(int(motif), "")
	if OS.get_environment("FAUNA_SKINS") != "0" \
			and ResourceLoader.exists(skin_dir + "albedo.png"):
		material.set_shader_parameter("skin_albedo", load(skin_dir + "albedo.png"))
		material.set_shader_parameter("skin_normal", load(skin_dir + "normal.png"))
		material.set_shader_parameter("skin_mask", load(skin_dir + "mask.png"))
		material.set_shader_parameter("skin_ready", 1.0)
		material.set_shader_parameter("skin_repeat", SKIN_REPEAT.get(int(motif), Vector2.ONE))
	# The existing root material collector uses this presentation-only tag to
	# select one of five bounded costume records. It creates no fauna owner and
	# does not enter instance custom data or the density tick.
	material.set_meta("dream_fauna_family_index", int(motif))
	var node := MultiMeshInstance3D.new(); node.name = label
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	else:
		mesh.surface_set_material(0, material)
	# Compatibility expands a MultiMesh material_override into per-instance
	# waking-view submissions. A zero-mesh, invisible binding lets the existing
	# root collector discover this exact material without entering any render
	# pass; the batch keeps the same material on its sole mesh surface.
	var binding := MeshInstance3D.new()
	binding.name = label+"MaterialBinding"
	binding.visible = false
	binding.material_override = material
	_material_bindings.add_child(binding)
	add_child(node)
	var batch := MultiMesh.new(); batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true; batch.mesh = mesh; node.multimesh = batch
	return node

func _genome(phase: float, index: int, salt: float) -> float:
	return fposmod(sin(phase * 91.7 + float(index) * 17.31 + salt) * 43758.5453,
			1.0)

func _apply(node: MultiMeshInstance3D, xforms: Array[Transform3D],
		custom: Array[Color], addresses: Array[String] = [],
		life: Array[Dictionary] = []) -> void:
	_records[node.name] = {"xforms": xforms, "custom": custom,
			"addresses": addresses, "life": life}
	node.multimesh.instance_count = xforms.size()
	for i in xforms.size():
		node.multimesh.set_instance_transform(i, xforms[i])
		node.multimesh.set_instance_custom_data(i, custom[i])


## FA-V4 — COLLISION-FREE INSPECTION. Read-only queries over the director's
## own submission records for DreamWalk's F key. They create no collision, no
## per-creature node, no cache beyond `_records` and no pathfinding, and they
## never write. Selection is analytical: the live instance whose centre lies
## nearest the ray in angular terms, inside its bounding radius plus
## INSPECT_CONE_TAN, and no further along the ray than `max_distance` (the
## caller passes its real physics hit so a creature behind a wall is not
## named through it).
func inspect_ray(from: Vector3, direction: Vector3,
		max_distance := 40.0) -> Dictionary:
	var dir := direction.normalized()
	if dir.is_zero_approx():
		return {}
	var best := {}
	var best_angle := INF
	for batch in _batches():
		var rows: Dictionary = _records[batch.name]
		var xforms: Array = rows.xforms
		var aabb := _batch_aabb(batch)
		var half := aabb.size.length() * 0.5
		for i in xforms.size():
			var world: Transform3D = batch.global_transform * xforms[i]
			var centre := world * aabb.get_center()
			var offset := centre - from
			var along := offset.dot(dir)
			if along <= 0.0 or along > max_distance:
				continue
			var miss := (offset - dir * along).length()
			var radius := half * _max_axis_scale(world.basis)
			if miss > radius + along * INSPECT_CONE_TAN:
				continue
			var angle := miss / along
			if angle >= best_angle:
				continue
			best_angle = angle
			best = _describe_instance(batch, i, world, centre, along, miss, radius)
	return best


## The live instance nearest a point by straight-line distance, optionally
## within one named batch; DreamWalk's probe mode uses it to choose something
## to look at. Same read-only contract as inspect_ray.
func nearest_to(point: Vector3, batch_name := "") -> Dictionary:
	var best := {}
	var best_d := INF
	for batch in _batches():
		if not batch_name.is_empty() and batch.name != batch_name:
			continue
		var rows: Dictionary = _records[batch.name]
		var xforms: Array = rows.xforms
		var aabb := _batch_aabb(batch)
		var half := aabb.size.length() * 0.5
		for i in xforms.size():
			var world: Transform3D = batch.global_transform * xforms[i]
			var centre := world * aabb.get_center()
			var d := centre.distance_to(point)
			if d >= best_d:
				continue
			best_d = d
			best = _describe_instance(batch, i, world, centre, d, 0.0,
					half * _max_axis_scale(world.basis))
	return best


## One readable block for a HUD or a log. Pure formatting.
static func inspection_text(report: Dictionary) -> String:
	if report.is_empty():
		return "fauna: none under the crosshair"
	var ch: Dictionary = report.channels
	var mat: Dictionary = report.material
	var flags: PackedStringArray = report.flags
	var flag_text := "[" + ", ".join(flags) + "]"
	# Anything the material could not answer prints as "nan" rather than
	# aborting the whole report; a missing number is itself a finding.
	return ("FAUNA %s  [%s #%d of %d]  room %s\n"
			+ "  at %s  %.2f m  miss %.2f m  radius %.2f m  scale %s\n"
			+ "  custom %s  gpu readback %s\n"
			+ "  phase %.3f  allocation %.3f  emergence %.3f  activity %.3f"
			+ "  hue %.3f  pattern %.3f  flags %s\n"
			+ "  density %s\n"
			+ "  material gait %.3f @ %.2f Hz  gold_gain %.2f  dark_glow %.3f"
			+ "  vertex_channels %.0f  lamp_energy %.2f\n"
			+ "  shader %s  compiled %s  shadows %s") % [
			str(report.family), str(report.batch), int(report.index),
			int(report.instance_count), str(report.room_key),
			fmt_vec3(report.position), _num(report.distance),
			_num(report.miss), _num(report.radius),
			fmt_vec3(report.scale),
			str(report.custom_raw), str(report.get("gpu_custom", "-")),
			_num(ch.get("identity_phase")), _num(ch.get("allocation")),
			_num(ch.get("emergence")), _num(ch.get("activity")),
			_num(ch.get("hue_jitter")), _num(ch.get("pattern_jitter")),
			flag_text, str(report.density),
			_num(mat.get("gait_amount")), _num(mat.get("gait_hz")),
			_num(mat.get("gold_gain")), _num(mat.get("fauna_dark_glow")),
			_num(mat.get("vertex_channels_ready")),
			_num(mat.get("lamp_energy")),
			str(report.shader), str(report.shader_compiled),
			"OFF" if int(report.cast_shadow)
					== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else "ON"]


## `str(Vector3).pad_decimals(2)` is a trap: pad_decimals treats the whole
## string as one number and truncates at the first component's decimals.
static func fmt_vec3(value: Variant) -> String:
	if not (value is Vector3):
		return str(value)
	var v: Vector3 = value
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


static func _num(value: Variant) -> float:
	return float(value) if (value is float or value is int) else NAN


func _batches() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for batch in [_buttons, _tessellates, _anemones, _ribbonettes, _loupe]:
		if batch != null and batch.visible and batch.multimesh != null \
				and _records.has(batch.name):
			out.append(batch)
	return out


static func _batch_aabb(batch: MultiMeshInstance3D) -> AABB:
	var mesh: Mesh = batch.multimesh.mesh
	return mesh.get_aabb() if mesh != null else AABB()


static func _max_axis_scale(basis: Basis) -> float:
	return maxf(basis.x.length(), maxf(basis.y.length(), basis.z.length()))


func _describe_instance(batch: MultiMeshInstance3D, index: int,
		world: Transform3D, centre: Vector3, distance: float, miss: float,
		radius: float) -> Dictionary:
	var mm: MultiMesh = batch.multimesh
	var rows: Dictionary = _records[batch.name]
	var custom: Array = rows.custom
	var material: ShaderMaterial = null
	if mm.mesh != null:
		material = mm.mesh.surface_get_material(0) as ShaderMaterial
	var raw: Color = custom[index]
	var decoded := DreamFaunaChannels.decode(raw)
	# What the renderer hands back for the same slot. With a real window this
	# is the half-float-truncated value the shader actually decodes; headless
	# it is the dummy renderer's default and says so by differing.
	var gpu_raw: Color = mm.get_instance_custom_data(index) \
			if index < mm.instance_count else Color()
	var motif := -1
	var shader: Shader = null
	var material_facts := {}
	if material != null:
		motif = int(material.get_shader_parameter("family_motif"))
		shader = material.shader
		for key in ["gait_amount", "gait_hz", "gold_gain", "fauna_dark_glow",
				"vertex_channels_ready", "lamp_energy", "base_color",
				"jewel_color"]:
			# A uniform the batch never set answers null here, not the
			# shader's default; gold_gain is set on only three of five batches.
			var value: Variant = material.get_shader_parameter(key)
			if value == null and shader != null:
				value = RenderingServer.shader_get_parameter_default(
						shader.get_rid(), key)
			if value != null:
				material_facts[key] = value
	var room_key := _room_key_at(centre)
	var addresses: Array = rows.get("addresses", [])
	var lives: Array = rows.get("life", [])
	var address: String = str(addresses[index]) if index < addresses.size() else ""
	var life: Dictionary = lives[index] if index < lives.size() else {}
	var family := "unknown"
	if motif >= 0 and motif < FAMILY_LABELS.size():
		family = str(FAMILY_LABELS[motif])
	return {
		"batch": batch.name,
		"family": family,
		"family_motif": motif,
		"index": index,
		"instance_count": custom.size(),
		"position": centre,
		"distance": distance,
		"miss": miss,
		"radius": radius,
		"scale": world.basis.get_scale(),
		"custom_raw": raw,
		"gpu_custom": gpu_raw,
		"gpu_channels": DreamFaunaChannels.decode(gpu_raw),
		"channels": decoded,
		"flags": DreamFaunaChannels.flag_names(int(decoded.flags)),
		"room_key": room_key,
		"address": address,
		"life": life,
		"density": (_densities.get(room_key, {}) as Dictionary).duplicate(true),
		"material": material_facts,
		"shader": shader.resource_path if shader != null else "NULL",
		"shader_compiled": shader != null
				and not shader.get_shader_uniform_list().is_empty(),
		"cast_shadow": batch.cast_shadow,
	}


## Which live room rect holds a point, with half a metre of slack for a
## creature sitting on a doorway. The pocket owns the rects; this only reads.
func _room_key_at(point: Vector3) -> String:
	if rooms == null:
		return ""
	for room in rooms.live_rooms():
		var r: Array = room.get("rect", [])
		if r.size() < 4:
			continue
		if point.x >= float(r[0]) - 0.5 and point.x <= float(r[2]) + 0.5 \
				and point.z >= float(r[1]) - 0.5 and point.z <= float(r[3]) + 0.5:
			return str(room.get("key", ""))
	return ""
