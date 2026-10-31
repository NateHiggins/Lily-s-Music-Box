class_name MailOrders
extends RefCounted
## Coupons torn from the back page and posted at News & Cigars. A posted order waits
## its days and then is due in the 4B box through the existing mail catalogue. This
## owns only what has been torn and when it was posted. Money stays with the ledger
## and the parcel with the mail bank. An order can be placed once in a campaign.

const KEY := "mail_orders"
const DAY := 1440.0

static var _clock := CampaignClock.new()


static func book() -> Dictionary:
	if not RealityState.data.has(KEY):
		RealityState.data[KEY] = {"torn": {}, "posted": {}}
	return RealityState.data[KEY]


static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.get("torn") is not Dictionary or value.get("posted") is not Dictionary:
		return false
	for order: Variant in value.posted:
		if order is not String or typeof(value.posted[order]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	for order: Variant in value.torn:
		if order is not String or value.torn[order] is not bool:
			return false
	return true


static func torn(order: String) -> bool:
	return book().torn.has(order)


static func posted(order: String) -> bool:
	return book().posted.has(order)


## In the case, waiting to be posted.
static func held() -> Array:
	var out: Array = []
	for order: String in book().torn:
		if not posted(order):
			out.append(order)
	out.sort()
	return out


static func tear(order: String) -> bool:
	if order == "" or torn(order) or RealityState.save_write_blocked:
		return false
	book().torn[order] = true
	RealityState.commit()
	return true


## Uncommitted: the sale's settlement saves the order with the debit.
static func post(order: String) -> bool:
	if not torn(order) or posted(order) or not _clock.bind_state():
		return false
	book().posted[order] = _clock.elapsed_minutes()
	return true


static func arrived(order: String, days: int) -> bool:
	if not posted(order) or not _clock.bind_state():
		return false
	return _clock.elapsed_minutes() >= float(book().posted[order]) + float(days) * DAY
