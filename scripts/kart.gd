class_name Kart
extends Node3D
## One racer: the N64's kart_update() (src/race.c), in the same units and
## with the same numbers, so the remaster handles like the cartridge.
## The race (scripts/race.gd) owns items in flight, hazards and bumps.

const TOP_SPEED := 470.0
const ACCEL := 330.0
const TURN_RATE := 2.5
const KART_R := 15.0
const DRIFT_BLUE := 0.55   # seconds of sliding for the short mini-turbo
const DRIFT_ORANGE := 1.25  # ... and for the long one
const ASK_TIME := 12.0
const VERDICT_RIGHT := 0.5
const VERDICT_WRONG := 1.3
const CLASS_SPEED := [0.84, 1.0, 1.13]  # Freshman, Sophomore, Senior
# speed, accel, turn, weight (src/race.c STATS)
const STATS := [
	[1.00, 1.00, 1.00, 1.0],  # Hamlet: balanced, like his indecision
	[1.04, 0.86, 0.90, 1.3],  # Claudius: heavy crown
	[1.00, 0.96, 1.05, 1.0],  # Gertrude
	[0.96, 1.14, 1.15, 0.8],  # Ophelia: light
	[1.05, 0.80, 0.88, 1.3],  # Polonius: slow to get going, won't stop
	[1.03, 1.02, 0.95, 1.1],  # Laertes: hothead
	[0.98, 1.06, 1.10, 0.9],  # Horatio: sensible
	[0.97, 1.12, 1.15, 0.7],  # The Ghost: floaty
]
const KART_FRAMES := 32
const KART_PX_PER_UNIT := 0.9  # tools/make_sprites.py
const KART_ANCHOR_Y := 58       # frame row the wheels sit on
const RAMP_H := 14.0     # the launch ramp's lip
const PAD_LEN := 2       # samples a boost pad covers
const PAD_HALF := 22.0   # half its width
enum { IT_NONE = -1, IT_ESPRESSO, IT_SKULL, IT_LETTER, IT_MOUSETRAP, IT_ARMOR, IT_SHIP, IT_POISON }

var track: Track
var race  # scripts/race.gd: items are used through it
var peer := ""  # online: the player driving this kart ("" = here or a CPU)
var ch := 0
var human := false
var race_class := 1

var x := 0.0
var y := 0.0
var z := 0.0
var yaw := 0.0
var speed := 0.0
var steer := 0.0
var slide := 0.0
var knock := Vector2.ZERO
var hop := 0.0
var hop_v := 0.0
var seg := 0
var seg_t := 0.0
var lat := 0.0
var prev_seg := 0
var lap := -1
var progress := 0.0
var place := 0
var finished := false
var finish_time := 0.0

var boost_t := 0.0
var bump_t := 0.0
var shake_t := 0.0
var drift_dir := 0
var drift_arm := false
var drift_t := 0.0
var airborne := false   # launched off the ramp: land straight for a boost
var pad_t := 0.0        # boost pad cool-down

# items and what they do to you
var item := IT_NONE
var roulette_t := 0.0   # the item box spinning before it lands
var holding := false    # Yorick's Skull held behind the kart, as a shield
var hold_t := 0.0
var spin_t := 0.0
var star_t := 0.0       # Ghost's Armor: can't be hit, rams others
var ship_t := 0.0       # Pirate Ship: carried ahead
var nap_t := 0.0        # Poison in the Ear: slowed to a crawl
var draft_t := 0.0      # slipstream building up behind a kart
var start_press := 0.0  # countdown value when gas went down (rocket start)

# the quiz
var asking := false
var ask_t := 0.0
var question: Dictionary   # {q, answers, correct, index}
var verdict_t := 0.0
var verdict_ok := false
var answered := -1
var retry_q := -1          # a missed question comes back at the next box
var used_q: Array[int] = []
var streak := 0
var right := 0
var wrong := 0

# CPU driving
var ai_lane := 0.0
var ai_think := 0.0
var ai_alt := false

var sprite: Sprite3D


func setup(t: Track, character: int, is_human: bool, grid_slot: int) -> void:
	track = t
	ch = character
	human = is_human
	var row := grid_slot / 2
	var col := grid_slot % 2
	seg = posmod(t.n - 2 - row, t.n)
	lat = (1 if col else -1) * t.road_half * 0.45
	var p := t.point(seg, 0.0 if row % 2 else 0.5, lat)
	x = p.x
	y = p.y
	z = p.z
	yaw = t.yaw_at(seg)
	prev_seg = seg
	ai_lane = lat / t.road_half
	sprite = Sprite3D.new()
	sprite.texture = load("res://assets/images/karts/k%02d.png" % ch)
	sprite.hframes = 8
	sprite.vframes = 4
	sprite.pixel_size = 1.0 / KART_PX_PER_UNIT
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.offset = Vector2(0, KART_ANCHOR_Y - 32)  # wheels on the road (+y is up)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.shaded = false
	add_child(sprite)
	_place()


