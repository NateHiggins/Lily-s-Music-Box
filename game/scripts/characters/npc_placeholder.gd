class_name NPCPlaceholder
extends Node3D
## Temporary resident actor made from the approved character concept sheet.
## It faces the camera around Y only, remains grounded, casts a cutout shadow,
## and reserves roughly the same footprint as the eventual rigged character.

var display_name := ""
var texture_path := ""


func setup(character_name: String, source_texture: String) -> void:
	display_name = character_name
	texture_path = source_texture


func _ready() -> void:
	name = "NPC_" + display_name.to_snake_case()
	add_to_group("resident_placeholders")
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("NPC sprite missing: %s" % texture_path)
		return
	var sprite := Sprite3D.new()
	sprite.name = "CharacterSprite"
	sprite.texture = texture
	sprite.pixel_size = 1.72 / float(texture.get_height())
	sprite.position.y = 0.86
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.18
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	add_child(sprite)

	# The footprint is reserved but NOT collidable, and that is deliberate.
	# Placeholders are dropped at the centre of each resident's main room,
	# which is exactly where the route from the unit door to the bedroom
	# door runs — Mina stood squarely in 2A's and WalkTest could no longer
	# walk a capsule to the bed. Reachability in this building is proven by
	# physics and gated by the generator's movement audit, and that audit
	# authors furniture positions with clearances; it knows nothing about
	# actors placed later in Godot. Solid residents therefore have to come
	# from gen_layout, so the same pass that guarantees the route is the one
	# that puts a person on it. Until then they are scenery: visible,
	# shadow-casting, and walk-through.
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 0
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.55
	collision.shape = capsule
	collision.position.y = 0.775
	body.add_child(collision)
	add_child(body)

	var label := Label3D.new()
	label.name = "Nameplate"
	label.text = display_name
	label.position.y = 1.88
	label.font_size = 34
	label.pixel_size = 0.002
	label.modulate = Color(0.82, 0.84, 0.80, 0.72)
	label.outline_modulate = Color(0.02, 0.025, 0.03, 0.9)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.no_depth_test = false
	add_child(label)
