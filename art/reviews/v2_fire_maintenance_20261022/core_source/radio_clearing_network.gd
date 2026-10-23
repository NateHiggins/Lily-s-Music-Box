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
	if not is_instance_valid(economy) or not radio_available.is_valid() \
			or not merchant_available.is_valid() or not bool(radio_available.call()) \
			or not bool(merchant_available.call(merchant)): return false
	return economy.purchase_once(identity,merchant,item,cents,deliver)

func receipt(identity: String) -> Dictionary:
	return economy.purchase_receipt(identity) if is_instance_valid(economy) else {}