static func fwd_of(a: float) -> Vector2:
	return Vector2(sin(a), cos(a))


func top_speed() -> float:
	return TOP_SPEED * STATS[ch][0] * CLASS_SPEED[race_class]


func immune() -> bool:
	return star_t > 0 or ship_t > 0


## One frame. `pad` (humans): {stick, stick_y: -1..1, gas, brake, drift_press,
## drift_held, item, item_held, answer: -1..3}.
func update(dt: float, pad: Dictionary, countdown: float, best_human_progress: float) -> void:
	if countdown > 0:
		y = track.height(seg, seg_t)
		# rocket start: note when gas went down; letting go resets it
		if human:
			if not pad.gas:
				start_press = 0
			elif start_press <= 0:
				start_press = countdown
		_place()
		return
	var st: Array = STATS[ch]
	var steer_in := 0.0
	var gas := false
	var brake := false

	if human and not finished:
		var sx: float = clampf(pad.stick, -1, 1)
		# response curve: small nudges steer gently, full stick still turns fully
		var mag := 0.0 if absf(sx) < 0.15 else (absf(sx) - 0.15) / 0.85
		steer_in = signf(sx) * pow(mag, 1.6)
		gas = pad.gas
		brake = pad.brake
		if pad.item:
			race.use_item(self)
		if holding:
			hold_t += dt
			if not pad.item_held:
				race.release_skull(self, pad.stick_y < -0.4)  # stick pulled back: roll it behind
		if asking or verdict_t > 0:
			# the kart drives itself while the question is up, and until the
			# verdict strip has gone, so the wheel comes back with the road clear
			var ai := _steer_ai(dt)
			steer_in = ai
			gas = true
			brake = false
			if asking and pad.answer >= 0:
				answer(pad.answer)
			drift_dir = 0
			drift_arm = false
		else:
			# hop-drift: R hops; with R held, the slide starts as soon as the
			# stick leans either way. Let go for a blue or orange mini-turbo.
			if pad.drift_press and hop <= 0.5 and drift_dir == 0:
				hop_v = 110
				drift_arm = true
			if drift_arm and not pad.drift_held:
				drift_arm = false
			if drift_arm and absf(sx) > 0.35 and speed > 120:
				drift_arm = false
				drift_dir = 1 if sx > 0 else -1
				drift_t = 0
			if drift_dir != 0:
				if not pad.drift_held or spin_t > 0 or speed < 100:
					if not pad.drift_held and spin_t <= 0 and drift_t > DRIFT_BLUE:
						boost_t = maxf(boost_t, 1.4 if drift_t > DRIFT_ORANGE else 0.7)
					drift_dir = 0
				else:
					# centred holds a medium arc, into the bend tightens, away widens
					steer_in = drift_dir * (0.45 + 0.2 * clampf(sx * drift_dir, -1, 1))
					drift_t += dt
	else:
		steer_in = _steer_ai(dt)
		gas = true
		# CPUs drift through the sharp bends too
		if item != IT_NONE and roulette_t <= 0 and randf() < dt * 0.5:  # CPU items: used after a short think
			race.use_item(self)
		if drift_dir == 0 and absf(steer_in) > 0.75 and speed > 260 and hop <= 0 and spin_t <= 0:
			drift_dir = 1 if steer_in > 0 else -1
			drift_t = 0
			hop_v = 90
		elif drift_dir != 0:
			drift_t += dt
			if steer_in * drift_dir < 0.2 or spin_t > 0 or drift_t > 2.4:
				if drift_t > DRIFT_BLUE and spin_t <= 0:
					boost_t = maxf(boost_t, 1.1 if drift_t > DRIFT_ORANGE else 0.5)
				drift_dir = 0

	if ship_t > 0 or (human and finished):  # the pirate ship, and after the finish line
		var tp := track.point(seg + 6, 0, 0)
		steer_in = clampf(-wrapf(atan2(tp.x - x, tp.z - z) - yaw, -PI, PI) * 2.5, -1, 1)
		gas = true
		brake = false

	var top := top_speed()
	if not human:
		# rubber band: CPUs ease off ahead of the best human, push behind
		var gap := (progress - best_human_progress) / track.n
		top *= clampf(0.95 - gap * 0.25, 0.86, 1.04)
	if boost_t > 0:
		top *= 1.45
	if star_t > 0:
		top *= 1.15
	if ship_t > 0:
		top *= 1.4
	if nap_t > 0:
		top *= 0.4

	if spin_t > 0:
		speed = move_toward_exp(speed, 0, dt * 3)
		steer_in = 0
	elif boost_t > 0 or ship_t > 0:
		speed = move_toward_exp(speed, top, dt * 4)
	elif gas:
		if speed < top:
			speed += ACCEL * st[1] * CLASS_SPEED[race_class] * dt
		if speed > top:
			speed = move_toward_exp(speed, top, dt * 2.5)
	elif brake:
		speed = maxf(speed - 600 * dt, -140)
	else:
		speed = move_toward_exp(speed, 0, dt * 0.9)

	# steering eases in, a slide swings in and out; calmer at top speed
	var grip := clampf(absf(speed) / 140, 0, 1) * (-1.0 if speed < 0 else 1.0)
	steer = move_toward_exp(steer, steer_in, dt * (3.0 if human and (drift_dir != 0 or absf(slide) > 0.1) else 6.0))
	slide = move_toward_exp(slide, drift_dir, dt * 5)
	var calm := 1.0 if drift_dir != 0 else 1 - 0.2 * clampf(absf(speed) / TOP_SPEED, 0, 1)
	yaw -= steer * TURN_RATE * st[2] * grip * calm * dt

	var f := fwd_of(yaw)
	x += (f.x * speed + knock.x) * dt
	z += (f.y * speed + knock.y) * dt
	knock *= exp(-dt * 5)

	_walls(dt)

	# hop
	hop_v -= 520 * dt
	hop += hop_v * dt
	if hop < 0:
		if airborne:
			airborne = false
			# land pointing down the road for a little boost
			if absf(wrapf(track.yaw_at(seg) - yaw, -PI, PI)) < 0.25:
				boost_t = maxf(boost_t, 0.6)
		hop = 0
		hop_v = 0
	y = track.height(seg, seg_t) + hop

	# laps
	var n := track.n
	if prev_seg > n * 3 / 4 and seg < n / 4:
		lap += 1
	elif prev_seg < n / 4 and seg > n * 3 / 4:
		lap -= 1
	prev_seg = seg
	progress = lap * n + seg + seg_t

	# the launch ramp: fast karts fly
	if track.ramp >= 0 and seg == track.ramp and not airborne and speed > 200 and absf(lat) < track.road_half:
		hop = maxf(hop, RAMP_H * seg_t)  # ride up the wedge
		hop_v = maxf(hop_v, 0)
		if seg_t > 0.8:
			hop_v = 130 + speed * 0.18
			airborne = true
			drift_dir = 0
			drift_arm = false
	# boost pads
	if pad_t <= 0:
		for p in track.pads:
			if posmod(seg - p.seg, n) < PAD_LEN and absf(lat - p.lat) <= PAD_HALF + 6:
				boost_t = maxf(boost_t, 1.0)
				pad_t = 0.8
				race.on_boost(self)

	for k in ["boost_t", "bump_t", "shake_t", "verdict_t", "spin_t", "star_t", "ship_t", "nap_t", "pad_t", "roulette_t"]:
		set(k, maxf(get(k) - dt, 0))
	if asking:
		ask_t -= dt
		if ask_t <= 0:
			answer(-1)
	_place()


