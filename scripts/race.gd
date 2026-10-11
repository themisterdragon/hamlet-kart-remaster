extends Node3D
## A race: one track, 8 karts (player 1 and 7 CPUs for now), question boxes,
## the chase camera and the HUD. Mirrors the N64's race_start/race_update.
## Test args (after --): --track=N  --class=0..2  --autotest (a robot drives
## and answers, for screenshots)  --ask (a question 1 s after GO)  --laps=N
## --items (the player gets each item in turn every 4 s)  --touch (phone controls)
## --click-answer=N (with --ask: click answer box N with the mouse)
## --tap-answer=N (with --ask --touch: hold gas with one finger, tap box N with another)
## --view=hazardN / --view=clutterN (the camera watches that obstacle).
## --intro (play the landmark flyover even in a test run).

var LAPS := 4  # (--laps=N in test runs)
const BOX_ROWS := [0.14, 0.47, 0.76]
const BOX_PER_ROW := 4
const CAM_BACK := 90.0
const CAM_UP := 70.0

var track: Track
var karts: Array[Kart] = []
var player: Kart
var boxes: Array = []  # [{node, seg, lat, pos, respawn}]
var countdown := 3.99
var race_time := 0.0
var autotest := false
var ask_test := false
var item_test := false
var click_test := -1  # (test) click this answer box with the mouse
var tap_test := false  # (test) ...or tap it with a second finger while the first holds gas
var view_test := ""   # (test) the camera watches an obstacle
var item_test_next := 0
var track_index := 6
var finished_t := 0.0  # how long the player has been over the line

# the opening flyover: the camera visits the scene's three landmarks
# (Track.landmarks) before the countdown; any button skips it
const SHOT_LEN := 2.8
const SHOT_FADE := 0.3
var intro: Array = []  # [{name, node}]
var intro_t := -1.0    # -1: no flyover (or it's over)
var intro_skip := false

var cam: Camera3D
var cam_yaw := 0.0
var cam_boost := 0.0
var hud: Hud
var touch: TouchControls
var env: Environment
var sun: DirectionalLight3D
var perf_frames := 0     # frames counted during the countdown, to judge this computer
var perf_time := 0.0
var fx: Fx

# online class races (Game.Mode.HOST runs the race; CLIENT shows it)
var online := false
var remote_in := {}     # (host) peer -> that player's latest controls
var send_t := 0.0
var snap: Dictionary    # (player) the latest race state from the host
var snap_new := false
var latched := {}       # (player) button presses not sent yet

# items in flight and on the road, and the moving scenery
var projs: Array = []  # {type, owner, target, seg, t, lat, speed, life, dir, node}
var drops: Array = []  # {owner, pos, life, grace, node}
var obstacles: Obstacles  # hazards and loose clutter (scripts/obstacles.gd)
# item odds by place (esp skull letter trap armor ship poison): the further
# back, the stronger the help; a quiz streak moves you up a tier
const ODDS := [
	[30, 35, 0, 35, 0, 0, 0],    # front
	[25, 20, 25, 15, 10, 0, 5],  # middle
	[20, 0, 20, 0, 20, 20, 20],  # back
]


