extends RefCounted
## Existing period laundry mechanisms at explicit basement service anchors.
func mount(adapter: OrisonV2AnchorAdapter) -> bool:
	var ids: Array[String] = ["B1_WASHER_01","B1_WASHER_02","B1_LAUNDRY_AIRER_01"]
	for identity in ids:
		if adapter.resolve(identity) == null: return false
	if not adapter.install_acoustic_overrides(ids): return false
	for identity in ids:
		var machine: FunctionalProp = LaundryAirerProp.new() if "AIRER" in identity else WasherProp.new()
		machine.prop_type = "laundry_airer" if "AIRER" in identity else "washer"
		if not adapter.mount_consumer(identity,machine):
			machine.free()
			return false
	return true