## Knocked into a spin (items; scenery only ever bumps).
func hit(spin: float) -> void:
	if immune() or finished:
		return
	if holding:  # knocked out of your hands
		holding = false
		item = IT_NONE
	shake_t = 0.35
	spin_t = maxf(spin_t, spin)
	speed *= 0.35
	hop_v = 140
	race.on_hit(self)


static func move_toward_exp(from: float, to: float, k: float) -> float:
	return from + (to - from) * (1 - exp(-k))


func _walls(dt: float) -> void:
	var loc := track.locate(x, z, seg)
	seg = loc[0]
	seg_t = loc[1]
	lat = loc[2]
	var r := track.lat_range(seg, seg_t, lat)
	var lo := r.x + KART_R
	var hi := r.y - KART_R
	if lat <= hi and lat >= lo:
		return
	# bumper barrier: push back inside and bounce off toward the road
	var s := 1.0 if lat > hi else -1.0
	var lim := hi if s > 0 else lo
	var push := (lat - lim) * s
	var rv := track.right(seg)
	x -= rv.x * push * s
	z -= rv.y * push * s
	lat = lim
	var f := fwd_of(yaw)
	var vel := f * speed + knock
	var into := vel.dot(rv) * s
	var kin := knock.dot(rv) * s
	if kin > 0:
		knock -= rv * s * kin
	if into > 10:
		var out := clampf(into * 0.9 + 40, 60, 220)
		knock -= rv * s * out
		if bump_t <= 0:
			speed *= 0.85
			bump_t = 0.3
			shake_t = maxf(shake_t, 0.12)
			if hop <= 0:
				hop_v = maxf(hop_v, 45)
	# turn the nose away from the barrier, back along the road
	var along := track.yaw_at(seg)
	if speed < 0:
		along += PI
	yaw += wrapf(along - yaw, -PI, PI) * (1 - exp(-dt * 8))


