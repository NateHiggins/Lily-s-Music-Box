class_name PhoneOS
extends RefCounted
## orisonOS — somebody's hacked Linux on a company handset.
##
## The fiction: the answering service issues its night operators a
## NOCTURNE 900, a 2011-ish enterprise handset with a real keyboard. At
## some point an operator who signed their commits `op@nightdesk`
## flashed a stripped Linux onto theirs and left it that way, and the
## phone has been handed down the shift rota ever since. It boots too
## slowly, the clock comes off the network because the RTC battery died
## years ago, and nobody has ever managed to make sleep mode work.
##
## Everything renders into a TermGrid. There are no widgets and no
## retained UI: the OS composes its whole screen each frame, the way the
## hardware it is pretending to be actually did. If you are coming from
## Python, `render()` is closer to a curses redraw loop than to Tk.

enum Screen { BOOT, MOTD, HOME, APP }

const BOOT_LOG := [
	[0.00, " NOCTURNE 900     BOOTLOADER 2.11", TermGrid.HI],
	[0.10, "  rom checksum ................. ok", TermGrid.DIM],
	[0.22, "  radio firmware ............... 1610", TermGrid.DIM],
	[0.34, "  battery ...................... 41% (reported)", TermGrid.DIM],
	[0.46, "  rtc .......................... dead, clock from network",
			TermGrid.WARN],
	[0.62, "", TermGrid.FG],
	[0.70, " booting /vmlinuz-orison", TermGrid.FG],
	[0.86, "[0.000] Linux 3.2.0-orison (op@nightdesk) #47", TermGrid.DIM],
	[0.96, "[0.011] tty0 480x384 mono", TermGrid.DIM],
	[1.06, "[0.043] mtd: 4 partitions on internal flash", TermGrid.DIM],
	[1.16, "[0.088] snd_pcm: ok", TermGrid.DIM],
	[1.30, "[0.140] warn: /dev/mic busy, held by pid 1", TermGrid.WARN],
	[1.44, "[0.201] eth: no carrier", TermGrid.DIM],
	[1.56, "[0.266] gsm0: registered, no operator name", TermGrid.DIM],
	[1.70, "[0.310] mount /home ......... ok", TermGrid.DIM],
	[1.84, "[0.402] starting dispatchd .. ok", TermGrid.DIM],
	[1.98, "[0.511] starting nightdesk .. ok", TermGrid.DIM],
	[2.16, "", TermGrid.FG],
	[2.24, " login: operator (auto)", TermGrid.HI],
]
const MOTD_ART := [
	"        .-.",
	"       ( o )",
	"        `-'",
	"       / | \\",
	"      '  |  '",
	"         |",
]
## id, label, ascii glyph, and whether the thing behind it exists yet.
const APPS := [
	{"id": "dial", "label": "dial", "icon": ["[##]", " )( "], "live": true},
	{"id": "notes", "label": "notes", "icon": ["/==\\", "\\__/"], "live": true},
	{"id": "cam", "label": "cam", "icon": ["(oo)", "'--'"], "live": true},
	{"id": "term", "label": "term", "icon": ["$_  ", "    "], "live": true},
	{"id": "radio", "label": "radio", "icon": ["|)) ", "1610"], "live": true},
	{"id": "maze", "label": "maze", "icon": ["|_||", "||_|"], "live": false},
	{"id": "shards", "label": "shards", "icon": ["\\/\\/", "/\\/\\"], "live": false},
	{"id": "pairs", "label": "pairs", "icon": ["[][]", "[][]"], "live": false},
	{"id": "sys", "label": "sys", "icon": ["<+>", "   "], "live": true},
]
const COLS_PER_ROW := 3

var screen: int = Screen.BOOT
var cursor := 0
var t := 0.0
var app_id := ""
var led_pulse := 0.0

## Set by Phone3D so the cam app can report the roll without owning it.
var camera_roll := 0
var camera_cap := 40
var gallery_index := 0
var gallery_open := false
var last_shot := ""

var _term_lines: Array[String] = []
var _term_input := ""
var _boot_done_at := 0.0
var _grid := TermGrid.new()

