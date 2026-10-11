class_name Hud
extends CanvasLayer
## The race HUD, kept clean: lap and time up top, place in the corner, the
## countdown, and the quiz panel only while a question is up.

const PLACE_COLOURS := ["f2c94c", "d8dde6", "d79a5a"]  # gold, silver, bronze; then white
const ORDINAL := ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"]

var laps := 4
var title := load("res://assets/fonts/Almendra-Bold.ttf")
var chunky := load("res://assets/fonts/LilitaOne-Regular.ttf")
var body := load("res://assets/fonts/Andika-Bold.ttf")

var lap_label: Label
var time_label: Label
var place_label: Label
var count_label: Label
var card: VBoxContainer
var panel: PanelContainer
var q_label: Label
var a_labels: Array[Label] = []
var a_arrows: Array[DpadArrow] = []
var a_cells: Array[PanelContainer] = []
const BOX_IDLE := Color("1b2448")
const BOX_RIGHT := Color("1e7a3c")   # white text on it: 5.4:1
const BOX_WRONG := Color("a8323a")   # white text on it: 6.3:1
var shown_q := ""
var touch_layout := false  # place moved clear of the touch buttons
var quiz_touch := false    # answers in a column on the left (phones)
var grid: GridContainer    # the answers as a D-pad diamond
var column: VBoxContainer  # the answers in a column
var quiz_open := false
var results_up := false
var item_box: PanelContainer
var item_icon: TextureRect
var item_tex: Array[Texture2D] = []
var overlay: PanelContainer
var overlay_text: Label
var overlay_buttons: HBoxContainer
signal choice(what: String)  # a tapped overlay button: resume, restart, next, menu, lobby


func setup(content_track: Dictionary, lap_count: int) -> void:
	laps = lap_count
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	lap_label = _label(chunky, 54, Color.WHITE)
	lap_label.position = Vector2(48, 32)
	root.add_child(lap_label)
	time_label = _label(chunky, 44, Color.WHITE)
	time_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.position = Vector2(-348, 36)
	time_label.size = Vector2(300, 60)
	root.add_child(time_label)
	place_label = _label(chunky, 120, Color.WHITE)
	place_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place_label.position = Vector2(-348, -190)
	place_label.size = Vector2(300, 150)
	root.add_child(place_label)
	count_label = _label(chunky, 220, Color("f2c94c"))
	count_label.set_anchors_preset(Control.PRESET_CENTER)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.position = Vector2(-300, -260)
	count_label.size = Vector2(600, 260)
	root.add_child(count_label)

	# the item slot: top centre, a gold frame with the item inside
	for i in 7:
		item_tex.append(load("res://assets/images/items/%02d.png" % i))
	item_box = PanelContainer.new()
	var ib := StyleBoxFlat.new()
	ib.bg_color = Color(0.06, 0.08, 0.16, 0.55)
	ib.border_color = Color("f2c94c")
	ib.set_border_width_all(5)
	ib.set_corner_radius_all(16)
	ib.set_content_margin_all(10)
	item_box.add_theme_stylebox_override("panel", ib)
	item_icon = TextureRect.new()
	item_icon.custom_minimum_size = Vector2(96, 96)
	item_box.custom_minimum_size = Vector2(120, 120)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	item_box.add_child(item_icon)
	root.add_child(item_box)
	item_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 28)
	item_box.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# the title card: scene and name, on the grid before GO
	card = VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-700, 150)
	card.size = Vector2(1400, 200)
	var scene := _label(body, 36, Color("f2d27a"))
	scene.text = "%s · %s" % [Content.acts[int(content_track.act)].name, content_track.scenes]
	var name := _label(title, 84, Color.WHITE)
	name.text = content_track.name
	for l in [scene, name]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
	root.add_child(card)

	# the quiz: the question, then each answer in its own box, laid out like
	# the D-pad (up, left, right, down). The kart drives itself meanwhile, so
	# it can take room; it sits clear of the screen's bottom edge (phones'
	# home bars) and the boxes are big enough to tap.
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.7)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	q_label = _label(body, 40, Color.WHITE)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.custom_minimum_size.x = 1100
	box.add_child(q_label)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	for i in 4:
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_STOP  # click or tap an answer
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				Controls.touch.answer = i)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arrow := DpadArrow.new(i, 30)
		var a := _label(body, 40, Color.WHITE)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(arrow)
		row.add_child(a)
		cell.add_child(row)
		a_arrows.append(arrow)
		a_labels.append(a)
		a_cells.append(cell)
	box.add_child(grid)
	column = VBoxContainer.new()  # (phones) the same boxes in a column, for the left thumb
	column.add_theme_constant_override("separation", 12)
	box.add_child(column)
	panel.add_child(box)
	panel.visible = false
	root.add_child(panel)
	_quiz_layout()

	# pause and results: one centred panel
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = PanelContainer.new()
	var ob := sb.duplicate()
	ob.bg_color = Color(0.06, 0.08, 0.16, 0.86)
	ob.content_margin_left = 64
	ob.content_margin_right = 64
	ob.content_margin_top = 36
	ob.content_margin_bottom = 36
	overlay.add_theme_stylebox_override("panel", ob)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 14)
	overlay.add_child(ov)
	overlay_text = _label(body, 38, Color.WHITE)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(overlay_text)
	overlay_buttons = HBoxContainer.new()  # tappable choices, for phones
	overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_buttons.add_theme_constant_override("separation", 16)
	ov.add_child(overlay_buttons)
	overlay.visible = false
	root.add_child(overlay)
	_intro_nodes()


