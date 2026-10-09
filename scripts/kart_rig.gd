class_name KartRig
extends Node3D
## A built kart (scripts/kart_build.gd) on screen: the body on springs over
## four wheels, the rider in the seat. Everything moves by turning and
## sliding a few nodes (no skeletons, no per-vertex work), so it's cheap:
## wheels roll and the front pair steers, the body pitches under gas and
## brakes, rolls in bends and settles after a landing, the rider leans into
## the turn and sways a beat behind. Far from the camera each part swaps to
## a light copy, and shadows always come from the light copies.

const NEAR := 420.0  # beyond this the light copies show
const PARTS := "res://assets/models/parts/"
# where each body's hood ornament sits, from the classic racer's nose
const ORN_OFF := {"racer": Vector3.ZERO, "royal": Vector3.ZERO, "coach": Vector3(0, -0.8, -1.5),
	"coffin": Vector3(0, 1.4, -1.5), "ship": Vector3(0, 0.6, -2.5)}
const HIP := Vector3(0, 14, -2)  # the rider leans from here

static var _meshes := {}
static var _shader: Shader

var chassis := Node3D.new()  # body, seat, rider: rides the springs
var rider := Node3D.new()
var wheels: Array[Node3D] = []  # front left, front right, back left, back right
var spins: Array[Node3D] = []
var wheel_r: Array[float] = []
var mat: ShaderMaterial

# springs: value, velocity
var pitch := Vector2.ZERO
var roll := Vector2.ZERO
var heave := Vector2.ZERO
var sway := Vector2.ZERO   # the rider, a beat behind the body
var spin_a := 0.0
var last_speed := 0.0
var last_yaw := 0.0
var was_air := false
var first := true


static func make(ch: int, b: Dictionary) -> KartRig:
	var r := KartRig.new()
	r._build(ch, b)
	return r


static func _mesh(name: String) -> Mesh:
	if not _meshes.has(name):
		var path := PARTS + name + ".glb"
		var m: Mesh = null
		if ResourceLoader.exists(path):
			var scene: Node = load(path).instantiate()
			var mi := scene.find_children("*", "MeshInstance3D", true, false)
			if not mi.is_empty():
				m = mi[0].mesh
			scene.free()
		_meshes[name] = m
	return _meshes[name]


## The kart paint: the parts' key colours (pure green, blue, red) take the
## build's paint, trim and seat, shaded as sculpted; everything else is
## clay as it is. Worked out per vertex, so it costs nothing per pixel.
static func paint_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
uniform vec4 paint : source_color;
uniform vec4 trim : source_color;
uniform vec4 seat : source_color;
varying vec3 col;
varying float gloss;

float key(float d, float a, float b) {
	return (1.0 - smoothstep(0.12, 0.4, max(a, b) / max(d, 0.001))) * smoothstep(0.02, 0.08, d);
}