func _ready() -> void:
	Controls.setup()
	process_mode = Node.PROCESS_MODE_ALWAYS  # so Esc/Start still works while paused
	track_index = Game.track
	var cls := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_index = int(arg.substr(8))
		elif arg.begins_with("--class="):
			cls = int(arg.substr(8))
		elif arg == "--autotest":
			autotest = true
			seed(1)  # the same race every time, so screenshots repeat
		elif arg.begins_with("--laps="):
			LAPS = int(arg.substr(7))
		elif arg == "--items":
			item_test = true
		elif arg == "--ask":
			ask_test = true
		elif arg == "--touch":
			Controls.touch_mode = true
		elif arg.begins_with("--click-answer="):
			click_test = int(arg.substr(15))
		elif arg.begins_with("--tap-answer="):
			click_test = int(arg.substr(13))
			tap_test = true
		elif arg.begins_with("--view="):
			view_test = arg.substr(7)
		elif arg == "--intro":
			Game.intro_seen = -1
			intro_t = 0.0
	track = Track.new()
	add_child(track)
	track.load_track(track_index)
	_environment()

	var chars := []
	var me := 5  # solo: the player starts in the back half, like the N64's 1-player race
	online = Game.mode != Game.Mode.SOLO and not Game.kart_chars.is_empty()
	if online:
		chars = Game.kart_chars
		me = Game.my_kart
		cls = Game.race_class
		Net.message.connect(_net_message)
		Net.peer_left.connect(_net_left)
	else:
		var others := range(8)
		others.shuffle()
		others.erase(Game.my_char)
		chars = others
		chars.insert(me, Game.my_char)
	for g in 8:
		var k := Kart.new()
		k.race = self
		k.race_class = cls
		add_child(k)
		var human: bool = g == me or (online and Game.kart_peers[g] != null)
		var b: Dictionary = {}
		if online:
			var bs: Array = Game.kart_builds
			b = bs[g] if g < bs.size() and bs[g] is Dictionary else {}
		elif g == me:
			b = KartBuild.saved(Game.my_char)
		k.setup(track, int(chars[g]), human, g, b)
		if online and Game.kart_peers[g] is String:
			k.peer = Game.kart_peers[g]
		karts.append(k)
	player = karts[me]
	_boxes()
	obstacles = Obstacles.new()
	add_child(obstacles)
	obstacles.setup(self, track, track_index)
	fx = Fx.new()
	add_child(fx)

	cam = Camera3D.new()
	cam.near = 10
	cam.far = 9000
	add_child(cam)
	cam_yaw = player.yaw
	_camera(1.0)

	Sound.race_over()
	Sound.music("act%d" % (int(Content.tracks[track_index].act) + 1))
	hud = Hud.new()
	add_child(hud)
	hud.choice.connect(_choice)
	touch = TouchControls.new()
	add_child(touch)
	hud.setup(Content.tracks[track_index], LAPS)
	var tests := autotest or ask_test or item_test or click_test >= 0 or view_test != ""
	if (intro_t == 0.0 or not tests) and Game.intro_seen != track_index:
		_start_intro()


## The flyover's shots: each landmark's node (scenery or a hazard).
func _start_intro() -> void:
	Game.intro_seen = track_index  # racing the same scene again goes straight to the grid
	for lm in Track.landmarks(track_index):
		var node: Node3D = obstacles.hazards[lm.hazard].node if lm.has("hazard") else track.prop_nodes[lm.prop_index]
		intro.append({"name": lm.name, "node": node})
	intro_t = 0.0 if intro.size() > 0 else -1.0
	hud.set_intro(intro_t >= 0)
	touch.visible = false


func _end_intro() -> void:
	intro_t = -1.0
	hud.set_intro(false)
	touch.visible = Controls.touch_mode
	_camera(1.0)
	hud.fade.color.a = 1.0  # up from black onto the grid
	create_tween().tween_property(hud.fade, "color:a", 0.0, 0.45)


## One frame of the flyover. Each shot circles slowly round its landmark,
## framed by its size, from the side the road passes; the picture dips to
## black between shots and into the grid.
func _intro_frame(delta: float) -> void:
	intro_t += minf(delta, 0.1)
	var shot := int(intro_t / SHOT_LEN)
	if intro_skip or shot >= intro.size():
		intro_skip = false
		_end_intro()
		return
	var u := fmod(intro_t, SHOT_LEN) / SHOT_LEN
	var node: Node3D = intro[shot].node
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(node.global_position, Vector3.ONE * 40)
	var size := clampf(box.size.length(), 90.0, 1400.0)
	var at := box.get_center()
	# start from the road's side of it, then swing round a little
	var road := track.point(track.locate_global(at.x, at.z), 0, 0)
	var from := Vector2(road.x - at.x, road.z - at.z).normalized()
	if from == Vector2.ZERO:
		from = Vector2(0, 1)
	var ang := from.angle() - 0.45 + u * 0.9 * (1 if shot % 2 == 0 else -1)
	var dist := (size * 1.25 + 90) * (1.0 - u * 0.12)  # a slow push in
	cam.fov = 50
	cam.position = at + Vector3(cos(ang) * dist, size * 0.45 + 45, sin(ang) * dist)
	cam.look_at(at - Vector3(0, size * 0.1, 0))  # (the landmark sits above its name)
	var t := fmod(intro_t, SHOT_LEN)
	var dark := clampf(maxf(1.0 - t / SHOT_FADE, (t - (SHOT_LEN - SHOT_FADE)) / SHOT_FADE), 0, 1)
	hud.show_intro(intro[shot].name, shot, intro.size(), u, dark)
	# the world keeps living meanwhile: hazards move, karts idle on the grid
	obstacles.pose(intro_t, 1.0)
	for k in karts:
		k.show_between(1.0)
		k.face(cam.global_position, minf(delta, 0.1))
	hud.show_state(player, countdown, race_time, karts.size())