## The little filesystem `term` can see. Two of these are the reason the
## app exists at all.
const FILES := {
	"readme": [
		"this handset is the property of the answering service.",
		"it is not to be reflashed. it has been reflashed.",
		"",
		"  -- management",
	],
	"shift.txt": [
		"nights are yours now. the log is in dispatchd.",
		"the line rings even when the building is empty.",
		"you will want to answer it anyway. answer it anyway.",
		"",
		"the sleep mode does not work. i tried for a month.",
		"if you fix it do not tell them, they will want it back.",
		"",
		"      op@nightdesk",
	],
	"1610.log": [
		"carrier detected 1610kHz  03:11:04",
		"carrier detected 1610kHz  03:11:59",
		"carrier detected 1610kHz  03:12:54",
		"...",
		"(4471 lines suppressed)",
		"no transmitter has ever been found.",
	],
}


func boot() -> void:
	screen = Screen.BOOT
	t = 0.0
	cursor = 0
	_term_lines = ["orisonOS 0.9.7 — type `help`", ""]


func advance(delta: float) -> void:
	t += delta
	led_pulse += delta
	if screen == Screen.BOOT and t > float(BOOT_LOG[-1][0]) + 0.9:
		screen = Screen.MOTD
		t = 0.0
	elif screen == Screen.MOTD and t > 3.2:
		screen = Screen.HOME


## ---- input ---------------------------------------------------------

func key(action: String, typed := "") -> void:
	if screen == Screen.BOOT or screen == Screen.MOTD:
		if action in ["ok", "back"]:
			screen = Screen.HOME
		return
	if screen == Screen.HOME:
		match action:
			"left": cursor = maxi(0, cursor - 1)
			"right": cursor = mini(APPS.size() - 1, cursor + 1)
			"up": cursor = maxi(0, cursor - COLS_PER_ROW)
			"down": cursor = mini(APPS.size() - 1, cursor + COLS_PER_ROW)
			"ok":
				app_id = str(APPS[cursor].id)
				screen = Screen.APP
				t = 0.0
		return
	# inside an app
	if action == "back":
		if app_id == "term" and _term_input != "":
			_term_input = ""
			return
		screen = Screen.HOME
		return
	if app_id == "cam":
		match action:
			"up": gallery_open = true
			"down": gallery_open = false
			"left":
				if gallery_open:
					gallery_index = maxi(0, gallery_index - 1)
			"right":
				if gallery_open:
					gallery_index = mini(maxi(0, camera_roll - 1),
							gallery_index + 1)
		return
	if app_id == "term":
		if action == "ok":
			_run_command(_term_input)
			_term_input = ""
		elif action == "backspace":
			_term_input = _term_input.substr(0, maxi(0, _term_input.length() - 1))
		elif typed != "":
			if _term_input.length() < 44:
				_term_input += typed


func _echo(line: String) -> void:
	_term_lines.append(line)
	while _term_lines.size() > 17:
		_term_lines.pop_front()


func _run_command(raw: String) -> void:
	var line := raw.strip_edges()
	_echo("$ " + line)
	var argv := line.split(" ", false)
	if argv.is_empty():
		return
	match argv[0]:
		"help":
			_echo("ls cat uname ps dmesg free date whoami clear")
		"ls":
			_echo("  ".join(FILES.keys()))
		"cat":
			if argv.size() < 2:
				_echo("cat: needs a file")
			elif FILES.has(argv[1]):
				for l in FILES[argv[1]]:
					_echo(l)
			else:
				_echo("cat: %s: no such file" % argv[1])
		"uname":
			_echo("Linux nocturne 3.2.0-orison #47 armv7l")
		"whoami":
			_echo("operator")
		"ps":
			_echo("  1 ?  Ss  dispatchd")
			_echo(" 47 ?  S   nightdesk")
			_echo(" 88 ?  S   [mic]  <- will not die")
		"dmesg":
			_echo("[0.140] warn: /dev/mic busy, held by pid 1")
			_echo("[0.266] gsm0: registered, no operator name")
			_echo("[9999.9] carrier detected 1610kHz")
		"free":
			_echo("        total   used   free")
			_echo("Mem:    262144 251008  11136")
		"date":
			_echo(Time.get_datetime_string_from_system()
					+ "  (from network; rtc dead)")
		"clear":
			_term_lines.clear()
		_:
			_echo("%s: command not found" % argv[0])