void vertex() {
	vec3 c = COLOR.rgb;
	vec3 lin = pow(c, vec3(2.2));
	float kp = c.g > max(c.r, c.b) ? key(c.g, c.r, c.b) : 0.0;
	float kt = c.b > max(c.r, c.g) ? key(c.b, c.r, c.g) : 0.0;
	float ks = c.r > max(c.g, c.b) ? key(c.r, c.g, c.b) : 0.0;
	float m = max(c.r, max(c.g, c.b)) / 0.784;  // keys were sculpted at 200/255
	vec3 tint = paint.rgb * kp + trim.rgb * kt + seat.rgb * ks;
	float k = kp + kt + ks;
	col = mix(lin, tint * pow(m, 2.2) / max(k, 0.001), k);
	gloss = kp + kt;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = mix(0.6, 0.32, gloss);
	SPECULAR = 0.5;
	RIM = 0.2;
	RIM_TINT = 0.6;
}
"""
	return _shader


func _build(ch: int, b: Dictionary) -> void:
	mat = ShaderMaterial.new()
	mat.shader = paint_shader()
	recolour(ch, b)
	add_child(chassis)
	_part(chassis, "body_" + b.body, mat, true)
	if int(b.orn) >= 0:
		var o := _part(chassis, "orn_c%02d" % int(b.orn), Cast.clay(), false)
		o.position = ORN_OFF.get(b.body, Vector3.ZERO)
	chassis.add_child(rider)
	rider.position = HIP
	var seat := Node3D.new()
	seat.position = -HIP
	rider.add_child(seat)
	_part(seat, "rider_c%02d" % ch, Cast.clay(), true)
	var axles: Dictionary = KartBuild.data().bodies[b.body]
	for a in [axles.front, axles.front, axles.back, axles.back]:
		var side := 1.0 if wheels.size() % 2 == 0 else -1.0
		var w := Node3D.new()
		w.position = Vector3(side * float(a[0]), float(a[2]), float(a[1]))
		var s := Node3D.new()
		s.scale = Vector3.ONE * float(a[2]) / float(KartBuild.data().wheel_r)
		if side < 0:
			s.rotation.y = PI  # hub cap outward on the right-hand side too
		w.add_child(s)
		var roller := Node3D.new()
		s.add_child(roller)
		_part(roller, "wheel_" + b.wheels, mat, false, false)
		add_child(w)
		wheels.append(w)
		spins.append(roller)
		wheel_r.append(float(a[2]))


func recolour(ch: int, b: Dictionary) -> void:
	mat.set_shader_parameter("paint", Color(b.paint))
	mat.set_shader_parameter("trim", Color(b.trim))
	mat.set_shader_parameter("seat", KartBuild.seat(ch, b))


## One part: the full mesh up close, the light copy far off (and for shadows).
func _part(parent: Node3D, name: String, m: Material, shadow: bool, far := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var hi := _mesh(name)
	var lo := _mesh(name + "_lo") if far else null
	if hi:
		var mi := MeshInstance3D.new()
		mi.mesh = hi
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if lo or not shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.visibility_range_end = NEAR
		mi.visibility_range_end_margin = 30
		root.add_child(mi)
	if lo:
		var mi := MeshInstance3D.new()
		mi.mesh = lo
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_begin = NEAR
		mi.visibility_range_begin_margin = 30
		root.add_child(mi)
		if shadow:
			var sh := MeshInstance3D.new()
			sh.mesh = lo
			sh.material_override = m
			sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			sh.visibility_range_end = NEAR * 2  # (the sun's shadows stop well before)
			root.add_child(sh)
	return root


## A spring toward `target`: stiff and a little bouncy, like clay on springs.
static func _spring(s: Vector2, target: float, dt: float, k := 170.0, d := 13.0) -> Vector2:
	s.y += (-(s.x - target) * k - s.y * d) * dt
	s.x += s.y * dt
	return s


## Move the parts for this frame. `k` is the Kart being shown.
func animate(dt: float, k: Kart) -> void:
	if dt <= 0:
		return
	if first:
		first = false
		last_speed = k.speed
		last_yaw = k.yaw
	var t := Time.get_ticks_msec() / 1000.0
	var accel := clampf((k.speed - last_speed) / dt, -900, 900)
	var yaw_rate := wrapf(k.yaw - last_yaw, -PI, PI) / dt
	last_speed = k.speed
	last_yaw = k.yaw
	var air := k.hop > 0.5
	var turn := clampf(yaw_rate * k.speed / 1200.0, -1, 1)  # sideways pull, -1..1
	# the body: nose up under gas, down under brakes; rolls out of the bend
	var p_target := 0.0 if air else clampf(-accel * 0.00022, -0.09, 0.11)
	var r_target := 0.0 if air else turn * 0.11
	if k.spin_t > 0:
		r_target = sin(t * 30) * 0.12
	# substeps keep the springs steady at low frame rates
	var n := ceili(dt / (1.0 / 120))
	var h := dt / n
	if was_air and not air:  # landing: a thump
		heave.y -= 40
	was_air = air
	for i in n:
		pitch = _spring(pitch, p_target, h)
		roll = _spring(roll, r_target, h)
		heave = _spring(heave, 0.0, h, 220, 11)
		sway = _spring(sway, turn, h, 60, 7)  # the rider: softer, later
	chassis.rotation = Vector3(pitch.x, 0, roll.x)
	var hum := sin(t * 70 + k.ch) * 0.12 * clampf(absf(k.speed) / 300, 0, 1)  # the engine
	chassis.position = Vector3(0, heave.x * 0.06 + hum, 0)
	# squash and stretch: napping flattens; revving squats and shakes;
	# a rocket start stretches; a landing squashes for a moment
	var sq := Vector3(1 - clampf(heave.x * 0.002, -0.05, 0.05), 1 + clampf(heave.x * 0.004, -0.1, 0.1), 1 - clampf(heave.x * 0.002, -0.05, 0.05))
	if k.nap_t > 0:
		sq = Vector3(1.15, 0.6, 1.15)
	elif k.rev > 0.01:
		var throb := 0.5 + 0.5 * absf(sin(t * 18))
		sq = Vector3(1 + 0.10 * k.rev * throb, 1 - 0.16 * k.rev * throb, 1 + 0.08 * k.rev * throb)
		chassis.position += Vector3(sin(t * 61) * k.rev * 1.2, -absf(sin(t * 47)) * k.rev * 1.8, 0)
	elif k.launch_t > 0:
		var u := k.launch_t / 0.45
		sq = Vector3(1 - 0.06 * u, 1 + 0.10 * u, 1 + 0.12 * u)
	chassis.scale = sq
	# the rider leans into the bend (against the body's roll), looks where
	# the kart is going, and is pressed back by a boost
	var boost := 1.0 if k.boost_t > 0 else 0.0
	rider.rotation = Vector3(-0.1 * boost + pitch.x * 0.6, -k.steer * 0.16 - k.slide * 0.22, -sway.x * 0.22 - roll.x * 1.2)
	# wheels roll with the road and the front pair steers
	spin_a += k.speed * dt
	for i in 4:
		# (the right-hand wheels are turned round, so they roll the other way)
		spins[i].rotation.x = spin_a / wheel_r[i] * (1.0 if i % 2 == 0 else -1.0)
		if i < 2:
			wheels[i].rotation.y = -k.steer * 0.42 + k.slide * 0.3