func _environment() -> void:
	var th := track.theme
	env = Environment.new()
	# a soft sky in the scene's colours: deep overhead, fog at the horizon
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(th.sky).darkened(0.25)
	sky_mat.sky_horizon_color = Color(th.fog)
	sky_mat.ground_horizon_color = Color(th.fog)
	sky_mat.ground_bottom_color = Color(th.ground)
	sky_mat.sun_angle_max = 20
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.glow_enabled = true  # flames and sparks glow a little
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(th.ambient)
	env.ambient_light_energy = 0.42  # a low fill: more keeps the cast pale and flat
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(th.fog)
	env.fog_depth_begin = float(th.fog_rng[0]) * 1.6  # a PC screen can see further than the N64 could
	env.fog_depth_end = float(th.fog_rng[1]) * 2.2
	env.fog_density = 1.0
	env.fog_sky_affect = 0.35
	# linear, not filmic: filmic bleached the clay's colours (skin turned
	# white); the scenes are lit to stay in range instead
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(th.sun)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)
	if Game.low_quality:
		_low_quality()


## For slow computers (school Chromebooks): no shadows, glow or smoothing.
func _low_quality() -> void:
	Game.low_quality = true
	sun.shadow_enabled = false
	env.glow_enabled = false
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED


func _boxes() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.3, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.35, 0.05)
	var cube := BoxMesh.new()
	cube.size = Vector3(24, 24, 24)
	cube.material = mat
	for row in BOX_ROWS:
		for j in BOX_PER_ROW:
			var seg := int(row * track.n)
			var lat := (-0.66 + j * 0.44) * track.road_half
			var pos := track.point(seg, 0, lat) + Vector3(0, 22, 0)
			var node := Node3D.new()
			var mi := MeshInstance3D.new()
			mi.mesh = cube
			node.add_child(mi)
			var q := Label3D.new()
			q.text = "?"
			q.font = load("res://assets/fonts/LilitaOne-Regular.ttf")
			q.font_size = 160
			q.pixel_size = 0.12
			q.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			q.outline_size = 24
			q.no_depth_test = false
			node.add_child(q)
			node.position = pos
			add_child(node)
			boxes.append({"node": node, "cube": mi, "seg": seg, "lat": lat, "pos": pos, "respawn": 0.0})


## Pause (Esc / Start), and after the finish: next track or race again.
func _unhandled_input(event: InputEvent) -> void:
	if intro_t >= 0:  # any button, key, click or tap skips the flyover
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("p0_gas") or \
				(event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			intro_skip = true
			get_viewport().set_input_as_handled()
			return
	var start: bool = event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START)
	if online:
		# no pausing a shared race; after it, the host takes everyone back to the lobby
		if hud.results_up and Game.mode == Game.Mode.HOST and (event.is_action_pressed("ui_accept") or start):
			Net.broadcast({"k": "back"})
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if hud.results_up:
		if event.is_action_pressed("ui_accept") or start:
			Game.track = (track_index + 1) % Content.tracks.size()
			get_tree().reload_current_scene()
		elif _is_restart(event):
			get_tree().reload_current_scene()
		elif Controls.is_menu_button(event):
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if get_tree().paused:
		if start or event.is_action_pressed("ui_accept"):
			_pause(false)
		elif _is_restart(event):
			_pause(false)
			get_tree().reload_current_scene()
		elif Controls.is_menu_button(event):
			_pause(false)
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q and not OS.has_feature("web"):
			get_tree().quit()
	elif start:
		_pause(true)


func _is_restart(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and event.physical_keycode == KEY_R) or \
		(event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)


func _pause(on: bool) -> void:
	get_tree().paused = on
	hud.show_pause(on)


## The race runs in fixed steps of STEP seconds, whatever the screen's rate,
## so karts handle the same on a 30 Hz Chromebook and a 144 Hz monitor;
## between steps karts are drawn part way (Kart.show_between) and the camera
## follows every frame.
const STEP := 1.0 / 60
var acc := 0.0
var pad_in := {}  # player 1's controls, presses held until a step reads them


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if intro_t >= 0:
		if Game.mode == Game.Mode.CLIENT and online and snap_new and float(snap.cd) < 3.9:
			_end_intro()  # (player) the host's race has begun
		else:
			_intro_frame(delta)
			return
	if Game.mode == Game.Mode.CLIENT and online:
		_client_process(minf(delta, 1.0 / 20))
		return
	# judge this computer on the grid: under 45 frames a second, go light
	if countdown > 0 and countdown < 3.5 and not Game.low_quality:
		perf_frames += 1
		perf_time += delta
		if perf_time > 2.0 and perf_frames / perf_time < 45:
			_low_quality()
	var pad := Controls.read(0)
	for key in ["drift_press", "item"]:
		pad[key] = pad[key] or pad_in.get(key, false)
	if pad.answer < 0:
		pad.answer = pad_in.get("answer", -1)
	pad_in = pad
	acc += minf(delta, 0.25)
	var steps := 0
	while acc >= STEP and steps < 6:
		acc -= STEP
		steps += 1
		_step(STEP)
		pad_in.drift_press = false
		pad_in.item = false
		pad_in.answer = -1
	if steps == 6:
		acc = 0  # far behind (a very slow frame): let it go rather than race to catch up
	var a := acc / STEP
	for k in karts:
		k.show_between(a)
	obstacles.pose(race_time + (a * STEP if countdown <= 0 else 0.0), a)
	_camera(minf(delta, 0.1))
	for k in karts:
		k.face(cam.global_position, minf(delta, 0.1))
		# a kart right at the camera (the grid row behind you) would fill the screen
		var near := k != player and Vector2(k.position.x - cam.position.x, k.position.z - cam.position.z).length() <= 50
		if k.model == null:
			k.sprite.visible = not near
		elif near:
			k.model.visible = false
	hud.show_state(player, countdown, race_time, karts.size())
	touch.set_driving(not (player.asking or player.verdict_t > 0))
	Sound.watch(player, countdown, LAPS, int(Content.tracks[track_index].act))