## The quiz panel's two shapes. Pad and keyboard: a D-pad diamond in the
## middle, arrows showing which way picks which. Phones: one column at the
## bottom left, where the left thumb rests (the steering buttons step aside),
## so the right thumb can keep holding gas.
func _quiz_layout() -> void:
	quiz_touch = Controls.touch_mode
	var slots := [0, 3, 1, 2] if quiz_touch else []  # up, left, right, down as read down the column
	for i in 4:
		var cell := a_cells[i]
		if cell.get_parent():
			cell.get_parent().remove_child(cell)
		a_arrows[i].visible = not quiz_touch
	for c in grid.get_children():
		c.queue_free()
	grid.visible = not quiz_touch
	column.visible = quiz_touch
	if quiz_touch:
		for i in slots:
			a_cells[i].custom_minimum_size = Vector2(820, 104)
			a_cells[i].pivot_offset = Vector2(410, 52)
			column.add_child(a_cells[i])
		q_label.custom_minimum_size.x = 820
		q_label.add_theme_font_size_override("font_size", 36)
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 32)
		panel.grow_horizontal = Control.GROW_DIRECTION_END
	else:
		# up / left, right / down, in a diamond
		for c in [null, a_cells[0], null, a_cells[3], null, a_cells[1], null, a_cells[2], null]:
			if c:
				c.custom_minimum_size = Vector2(470, 120)  # (about 50 points tall on a phone)
				c.pivot_offset = Vector2(235, 60)
			grid.add_child(c if c else Control.new())
		q_label.custom_minimum_size.x = 1100
		q_label.add_theme_font_size_override("font_size", 40)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.reset_size()


## Phones: an answer tapped by any finger. (Godot only turns the first finger
## into a mouse click, and that finger is often on the gas.)
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and quiz_open:
		for i in 4:
			if a_cells[i].is_visible_in_tree() and a_cells[i].get_global_rect().has_point(event.position):
				Controls.touch.answer = i
				get_viewport().set_input_as_handled()
				return


# ------------------------------------------------ the opening flyover

var intro_box: VBoxContainer
var intro_name: Label
var intro_count: Label
var intro_skip: Label
var fade: ColorRect


