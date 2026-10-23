extends RefCounted
## Transport/authorization adapter. Money remains CaretakerEconomy's; stock
## and delivery remain the shop/inventory owners'. No per-frame radio scans.
var economy: Node
var radio_available: Callable
var merchant_available: Callable

func configure(ledger: Node, radio: Callable, merchant: Callable) -> bool:
	if ledger==null or not ledger.has_method("purchase_once") or not radio.is_valid() or not merchant.is_valid(): return false
	economy=ledger;radio_available=radio;merchant_available=merchant
	return true

func settle(identity: String, merchant: String, item: String,
		cents: int, deliver: Callable) -> bool:
	if settlement_status(merchant,cents)!="available":return false
	return economy.purchase_once(identity,merchant,item,cents,deliver)

func settlement_status(merchant: String, cents: int) -> String:
	if cents<0:return "invalid_quote"
	if not is_instance_valid(economy) or not radio_available.is_valid() \
			or not bool(radio_available.call()):return "no_carrier"
	if not merchant_available.is_valid() or not bool(merchant_available.call(merchant)):return "terminal_unavailable"
	if RealityState.save_write_blocked:return "save_unavailable"
	if int(economy.book().cash)<cents:return "insufficient_funds"
	return "available"

func receipt(identity: String) -> Dictionary:
	return economy.purchase_receipt(identity) if is_instance_valid(economy) else {}