## One fixed step of the race.
func _step(dt: float) -> void:
	if player.finished:
		finished_t += dt
		if finished_t > 2.0 and not hud.results_up:
			hud.show_results(karts, player)
	if countdown > 0:
		countdown -= dt
		if countdown <= 0:
			_rocket_starts()
	else:
		race_time += dt
		if item_test and player.item == Kart.IT_NONE and player.roulette_t <= 0 and fmod(race_time, 4.0) < dt:
			player.item = item_test_next % 7
			item_test_next += 1
		if tap_test and click_test >= 0 and race_time >= 0.5 and race_time < 0.6:  # finger 0 down on gas
			_touch(0, get_viewport().get_screen_transform() * (touch.pads.filter(func(p): return p.name == "gas")[0].button.position + Vector2(150, 150)), true)
		if click_test >= 0 and player.asking and race_time >= 2.0 and tap_test:  # finger 1 taps the box
			var at := get_viewport().get_screen_transform() * hud.a_cells[click_test].get_global_rect().get_center()
			_touch(1, at, true)
			_touch(1, at, false)
			print("tapped answer box ", click_test, " with finger 1; gas held: ", Input.is_action_pressed("p0_gas"))
			click_test = -2
		elif click_test >= 0 and player.asking and race_time >= 2.0:  # a real mouse click on the box
			var at := get_viewport().get_screen_transform() * hud.a_cells[click_test].get_global_rect().get_center()  # (window pixels)
			for down in [true, false]:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = down
				e.position = at
				e.global_position = at
				Input.parse_input_event(e)
			print("clicked answer box ", click_test, " at ", at)
			click_test = -2
		elif click_test == -2 and not player.asking:
			print("answered: slot ", player.answered, ", right: ", player.verdict_ok)
			if tap_test:
				print("gas still held after the question: ", Input.is_action_pressed("p0_gas"))
			click_test = -1
		if ask_test and race_time >= 1.0 and not player.asking and player.verdict_t <= 0 and player.right + player.wrong == 0:
			player.start_question(Content.tracks[track_index])
	var best := -INF
	for k in karts:
		if k.human:
			best = maxf(best, k.progress)
	for k in karts:
		k.prev_pos = Vector3(k.x, k.y, k.z)
		k.prev_yaw = k.yaw
		var pad: Dictionary = pad_in if k == player else {}
		if k == player and autotest:
			pad = _robot(k)
		elif k.peer != "":
			pad = _remote_pad(k)
		k.update(dt, pad, countdown, best)
		if countdown <= 0:
			_draft(k, dt)
		if k.lap >= LAPS and not k.finished:
			k.finished = true
			k.finish_time = race_time
	_collide()
	_rank()
	_update_boxes(dt)
	_update_projs(dt)
	_update_drops(dt)
	obstacles.step(dt, karts, race_time, true)
	for k in karts:
		fx.emit(k, dt)
	if online:
		send_t -= dt
		if send_t <= 0:
			send_t = 0.05  # 20 times a second
			Net.broadcast(_snapshot())


## Test robot: holds gas, follows the CPU line, answers after 2.5 s.
func _robot(k: Kart) -> Dictionary:
	var ans := -1
	if k.asking and k.ask_t < Kart.ASK_TIME - 2.5:
		ans = randi() % 4
	# uses an item a second after it lands; holds the skull for a second, then throws it
	var use := k.item != Kart.IT_NONE and k.roulette_t <= 0 and not k.holding and fmod(race_time, 2.0) < 0.05
	# gas down in the back half of "2": a rocket start
	return {"stick": k._steer_ai(0), "stick_y": 0.0, "gas": countdown < 2.3, "brake": false, "drift_press": false, "drift_held": false,
		"item": use, "item_held": k.holding and k.hold_t < 1.0, "answer": ans}


