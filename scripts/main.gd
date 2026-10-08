extends Control
## Milestone 0: proves the content loads and the quiz reads well at PC size.
## Page Up/Down picks a track, the D-pad (or arrow keys) answers, Enter deals the next question.

const DIRS := ["ui_up", "ui_right", "ui_down", "ui_left"]
const ARROWS := ["▲", "▶", "▼", "◀"]

var track := 8  # Act III first: it sets the standard
var q_index := 0
var card: Dictionary
var answered := -1

var title_font := load("res://assets/fonts/Almendra-Bold.ttf")
var body_font := load("res://assets/fonts/Andika-Bold.ttf")
var heading: Label
var question: Label
var buttons: Array[Label] = []


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b2440")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	add_child(box)

	heading = _label(title_font, 56, Color("f2d27a"))
	question = _label(body_font, 44, Color.WHITE)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size.x = 1400
	box.add_child(heading)
	box.add_child(question)
	for i in 4:
		var b := _label(body_font, 38, Color.WHITE)
		buttons.append(b)
		box.add_child(b)
	_deal()


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _deal() -> void:
	var t: Dictionary = Content.tracks[track]
	var act: Dictionary = Content.acts[int(t.act)]
	heading.text = "%s · %s · %s" % [act.name, t.scenes, t.name]
	card = Content.deal(track, q_index)
	answered = -1
	question.text = card.q
	for i in 4:
		buttons[i].text = "%s  %s" % [ARROWS[i], card.answers[i]]
		buttons[i].add_theme_color_override("font_color", Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		q_index = (q_index + 1) % Content.tracks[track].questions.size()
		_deal()
	elif event.is_action_pressed("ui_page_down") or event.is_action_pressed("ui_page_up"):
		var step := 1 if event.is_action_pressed("ui_page_down") else -1
		track = posmod(track + step, Content.tracks.size())
		q_index = 0
		_deal()
	elif answered < 0:
		for i in 4:
			if event.is_action_pressed(DIRS[i]):
				answered = i
				# the right answer always turns green, so a miss still teaches
				# (a tick and cross too, never colour alone)
				buttons[card.correct].add_theme_color_override("font_color", Color("6fdc8c"))
				buttons[card.correct].text += "  ✓"
				if i != card.correct:
					buttons[i].add_theme_color_override("font_color", Color("ff8a80"))
					buttons[i].text += "  ✗"
