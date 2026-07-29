extends Control

@onready var rewire_label: Label = %RewireLabel
@onready var chime_label: Label = %ChimeLabel
@onready var map_graph: Label = %MapGraph
@onready var deaths_list: ItemList = %DeathsList
@onready var custom_panel: Panel = %CustomizePanel
@onready var hair_style_btn: OptionButton = %HairStyle
@onready var hair_gradient_btn: OptionButton = %HairGradient
@onready var aura_btn: OptionButton = %Aura
@onready var face_btn: OptionButton = %Face
@onready var outfit_btn: OptionButton = %Outfit

func _ready() -> void:
	_init_options()
	_refresh()

func _init_options() -> void:
	var mapping := {
		hair_style_btn: ["LongWaves", "TwinTails", "BluntBob"],
		hair_gradient_btn: ["Pink", "Blue", "Lavender"],
		aura_btn: ["None", "SoftSparkle", "CherryPetals"],
		face_btn: ["Normal", "PorcelainCrack"],
		outfit_btn: ["BalletBoots", "StreetCorset", "LaceTrim"],
	}
	for btn in mapping.keys():
		btn.clear()
		for item in mapping[btn]:
			btn.add_item(item)

func _refresh() -> void:
	var st := MansionStateStore.state
	rewire_label.text = "Rewires: %s | Last: %s" % [st["rewire_count"], st["last_rewire_timestamp"]]
	chime_label.text = st["chime_message"]
	map_graph.text = "●─●─◉\n│  ╲│\n●──●"
	deaths_list.clear()
	for d in DeathRemnantStore.recent(5):
		deaths_list.add_item("%s @ (%s,%s)" % [d["room_id"], int(d["position"]["x"]), int(d["position"]["y"])])

func _on_start_run_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Run.tscn")

func _on_customize_avatar_pressed() -> void:
	custom_panel.visible = true

func _on_close_customize_pressed() -> void:
	custom_panel.visible = false
	ProfileStore.save_profile()

func _on_setting_changed(idx: int, option: String) -> void:
	var p := ProfileStore.profile
	var values := {
		"hair_style": ["LongWaves", "TwinTails", "BluntBob"],
		"hair_gradient": ["Pink", "Blue", "Lavender"],
		"aura_particles": ["None", "SoftSparkle", "CherryPetals"],
		"face_option": ["Normal", "PorcelainCrack"],
		"outfit": ["BalletBoots", "StreetCorset", "LaceTrim"],
	}
	p.set(option, values[option][idx])