func _update_boxes(dt: float) -> void:
	var spin := race_time * 1.6
	for b in boxes:
		b.node.get_child(0).rotation = Vector3(spin * 0.6, spin, 0)
		if b.respawn > 0:
			b.respawn -= dt
			b.node.visible = b.respawn <= 0
			continue
		for k in karts:
			if k.finished:
				continue
			var d := Vector2(k.x - b.pos.x, k.z - b.pos.z)
			if d.length_squared() > 28 * 28:
				continue
			b.respawn = 3.0
			b.node.visible = false
			if k.asking or k.verdict_t > 0:
				continue
			if k.item != Kart.IT_NONE or k.roulette_t > 0:
				continue
			if k.human:
				k.start_question(Content.tracks[track_index])
			elif randf() < 0.75:
				give_item(k, 0)  # the CPUs know their Hamlet, mostly
			break


## Karts bounce sideways off each other; heavier ones push harder.
func _collide() -> void:
	var min_d := Kart.KART_R * 2
	for a in karts.size():
		for b in range(a + 1, karts.size()):
			var p := karts[a]
			var q := karts[b]
			var d := Vector2(q.x - p.x, q.z - p.z)
			var l := d.length()
			if l >= min_d or l < 0.01:
				continue
			d /= l
			var wp: float = p.stats[3]
			var wq: float = q.stats[3]
			var kp := wq / (wp + wq)
			var kq := wp / (wp + wq)
			var push := min_d - l
			p.x -= d.x * push * kp
			p.z -= d.y * push * kp
			q.x += d.x * push * kq
			q.z += d.y * push * kq
			var closing := (Kart.fwd_of(p.yaw) * p.speed + p.knock - Kart.fwd_of(q.yaw) * q.speed - q.knock).dot(d)
			if closing > 15:
				var k := clampf(70 + closing * 0.5, 70, 170)
				p.knock += _side(p, -d) * k * kp * 2
				q.knock += _side(q, d) * k * kq * 2
				p.bump_t = 0.3
				q.bump_t = 0.3


## Across the road, toward `n`: bumps slide karts over, not forward.
func _side(k: Kart, n: Vector2) -> Vector2:
	var r := track.right(k.seg)
	return r if r.dot(n) >= 0 else -r


func _rank() -> void:
	var order := karts.duplicate()
	order.sort_custom(func(a: Kart, b: Kart) -> bool:
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		return a.progress > b.progress)
	for i in order.size():
		order[i].place = i + 1


var cam_h := 0.0  # the camera's height, eased on its own so hops don't jolt it


func _camera(dt: float) -> void:
	var r := player
	var at := r.position  # where the kart is drawn this frame
	# follow the heading, half of a drift's angle too, so a slide stays framed
	cam_yaw += wrapf(r.vis_yaw + r.slide * 0.15 - cam_yaw, -PI, PI) * (1 - exp(-dt * 5))
	var fast := r.boost_t > 0
	cam_boost = Kart.move_toward_exp(cam_boost, 1.0 if fast else 0.0, dt * (6.0 if fast else 2.5))
	var back := CAM_BACK + 24 * cam_boost
	var up := CAM_UP + 6 * cam_boost
	var f := Kart.fwd_of(cam_yaw)
	var ground := at.y - r.hop
	cam_h = ground + r.hop * 0.4 if dt >= 1 else Kart.move_toward_exp(cam_h, ground + r.hop * 0.4, dt * 6)
	var target := Vector3(at.x - f.x * back, cam_h + up, at.z - f.y * back)
	var k := 1 - exp(-dt * 10)
	cam.position = cam.position.lerp(target, k) if dt < 1 else target
	if r.shake_t > 0:
		var s := r.shake_t * 18
		cam.position += Vector3(randf() - 0.5, randf() - 0.5, 0) * s
	cam.fov = 68 + 9 * cam_boost
	if view_test != "":
		var at_o: Vector3
		if view_test.begins_with("hazard"):
			at_o = obstacles.hazards[int(view_test.substr(6))].node.position
			at_o = Vector3(at_o.x, track.point(obstacles.hazards[int(view_test.substr(6))].sample, 0, 0).y, at_o.z)
		else:
			at_o = obstacles.loose[int(view_test.substr(7)) * 4].home
		var o_seg := track.locate_global(at_o.x, at_o.z)
		var back_p := track.point(o_seg - 5, 0, 0) + Vector3(0, 90, 0)
		cam.position = back_p
		cam.look_at(at_o + Vector3(0, 20, 0))
		return
	# look a little into the bend
	var side := Vector2(-f.y, f.x) * -r.steer * 14
	cam.look_at(Vector3(at.x + f.x * 70 + side.x, cam_h + 10, at.z + f.y * 70 + side.y))


