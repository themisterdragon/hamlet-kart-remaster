class_name TouchControls
extends CanvasLayer
## Phone and tablet controls: a thumbstick on the left half (put a thumb
## down anywhere and slide), automatic gas, and Drift, Item and Brake on
## the right. Shown after the first touch; hidden again by keys or a pad.
## Quiz answers are tapped in the quiz panel (scripts/hud.gd).

signal pause_pressed

const STICK_RANGE := 110.0  # pixels of slide for full lock (in the 1920x1080 layout)

var stick_id := -1          # the finger on the stick
var stick_origin := Vector2.ZERO
var stick_now := Vector2.ZERO
var held := {}              # button name -> finger
var buttons := {}           # button name -> {centre, radius, label}
var root: Control


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_controls)
	add_child(root)
	visible = Controls.touch_mode
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := root.get_viewport_rect().size
	buttons = {
		"drift": {"c": Vector2(s.x - 170, s.y - 190), "r": 105.0, "t": "DRIFT"},
		"item": {"c": Vector2(s.x - 380, s.y - 120), "r": 85.0, "t": "ITEM"},
		"brake": {"c": Vector2(s.x - 140, s.y - 420), "r": 70.0, "t": "BRAKE"},
		"pause": {"c": Vector2(s.x - 80, 150), "r": 46.0, "t": "II"},
	}


func _hit(pos: Vector2) -> String:
	for name in buttons:
		if pos.distance_to(buttons[name].c) <= buttons[name].r * 1.15:
			return name
	return ""


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not Controls.touch_mode:
			Controls.touch_mode = true
			visible = true
	elif (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed():
		Controls.touch_mode = false
		visible = false
		_release_all()
		return
	if not visible:
		return
	var pos: Vector2 = event.position if (event is InputEventScreenTouch or event is InputEventScreenDrag) else Vector2.ZERO
	if event is InputEventScreenTouch:
		if event.pressed:
			var b := _hit(pos)
			if b == "pause":
				pause_pressed.emit()
			elif b != "":
				held[b] = event.index
				if b == "drift":
					Controls.touch.drift_press = true
				elif b == "item":
					Controls.touch.item = true
			elif pos.x < root.get_viewport_rect().size.x * 0.45 and stick_id < 0:
				stick_id = event.index
				stick_origin = pos
				stick_now = pos
		else:
			if event.index == stick_id:
				stick_id = -1
			for b in held.keys():
				if held[b] == event.index:
					held.erase(b)
		_sync()
	elif event is InputEventScreenDrag and event.index == stick_id:
		stick_now = pos
		_sync()


func _release_all() -> void:
	stick_id = -1
	held.clear()
	_sync()


func _sync() -> void:
	var t: Dictionary = Controls.touch
	t.stick = clampf((stick_now.x - stick_origin.x) / STICK_RANGE, -1, 1) if stick_id >= 0 else 0.0
	t.stick_y = clampf((stick_origin.y - stick_now.y) / STICK_RANGE, -1, 1) if stick_id >= 0 else 0.0
	t.drift_held = held.has("drift")
	t.item_held = held.has("item")
	t.brake = held.has("brake")
	root.queue_redraw()


func _draw_controls() -> void:
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	for name in buttons:
		var b: Dictionary = buttons[name]
		var on := held.has(name)
		root.draw_circle(b.c, b.r, Color(0.06, 0.08, 0.16, 0.55 if not on else 0.8))
		root.draw_arc(b.c, b.r, 0, TAU, 48, Color("f2c94c"), 5 if not on else 8, true)
		var size := 34 if b.r > 60 else 28
		var w := font.get_string_size(b.t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		root.draw_string(font, b.c + Vector2(-w / 2, size * 0.35), b.t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
	if stick_id >= 0:
		root.draw_arc(stick_origin, STICK_RANGE, 0, TAU, 48, Color(1, 1, 1, 0.5), 4, true)
		var knob := stick_origin + (stick_now - stick_origin).limit_length(STICK_RANGE)
		root.draw_circle(knob, 46, Color(0.95, 0.79, 0.3, 0.75))
	else:
		var hint := Vector2(240, root.get_viewport_rect().size.y - 200)
		root.draw_arc(hint, 80, 0, TAU, 48, Color(1, 1, 1, 0.25), 4, true)
		var w := font.get_string_size("STEER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		root.draw_string(font, hint + Vector2(-w / 2, 10), "STEER", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.45))