func _intro_nodes() -> void:
	fade = ColorRect.new()  # dips to black between shots
	fade.color = Color(0.02, 0.02, 0.06, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	intro_box = VBoxContainer.new()  # the landmark's name, low on the screen like a film title
	intro_box.add_theme_constant_override("separation", -6)
	intro_count = _label(body, 30, Color("f2d27a"))
	intro_name = _label(title, 92, Color.WHITE)
	for l in [intro_count, intro_name]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intro_box.add_child(l)
	add_child(intro_box)
	intro_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 110)
	intro_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	intro_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	intro_skip = _label(body, 28, Color(1, 1, 1, 0.75))
	add_child(intro_skip)
	intro_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	intro_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	intro_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	set_intro(false)


## The flyover: the race HUD steps aside for the scene's title and each
## landmark's name.
func set_intro(on: bool) -> void:
	for n in [lap_label, time_label, place_label, item_box, count_label]:
		n.visible = not on
	intro_box.visible = on
	intro_skip.visible = on
	intro_skip.text = "%s  Skip" % ("Tap" if Controls.touch_mode else Controls.glyph("accept"))
	if not on:
		fade.color.a = 0


## One frame of the flyover: which landmark (shot of shots) and how far into
## its shot (0-1); the name slides in and the picture dips to black at the cuts.
func show_intro(name: String, shot: int, shots: int, u: float, dark: float) -> void:
	intro_count.text = "Landmark %d of %d" % [shot + 1, shots]
	intro_name.text = name
	var a := clampf(minf(u * 5.0, (1.0 - u) * 6.0), 0, 1)
	intro_box.modulate.a = a
	intro_name.position.x = (1.0 - a) * -40
	fade.color.a = dark


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", maxi(size / 7, 6))
	return l


func show_state(k: Kart, countdown: float, time: float, racers: int) -> void:
	lap_label.text = "Lap %d/%d" % [clampi(k.lap + 1, 1, laps), laps]
	time_label.text = "%d:%05.2f" % [int(time) / 60, fmod(time, 60)]
	if Controls.touch_mode != touch_layout:  # phones: the place goes top left, clear of the buttons
		touch_layout = Controls.touch_mode
		if touch_layout:
			place_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
			place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			place_label.position = Vector2(48, 90)
		else:
			place_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			place_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			place_label.position = Vector2(-348, -190)
	var p := clampi(k.place, 1, racers)
	place_label.text = ORDINAL[p - 1]
	place_label.add_theme_color_override("font_color", Color(PLACE_COLOURS[p - 1]) if p <= 3 else Color.WHITE)
	card.visible = countdown > 1.0
	if countdown > 0:
		count_label.text = str(ceili(countdown)) if countdown < 3.0 else ""
	elif countdown > -1.0 and time < 1.0:
		count_label.text = "GO!"
	else:
		count_label.text = ""
	if k.finished:
		count_label.text = "" if results_up else "Finish!"

	# the item: spins through the icons while the box decides, dims while held
	if k.roulette_t > 0:
		item_icon.texture = item_tex[int(k.roulette_t * 14) % item_tex.size()]
		item_icon.modulate = Color(1, 1, 1, 0.8)
	elif k.item >= 0:
		item_icon.texture = item_tex[k.item]
		item_icon.modulate = Color(1, 1, 1, 0.5) if k.holding else Color.WHITE
	else:
		item_icon.texture = null
	card.position.y = 40 if intro_box.visible else 190  # below the item slot (none in the flyover)

	var asking := k.asking or k.verdict_t > 0
	if Controls.touch_mode != quiz_touch:
		_quiz_layout()
	panel.visible = asking
	quiz_open = k.asking
	if not asking:
		shown_q = ""
		return
	if shown_q != k.question.q:
		shown_q = k.question.q
		q_label.text = k.question.q
		for c in a_cells:  # the boxes pop in
			c.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 4:
		var mark := ""
		var fill := BOX_IDLE
		var text := Color.WHITE
		var edge := Color("f2c94c")
		if not k.asking:  # the verdict: the right answer always shows, with a tick
			if i == k.question.correct:
				mark = "  ✓"
				fill = BOX_RIGHT
			elif i == k.answered:
				mark = "  ✗"
				fill = BOX_WRONG
			else:
				text = Color("b8bcc8")  # set aside, still readable (9:1)
				edge = Color("3a4060")
		a_labels[i].text = "%s%s" % [k.question.answers[i], mark]
		a_labels[i].add_theme_color_override("font_color", text)
		a_arrows[i].color = text
		var st := StyleBoxFlat.new()
		st.bg_color = fill
		st.border_color = edge
		st.set_border_width_all(4)
		st.set_corner_radius_all(18)
		st.set_content_margin_all(12)
		a_cells[i].add_theme_stylebox_override("panel", st)


