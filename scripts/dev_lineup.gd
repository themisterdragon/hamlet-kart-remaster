extends Control
## (test) All eight racers side by side, close up, lit as on character select,
## for judging the character art: tools/shot.sh OUT 20 "" with
## SHOT_SCENE=res://scenes/dev_lineup.tscn, plus --yaw=DEG (0 = facing the
## camera, 180 = from behind as in a race) and --zoom=N (1 = rider and kart).

func _ready() -> void:
	var yaw := 25.0
	var zoom := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--yaw="):
			yaw = float(arg.substr(6))
		elif arg.begins_with("--zoom="):
			zoom = float(arg.substr(7))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	var bg := ColorRect.new()
	bg.color = Color("1c1838")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	for ch in Content.characters.size():
		var vpc := SubViewportContainer.new()
		vpc.stretch = true
		vpc.custom_minimum_size = Vector2(480, 540)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vpc.add_child(vp)
		grid.add_child(vpc)
		Studio.light(vp)
		var m := KartRig.make(ch, KartBuild.saved(ch))
		m.rotation_degrees.y = yaw
		vp.add_child(m)
		var cam := Camera3D.new()
		cam.fov = 40.0 / zoom
		var look := Vector3(0, 19 + 8 * (zoom - 1) / zoom, 0)
		var eye := Vector3(0, 40, 110)
		cam.transform = Transform3D(Basis.looking_at(look - eye), eye)
		vp.add_child(cam)
