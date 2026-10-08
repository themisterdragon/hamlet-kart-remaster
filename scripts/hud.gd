class_name Hud
extends CanvasLayer
## The race HUD, kept clean: lap and time up top, place in the corner, the
## countdown, and the quiz panel only while a question is up.

const ARROWS := ["▲", "▶", "▼", "◀"]
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
var shown_q := ""


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
	for i in 4:
		var a := _label(body, 32, Color.WHITE)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a.custom_minimum_size = Vector2(280, 0)
		a_labels.append(a)
	# up / left, right / down, in a diamond
	var cells := [null, a_labels[0], null, a_labels[3], null, a_labels[1], null, a_labels[2], null]
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
		count_label.text = "Finish!"

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
		a_labels[i].text = "%s %s%s" % [ARROWS[i], k.question.answers[i], mark]
		a_labels[i].add_theme_color_override("font_color", col)
