extends Node
## Test-only screenshots, for checking the game without a person at the screen.
## Off unless the game is started with user args, e.g.:
##   godot -- --shot=/tmp/out --at=30,90 --press=60:ui_down
## saves shot_30.png and shot_90.png, presses ui_down at frame 60, then quits.

var out := ""
var at: Array[int] = []
var presses := {}
var frame := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			out = arg.substr(7)
		elif arg.begins_with("--at="):
			for n in arg.substr(5).split(","):
				at.append(int(n))
		elif arg.begins_with("--press="):
			for p in arg.substr(8).split(","):
				var kv := p.split(":")
				presses[int(kv[0])] = kv[1]
	set_process(out != "")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	frame += 1
	if presses.has(frame):
		var ev := InputEventAction.new()
		ev.action = presses[frame]
		ev.pressed = true
		Input.parse_input_event(ev)
	if frame in at:
		get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [out, frame])
	if at.is_empty() or frame >= at.max():
		get_tree().quit()
