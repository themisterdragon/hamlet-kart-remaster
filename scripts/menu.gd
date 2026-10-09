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
	for arg in OS.get_cmdline_user_args():  # (test) straight to the garage: --garage=N
		if arg.begins_with("--garage="):
			_garage(int(arg.substr(9)))


# ------------------------------------------------------------- building

func _clear() -> void:
	in_garage = false
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
	var build := FileAccess.get_file_as_string("res://data/build.txt").strip_edges()
	if build != "":  # which build this is, to tell old cached copies apart
		var v := Label.new()
		v.text = "build " + build
		v.add_theme_font_override("font", body)
		v.add_theme_font_size_override("font_size", 22)
		v.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
		v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		v.grow_vertical = Control.GROW_DIRECTION_BEGIN
		add_child(v)
	_button("Solo Race", func(): _characters(_tracks))
	if Net.available():
		_button("Host a Class Race", func():
			Game.mode = Game.Mode.HOST
			_characters(_start_hosting))
		_button("Join a Class Race", _join_page)
	else:
		_text("Class races (up to 8 players) work in the browser version.", body, 26, Color(1, 1, 1, 0.7))
	_button("Controls", _controls_page)
	_focus_first()


## Every control, for a controller and the keyboard side by side (button
## names follow the controller that's plugged in).
func _controls_page() -> void:
	_clear()
	_text("Controls", title_font, 64, Color("f2d27a"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	var pad_name := "PlayStation controller" if Controls.style() == "ps" else "Controller"
	var rows: Array = [["", pad_name, "Keyboard"]] + Controls.table()
	for i in rows.size():
		for j in 3:
			var l := _label_in(grid, chunky if i == 0 else body, 30, Color("f2d27a") if i == 0 or j == 0 else Color.WHITE)
			l.text = rows[i][j]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if j == 0 else HORIZONTAL_ALIGNMENT_CENTER
	if Controls.touch_mode or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		_text("On a phone or tablet the buttons are on the screen; tap an answer to pick it.", body, 26, Color(1, 1, 1, 0.8))
	_text("While a question is up your kart drives itself, so the arrows (or D-pad) answer.", body, 26, Color(1, 1, 1, 0.8))
	_button("Back", _title)
	_focus_first()


var focus_char := 0  # the racer highlighted on character select


func _characters(next: Callable) -> void:
	_clear()
	if next.is_valid():
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
		b.focus_entered.connect(func():
			focus_char = i
			_preview(i))
		b.mouse_entered.connect(func(): b.grab_focus())
	var side := _preview_panel()
	row.add_child(side)
	var garage := _button("Build your kart", func(): _garage(focus_char), side)
	garage.custom_minimum_size = Vector2(420, 70)
	garage.add_theme_font_size_override("font_size", 32)
	await get_tree().process_frame
	var buttons := grid.get_children()
	if focus_char < buttons.size():
		buttons[focus_char].grab_focus()


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
	cam.fov = 40
	pv_root.add_child(cam)
	var eye := Vector3(0, 46, 128)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 19, 0) - eye), eye)  # (not in the tree yet)
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


func _preview(ch: int, b: Dictionary = {}) -> void:
	var angle := 0.0
	if pv_model and is_instance_valid(pv_model):
		angle = pv_model.rotation.y
		pv_model.queue_free()
	if b.is_empty():
		b = KartBuild.saved(ch)
	pv_model = KartRig.make(ch, b)
	pv_model.rotation.y = angle
	pv_root.add_child(pv_model)
	var c: Dictionary = Content.characters[ch]
	pv_name.text = c.name
	pv_tag.text = c.tag
	pv_stats.text = _stat_lines(ch, b)


## The racer's real handling with this build (KartBuild.stats) as 1-5 dots,
## with a + or - where the parts change it.
func _stat_lines(ch: int, b: Dictionary) -> String:
	var st := KartBuild.stats(ch, b)
	var base: Array = Kart.STATS[ch]
	var lines := []
	for i in 4:
		var d := KartBuild.dots(i, st[i])
		var change: float = st[i] / base[i]
		var mark := "  +" if change > 1.005 else ("  −" if change < 0.995 else "")
		lines.append("%s  %s%s" % [KartBuild.STAT_NAMES[i], "●".repeat(d) + "○".repeat(5 - d), mark])
	return "\n".join(lines)


# ---------------------------------------------------------------- garage

var g_ch := 0
var g_build: Dictionary
var g_rows := {}  # part -> its button
var g_note: Label
var in_garage := false