## ---- render --------------------------------------------------------

func render() -> TermGrid:
	var g := _grid
	g.clear()
	match screen:
		Screen.BOOT: _render_boot(g)
		Screen.MOTD: _render_motd(g)
		Screen.HOME: _render_home(g)
		Screen.APP: _render_app(g)
	return g


func _render_boot(g: TermGrid) -> void:
	var row := 1
	for entry in BOOT_LOG:
		if t < float(entry[0]):
			break
		g.put(1, row, str(entry[1]), entry[2])
		row += 1
	if fmod(t, 0.9) < 0.55 and row < TermGrid.ROWS:
		g.put(1, row, "_", TermGrid.HI)


## The handover from the company's bootloader to the operator's skin,
## and the moment the phone stops being beige. Everything above this
## screen is dry and technical; everything below it is 1995.
func _render_motd(g: TermGrid) -> void:
	var cyc := int(t * 14.0)
	for i in 6:
		g.data_column(2 + i * 12, i, t * (0.6 + i * 0.2))
	# Punch the hex out from behind the wordmark. The film's screens are
	# dense but its titles are always legible; noise belongs around the
	# word, not inside the letterforms.
	for r in range(1, 8):
		g.fill_row(r, TermGrid.BG)
	g.banner(9, 2, "ORISON", cyc)
	g.banner(33, 2, "OS", cyc + 2)
	g.put(33, 7, "0.9.7  op@nightdesk", TermGrid.CYAN)
	# The film never lets a readout sit still, so neither does this.
	var sweep := int(fmod(t * 22.0, 44.0))
	g.put(8, 14, "[" + "=".repeat(mini(sweep, 42)).rpad(42) + "]",
			TermGrid.GREEN)
	g.put(8, 15, "linking dispatchd", TermGrid.GREEN)
	if t > 1.4:
		g.put_centre(17, " A C C E S S   G R A N T E D ",
				TermGrid.BG, TermGrid.MAGENTA)
	if t > 2.0:
		g.put(6, 19, "27 unread.", TermGrid.HI)
		g.put(6, 20, "27 is not a real number of unread.", TermGrid.WARN)
	if fmod(t, 0.7) < 0.45:
		g.put_centre(22, "[ any key ]", TermGrid.CYAN)


## The launcher. Nine blocks in a grid, the selected one lit and
## breathing, hex falling down the gutters behind everything, and a
## ticker along the bottom that never shuts up.
func _render_home(g: TermGrid) -> void:
	for i in 4:
		g.data_column(1 + i * 19, i + 3, t * (0.5 + i * 0.17))
	_status_bar(g)
	for i in APPS.size():
		var app: Dictionary = APPS[i]
		var col := i % COLS_PER_ROW
		var row := i / COLS_PER_ROW
		var x := 3 + col * 19
		var y := 3 + row * 6
		var selected := i == cursor
		var accent: Color = TermGrid.NEON[i % TermGrid.NEON.size()]
		var fg: Color = accent if app.live else TermGrid.DIM
		# Clear the falling hex out from behind a tile so the grid
		# stays legible - the film is maximalist, not unreadable.
		for r in 5:
			g.put(x - 1, y - 1 + r, " ".repeat(16), fg, TermGrid.BG)
		if selected:
			var pulse: Color = accent if fmod(t, 0.8) < 0.5 else TermGrid.HI
			g.box(x - 1, y - 1, 16, 6, pulse)
			g.put(x - 1, y - 1, ">", pulse)
		var icon: Array = app.icon
		for k in icon.size():
			g.put(x + 5, y + k, str(icon[k]),
					TermGrid.HI if selected else fg)
		g.put(x + 4, y + 3, str(app.label), fg)
		if not app.live:
			# pairs deals its deck from the camera roll, so once there
			# are photographs it has something real to say.
			if str(app.id) == "pairs" and camera_roll >= 8:
				g.put(x + 1, y + 4, "%d photos ready" % camera_roll,
						TermGrid.GREEN)
			else:
				g.put(x + 2, y + 4, "no cartridge", TermGrid.DIM)
	g.fill_row(23, TermGrid.BG_ALT)
	var ticker := ("  CARRIER 1610 PRESENT  //  NO TRANSMITTER FOUND  "
			+ "//  27 UNREAD  //  SLEEP MODE UNIMPLEMENTED  "
			+ "//  DO NOT FLASH THIS  ")
	var off := int(fmod(t * 11.0, float(ticker.length())))
	g.put(0, 23, (ticker.substr(off) + ticker).substr(0, TermGrid.COLS),
			TermGrid.GREEN, TermGrid.BG_ALT)


