class_name DreamOrganelleExhibit
extends Node3D
## Debug staging around the warehouse's existing organs. The architecture
## receiver and LivingField interpret their own packets; this host only ticks
## the field and supplies inspectable surfaces. No case, save or maze is built.

const LivingScript := preload("res://scripts/reality/living_field.gd")
const ReceiverScript := preload("res://scripts/reality/apartment_encroachment.gd")
const TendrilScript := preload("res://scripts/dream/field/dream_surface_tendrils.gd")
const SurfaceShader := preload("res://shaders/orison_surface.gdshader")
const WALL_WIDTH := 8.0
const WALL_HEIGHT := 3.4
const EXHIBIT_LAYER := 1 << 19
const FIELD_ID := "warehouse_organelle_wall"

var living: LivingField
var receiver: ApartmentEncroachment
var tendrils: DreamSurfaceTendrils
var panel_material: ShaderMaterial
var panel: MeshInstance3D
var contact_pad: StaticBody3D
var field: DreamFieldController
var residue: DreamResidue
var director: DreamEcologyDirector
var margin: DreamMarginController
var palps: DreamPalpRenderer
var hero: DreamHeroTentacle
var roster: RefCounted
var initialized := false
var active := true
var paused := false
var display_palps := 0
var debug_secretions := 0

var _wall := Vector3.ZERO
var _normal := Vector3.BACK
var _side := Vector3.RIGHT
var _previous_living: RefCounted
var _source := -1


func setup(existing_field: DreamFieldController, existing_residue: DreamResidue,
		existing_director: DreamEcologyDirector, existing_margin: DreamMarginController,
		existing_palps: DreamPalpRenderer, existing_hero: DreamHeroTentacle,
		existing_roster: RefCounted, wall_global_position: Vector3,
		wall_normal: Vector3) -> bool:
	if initialized:
		return true
	if GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG or not is_inside_tree():
		return false
	if existing_field == null or existing_residue == null or existing_director == null \
			or existing_margin == null or existing_palps == null or existing_hero == null \
			or existing_roster == null or not wall_global_position.is_finite() \
			or not wall_normal.is_finite() or wall_normal.length_squared() < 0.99 \
			or absf(wall_normal.normalized().y) > 0.01:
		push_error("Organelle exhibit requires existing owners and a vertical wall")
		return false
	name = "DreamOrganelleExhibit"
	field = existing_field
	residue = existing_residue
	director = existing_director
	margin = existing_margin
	palps = existing_palps
	hero = existing_hero
	roster = existing_roster
	_wall = wall_global_position
	_normal = wall_normal.normalized()
	_side = Vector3.UP.cross(_normal).normalized()
	_previous_living = field.living_field
	_build_architecture()
	_build_contact_pad()
	tendrils = TendrilScript.new()
	add_child(tendrils)
	# This renderer's shader supplies world positions; its owning transform
	# must not translate those positions again when the warehouse is moved.
	tendrils.top_level = true
	tendrils.global_transform = Transform3D.IDENTITY
	tendrils.setup(field, 73203)
	tendrils.mesh_instance.layers = EXHIBIT_LAYER
	# The imported renderer's origin-centred bounds do not follow this
	# translated warehouse: its shader and identity model use world space.
	var rect: Vector4 = field.storey_rect
	var tendril_mesh: ArrayMesh = tendrils.mesh_instance.mesh as ArrayMesh
	tendril_mesh.custom_aabb = AABB(
			Vector3(rect.x - 2.0, field.floor_y - 2.0, rect.y - 2.0),
			Vector3(rect.z - rect.x + 4.0, 8.0, rect.w - rect.y + 4.0))
	field.living_field = living
	initialized = true
	reset_display()
	_apply_activity()
	return true


func _build_architecture() -> void:
	var lo := _wall
	var hi := _wall
	for across in [-WALL_WIDTH * 0.5, WALL_WIDTH * 0.5]:
		for depth in [-0.30, 1.50]:
			var point: Vector3 = _wall + _side * across + _normal * depth
			lo = lo.min(point)
			hi = hi.max(point)
	living = LivingScript.new()
	living.configure(Vector4(lo.x, lo.z, hi.x, hi.z),
			_wall.y - WALL_HEIGHT * 0.5, 73201)
	_source = living.add_source(_wall - _side * 1.5 - Vector3.UP * 0.25
			+ _normal * 0.12, 0)
	living.set_source_intensity(_source, 0.82)
	# ApartmentEncroachment has no _ready hook. Do not call its building/case
	# setup or its broad _physics_process (which also owns lights and limbs).
	# Reuse only its exact addressed receiver and material binding seams.
	receiver = ReceiverScript.new()
	receiver.name = "OrganelleArchitectureReceiver"
	add_child(receiver)
	receiver.set_physics_process(false)
	receiver.set_process(false)
	receiver.ecology = director
	receiver.fields[FIELD_ID] = living
	panel_material = ShaderMaterial.new()
	panel_material.shader = SurfaceShader
	panel_material.set_shader_parameter("albedo_color", Color(0.29, 0.20, 0.27))
	panel_material.set_shader_parameter("has_normal_tex", false)
	panel_material.set_shader_parameter("has_rough_tex", false)
	panel_material.set_shader_parameter("roughness_mul", 0.74)
	receiver._bind_living(panel_material, FIELD_ID)
	panel = MeshInstance3D.new()
	panel.name = "LivingArchitecturePanel"
	var quad := QuadMesh.new()
	quad.size = Vector2(WALL_WIDTH, WALL_HEIGHT)
	panel.mesh = quad
	panel.material_override = panel_material
	panel.layers = EXHIBIT_LAYER
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(panel)
	panel.global_transform = Transform3D(Basis(_side, Vector3.UP, _normal),
			_wall + _normal * 0.065)


