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
	Sound.race_over()
	Sound.music("title")
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
	b.pressed.connect(func():
		Sound.sfx("select")
		on_press.call())
	b.focus_entered.connect(func(): Sound.sfx("move", 1.0, -8))
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
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	page.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	row.add_child(grid)
	var sheet: Texture2D = load("res://assets/images/portraits.png")
	for i in Content.characters.size():
		var c: Dictionary = Content.characters[i]
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 48, 0, 48, 48)
		var b := _button(c.name, func(): _picked(i), grid)
		b.icon = at
		b.expand_icon = true
		b.custom_minimum_size = Vector2(340, 104)
		b.add_theme_font_size_override("font_size", 32)
		b.focus_entered.connect(func(): _preview(i))
		b.mouse_entered.connect(func(): b.grab_focus())
	row.add_child(_preview_panel())
	_focus_first()


# ------------------------------------------------- the 3D racer preview

var pv_root: Node3D
var pv_model: Node3D
var pv_name: Label
var pv_tag: Label
var pv_stats: Label


func _preview_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(560, 470)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(vp)
	pv_root = Node3D.new()
	vp.add_child(pv_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9a98b0")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	pv_root.add_child(we)
	var key := DirectionalLight3D.new()  # a warm key light and a cool rim, like a studio portrait
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_color = Color("fff0d8")
	key.shadow_enabled = true
	pv_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_color = Color("9ab8ff")
	rim.light_energy = 0.7
	pv_root.add_child(rim)
	var podium := MeshInstance3D.new()  # a gold-rimmed podium to turn on
	var cyl := CylinderMesh.new()
	cyl.top_radius = 34
	cyl.bottom_radius = 36
	cyl.height = 6
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("3a2a5a")
	pm.roughness = 0.4
	cyl.material = pm
	podium.mesh = cyl
	podium.position.y = -3
	pv_root.add_child(podium)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 36, 96)
	cam.fov = 40
	pv_root.add_child(cam)
	cam.look_at(Vector3(0, 16, 0))
	box.add_child(vpc)
	pv_name = _label_in(box, title_font, 54, Color("f2d27a"))
	pv_tag = _label_in(box, body, 28, Color(1, 1, 1, 0.85))
	pv_stats = _label_in(box, body, 28, Color.WHITE)
	return box


func _label_in(parent: Node, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _preview(ch: int) -> void:
	if pv_model and is_instance_valid(pv_model):
		pv_model.queue_free()
	pv_model = Cast.model(ch)
	if pv_model:
		pv_root.add_child(pv_model)
	var c: Dictionary = Content.characters[ch]
	pv_name.text = c.name
	pv_tag.text = c.tag
	# the racer's real handling numbers (Kart.STATS), as 1-5 dots
	var st: Array = Kart.STATS[ch]
	var ranges := [[0.96, 1.05], [0.80, 1.14], [0.88, 1.15], [0.7, 1.3]]
	var names := ["Speed", "Pickup", "Handling", "Weight"]
	var lines := []
	for i in 4:
		var r: Array = ranges[i]
		var dots := clampi(1 + roundi((st[i] - r[0]) / (r[1] - r[0]) * 4), 1, 5)
		lines.append("%s  %s" % [names[i], "●".repeat(dots) + "○".repeat(5 - dots)])
	pv_stats.text = "\n".join(lines)


func _process(delta: float) -> void:
	if pv_model and is_instance_valid(pv_model):
		pv_model.rotation.y += delta * 0.9


func _picked(ch: int) -> void:
	Game.my_char = ch
	Sound.voice(ch, Sound.LINE_SELECT)
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
	# an on-screen keyboard, for controllers (and touch): the code's own letters
	var keys := GridContainer.new()
	keys.columns = 8
	keys.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keys.add_theme_constant_override("h_separation", 8)
	keys.add_theme_constant_override("v_separation", 8)
	page.add_child(keys)
	var first: Button = null
	for ch in Net.CODE_CHARS:
		var k := _button(ch, func():
			if code_edit.text.length() < 5:
				code_edit.text += ch, keys)
		k.custom_minimum_size = Vector2(84, 64)
		if first == null:
			first = k
	var del := _button("⌫", func(): code_edit.text = code_edit.text.left(-1), keys)
	del.custom_minimum_size = Vector2(84, 64)
	_button("Next: choose your racer", _join_go)
	_button("Back", _title)
	status_label = _text("Type the code, or pick the letters with %s." % Controls.glyph("accept"), body, 26, Color(1, 1, 1, 0.7))
	await get_tree().process_frame
	if Controls.style() == "keys":
		code_edit.grab_focus()
	else:
		first.grab_focus()


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


## Circle / B / Esc goes back to the title (not from inside a lobby).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not Net.active:
		Sound.sfx("move")
		_title()