func _status_bar(g: TermGrid) -> void:
	g.fill_row(0, TermGrid.BG_ALT)
	g.put(1, 0, "orisonOS", TermGrid.CYAN, TermGrid.BG_ALT)
	g.put(20, 0, "no operator name", TermGrid.DIM, TermGrid.BG_ALT)
	# Signal bars that move, because nothing in this interface is
	# allowed to be still.
	for i in 4:
		var lit: bool = i < 2 + int(fmod(t * 0.7, 2.0))
		g.put(40 + i, 0, "|" if lit else ".",
				TermGrid.GREEN if lit else TermGrid.DIM, TermGrid.BG_ALT)
	g.put(46, 0, "41%", TermGrid.WARN, TermGrid.BG_ALT)
	g.put(51, 0, "03:11", TermGrid.FG, TermGrid.BG_ALT)


func _render_app(g: TermGrid) -> void:
	_status_bar(g)
	var app := _app_by_id(app_id)
	g.put(1, 1, "/ " + str(app.get("label", app_id)), TermGrid.HI)
	match app_id:
		"term": _app_term(g)
		"notes": _app_notes(g)
		"cam": _app_cam(g)
		"dial": _app_dial(g)
		"radio": _app_radio(g)
		"sys": _app_sys(g)
		_: _app_cartridge(g, str(app.get("label", app_id)))
	g.fill_row(23, TermGrid.BG_ALT)
	g.put(1, 23, "esc: back", TermGrid.DIM, TermGrid.BG_ALT)


func _app_by_id(id: String) -> Dictionary:
	for a in APPS:
		if str(a.id) == id:
			return a
	return {}


func _app_term(g: TermGrid) -> void:
	var row := 3
	for l in _term_lines:
		g.put(1, row, l, TermGrid.FG)
		row += 1
	var caret := "_" if fmod(t, 0.9) < 0.55 else " "
	g.put(1, mini(21, row), "$ " + _term_input + caret, TermGrid.HI)


func _app_notes(g: TermGrid) -> void:
	g.put(2, 3, "tonight", TermGrid.HI)
	g.put(2, 5, "[ ] answer the line", TermGrid.FG)
	g.put(2, 6, "[ ] do not go to four", TermGrid.FG)
	g.put(2, 7, "[x] check the mail bank", TermGrid.DIM)
	g.put(2, 9, "nothing here syncs anywhere.", TermGrid.DIM)
	g.put(2, 10, "the notes app was never finished.", TermGrid.DIM)


