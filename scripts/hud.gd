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
var shown_q := ""
var results_up := false
var item_box: PanelContainer
var item_icon: TextureRect
var item_tex: Array[Texture2D] = []
var overlay: PanelContainer
var overlay_text: Label


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

	# the quiz panel: see-through, bottom centre; answers sit like the D-pad
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.62)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	q_label = _label(body, 36, Color.WHITE)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.custom_minimum_size.x = 900
	box.add_child(q_label)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	var rows: Array[HBoxContainer] = []
	for i in 4:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(280, 0)
		row.add_theme_constant_override("separation", 10)
		var arrow := DpadArrow.new(i, 22)
		var a := _label(body, 32, Color.WHITE)
		row.add_child(arrow)
		row.add_child(a)
		a_arrows.append(arrow)
		a_labels.append(a)
		rows.append(row)
	# up / left, right / down, in a diamond
	var cells := [null, rows[0], null, rows[3], null, rows[1], null, rows[2], null]
	for c in cells:
		grid.add_child(c if c else Control.new())
	box.add_child(grid)
	panel.add_child(box)
	panel.visible = false
	root.add_child(panel)
	# bottom centre, just its own size, below the player's kart
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

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
	overlay_text = _label(body, 38, Color.WHITE)
	overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_text)
	overlay.visible = false
	root.add_child(overlay)


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
	card.position.y = 190  # below the item slot

	var asking := k.asking or k.verdict_t > 0
	panel.visible = asking
	if not asking:
		shown_q = ""
		return
	if shown_q != k.question.q:
		shown_q = k.question.q
		q_label.text = k.question.q
	for i in 4:
		var mark := ""
		var col := Color.WHITE
		if not k.asking:  # the verdict: the right answer always shows, with a tick
			if i == k.question.correct:
				mark = "  ✓"
				col = Color("6fdc8c")
			elif i == k.answered:
				mark = "  ✗"
				col = Color("ff8a80")
			else:
				col = Color(1, 1, 1, 0.45)
		a_labels[i].text = "%s%s" % [k.question.answers[i], mark]
		a_labels[i].add_theme_color_override("font_color", col)
		a_arrows[i].color = col


func _show_overlay(text: String) -> void:
	overlay_text.text = text
	overlay.visible = true
	overlay.reset_size()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _quit_hint() -> String:
	return "" if OS.has_feature("web") else "\nQ  Quit"


func show_pause(on: bool) -> void:
	if not on:
		overlay.visible = false
		return
	_show_overlay("Paused\n\nEnter / Start  Resume\nR / Y  Restart race" + _quit_hint())


func show_results(karts: Array, me: Kart) -> void:
	results_up = true
	panel.visible = false
	var order := karts.duplicate()
	order.sort_custom(func(a, b): return a.place < b.place)
	var lines := ["Results", ""]
	for k in order:
		var who: String = Content.characters[k.ch].name
		var t := "%d:%05.2f" % [int(k.finish_time) / 60, fmod(k.finish_time, 60)] if k.finished else "—"
		lines.append(("%s   %s   %s" % [ORDINAL[k.place - 1], who, t]) + ("   ◀ you" if k == me else ""))
	lines.append("")
	lines.append("Questions right: %d of %d" % [me.right, me.right + me.wrong])
	lines.append("")
	if Game.mode == Game.Mode.HOST and Net.active:
		lines.append("Enter / Start  Back to the lobby")
	elif Game.mode == Game.Mode.CLIENT and Net.active:
		lines.append("Waiting for the host to pick the next scene...")
	else:
		lines.append("Enter / Start  Next track\nR / Y  Race again\nM  Menu" + _quit_hint())
	_show_overlay("\n".join(lines))
