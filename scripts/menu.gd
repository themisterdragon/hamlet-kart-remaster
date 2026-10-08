extends Control
## Title, character select, track select, and the class-race lobby (host
## shows a code; players type it in). Mouse, keyboard or gamepad.

const MAX_PLAYERS := 8

var title_font := load("res://assets/fonts/Almendra-Bold.ttf")
var body := load("res://assets/fonts/Andika-Bold.ttf")
var chunky := load("res://assets/fonts/LilitaOne-Regular.ttf")
var page: VBoxContainer
var after_char: Callable
var lobby_label: Label
var status_label: Label
var code_edit: LineEdit
var hello_sent := false


func _ready() -> void:
	Controls.setup()
	var bg := TextureRect.new()
	bg.texture = load("res://assets/images/title_bg.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.45, 0.45, 0.55)
	add_child(bg)
	page = VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 18)
	add_child(page)
	Net.opened.connect(_net_opened)
	Net.peer_joined.connect(_peer_joined)
	Net.peer_left.connect(_peer_left)
	Net.message.connect(_net_message)
	Net.failed.connect(_net_failed)
	if Game.mode == Game.Mode.HOST and Net.active:
		_lobby()  # back from a race: same lobby, same code
	elif Game.mode == Game.Mode.CLIENT and Net.active:
		_waiting()
	else:
		_title()


# ------------------------------------------------------------- building

func _clear() -> void:
	for c in page.get_children():
		c.queue_free()