func _app_cam(g: TermGrid) -> void:
	# Draws CHROME ONLY. Every cell left as a space is a hole the
	# viewfinder shows through, because Phone3D paints the lens texture
	# under the grid and TermGrid never fills a cell whose background is
	# still the default. Writing a box of spaces here would black the
	# picture out.
	if gallery_open:
		_app_gallery(g)
		return
	g.put(1, 2, "REC", TermGrid.WARN)
	g.put(6, 2, "%d/%d" % [camera_roll, camera_cap], TermGrid.HI)
	if camera_roll >= camera_cap:
		g.put(16, 2, "roll full - oldest goes", TermGrid.WARN)
	# corner marks, the way a viewfinder frames rather than a full box
	for corner in [[2, 4, "+--", "|"], [55, 4, "--+", "|"],
			[2, 19, "+--", "|"], [55, 19, "--+", "|"]]:
		g.put(int(corner[0]), int(corner[1]), str(corner[2]),
				TermGrid.CYAN)
	g.put(29, 4, "|", TermGrid.CYAN)
	g.put(29, 19, "|", TermGrid.CYAN)
	g.put(2, 11, "-", TermGrid.CYAN)
	g.put(57, 11, "-", TermGrid.CYAN)
	if last_shot != "":
		g.put(1, 21, "saved", TermGrid.GREEN)
	g.put(1, 22, "enter: shutter    up: gallery", TermGrid.DIM)


## The roll, one frame at a time, with the picture itself drawn under
## this by Phone3D exactly as the viewfinder is.
func _app_gallery(g: TermGrid) -> void:
	g.put(1, 2, "ROLL", TermGrid.HI)
	if camera_roll == 0:
		g.put_centre(11, "no photographs yet", TermGrid.DIM)
		g.put(1, 22, "down: viewfinder", TermGrid.DIM)
		return
	g.put(8, 2, "%d of %d" % [gallery_index + 1, camera_roll],
			TermGrid.CYAN)
	g.put(1, 22, "left/right: browse   down: viewfinder", TermGrid.DIM)


func _app_dial(g: TermGrid) -> void:
	g.put(2, 3, "the line", TermGrid.HI)
	g.put(2, 5, "  no operator name", TermGrid.DIM)
	g.put(2, 6, "  0 calls waiting", TermGrid.FG)
	g.put(2, 8, "dispatchd is running but this handset", TermGrid.DIM)
	g.put(2, 9, "is not bound to the desk yet.", TermGrid.DIM)
	g.put(2, 11, "when it is, the calls come here.", TermGrid.FG)


func _app_radio(g: TermGrid) -> void:
	g.put(2, 3, "1610 kHz", TermGrid.HI)
	var bars := int(fmod(t * 6.0, 20.0))
	for i in 20:
		var h := (i * 7 + int(t * 40.0)) % 5
		g.put(4 + i * 2, 10 - h, "|",
				TermGrid.FG if i < bars else TermGrid.DIM)
	g.put(2, 12, "carrier present. no programme.", TermGrid.FG)
	g.put(2, 13, "there is no transmitter.", TermGrid.WARN)
	g.put(2, 15, "it is 03:11 and something is", TermGrid.DIM)
	g.put(2, 16, "still broadcasting.", TermGrid.DIM)


func _app_sys(g: TermGrid) -> void:
	g.put(2, 3, "NOCTURNE 900", TermGrid.HI)
	g.put(2, 5, "os ......... orisonOS 0.9.7", TermGrid.FG)
	g.put(2, 6, "kernel ..... 3.2.0-orison #47", TermGrid.FG)
	g.put(2, 7, "built by ... op@nightdesk", TermGrid.FG)
	g.put(2, 8, "screen ..... 480x384 mono", TermGrid.FG)
	g.put(2, 9, "radio ...... 1610", TermGrid.FG)
	g.put(2, 10, "rtc ........ dead", TermGrid.WARN)
	g.put(2, 11, "sleep ...... unimplemented", TermGrid.WARN)
	g.put(2, 13, "warranty void. it was void when", TermGrid.DIM)
	g.put(2, 14, "you got it.", TermGrid.DIM)


## The three HTML games land here once a runtime is chosen. Saying so
## plainly beats a fake loading bar: the slot is real, the cartridge
## is not in it yet.
func _app_cartridge(g: TermGrid, label: String) -> void:
	g.box(10, 5, 40, 11, TermGrid.DIM)
	g.put_centre(7, "/dev/cartridge", TermGrid.DIM)
	g.put_centre(9, label.to_upper(), TermGrid.HI)
	g.put_centre(11, "no runtime bound", TermGrid.WARN)
	g.put_centre(13, "gilded moth productions", TermGrid.DIM)
