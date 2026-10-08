class_name Controls
## Player controls. Gamepad (Xbox / PlayStation names): left stick steers,
## A/Cross or RT/R2 gas, B/Circle or X/Square brake, RB/R1 drift, LB/L1 or
## LT/L2 item (hold the skull, let go to throw; stick back rolls it behind),
## D-pad answers, Start/Options pauses. Player 1 takes any connected pad. Keyboard (player 1): arrows or A/D steer, X gas, Z brake,
## Shift or C drift, Space item (Down held: roll it back); while a question
## is up the kart drives itself, so the arrow keys answer.

const DIRS := ["up", "right", "down", "left"]  # answer slots, as the D-pad


static func setup() -> void:
	for p in 4:
		var dev := -1 if p == 0 else p  # (-1: every device)
		var k := p == 0
		_action("p%d_left" % p, [[JOY_AXIS_LEFT_X, -1.0]], dev, [KEY_LEFT, KEY_A] if k else [])
		_action("p%d_right" % p, [[JOY_AXIS_LEFT_X, 1.0]], dev, [KEY_RIGHT, KEY_D] if k else [])
		_action("p%d_gas" % p, [JOY_BUTTON_A, [JOY_AXIS_TRIGGER_RIGHT, 1.0]], dev, [KEY_X, KEY_W] if k else [])
		_action("p%d_brake" % p, [JOY_BUTTON_B, JOY_BUTTON_X], dev, [KEY_Z, KEY_S] if k else [])
		_action("p%d_drift" % p, [JOY_BUTTON_RIGHT_SHOULDER], dev, [KEY_SHIFT, KEY_C] if k else [])
		_action("p%d_item" % p, [JOY_BUTTON_LEFT_SHOULDER, [JOY_AXIS_TRIGGER_LEFT, 1.0]], dev, [KEY_SPACE] if k else [])
		_action("p%d_back" % p, [[JOY_AXIS_LEFT_Y, 1.0]], dev, [KEY_DOWN] if k else [])
		_action("p%d_fwd" % p, [[JOY_AXIS_LEFT_Y, -1.0]], dev, [KEY_UP] if k else [])
		_action("p%d_up" % p, [JOY_BUTTON_DPAD_UP], dev, [KEY_UP] if k else [])
		_action("p%d_right_a" % p, [JOY_BUTTON_DPAD_RIGHT], dev, [KEY_RIGHT] if k else [])
		_action("p%d_down" % p, [JOY_BUTTON_DPAD_DOWN], dev, [KEY_DOWN] if k else [])
		_action("p%d_left_a" % p, [JOY_BUTTON_DPAD_LEFT], dev, [KEY_LEFT] if k else [])


## An action from gamepad buttons, axes ([axis, direction]) and keys.
static func _action(name: String, joy: Array, device: int, keys: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	for j in joy:
		if j is Array:
			var m := InputEventJoypadMotion.new()
			m.axis = j[0]
			m.axis_value = j[1]
			m.device = device
			InputMap.action_add_event(name, m)
		else:
			var b := InputEventJoypadButton.new()
			b.button_index = j
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
		"stick_y": Input.get_axis(pre + "back", pre + "fwd"),  # pulled back is negative
		"item": Input.is_action_just_pressed(pre + "item"),
		"item_held": Input.is_action_pressed(pre + "item"),
		"answer": answer,
	}


## A short rumble on every connected pad (player 1's pad may be any of them).
static func rumble(weak: float, strong: float, seconds: float) -> void:
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, weak, strong, seconds)
