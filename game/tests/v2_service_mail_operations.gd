extends RefCounted
## Actual mail input in the reached production room, plus rebuild expectations.

func exercise(driver: Node) -> Dictionary:
	var world: OrisonV2RuntimeRoot=driver.world
	var bank: MailBankProp=world.adapter.resolve("LobbyMailBank") as MailBankProp
	if not driver._require(bank!=null and bank._hand_controls!=null,"reached production bank has native hand controls"):return {}
	var stance: Vector3=world.adapter.root.to_local(bank.global_position-bank.global_basis.z*.9)
	stance.y=0.
	if not await driver._walk(stance):return {}
	var door_point: Vector3=bank._hinge.to_global(Vector3(bank.LEAF_W*.5,-.008,0))
	if not await driver._drag_part(bank,door_point,deg_to_rad(95.),"production_mail_leaf"):return {}
	var first: Dictionary=_highest(bank)
	if not driver._require(not first.is_empty(),"normal opening-day catalogue has a physical due delivery"):return {}
	var part: MeshInstance3D=first.part
	if not await driver._drag_part(bank,part.to_global(part.get_aabb().get_center()),.25,"production_mail_withdrawal"):return {}
	var taken: String=str(first.id)
	if not driver._require(taken in RealityState.data.get("mail_taken",[]) and not world.player.call_locked and not bank._panel.attention_active(),"reached-room withdrawal uses existing custody without a modal"):return {}
	var remaining: Dictionary=_highest(bank)
	if not driver._require(not remaining.is_empty(),"a second opening-day article remains to test partial-pull restoration"):return {}
	part=remaining.part
	if not await driver._drag_part(bank,part.to_global(part.get_aabb().get_center()),.06,"production_mail_partial"):return {}
	if not driver._require(str(remaining.id) not in RealityState.data.get("mail_taken",[]),"partial production-room pull retains bank custody"):return {}
	await driver._capture("operated_mail_bank",world.adapter.root.to_local(bank.to_global(Vector3(-.15,1.4,-.1))))
	return {"taken":taken,"remaining":str(remaining.id),"mechanism":bank.mechanism_snapshot().duplicate(true)}

func _highest(bank: MailBankProp) -> Dictionary:
	var found: Dictionary={}
	for identity: String in bank._hand_controls.articles:
		var article: Dictionary=bank._hand_controls.articles[identity]
		var part: MeshInstance3D=article.stocks[0].part
		if found.is_empty() or part.global_position.y>(found.part as MeshInstance3D).global_position.y:
			found={"id":identity,"part":part}
	return found

func restored(world: OrisonV2RuntimeRoot,expected: Dictionary) -> bool:
	if expected.is_empty():return false
	var bank: MailBankProp=world.adapter.resolve("LobbyMailBank") as MailBankProp
	if bank==null or bank._hand_controls==null:return false
	if str(expected.taken) not in RealityState.data.get("mail_taken",[]) or str(expected.remaining) in RealityState.data.get("mail_taken",[]):return false
	if bank._hand_controls.articles.has(str(expected.taken)) or not bank._hand_controls.articles.has(str(expected.remaining)):return false
	var actual: Dictionary=bank.mechanism_snapshot()
	var wanted: Dictionary=expected.mechanism
	if absf(float(actual.door)-float(wanted.door))>1e-6 or actual.pulls.keys()!=wanted.pulls.keys():return false
	for identity: String in wanted.pulls:
		if absf(float(actual.pulls[identity])-float(wanted.pulls[identity]))>1e-6:return false
	return true
