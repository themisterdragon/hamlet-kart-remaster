class_name Fx
extends Node3D
## Particle effects, after the N64's fx_emit(): wheel dust, boost flames,
## drift sparks (blue, then orange), slipstream streaks, armour sparkles.
## Each look is a pool of billboard quads in one MultiMesh, moved by hand.

enum { DUST, FLAME, SPARK_BLUE, SPARK_ORANGE, STREAK, SPARKLE }
const MAX := 256  # live particles per look

# look: colour, size, lifetime, gravity, glowing (additive), grows (else shrinks)
const LOOKS := [
	[Color(0.75, 0.68, 0.58, 0.55), 9.0, 0.5, -10.0, false, true],
	[Color(1.6, 0.75, 0.2, 1.0), 10.0, 0.35, 20.0, true, false],
	[Color(0.5, 0.8, 2.0, 1.0), 4.0, 0.25, -380.0, true, false],
	[Color(2.0, 0.9, 0.3, 1.0), 4.5, 0.25, -380.0, true, false],
	[Color(1.0, 1.0, 1.0, 0.5), 3.0, 0.25, 0.0, true, false],
	[Color(2.0, 1.8, 1.0, 1.0), 5.0, 0.45, 8.0, true, false],
]

var pools: Array = []  # per look: {mm, pos, vel, age, n}


func _ready() -> void:
	for l in LOOKS:
		var q := QuadMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if l[4] else BaseMaterial3D.BLEND_MODE_MIX
		m.albedo_texture = _soft_dot()
		q.material = m
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = q
		mm.instance_count = MAX
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
		add_child(mi)
		pools.append({"mm": mm, "pos": [], "vel": [], "age": []})


func spawn(kind: int, pos: Vector3, vel: Vector3) -> void:
	var p: Dictionary = pools[kind]
	if p.pos.size() >= MAX:
		return
	p.pos.append(pos)
	p.vel.append(vel)
	p.age.append(0.0)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	for kind in pools.size():
		var p: Dictionary = pools[kind]
		var l: Array = LOOKS[kind]
		var life: float = l[2]
		var i := 0
		while i < p.pos.size():
			p.age[i] += dt
			if p.age[i] >= life:  # dead: swap with the last one
				var last: int = p.pos.size() - 1
				p.pos[i] = p.pos[last]
				p.vel[i] = p.vel[last]
				p.age[i] = p.age[last]
				p.pos.resize(last)
				p.vel.resize(last)
				p.age.resize(last)
				continue
			p.vel[i] += Vector3(0, l[3], 0) * dt
			p.pos[i] += p.vel[i] * dt
			var u: float = p.age[i] / life
			var size: float = l[1] * (lerpf(0.6, 1.4, u) if l[5] else lerpf(1.0, 0.3, u))
			p.mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), p.pos[i]))
			var c: Color = l[0]
			p.mm.set_instance_color(i, Color(c.r, c.g, c.b, c.a * (1 - u)))
			i += 1
		p.mm.visible_instance_count = p.pos.size()


static var _dot: Texture2D


## A round soft spot, made once.
static func _soft_dot() -> Texture2D:
	if _dot == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1 - d * d, 0, 1)))
		_dot = ImageTexture.create_from_image(img)
	return _dot


## One kart's ongoing effects; rates scale with dt, as on the N64.
func emit(k: Kart, dt: float) -> void:
	var f := Kart.fwd_of(k.yaw)
	var fwd := Vector3(f.x, 0, f.y)
	var right := Vector3(-f.y, 0, f.x)
	var at := Vector3(k.x, k.y, k.z)
	var speed := absf(k.speed)
	var side := -1.0 if randf() < 0.5 else 1.0
	if k.rev > 0.2:  # revving on the grid: exhaust puffs, and sparks if a rocket start is lined up
		var back := at - fwd * 20 + Vector3(0, 6, 0)
		if randf() < dt * 12 * k.rev:
			spawn(DUST, back, -fwd * 50 + Vector3((randf() - 0.5) * 30, 15 + randf() * 25, (randf() - 0.5) * 30))
		if k.rev_spark > 0 and randf() < dt * 34:
			spawn(SPARK_ORANGE if k.rev_spark == 2 else SPARK_BLUE, back + Vector3((randf() - 0.5) * 10, 0, (randf() - 0.5) * 10),
				-fwd * 60 + Vector3((randf() - 0.5) * 60, 30 + randf() * 50, (randf() - 0.5) * 60))
	if k.hop <= 0 and speed > 140 and absf(k.steer) > 0.55 and randf() < dt * 18:
		spawn(DUST, at - fwd * 14 + right * 12 * side + Vector3(0, 2, 0), -fwd * 30 + Vector3(0, 18, 0))
	if (k.boost_t > 0 or k.star_t > 0) and randf() < dt * 30:
		spawn(FLAME, at - fwd * 22 + Vector3(0, 9, 0), -fwd * 60 + Vector3(randf() - 0.5, 0.3, randf() - 0.5) * 30)
	if k.draft_t > 0.3 and randf() < dt * 24:
		spawn(STREAK, at + fwd * 30 + right * 18 * side + Vector3(0, 8 + randf() * 20, 0), -fwd * 220)
	if k.drift_dir != 0 and k.drift_t > Kart.DRIFT_BLUE and randf() < dt * 40:
		spawn(SPARK_ORANGE if k.drift_t > Kart.DRIFT_ORANGE else SPARK_BLUE,
			at - fwd * 16 + right * 11 * side + Vector3(0, 3, 0),
			-fwd * 40 + Vector3((randf() - 0.5) * 60, 50 + randf() * 40, (randf() - 0.5) * 60))
	if k.star_t > 0 and randf() < dt * 16:
		var a := randf() * TAU
		spawn(SPARKLE, at + Vector3(cos(a) * 20, 10 + randf() * 34, sin(a) * 20), Vector3(0, 20, 0))