# ------------------------------------------------------------------ items

func give_item(k: Kart, bonus: int) -> void:
	var n := karts.size()
	var f := (k.place - 1) / float(n - 1) if n > 1 else 0.0
	var tier := 0 if f < 0.3 else (1 if f < 0.7 else 2)
	tier = mini(tier + bonus, 2)
	var w: Array = ODDS[tier]
	var x := randi() % int(w.reduce(func(a, b): return a + b))
	k.item = Kart.IT_ESPRESSO
	for i in w.size():
		if x < w[i]:
			k.item = i
			break
		x -= w[i]
	k.roulette_t = 1.1


func _racer_at_place(place: int) -> Kart:
	for k in karts:
		if k.place == place:
			return k
	return null


func use_item(k: Kart) -> void:
	var it := k.item
	if it == Kart.IT_NONE or k.roulette_t > 0 or k.holding:
		return
	# Yorick's Skull: a player holds it behind the kart while the button stays
	# down, where it blocks one item from behind; letting go throws it
	if it == Kart.IT_SKULL and k.human:
		k.holding = true
		k.hold_t = 0
		return
	k.item = Kart.IT_NONE
	match it:
		Kart.IT_ESPRESSO:
			k.boost_t = 1.6
		Kart.IT_SKULL, Kart.IT_LETTER:
			# the Letter goes to the racer one place ahead; the leader's just flies off
			var target: Kart = _racer_at_place(k.place - 1) if it == Kart.IT_LETTER else null
			_throw(k, it, 1, target)
		Kart.IT_MOUSETRAP:
			var f := Kart.fwd_of(k.yaw)
			var pos := Vector3(k.x - f.x * 34, k.y - k.hop, k.z - f.y * 34)
			var node := _item_sprite(Kart.IT_MOUSETRAP, 0.45)
			node.position = pos + Vector3(0, 10, 0)
			add_child(node)
			drops.append({"owner": k, "pos": pos, "life": 40.0, "grace": 0.6, "node": node})
		Kart.IT_ARMOR:
			k.star_t = 6.0
		Kart.IT_SHIP:
			k.ship_t = 3.5
		Kart.IT_POISON:
			for o in karts:
				if o.place < k.place and not o.immune() and not o.finished:
					o.nap_t = 2.6


## Let go of the held skull: thrown down the road, or rolled back at anyone behind.
func release_skull(k: Kart, back: bool) -> void:
	k.holding = false
	k.item = Kart.IT_NONE
	_throw(k, Kart.IT_SKULL, -1 if back else 1, null)


func _throw(k: Kart, type: int, dir: int, target: Kart) -> void:
	var p := {"type": type, "owner": k, "target": target, "seg": k.seg, "t": k.seg_t,
		"lat": clampf(k.lat, -track.road_half, track.road_half),
		"speed": (520.0 if dir < 0 else 820.0) if type == Kart.IT_SKULL else 760.0,
		"life": 5.0 if type == Kart.IT_SKULL else 7.0, "dir": dir}
	p.t += -0.6 if dir < 0 else 0.5  # clear of the thrower either way
	p.node = _item_sprite(type, 0.4)
	add_child(p.node)
	projs.append(p)


func _item_sprite(type: int, scale_px: float) -> Sprite3D:
	var sp := Sprite3D.new()
	sp.texture = load("res://assets/images/items/%02d.png" % type)
	sp.pixel_size = scale_px
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = false
	return sp


## A held skull takes an item's hit for its holder, once.
func _block_with_skull(o: Kart) -> bool:
	if not o.holding:
		return false
	o.holding = false
	o.item = Kart.IT_NONE
	return true


func _update_projs(dt: float) -> void:
	for p in projs.duplicate():
		p.life -= dt
		if p.life <= 0:
			_remove(projs, p)
			continue
		p.t += p.dir * p.speed * dt / 56.0
		while p.t >= 1:
			p.t -= 1
			p.seg = posmod(p.seg + 1, track.n)
		while p.t < 0:
			p.t += 1
			p.seg = posmod(p.seg - 1, track.n)
		if p.target != null:
			p.lat = Kart.move_toward_exp(p.lat, p.target.lat, dt * 3)
		var pos := track.point(p.seg, p.t, p.lat) + Vector3(0, 16 if p.type == Kart.IT_LETTER else 10, 0)
		p.node.position = pos
		p.node.rotation.z = race_time * 9 if p.type == Kart.IT_SKULL else 0.0
		for o in karts:
			if o == p.owner and p.life > (6.5 if p.type == Kart.IT_LETTER else 4.5):
				continue
			if Vector2(o.x - pos.x, o.z - pos.z).length_squared() < 26 * 26:
				if not _block_with_skull(o):
					o.hit(1.0)
				_remove(projs, p)
				break


