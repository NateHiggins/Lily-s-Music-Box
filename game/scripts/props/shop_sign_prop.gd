class_name ShopSignProp
extends FunctionalProp
## The name over a shop, in letters you can actually read.
##
## The geometry pass builds every shopfront's sign band and its blade
## bracket; both were blank painted boards, so a street whose whole
## premise is that you can read it advertised nothing. This hangs the
## lettering on them.
##
## LABEL3D, NOT A TEXTURE, and that is a rule rather than a shortcut.
## The house texture rules forbid letters, numbers, words or logos in
## any generated plate — it is the most-broken rule in the brief and the
## reason every material in the catalog is clean. Signage is the one
## thing that genuinely needs type, so it gets type the way the bodega
## and the Harukiya already do: real glyphs, in 3D, lit by the shop's
## own door lamp.
##
## Everything here comes off the marker. A shop's name, its second line,
## its letter colour and whether it owns a blade are the layout's to
## decide, so adding an eleventh shop to SHOPS is the whole job and this
## file does not change.

var sign_text := "SHOP"
var sub_text := ""
var blade_text := ""
var blade_dx := 0.0
var tint := Color(0.90, 0.86, 0.74)
## Half the bay width, so the name can be shrunk to fit a narrow shop
## instead of running off the ends of its own board.
var half_width := 2.4
## Set when the shop has an awning and the name therefore lives on the
## valance rather than the fascia. A valance is 280 mm deep against the
## fascia board's 460, so the type has to come down and close up — and
## the blade, which is the only thing readable from up the street once
## an awning is in the way, stays exactly where it is.
var compact := false

const BAND_Z := 0.03          # proud of the board, or it z-fights it


func _build_visual() -> void:
	# THE FASCIA NAME. Sized to the bay: a 2.3 m news kiosk and a 5.6 m
	# laundry carry the same board height and very different amounts of
	# room, and type set for the wide one runs off the ends of the narrow
	# one. 0.052 m per character at the base size is measured off the
	# widest of the ten (PHOTO SUPPLIES at 5.2 m), so everything narrower
	# steps down rather than overflowing.
	var name_label := Label3D.new()
	name_label.text = sign_text
	var fit: float = 1.0
	var want: float = maxf(1.0, float(sign_text.length())) * 0.052
	if want > half_width * 1.7:
		fit = (half_width * 1.7) / want
	name_label.font_size = 86
	name_label.pixel_size = (0.0022 if compact else 0.0030) * fit
	name_label.modulate = tint
	# A dark keyline so the letters hold against a lit board behind them
	# AND against the black sky when the board is not lit. Without it the
	# pale trades (photo, funeral) vanish at night and the dark ones
	# vanish by day.
	name_label.outline_size = 5
	name_label.outline_modulate = Color(0.06, 0.05, 0.05, 0.85)
	name_label.position = Vector3(0, 0.045 if compact else 0.06, BAND_Z)
	add_child(name_label)

	if sub_text != "":
		# The trade line. Every shop of this date carried one and it is
		# where the period actually lives: nobody wrote SHOE REBUILDING
		# on a board without also promising it while you wait.
		var sub := Label3D.new()
		sub.text = sub_text
		var swant: float = maxf(1.0, float(sub_text.length())) * 0.021
		var sfit: float = 1.0
		if swant > half_width * 1.7:
			sfit = (half_width * 1.7) / swant
		sub.font_size = 30
		sub.pixel_size = (0.0024 if compact else 0.0030) * sfit
		sub.modulate = tint.lerp(Color(1, 1, 1), 0.25)
		sub.outline_size = 3
		sub.outline_modulate = Color(0.06, 0.05, 0.05, 0.8)
		sub.position = Vector3(0, -0.075 if compact else -0.13, BAND_Z)
		add_child(sub)

	# THE BLADE, both faces. A blade sign exists to be read from up the
	# street rather than from in front of the shop — which is the only
	# way anybody ever finds a locksmith — so it is lettered on both
	# sides and the two must face opposite ways or one of them reads
	# backwards to half the street.
	if blade_text != "":
		for side in [-1.0, 1.0]:
			var blade := Label3D.new()
			blade.text = blade_text
			blade.font_size = 64
			blade.pixel_size = 0.0028
			blade.modulate = tint
			blade.outline_size = 4
			blade.outline_modulate = Color(0.06, 0.05, 0.05, 0.85)
			# Local, and every term of it is measured rather than
			# guessed. The blade box is authored at z 2.70..3.42 (centre
			# 3.06) and F+0.28..F+1.30 (centre F+0.79); the sign sits at
			# z 2.76, F+0.27; the 180 yaw negates x and z. That gives
			# (dx, 0.30, 0.52). The first pass used 0.51 for the height
			# and put the word up against the top edge of its own panel,
			# which is visible in the render and nowhere in the source.
			blade.position = Vector3(blade_dx + side * 0.05, 0.30, 0.52)
			blade.rotation_degrees = Vector3(0, side * 90.0, 0)
			add_child(blade)