## Build your kart: body, wheels, hood ornament, paint and trim, each a row
## that ◀ ▶ (or a press) steps through; the stats change as you go.
func _garage(ch: int) -> void:
	_clear()
	g_ch = ch
	g_build = KartBuild.saved(ch)
	g_rows = {}
	in_garage = true
	_text("%s's kart" % Content.characters[ch].name, title_font, 60, Color("f2d27a"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	page.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	row.add_child(col)
	for part in ["body", "wheels", "orn", "paint", "trim"]:
		var b := _button("", func(): _step_part(part, 1), col)
		b.custom_minimum_size = Vector2(640, 76)
		b.add_theme_font_size_override("font_size", 32)
		b.gui_input.connect(func(e: InputEvent):
			if e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
				Sound.sfx("move")
				_step_part(part, -1 if e.is_action_pressed("ui_left") else 1)
				b.accept_event())
		g_rows[part] = b
	g_note = _label_in(col, body, 26, Color(1, 1, 1, 0.85))
	g_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g_note.custom_minimum_size = Vector2(640, 70)
	_button("Race with this kart", func():
		KartBuild.store(g_ch, g_build)
		_picked(g_ch), col)
	_button("Back to the racers", func():
		KartBuild.store(g_ch, g_build)
		focus_char = g_ch
		_characters(Callable()), col)
	_button("Their own kart", func():
		g_build = KartBuild.own(g_ch)
		_garage_show(), col)
	row.add_child(_preview_panel())
	_garage_show()
	await get_tree().process_frame
	g_rows.body.grab_focus()


func _step_part(part: String, d: int) -> void:
	var b := g_build
	match part:
		"body", "wheels":
			var list: Array = KartBuild.BODIES if part == "body" else KartBuild.WHEELS
			var ids := list.map(func(p): return p[0])
			b[part] = ids[posmod(ids.find(b[part]) + d, ids.size())]
		"orn":
			b.orn = posmod(int(b.orn) + 1 + d, 9) - 1  # -1 (none), then each racer's
		"paint", "trim":
			var own: String = KartBuild.own(g_ch)[part]
			var list: Array = [own] + (KartBuild.PAINTS if part == "paint" else KartBuild.TRIMS).filter(func(c): return c != own)
			b[part] = list[posmod(list.find(b[part]) + d, list.size())]
	_garage_show()


func _garage_show() -> void:
	var b := g_build
	var body_p := KartBuild.part(KartBuild.BODIES, b.body)
	var wheel_p := KartBuild.part(KartBuild.WHEELS, b.wheels)
	g_rows.body.text = "<   Body: %s   >" % body_p[1]
	g_rows.wheels.text = "<   Wheels: %s   >" % wheel_p[1]
	g_rows.orn.text = "<   Ornament: %s   >" % ("none" if int(b.orn) < 0 else Content.characters[int(b.orn)].name + "'s")
	g_rows.paint.text = "<   Paint   >"
	g_rows.trim.text = "<   Trim   >"
	for part in ["paint", "trim"]:  # a swatch of the colour on the button
		var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
		img.fill(Color(b[part]))
		for i in 40:  # a light edge so dark colours still show on the dark button
			for e in [0, 39]:
				img.set_pixel(i, e, Color.WHITE)
				img.set_pixel(e, i, Color.WHITE)
		g_rows[part].icon = ImageTexture.create_from_image(img)
	g_note.text = "%s: %s.  %s: %s." % [body_p[1], body_p[2], wheel_p[1], wheel_p[2]]
	_preview(g_ch, b)


func _process(delta: float) -> void:
	if pv_model and is_instance_valid(pv_model):
		pv_model.rotation.y += delta * 0.9


func _picked(ch: int) -> void:
	Game.my_char = ch
	focus_char = ch
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
	Game.players = [{"peer": "", "ch": Game.my_char, "kart": KartBuild.saved(Game.my_char)}]
	Net.host(Game.code)
	_lobby()
	status_label.text = "Opening the race..."


func _lobby() -> void:
	_clear()
	if Game.players.is_empty():
		Game.players = [{"peer": "", "ch": Game.my_char, "kart": KartBuild.saved(Game.my_char)}]
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
		Net.send(peer, {"k": "hello", "ch": Game.my_char, "kart": KartBuild.saved(Game.my_char)})
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
			var ch := clampi(int(d.ch), 0, 7)
			Game.players.append({"peer": peer, "ch": ch, "kart": KartBuild.clean(d.get("kart"), ch)})
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
				Game.kart_builds = d.get("builds", [])
				Game.my_kart = int(d.you)
				_go_race()


func _send_lobby() -> void:
	if Game.mode == Game.Mode.HOST and Net.active:
		Net.broadcast({"k": "lobby", "n": Game.players.size(), "track": Game.track})


## The grid: CPUs at the front, players at the back, everyone gets a kart.
func _host_start() -> void:
	var chars := []
	var peers := []
	var builds := []
	var cpu_chars := range(8)
	cpu_chars.shuffle()
	for i in MAX_PLAYERS - Game.players.size():
		chars.append(cpu_chars[i])
		peers.append(null)
		builds.append({})
	for p in Game.players:
		chars.append(p.ch)
		peers.append(p.peer)
		builds.append(p.get("kart", {}))
	Game.kart_chars = chars
	Game.kart_peers = peers
	Game.kart_builds = builds
	Game.my_kart = peers.find("")
	for i in peers.size():
		if peers[i] is String and peers[i] != "":
			Net.send(peers[i], {"k": "start", "track": Game.track, "cls": Game.race_class, "chars": chars, "peers": peers, "builds": builds, "you": i})
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
	if event.is_action_pressed("ui_cancel") and in_garage:
		Sound.sfx("move")
		KartBuild.store(g_ch, g_build)
		focus_char = g_ch
		_characters(Callable())
	elif event.is_action_pressed("ui_cancel") and not Net.active:
		Sound.sfx("move")
		_title()
