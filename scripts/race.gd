extends Node3D
## A race: one track, 8 karts (player 1 and 7 CPUs for now), question boxes,
## the chase camera and the HUD. Mirrors the N64's race_start/race_update.
## Test args (after --): --track=N  --class=0..2  --autotest (a robot drives
## and answers, for screenshots)  --ask (a question 1 s after GO).

const LAPS := 4
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
var track_index := 6  # Act III's first track: it sets the standard

var cam: Camera3D
var cam_yaw := 0.0
var cam_boost := 0.0
var hud: Hud


func _ready() -> void:
	Controls.setup()
	var cls := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--track="):
			track_index = int(arg.substr(8))
		elif arg.begins_with("--class="):
			cls = int(arg.substr(8))
		elif arg == "--autotest":
			autotest = true
			seed(1)  # the same race every time, so screenshots repeat
		elif arg == "--ask":
			ask_test = true
	track = Track.new()
	add_child(track)
	track.load_track(track_index)
	_environment()

	var cast := range(8)
	cast.shuffle()
	cast.erase(0)
	cast.insert(0, 0)  # player 1 is Hamlet for now; character select comes later
	# grid: the player starts at the back half, like the N64's 1-player race
	var order := [1, 2, 3, 4, 5, 0, 6, 7]
	for g in 8:
		var who: int = order[g]
		var k := Kart.new()
		k.race_class = cls
		add_child(k)
		k.setup(track, cast[who], who == 0, g)
		karts.append(k)
		if who == 0:
			player = k
	_boxes()

	cam = Camera3D.new()
	cam.near = 10
	cam.far = 9000
	add_child(cam)
	cam_yaw = player.yaw
	_camera(1.0)

	hud = Hud.new()
	add_child(hud)
	hud.setup(Content.tracks[track_index], LAPS)


func _environment() -> void:
	var th := track.theme
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(th.sky)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(th.ambient)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(th.fog)
	env.fog_depth_begin = float(th.fog_rng[0]) * 1.6  # a PC screen can see further than the N64 could
	env.fog_depth_end = float(th.fog_rng[1]) * 2.2
	env.fog_density = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(th.sun)
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)


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


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20)
	var racing := countdown <= 0
	if countdown > 0:
		countdown -= dt
	else:
		race_time += dt
		if ask_test and race_time >= 1.0 and not player.asking and player.verdict_t <= 0 and player.right + player.wrong == 0:
			player.start_question(Content.tracks[track_index])
	var best := -INF
	for k in karts:
		if k.human:
			best = maxf(best, k.progress)
	for k in karts:
		var pad := Controls.read(0) if k == player else {}
		if k == player and autotest:
			pad = _robot(k)
		k.update(dt, pad, racing, best)
		if k.lap >= LAPS and not k.finished:
			k.finished = true
			k.finish_time = race_time
	_collide()
	_rank()
	_update_boxes(dt)
	_camera(dt)
	for k in karts:
		k.face(cam.global_position)
		# a kart right at the camera (the grid row behind you) would fill the screen
		k.sprite.visible = k == player or Vector2(k.x - cam.position.x, k.z - cam.position.z).length() > 50
	hud.show_state(player, countdown, race_time, karts.size())


## Test robot: holds gas, follows the CPU line, answers after 2.5 s.
func _robot(k: Kart) -> Dictionary:
	var ans := -1
	if k.asking and k.ask_t < Kart.ASK_TIME - 2.5:
		ans = randi() % 4
	return {"stick": k._steer_ai(0), "gas": true, "brake": false, "drift_press": false, "drift_held": false, "item": false, "answer": ans}


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
			if k.human:
				k.start_question(Content.tracks[track_index])
			elif randf() < 0.75:
				k.boost_t = maxf(k.boost_t, 0.8)  # the CPUs know their Hamlet, mostly
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
			var wp: float = Kart.STATS[p.ch][3]
			var wq: float = Kart.STATS[q.ch][3]
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


func _camera(dt: float) -> void:
	var r := player
	cam_yaw += wrapf(r.yaw - cam_yaw, -PI, PI) * (1 - exp(-dt * 5))
	var fast := r.boost_t > 0
	cam_boost = Kart.move_toward_exp(cam_boost, 1.0 if fast else 0.0, dt * (6.0 if fast else 2.5))
	var back := CAM_BACK + 24 * cam_boost
	var up := CAM_UP + 6 * cam_boost
	var f := Kart.fwd_of(cam_yaw)
	var target := Vector3(r.x - f.x * back, r.y - r.hop * 0.5 + up, r.z - f.y * back)
	var k := 1 - exp(-dt * 10)
	cam.position = cam.position.lerp(target, k) if dt < 1 else target
	if r.shake_t > 0:
		var s := r.shake_t * 18
		cam.position += Vector3(randf() - 0.5, randf() - 0.5, 0) * s
	cam.fov = 68 + 9 * cam_boost
	cam.look_at(Vector3(r.x + f.x * 70, r.y + 10, r.z + f.y * 70))