func _text(t: String, font: Font, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", maxi(size / 7, 6))
	page.add_child(l)
	return l


func _button(t: String, on_press: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", chunky)
	b.add_theme_font_size_override("font_size", 40)
	b.custom_minimum_size = Vector2(560, 76)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.22, 0.85)
	sb.border_color = Color("f2c94c")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	b.add_theme_stylebox_override("normal", sb)
	var hi := sb.duplicate()
	hi.bg_color = Color(0.45, 0.3, 0.05, 0.95)
	hi.set_border_width_all(5)
	b.add_theme_stylebox_override("hover", hi)
	b.add_theme_stylebox_override("focus", hi)
	b.add_theme_stylebox_override("pressed", hi)
	b.pressed.connect(on_press)
	(parent if parent else page).add_child(b)
	return b


func _focus_first() -> void:
	await get_tree().process_frame
	for c in page.find_children("*", "Button", true, false):
		c.grab_focus()
		return


# ---------------------------------------------------------------- pages

func _title() -> void:
	_clear()
	Game.mode = Game.Mode.SOLO
	var logo := TextureRect.new()
	logo.texture = load("res://assets/images/logo.png")
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.custom_minimum_size = Vector2(900, 300)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(logo)
	_button("Solo Race", func(): _characters(_tracks))
	if Net.available():
		_button("Host a Class Race", func():
			Game.mode = Game.Mode.HOST
			_characters(_start_hosting))
		_button("Join a Class Race", _join_page)
	else:
		_text("Class races (up to 8 players) work in the browser version.", body, 26, Color(1, 1, 1, 0.7))
	_focus_first()


func _characters(next: Callable) -> void:
	_clear()
	after_char = next
	_text("Choose your racer", title_font, 64, Color("f2d27a"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	page.add_child(grid)
	var sheet: Texture2D = load("res://assets/images/portraits.png")
	for i in Content.characters.size():
		var c: Dictionary = Content.characters[i]
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 48, 0, 48, 48)
		var b := _button(c.name, func(): _picked(i), grid)
		b.icon = at
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 96)
		b.custom_minimum_size = Vector2(380, 130)
		b.add_theme_font_size_override("font_size", 32)
		b.tooltip_text = c.tag
	_text("Each racer drives a little differently. Pick anyone!", body, 26, Color(1, 1, 1, 0.75))
	_focus_first()


func _picked(ch: int) -> void:
	Game.my_char = ch
	after_char.call()


func _tracks() -> void:
	_clear()
	_text("Choose a scene", title_font, 64, Color("f2d27a"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	page.add_child(grid)
	for i in Content.tracks.size():
		var t: Dictionary = Content.tracks[i]
		var b := _button("%s\n%s" % [Content.acts[int(t.act)].name, t.name], func(): _track_picked(i), grid)
		b.custom_minimum_size = Vector2(420, 96)
		b.add_theme_font_size_override("font_size", 26)
	_focus_first()


func _track_picked(i: int) -> void:
	Game.track = i
	if Game.mode == Game.Mode.HOST:
		_lobby()
		_send_lobby()
	else:
		_go_race()


func _go_race() -> void:
	get_tree().change_scene_to_file("res://scenes/race.tscn")


# --------------------------------------------------------------- hosting

func _start_hosting() -> void:
	Game.code = Net.new_code()
	Game.players = [{"peer": "", "ch": Game.my_char}]
	Net.host(Game.code)
	_lobby()
	status_label.text = "Opening the race..."


func _lobby() -> void:
	_clear()
	if Game.players.is_empty():
		Game.players = [{"peer": "", "ch": Game.my_char}]
	_text("Class race code", body, 34, Color("f2d27a"))
	_text(" ".join(Game.code.split("")), chunky, 120, Color.WHITE)
	_text("Players go to this page, choose Join a Class Race and type the code.", body, 26, Color(1, 1, 1, 0.8))
	lobby_label = _text("", body, 30)
	status_label = _text("", body, 26, Color(1, 1, 1, 0.7))
	_button("Scene: %s" % Content.tracks[Game.track].name, _tracks)
	_button("Start the race", _host_start)
	_refresh_lobby()
	_focus_first()


func _refresh_lobby() -> void:
	if lobby_label == null or not is_instance_valid(lobby_label):
		return
	var lines := ["Players: %d of %d (computer racers fill the rest)" % [Game.players.size(), MAX_PLAYERS]]
	for i in Game.players.size():
		var who: String = Content.characters[Game.players[i].ch].name
		lines.append("P%d  %s%s" % [i + 1, who, "  (you, host)" if i == 0 else ""])
	lobby_label.text = "\n".join(lines)


func _net_opened(id: String) -> void:
	if Game.mode == Game.Mode.HOST:
		if status_label and is_instance_valid(status_label):
			status_label.text = "Ready: waiting for players."
	else:
		Game.code = Game.code  # (players) connected to the matchmaker; the host link opens next
		if status_label and is_instance_valid(status_label):
			status_label.text = "Finding the race..."


func _peer_joined(peer: String) -> void:
	if Game.mode == Game.Mode.CLIENT:
		Game.host_peer = peer
		Net.send(peer, {"k": "hello", "ch": Game.my_char})
		hello_sent = true
		_waiting()


func _peer_left(peer: String) -> void:
	if Game.mode == Game.Mode.HOST:
		Game.players = Game.players.filter(func(p): return p.peer != peer)
		_refresh_lobby()
		_send_lobby()
	elif peer == Game.host_peer:
		_lost("The host left the race.")


func _net_message(peer: String, d: Dictionary) -> void:
	if Game.mode == Game.Mode.HOST:
		if d.get("k") == "hello":
			if Game.players.size() >= MAX_PLAYERS:
				Net.send(peer, {"k": "full"})
				return
			Game.players = Game.players.filter(func(p): return p.peer != peer)
			Game.players.append({"peer": peer, "ch": int(d.ch)})
			_refresh_lobby()
			_send_lobby()
	else:
		match d.get("k"):
			"lobby":
				if status_label and is_instance_valid(status_label):
					status_label.text = "You're in! %d players. Scene: %s\nWaiting for the host to start." % [int(d.n), Content.tracks[int(d.track)].name]
			"full":
				_lost("That race is full (8 players).")
			"start":
				Game.track = int(d.track)
				Game.race_class = int(d.cls)
				Game.kart_chars = d.chars
				Game.kart_peers = d.peers
				Game.my_kart = int(d.you)
				_go_race()


func _send_lobby() -> void:
	if Game.mode == Game.Mode.HOST and Net.active:
		Net.broadcast({"k": "lobby", "n": Game.players.size(), "track": Game.track})


## The grid: CPUs at the front, players at the back, everyone gets a kart.
func _host_start() -> void:
	var chars := []
	var peers := []
	var cpu_chars := range(8)
	cpu_chars.shuffle()
	for i in MAX_PLAYERS - Game.players.size():
		chars.append(cpu_chars[i])
		peers.append(null)
	for p in Game.players:
		chars.append(p.ch)
		peers.append(p.peer)
	Game.kart_chars = chars
	Game.kart_peers = peers
	Game.my_kart = peers.find("")
	for i in peers.size():
		if peers[i] is String and peers[i] != "":
			Net.send(peers[i], {"k": "start", "track": Game.track, "cls": Game.race_class, "chars": chars, "peers": peers, "you": i})
	_go_race()


# --------------------------------------------------------------- joining

func _join_page() -> void:
	_clear()
	Game.mode = Game.Mode.CLIENT
	_text("Type the class race code", title_font, 60, Color("f2d27a"))
	code_edit = LineEdit.new()
	code_edit.max_length = 5
	code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_edit.add_theme_font_override("font", chunky)
	code_edit.add_theme_font_size_override("font_size", 90)
	code_edit.custom_minimum_size = Vector2(520, 130)
	code_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	code_edit.placeholder_text = "ABCDE"
	code_edit.text_submitted.connect(func(_t): _join_go())
	page.add_child(code_edit)
	_button("Next: choose your racer", _join_go)
	_button("Back", _title)
	status_label = _text("", body, 26, Color(1, 1, 1, 0.7))
	await get_tree().process_frame
	code_edit.grab_focus()


func _join_go() -> void:
	var c := code_edit.text.strip_edges().to_upper()
	if c.length() != 5:
		status_label.text = "The code has 5 letters and numbers."
		return
	Game.code = c
	_characters(func():
		_waiting()
		status_label.text = "Connecting..."
		Net.join(Game.code))


func _waiting() -> void:
	_clear()
	_text("Class race %s" % Game.code, title_font, 64, Color("f2d27a"))
	_text("You're %s." % Content.characters[Game.my_char].name, body, 34)
	status_label = _text("Connected: waiting for the host to start." if hello_sent else "Connecting...", body, 30)
	_button("Leave", func():
		Net.close()
		hello_sent = false
		_title())
	_focus_first()


func _net_failed(why: String) -> void:
	if Game.mode == Game.Mode.CLIENT and not hello_sent:
		_lost("Couldn't find that race (%s). Check the code with your teacher." % why)
	elif status_label and is_instance_valid(status_label):
		status_label.text = "Network problem: %s" % why


func _lost(why: String) -> void:
	Net.close()
	hello_sent = false
	_clear()
	_text(why, body, 36)
	_button("OK", _title)
	_focus_first()
