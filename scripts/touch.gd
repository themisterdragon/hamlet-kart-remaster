class_name TouchControls
extends CanvasLayer
## Phone and tablet controls: Godot's multi-touch buttons press the same
## actions as the keyboard and gamepad, so steering, gas (and the rocket
## start), drift, items and pause all work the same way. Shown after the
## first touch; hidden again by keys or a pad. Quiz answers are tapped in
## the quiz panel (scripts/hud.gd).
##
## Accessible by design: large targets (the smallest is about 2x the 44 px
## minimum on a phone), white text on solid navy (over 12:1), a gold rim
## that stands out on any road, a text label on every button, and a
## pressed state shown by fill and size, not by colour alone.

const NAVY := Color("141a33")
const GOLD := Color("f2c94c")
const PRESSED := Color("f2c94c")

var root: Node2D
var pads: Array = []  # [{button, label, name, radius}]
var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")


func _ready() -> void:
	layer = 5
	root = Node2D.new()
	add_child(root)
	# name, icon, label, action, radius
	for b in [
		["left", "◀", "LEFT", "p0_left", 125.0], ["right", "▶", "RIGHT", "p0_right", 125.0],
		["gas", "▲", "GAS", "p0_gas", 140.0], ["brake", "▼", "BRAKE", "p0_brake", 92.0],
		["drift", "⭮", "DRIFT", "p0_drift", 105.0], ["item", "★", "ITEM", "p0_item", 98.0],
		["pause", "II", "PAUSE", "ui_cancel", 62.0],
	]:
		_make(b[0], b[1], b[2], b[3], b[4])
	visible = Controls.touch_mode
	get_viewport().size_changed.connect(_layout)
	_layout()


func _make(name: String, icon: String, text: String, action: String, r: float) -> void:
	var tb := TouchScreenButton.new()
	tb.texture_normal = _disc(r, false)
	tb.texture_pressed = _disc(r, true)
	var shape := CircleShape2D.new()
	shape.radius = r * 1.1  # a little forgiving at the edges
	tb.shape = shape
	tb.shape_centered = true
	tb.action = action
	tb.passby_press = name in ["left", "right"]  # slide a thumb between the steering buttons
	# a big icon over a clear word (the word is the label, never the icon alone)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size = Vector2(r * 2, r * 2)
	box.add_theme_constant_override("separation", -int(r * 0.08))
	tb.add_child(box)
	var labels: Array[Label] = []
	for part in ([[icon, 0.62], [text, 0.27]] if r > 70 else [[icon, 0.7]]):
		var l := Label.new()
		l.text = part[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", int(r * part[1]))
		l.add_theme_color_override("font_color", Color.WHITE)
		box.add_child(l)
		labels.append(l)
	var label := labels
	tb.pressed.connect(func(): _press(label, true))
	tb.released.connect(func(): _press(label, false))
	root.add_child(tb)
	pads.append({"button": tb, "labels": label, "name": name, "radius": r})


func _press(labels: Array[Label], down: bool) -> void:
	for l in labels:
		l.add_theme_color_override("font_color", NAVY if down else Color.WHITE)


## A round button face: navy with a gold rim; pressed, gold and a touch smaller.
func _disc(r: float, pressed: bool) -> Texture2D:
	var n := int(r * 2)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(r, r)
	var rim := maxf(6.0, r * 0.07)
	var shrink := r * 0.06 if pressed else 0.0
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) + shrink
			var a := clampf(r - d, 0, 1)  # antialiased edge
			if a <= 0:
				continue
			var col: Color
			if d > r - rim:
				col = GOLD if not pressed else Color.WHITE
			else:
				col = PRESSED if pressed else NAVY
				col.a = 1.0  # solid, so the button never blends into a dark road
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	return ImageTexture.create_from_image(img)


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var at := {
		"left": Vector2(175, s.y - 185), "right": Vector2(455, s.y - 185),
		"gas": Vector2(s.x - 195, s.y - 200), "brake": Vector2(s.x - 175, s.y - 505),
		"drift": Vector2(s.x - 470, s.y - 140), "item": Vector2(s.x - 440, s.y - 380),
		"pause": Vector2(s.x - 90, 165),
	}
	for p in pads:
		p.button.position = at[p.name] - Vector2(p.radius, p.radius)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not Controls.touch_mode:
		Controls.touch_mode = true
		visible = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and Controls.touch_mode:
		Controls.touch_mode = false
		visible = false