func _build_contact_pad() -> void:
	# An actual reachable target for the hero and a supported +normal face
	# for the one existing crystal listener. The root provides the large wall.
	contact_pad = StaticBody3D.new()
	contact_pad.name = "OrganelleContactPad"
	contact_pad.collision_layer = 1
	contact_pad.collision_mask = 1
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.18, 0.20, 0.88)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	contact_pad.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.size
	mesh.mesh = box
	mesh.material_override = panel_material
	mesh.layers = EXHIBIT_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	contact_pad.add_child(mesh)
	add_child(contact_pad)
	contact_pad.global_transform = Transform3D(Basis(_side, Vector3.UP, _normal),
			_wall - _side * 1.75 - Vector3.UP * 0.25 + _normal * 0.44)


func recipient_position() -> Vector3:
	return _wall - _side * 1.75 - Vector3.UP * 0.25 + _normal * 0.90


func focus_position() -> Vector3:
	return _wall - _side * 1.25 - Vector3.UP * 0.10 + _normal * 0.40


func reset_display() -> void:
	if not initialized:
		return
	# This is the production acceptance arrangement, explicitly staged for
	# inspection. Release its long HOVER hold so normal targeting resumes.
	display_palps = margin.arrange_archetype_row(
			_wall - _side * 1.05 - Vector3.UP * 0.25 + _normal * 0.04,
			_normal, 0.27)
	margin.frozen = false
	for palp: Dictionary in margin.palps:
		palp.act_left = 1.6
	palps._process(0.0)
	# Neither field history nor the director's signal ring is erased by
	# rearranging a display. Their owners still decide decay and deduplication.


func pulse() -> bool:
	if not initialized or not active or paused or not is_instance_valid(hero):
		return false
	# Explicit debug secretion, matching the existing organelle shot seam.
	# It does not claim that the hero physically touched the pad this frame.
	var before := int(director.signal_census().emitted)
	hero._emit_contact_signal(recipient_position())
	var emitted := int(director.signal_census().emitted) == before + 1
	if emitted:
		debug_secretions += 1
	return emitted


func attention() -> bool:
	if not initialized or not active or paused:
		return false
	var before := director.attention_active()
	director.on_world_modified(focus_position(), "debug_organelle_display")
	return not before and director.attention_active()


func activate(value: bool = true) -> void:
	active = value
	_apply_activity()


func set_simulation_paused(value: bool) -> void:
	paused = value
	_apply_activity()


func _apply_activity() -> void:
	set_physics_process(initialized and active and not paused)
	if is_instance_valid(tendrils):
		tendrils.set_physics_process(active and not paused)
		tendrils.visible = active
	# Existing shared organs are paused by the warehouse, not by this adapter.


func _physics_process(delta: float) -> void:
	if not initialized or not active or paused:
		return
	receiver._receive_architecture_signals()
	if living.tick(delta):
		panel_material.set_shader_parameter("living_pulse", living.pulse_phase())
		receiver._push_living_lifecycle(FIELD_ID, living)


func stats() -> Dictionary:
	if not initialized:
		return {"initialized": false, "active": active, "paused": paused}
	var nearby := 0
	var specimens: Array = roster.get("critters")
	for specimen: Dictionary in specimens:
		if (specimen.pos as Vector3).distance_to(recipient_position()) < 1.1:
			nearby += 1
	var body: Dictionary = living.census()
	return {
		"initialized": true, "active": active, "paused": paused,
		"living_steps": living.steps, "living_clock": living.clock,
		"living_cells": int(body.live_voxels),
		"living_format": living.texture().get_format(), "living": body,
		"architecture": receiver.architecture_signal_census(),
		"signals": director.signal_census(), "tendrils": tendrils.census(),
		"nearby_critters": nearby, "recipient_position": recipient_position(),
		"display_palps": display_palps, "debug_secretions": debug_secretions,
		"scope": "debug arrangement; existing owners interpret live packets",
	}


func _exit_tree() -> void:
	initialized = false
	if is_instance_valid(field) and field.living_field == living:
		field.living_field = _previous_living
	if panel_material != null:
		panel_material.set_shader_parameter("has_living", false)
		panel_material.set_shader_parameter("living_tex", null)
	if is_instance_valid(receiver):
		receiver.fields.clear()
		receiver.storey_materials.clear()
		receiver.ecology = null
	_previous_living = null
	living = null
