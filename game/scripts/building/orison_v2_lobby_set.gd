extends RefCounted
## The lobby set carried from V1 into the V2 building (Lily's rulings
## v1r_lobby_boards, v1r_historical_radio_b and v1r_mail_chute, 2026-11-09):
## the notice board with the wireless notice, the original Orison broadside,
## and the mail chute beside the mail bank. Every position is data in
## res://data/orison_v2/lobby_set_placements.json, in the blockout's own plan
## coordinates; the props are children of the blockout, so its transform
## places them in the world.
const PLACEMENTS := "res://data/orison_v2/lobby_set_placements.json"
const Native := preload("res://scripts/building/orison_v2_native_lobby_set.gd")
const BulletinBoard := preload("res://scripts/building/orison_v2_lobby_bulletin_board.gd")
const AdBoard := preload("res://scripts/building/orison_v2_lobby_ad_board.gd")
const MailChute := preload("res://scripts/building/orison_v2_mail_chute_prop.gd")


## Mounts the three props and returns them as
## {"bulletin_board", "advert_board", "mail_chute"}; empty when refused.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, adapter: Variant) -> Dictionary:
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENTS))
	if plan is not Dictionary or plan.get("schema_version") != 1:
		push_error("V2 lobby set: placements missing or of another schema")
		return {}
	if root == null or blockout == null or adapter == null or not root.is_ancestor_of(blockout):
		push_error("V2 lobby set: the blockout is not under the runtime root")
		return {}
	var native := Native.new()
	if not native.prepare():
		push_error("V2 lobby set: native stock refused: " + ", ".join(PackedStringArray(native.errors)))
		return {}

	# The notice board becomes the lobby pinboard V2 already hangs: it takes
	# that board's place and retires the bare board's visual, keeping its body.
	var board_plan: Dictionary = plan.bulletin
	var host := adapter.resolve(str(board_plan.anchor)) as Node3D
	if host == null:
		push_error("V2 lobby set: no anchor " + str(board_plan.anchor))
		return {}
	var board := BulletinBoard.new()
	board.native = native
	board.plan = board_plan
	blockout.add_child(board)
	var seat: Array = board_plan.anchor_offset
	board.global_transform = host.global_transform * Transform3D(Basis(Vector3.UP, float(board_plan.anchor_yaw)),
			Vector3(float(seat[0]), float(seat[1]), float(seat[2])))
	if bool(board_plan.retire_anchor_visual):
		for child in host.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).visible = false
		host.set_meta("v2_lobby_set_visual_retired", true)

	var advert := AdBoard.new()
	advert.native = native
	advert.plan = plan.advert
	blockout.add_child(advert)
	advert.transform = _seat(layout, plan.advert)

	var chute := MailChute.new()
	chute.native = native
	chute.plan = plan.chute
	chute.prop_type = "mail_chute"
	chute.name = "LobbyMailChute"
	blockout.add_child(chute)
	chute.transform = _seat(layout, plan.chute)
	return {"bulletin_board": board, "advert_board": advert, "mail_chute": chute}


## A placement row to a blockout-local transform: plan x and z, height above
## the floor of its level, and the yaw of a prop authored facing local +Z.
static func _seat(layout: Dictionary, row: Dictionary) -> Transform3D:
	var floor_y := 0.0
	for level: Dictionary in layout.get("levels", []):
		if str(level.get("id", "")) == str(row.level):
			floor_y = float(level.y)
	var at: Array = row.position
	return Transform3D(Basis(Vector3.UP, float(row.yaw)), Vector3(float(at[0]), floor_y + float(at[1]), float(at[2])))
