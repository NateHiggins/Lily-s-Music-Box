extends RefCounted
## Reuse the actual input driver against the reached production mechanism.
const Phone=preload("res://tests/v2_house_switchboard_hand_bench.gd")

func exercise(driver: Node) -> bool:
	var world: OrisonV2RuntimeRoot=driver.world
	var board: HouseSwitchboardProp=world.adapter.resolve("F01_HOUSE_TELEPHONE_BOARD") as HouseSwitchboardProp
	if not driver._require(board!=null and board.native_switchboard_ready(),"reached production telephone retains native mechanism"):return false
	var stance: Vector3=world.adapter.root.to_local(board.global_position-board.global_basis.z*.95)
	stance.y=0.
	if not await driver._walk(stance):return false
	var line: HouseTelephoneNetwork=board.network as HouseTelephoneNetwork
	# This is a declared caller stimulus through the existing network API;
	# answering and carrying below require actual player mouse events.
	if not driver._require(line.request("F02_A_TELEPHONE"),"production telephone accepts the declared existing caller stimulus"):return false
	var hand: Node=Phone.new();hand.externally_managed=true;hand.board=board;hand.line=line;hand.player=world.player;driver.add_child(hand)
	var ok: bool=await driver._drag_part(board,board._key.to_global(Vector3(0,.108,0)),-.42,"production_listening_key")
	if ok:ok=await hand.connect_plug(0,"0_0")
	if ok:ok=driver._require(str(line.snapshot().state)=="ANSWERED","reached-room caller plug and key answer through original network")
	if ok:ok=await hand.connect_plug(1,"2_5")
	if ok:ok=driver._require(str(line.snapshot().state)=="CARRYING","reached-room trunk plug carries the original line")
	if ok:
		await driver._capture("operated_house_telephone",world.adapter.root.to_local(board.to_global(Vector3(0,.35,-.12))))
		var part: Node3D=board._hand_controls.plugs[0]
		await hand.aim(part.to_global(Vector3(0,0,-.025)));hand.click()
		ok=await hand.carry_to(Vector3(part.position.x,part.position.y,-.235))
		hand.click()
		ok=driver._require(ok and str(line.snapshot().state)=="IDLE","reached-room physical disconnection releases the original line")
	world.player.cancel_manipulation()
	var successful: bool=ok and hand.failures.is_empty()
	driver._require(successful,"complete production telephone mouse sequence without a state setter")
	hand.free()
	return successful