func _show_overlay(text: String, choices: Array = []) -> void:
	overlay_text.text = text
	for c in overlay_buttons.get_children():
		c.queue_free()
	if Controls.touch_mode:
		for c in choices:
			var b := Button.new()
			b.text = c[0]
			b.add_theme_font_override("font", chunky)
			b.add_theme_font_size_override("font_size", 40)
			b.custom_minimum_size = Vector2(260, 90)
			UiKit.style_button(b)
			b.focus_mode = Control.FOCUS_NONE  # (tapped, not chosen)
			b.pressed.connect(func(): choice.emit(c[1]))
			overlay_buttons.add_child(b)
	overlay.visible = true
	overlay.reset_size()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _quit_hint() -> String:
	return "" if OS.has_feature("web") or Controls.style() != "keys" else "\nQ  Quit"


func show_pause(on: bool) -> void:
	if not on:
		overlay.visible = false
		return
	if Controls.touch_mode:
		_show_overlay("Paused", [["Resume", "resume"], ["Restart", "restart"], ["Menu", "menu"]])
	else:
		var help := ["", "Controls (controller · keyboard)"]
		for r in Controls.table().slice(0, 6):
			help.append("%s:  %s  ·  %s" % r)
		_show_overlay("Paused\n\n%s  Resume\n%s  Restart race\n%s  Menu" % [Controls.glyph("accept"), Controls.glyph("restart"), Controls.glyph("menu")] + _quit_hint() + "\n".join(help))


func show_results(karts: Array, me: Kart) -> void:
	results_up = true
	panel.visible = false
	var order := karts.duplicate()
	order.sort_custom(func(a, b): return a.place < b.place)
	var lines := ["Results", ""]
	for k in order:
		var who: String = Content.characters[k.ch].name
		var t := "%d:%05.2f" % [int(k.finish_time) / 60, fmod(k.finish_time, 60)] if k.finished else "—"
		lines.append(("%s   %s   %s" % [ORDINAL[k.place - 1], who, t]) + ("   (you)" if k == me else ""))
	lines.append("")
	lines.append("Questions right: %d of %d" % [me.right, me.right + me.wrong])
	lines.append("")
	if Game.mode == Game.Mode.HOST and Net.active:
		lines.append("%s  Back to the lobby" % Controls.glyph("accept"))
	elif Game.mode == Game.Mode.CLIENT and Net.active:
		lines.append("Waiting for the host to pick the next scene...")
	else:
		lines.append("%s  Next scene\n%s  Race again\n%s  Menu" % [Controls.glyph("accept"), Controls.glyph("restart"), Controls.glyph("menu")] + _quit_hint())
	var choices := []
	if Game.mode == Game.Mode.HOST and Net.active:
		choices = [["Back to the lobby", "lobby"]]
	elif not Net.active:
		choices = [["Next scene", "next"], ["Race again", "restart"], ["Menu", "menu"]]
	if Controls.touch_mode:
		lines.resize(lines.size() - 1)  # the buttons say it
	_show_overlay("\n".join(lines), choices)
