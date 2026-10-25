extends "res://tests/orison_v2_gas_mantle_test.gd"
## The spare-mantle restock: once the first dozen has been taken, Management
## posts a second carton to box 4B; it shows in the pocket; lifting the empty
## workroom carton's lid with it in hand refills the carton (gas_mantle_13 to
## 24) and gives the next spare. The mail is taken by the bank's own physical
## take, the path its hand controls use; the carton by the player's grab.

func _init() -> void: route_label="GAS MANTLE RESTOCK"

func _route() -> void:
	var carton:=world.adapter.resolve("F01_GAS_MANTLE_CARTON") as OrisonV2MantleCarton
	var bank:=world.adapter.resolve("LobbyMailBank") as MailBankProp
	var inventory: MaintenanceInventory=world.maintenance_inventory
	if carton==null or bank==null or bank.inventory!=inventory:
		failures.append("carton or mail bank is not wired to the maintenance inventory");return
	if _due(bank):
		failures.append("the restock is posted before the first dozen is gone");return
	# Fixture: the first dozen taken and spent, as a year of renewals would leave it.
	for i in 12:
		var id:="gas_mantle_%02d" % (i+1)
		if not inventory.grant(id,"test_fixture") or not inventory.consume(id):
			failures.append("fixture could not spend "+id);return
	carton._show()
	if carton.remaining()!=0 or not _due(bank):
		failures.append("an empty carton does not bring Management's restock to box 4B");return
	for item: Dictionary in bank.pending():
		if str(item.id)=="pkg_gas_mantles":bank._take(item,true)
	if not inventory.has_item("gas_mantle_carton_2") or _due(bank):
		failures.append("taking the parcel did not put the second carton in hand");return
	if not PersonInventory.pocket_lines().has("PART: gas mantle carton 2"):
		failures.append("the carried carton is missing from the pocket ledger");return
	for point in [Vector3(1.925,0,-6.5),Vector3(0,0,-8.6),Vector3(4.85,0,-8.6),Vector3(4.85,0,-9.9),Vector3(4.6,0,-10.7),Vector3(6.4,0,-10.7),Vector3(7.55,0,-11.25)]:
		if not await _walk(point):return
	if not await _grab_to(carton.lid_part,carton.to_global(Vector3(0,0.075,0.07)),1.5):return
	if not carton.refilled() or carton.carried()!="gas_mantle_13" or carton.remaining()!=11 \
			or not inventory.is_consumed("gas_mantle_carton_2"):
		failures.append("the empty carton did not take the refill and give the next spare");return
	await _capture("carton_refilled")
	print("GAS MANTLE RESTOCK: empty carton posts a second dozen, pocket shows it, carton refills to 13..24")

func _due(bank: MailBankProp) -> bool:
	for item: Dictionary in bank.pending():
		if str(item.id)=="pkg_gas_mantles":return true
	return false