func _update_drops(dt: float) -> void:
	for d in drops.duplicate():
		d.life -= dt
		d.grace -= dt
		if d.life <= 0:
			_remove(drops, d)
			continue
		for o in karts:
			if o == d.owner and d.grace > 0:
				continue
			if Vector2(o.x - d.pos.x, o.z - d.pos.z).length_squared() > 26 * 26:
				continue
			if not _block_with_skull(o):
				o.hit(1.0)
			_remove(drops, d)
			break


func _remove(list: Array, entry: Dictionary) -> void:
	entry.node.queue_free()
	list.erase(entry)


# ---------------------------------------------------- hazards, slipstream

func _side_toward(k: Kart, n: Vector2) -> Vector2:
	var r := track.right(k.seg)
	var side := n.dot(r)
	if absf(side) < 0.15:
		side = k.lat  # dead-on: off toward its own side
	return r if side > 0 else -r


func _bump(k: Kart, dir: Vector2, strength: float) -> void:
	k.knock += dir * strength
	k.speed *= 0.9
	if k.bump_t > 0:
		return
	k.bump_t = 0.35
	if k.hop <= 0:
		k.hop_v = maxf(k.hop_v, 55)


## Slipstream: 1.2 s tucked in behind a kart ahead gives a short boost.
func _draft(k: Kart, dt: float) -> void:
	var in_draft := false
	var f := Kart.fwd_of(k.yaw)
	if k.speed > 160 and k.spin_t <= 0 and k.boost_t <= 0:
		for o in karts:
			if o == k:
				continue
			var d := Vector2(o.x - k.x, o.z - k.z)
			var ahead := d.dot(f)
			var off := absf(d.x * f.y - d.y * f.x)
			if ahead > 30 and ahead < 140 and off < 22 and f.dot(Kart.fwd_of(o.yaw)) > 0.9:
				in_draft = true
				break
	k.draft_t = k.draft_t + dt if in_draft else maxf(0, k.draft_t - dt * 2)
	if k.draft_t >= 1.2:
		k.draft_t = 0
		k.boost_t = maxf(k.boost_t, 0.9)
		on_boost(k)


## At GO: gas pressed in the back half of "2" (and held) launches you with
## a boost; pressed during "3" and you spin your wheels. Some CPUs get a good start too.
func _rocket_starts() -> void:
	for k in karts:
		var good := k.start_press >= 1.5 and k.start_press <= 2.5 if k.human else randf() < 0.35
		if good:
			k.boost_t = maxf(k.boost_t, 1.2)
			k.speed = maxf(k.speed, 120)
			k.launch_t = 0.45  # the launch stretch
		elif k.human and k.start_press > 2.5:
			k.spin_t = maxf(k.spin_t, 0.8)
		k.start_press = 0


# hooks for sound and effects (sound comes in the next step)
func on_boost(_k: Kart) -> void:
	pass


func on_hit(_k: Kart) -> void:
	pass


# ----------------------------------------------------------- online races

const NO_PAD := {"stick": 0.0, "stick_y": 0.0, "gas": false, "brake": false, "drift_press": false,
	"drift_held": false, "item": false, "item_held": false, "answer": -1}


## (host) A remote player's controls; presses count once.
func _remote_pad(k: Kart) -> Dictionary:
	var pad: Dictionary = remote_in.get(k.peer, NO_PAD).duplicate()
	if remote_in.has(k.peer):
		remote_in[k.peer].drift_press = false
		remote_in[k.peer].item = false
		remote_in[k.peer].answer = -1
	return pad


func _net_message(peer: String, d: Dictionary) -> void:
	match d.get("k"):
		"in":  # (host) a player's controls; keep presses until the race reads them
			var old: Dictionary = remote_in.get(peer, NO_PAD)
			var pad: Dictionary = d.i
			pad.drift_press = pad.drift_press or old.drift_press
			pad.item = pad.item or old.item
			if int(pad.answer) < 0:
				pad.answer = old.answer
			remote_in[peer] = pad
		"s":  # (player) the race as the host sees it
			snap = d
			snap_new = true
		"back":  # (player) the host went back to the lobby
			get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _net_left(peer: String) -> void:
	if Game.mode == Game.Mode.HOST:
		for k in karts:
			if k.peer == peer:  # their kart drives on as a CPU
				k.peer = ""
				k.human = false
				k.asking = false
	elif peer == Game.host_peer:
		Net.close()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


