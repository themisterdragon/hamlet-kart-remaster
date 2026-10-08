class_name Controls
## Player controls. Gamepad: left stick steers, A gas, B brake, R1 drift,
## L1 item, D-pad answers. Keyboard (player 1): arrows or A/D steer,
## X gas, Z brake, Shift or C drift, Space item; while a question is up the
## kart drives itself, so the arrow keys answer.

const DIRS := ["up", "right", "down", "left"]  # answer slots, as the D-pad


static func setup() -> void:
	for p in 4:
		_action("p%d_left" % p, [JOY_AXIS_LEFT_X, -1.0], p, [KEY_LEFT, KEY_A] if p == 0 else [])
		_action("p%d_right" % p, [JOY_AXIS_LEFT_X, 1.0], p, [KEY_RIGHT, KEY_D] if p == 0 else [])
		_action("p%d_gas" % p, JOY_BUTTON_A, p, [KEY_X, KEY_W] if p == 0 else [])
		_action("p%d_brake" % p, JOY_BUTTON_B, p, [KEY_Z, KEY_S] if p == 0 else [])
		_action("p%d_drift" % p, JOY_BUTTON_RIGHT_SHOULDER, p, [KEY_SHIFT, KEY_C] if p == 0 else [])
		_action("p%d_item" % p, JOY_BUTTON_LEFT_SHOULDER, p, [KEY_SPACE] if p == 0 else [])
		_action("p%d_up" % p, JOY_BUTTON_DPAD_UP, p, [KEY_UP] if p == 0 else [])
		_action("p%d_right_a" % p, JOY_BUTTON_DPAD_RIGHT, p, [KEY_RIGHT] if p == 0 else [])
		_action("p%d_down" % p, JOY_BUTTON_DPAD_DOWN, p, [KEY_DOWN] if p == 0 else [])
		_action("p%d_left_a" % p, JOY_BUTTON_DPAD_LEFT, p, [KEY_LEFT] if p == 0 else [])


static func _action(name: String, joy, device: int, keys: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	if joy is Array:
		var m := InputEventJoypadMotion.new()
		m.axis = joy[0]
		m.axis_value = joy[1]
		m.device = device
		InputMap.action_add_event(name, m)
	else:
		var b := InputEventJoypadButton.new()
		b.button_index = joy
		b.device = device
		InputMap.action_add_event(name, b)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(name, e)


## This frame's input for player p, in the kart's terms.
static func read(p: int) -> Dictionary:
	var pre := "p%d_" % p
	var answer := -1
	for i in 4:
		var act: String = pre + ["up", "right_a", "down", "left_a"][i]
		if Input.is_action_just_pressed(act):
			answer = i
	return {
		"stick": Input.get_axis(pre + "left", pre + "right"),
		"gas": Input.is_action_pressed(pre + "gas"),
		"brake": Input.is_action_pressed(pre + "brake"),
		"drift_press": Input.is_action_just_pressed(pre + "drift"),
		"drift_held": Input.is_action_pressed(pre + "drift"),
		"item": Input.is_action_just_pressed(pre + "item"),
		"answer": answer,
	}