## The CPU line (also the auto-drive while a question is up): returns steer.
func _steer_ai(dt: float) -> float:
	ai_think -= dt
	if ai_think <= 0:
		ai_think = 1.5 + randf() * 2
		ai_lane = (randf() * 2 - 1) * 0.55
	var look := 5 + int(speed / 160)
	var lane := ai_lane * track.road_half
	if track.split_a >= 0:
		if seg == posmod(track.split_a - 6, track.n):
			ai_alt = randf() < 0.45
		var off := track.split_off(posmod(seg + look, track.n), 0)
		if human and (asking or verdict_t > 0):  # a player on auto-drive keeps to the route they're on
			var here := track.split_off(seg, seg_t)
			ai_alt = here != 0 and (lat - here / 2) * track.split_peak > 0
		if off != 0 and ai_alt:
			lane = off + ai_lane * track.road_half * 0.5
	var tp := track.point(seg + look, 0, lane)
	var diff := wrapf(atan2(tp.x - x, tp.z - z) - yaw, -PI, PI)
	return clampf(-diff * 2.2, -1, 1)  # steering right lowers yaw


# --------------------------------------------------------------- the quiz

func start_question(content_track: Dictionary) -> void:
	var pool: Array = content_track.questions
	var qi := retry_q
	if qi < 0:
		# avoid repeats until the pool runs out
		if used_q.size() >= pool.size():
			used_q.clear()
		qi = randi() % pool.size()
		while qi in used_q:
			qi = (qi + 1) % pool.size()
		used_q.append(qi)
	var src: Dictionary = pool[qi]
	var answers: Array = [src.answer] + src.wrong
	answers.shuffle()
	question = {"q": src.q, "answers": answers, "correct": answers.find(src.answer), "index": qi}
	asking = true
	ask_t = ASK_TIME
	answered = -1
	verdict_t = 0


## Quiz as turbo: a right answer is a surge of speed; three in a row is a
## long turbo. A miss costs nothing but the reward, the right answer is
## always shown, and the missed question comes back at the next box.
func answer(slot: int) -> void:
	asking = false
	answered = slot
	verdict_ok = slot >= 0 and slot == question.correct
	verdict_t = VERDICT_RIGHT if verdict_ok else VERDICT_WRONG
	retry_q = -1 if verdict_ok else int(question.index)
	if verdict_ok:
		right += 1
		streak += 1
		var hot := streak >= 3
		if hot:
			streak = 0
		boost_t = maxf(boost_t, 1.8 if hot else 0.8)
		race.give_item(self, 1 if hot else 0)
	else:
		wrong += 1
		streak = 0


# ----------------------------------------------------------------- drawing

func _place() -> void:
	position = Vector3(x, y, z)


## Pick the sprite frame for this camera: the kart's heading against the
## line of sight; steering and sliding lean it into the turn.
func face(cam: Vector3) -> void:
	var view_yaw := atan2(x - cam.x, z - cam.z)
	var rel := view_yaw - yaw + spin_t * 14  # a spin-out whirls it
	var fr := rel / (TAU / KART_FRAMES) + clampf(steer, -1, 1) * 1.6 + slide * 1.5
	sprite.frame = posmod(roundi(fr), KART_FRAMES)
	var bob := 0.0 if hop > 0 else sin(Time.get_ticks_msec() / 1000.0 * 22 + ch) * clampf(absf(speed) / 300, 0, 1) * 0.8
	sprite.position.y = bob
	# napping squashes; the armour glows gold and blinks
	sprite.scale = Vector3(1.15, 0.6, 1) if nap_t > 0 else Vector3.ONE
	sprite.modulate = Color(1.0, 0.85, 0.4) if star_t > 0 and int(star_t * 12) % 2 == 0 else Color.WHITE
	sprite.visible = ship_t <= 0  # aboard the pirate ship



# ------------------------------------------------------------- online

const SNAP := ["x", "y", "z", "yaw", "steer", "slide", "hop", "speed", "spin_t", "star_t", "ship_t", "nap_t",
	"boost_t", "shake_t", "bump_t", "place", "lap", "finished", "finish_time", "item", "roulette_t", "holding",
	"asking", "ask_t", "verdict_t", "verdict_ok", "answered", "right", "wrong", "drift_dir", "drift_t"]


## (host) This kart's state for players' screens.
func snap() -> Array:
	var a := []
	for k in SNAP:
		var v = get(k)
		a.append(snappedf(v, 0.01) if v is float else v)
	return a


## (player) Show the host's state.
func apply(a: Array) -> void:
	for i in SNAP.size():
		var k: String = SNAP[i]
		var v = a[i]
		match typeof(get(k)):
			TYPE_INT:
				set(k, int(v))
			TYPE_BOOL:
				set(k, bool(v))
			_:
				set(k, float(v))
	_place()