## (host) Everything a player's screen needs, about 1-2 KB.
func _snapshot() -> Dictionary:
	var ks := []
	var qs := {}
	for i in karts.size():
		var k := karts[i]
		ks.append(k.snap())
		if k.peer != "" and (k.asking or k.verdict_t > 0):
			qs[str(i)] = k.question
	var bx := 0
	for i in boxes.size():
		if boxes[i].respawn > 0:
			bx |= 1 << i
	var ps := []
	for p in projs:
		ps.append([p.type, snappedf(p.node.position.x, 0.1), snappedf(p.node.position.y, 0.1), snappedf(p.node.position.z, 0.1)])
	var ds := []
	for d in drops:
		ds.append([snappedf(d.pos.x, 0.1), snappedf(d.pos.y, 0.1), snappedf(d.pos.z, 0.1)])
	return {"k": "s", "cd": countdown, "t": race_time, "ks": ks, "q": qs, "bx": bx, "ps": ps, "ds": ds, "lo": obstacles.snapshot()}


## (player) Send my controls, show the host's race.
func _client_process(dt: float) -> void:
	var pad := Controls.read(0)
	for key in ["drift_press", "item"]:
		latched[key] = latched.get(key, false) or pad[key]
	if pad.answer >= 0:
		latched.answer = pad.answer
	send_t -= dt
	if send_t <= 0:
		send_t = 1.0 / 30
		pad.drift_press = latched.get("drift_press", false)
		pad.item = latched.get("item", false)
		pad.answer = latched.get("answer", -1)
		latched = {}
		Net.send(Game.host_peer, {"k": "in", "i": pad})
	if snap_new:
		snap_new = false
		countdown = snap.cd
		race_time = snap.t
		for i in karts.size():
			karts[i].apply(snap.ks[i])
		var q: Dictionary = snap.q
		if q.has(str(Game.my_kart)):
			player.question = q[str(Game.my_kart)]
		for i in boxes.size():
			boxes[i].node.visible = (int(snap.bx) >> i) & 1 == 0
		_show_items(snap.ps, snap.ds)
		obstacles.apply(snap.get("lo", []))
	else:
		if countdown < 3.9:  # (not before the host's countdown has begun: it may still be in its flyover)
			countdown = maxf(countdown - dt, 0) if countdown > 0 else countdown
		if countdown <= 0:
			race_time += dt
	for k in karts:
		k.smooth(dt)
	var spin := race_time * 1.6
	for b in boxes:
		b.node.get_child(0).rotation = Vector3(spin * 0.6, spin, 0)
	obstacles.step(dt, karts, race_time, false)
	obstacles.pose(race_time)
	for k in karts:
		fx.emit(k, dt)
	_camera(dt)
	for k in karts:
		k.face(cam.global_position, dt)
		if k.model == null:
			k.sprite.visible = k.sprite.visible and (k == player or Vector2(k.x - cam.position.x, k.z - cam.position.z).length() > 50)
	if player.finished:
		finished_t += dt
		if finished_t > 2.0 and not hud.results_up:
			hud.show_results(karts, player)
	hud.show_state(player, countdown, race_time, karts.size())
	touch.set_driving(not (player.asking or player.verdict_t > 0))
	Sound.watch(player, countdown, LAPS, int(Content.tracks[track_index].act))


var _shown: Array = []  # (player) sprites for items in flight and on the road


func _show_items(ps: Array, ds: Array) -> void:
	for n in _shown:
		n.queue_free()
	_shown.clear()
	for p in ps:
		var sp := _item_sprite(int(p[0]), 0.4)
		sp.position = Vector3(p[1], p[2], p[3])
		add_child(sp)
		_shown.append(sp)
	for d in ds:
		var sp := _item_sprite(Kart.IT_MOUSETRAP, 0.45)
		sp.position = Vector3(d[0], d[1] + 10, d[2])
		add_child(sp)
		_shown.append(sp)


## (test) A finger touching the screen at a window pixel.
func _touch(index: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


## A tapped choice on the pause or results screen (phones).
func _choice(what: String) -> void:
	get_tree().paused = false
	match what:
		"resume":
			_pause(false)
		"restart":
			get_tree().reload_current_scene()
		"next":
			Game.track = (track_index + 1) % Content.tracks.size()
			get_tree().reload_current_scene()
		"menu":
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		"lobby":
			Net.broadcast({"k": "back"})
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
