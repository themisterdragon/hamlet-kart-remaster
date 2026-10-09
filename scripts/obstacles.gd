class_name Obstacles
extends Node3D
## Things in the road. Hazards (data/tracks.json) cross the road each in its
## own way: barrels roll, goblets and skulls bounce, censers and banners
## swing from above, ghosts drift up and down the road, ships and tombs
## rock. They squash at each turn and wobble when a kart brushes them.
## Loose clutter (barrels, books, goblets...) sits in little piles that karts
## send flying; it comes back a few seconds later.
## The rule from the N64 stands: nothing here costs more than a wrong
## answer. A hazard is a light bump to the side, no spin; clutter barely
## slows you; anyone answering passes straight through.
## Hazards move by the race clock, so every screen in a class race shows
## them the same; the host sends where flying clutter is (snapshot()).

const SWING_H := 150.0  # how high the swinging hazards hang from
const KIND := {
	"BARREL": "roll", "WORM": "crawl", "GOBLET": "bounce", "SKULLS": "bounce", "FLOWERS": "bounce",
	"CENSER": "swing", "BANNER": "swing", "ARRAS": "swing", "SWORDS": "swing",
	"GHOST": "float", "SHIP": "rock", "TENT": "rock", "TOMB": "rock", "SPYBUSH": "rock",
}
const CLUTTER := ["BARREL", "BOOKS", "GOBLET", "SKULLS", "CROWN", "FLOWERS"]
const CLUTTER_SCALE := 0.5
const GRAVITY := 600.0
const COME_BACK := 6.0

var race  # scripts/race.gd: bumps go through it
var track: Track
var hazards: Array = []  # {sample, speed, phase, kind, node, tell, rope, jolt: Vector2}
var loose: Array = []    # {node, home, pos, prev, vel, rot, spin, t (seconds since knocked, -1 resting)}


func setup(r, t: Track, index: int) -> void:
	race = r
	track = t
	var shadow := CylinderMesh.new()
	shadow.top_radius = 34
	shadow.bottom_radius = 34
	shadow.height = 0.5
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0, 0, 0, 0.35)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material = smat
	var rope_mesh := CylinderMesh.new()
	rope_mesh.top_radius = 1.0
	rope_mesh.bottom_radius = 1.0
	rope_mesh.height = 1.0
	rope_mesh.radial_segments = 6
	rope_mesh.rings = 1
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color("3a3030")
	rope_mesh.material = rmat
	for h in Track.data().tracks[index].hazards:
		var node := Props.make(h.prop, t.theme)
		add_child(node)
		var tell := MeshInstance3D.new()  # a shadow where it'll be in a moment
		tell.mesh = shadow
		tell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tell)
		var kind: String = KIND.get(h.prop, "sweep")
		var rope: MeshInstance3D = null
		if kind == "swing":
			rope = MeshInstance3D.new()
			rope.mesh = rope_mesh
			add_child(rope)
			_gantry(int(float(h.at) * t.n))
		hazards.append({"sample": int(float(h.at) * t.n), "speed": float(h.speed), "phase": float(h.phase),
			"kind": kind, "node": node, "tell": tell, "rope": rope, "jolt": Vector2.ZERO})
	_clutter(index)


## A wooden beam across the road on two posts, for a swinging hazard to hang from.
func _gantry(sample: int) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3a22")
	wood.roughness = 0.8
	var w := track.road_half + track.shoulder + 16
	var top := SWING_H + 12
	var root := Node3D.new()
	root.position = track.point(sample, 0, 0)
	root.rotation.y = track.yaw_at(sample)
	add_child(root)
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(10, top + 20, 10)
		pb.material = wood
		post.mesh = pb
		post.position = Vector3(side * w, (top + 20) / 2 - 10, 0)
		root.add_child(post)
	var beam := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(w * 2 + 16, 10, 12)
	bb.material = wood
	beam.mesh = bb
	beam.position = Vector3(0, top, 0)
	root.add_child(beam)


## Two little piles per track, away from the start, the question boxes,
## boost pads, the ramp and the hazards. The same every time for a track,
## so players' screens build the same piles as the host's.
func _clutter(index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (index + 1)
	var avoid: Array = [0.0, 0.14, 0.47, 0.76]
	for h in hazards:
		avoid.append(float(h.sample) / track.n)
	for p in track.pads:
		avoid.append(float(p.seg) / track.n)
	if track.ramp >= 0:
		avoid.append(float(track.ramp) / track.n)
	for spot in [0.26, 0.6]:
		var at: float = spot
		for tries in 12:
			var ok := true
			for a in avoid:
				if absf(wrapf(at - a, -0.5, 0.5)) < 0.04:
					ok = false
			if ok:
				break
			at = spot + rng.randf_range(-0.08, 0.08)
		var prop: String = CLUTTER[rng.randi() % CLUTTER.size()]
		var lane := rng.randf_range(-0.5, 0.5) * track.road_half
		for j in 4:
			var s := posmod(int(at * track.n) + j / 2, track.n)
			var home := track.point(s, (j % 2) * 0.5, lane + (j - 1.5) * 26)
			var node := Props.make(prop, track.theme)
			node.scale = Vector3.ONE * CLUTTER_SCALE
			node.position = home
			node.rotation.y = rng.randf() * TAU
			add_child(node)
			loose.append({"node": node, "home": home, "pos": home, "prev": home, "vel": Vector3.ZERO,
				"rot": node.rotation, "spin": Vector3.ZERO, "t": -1.0, "yaw0": node.rotation.y})


## Where hazard z is at race time `time`: [position, rotation, scale].
func _hazard_pose(z: Dictionary, time: float) -> Array:
	var swing := track.road_half - 28
	var w: float = z.speed * 1.1
	var ph: float = time * w + z.phase
	var lat := sin(ph) * swing
	var heading := track.yaw_at(z.sample) + PI / 2 * (1.0 if cos(ph) > 0 else -1.0)
	var rot := Vector3(0, heading, 0)
	var sc := Vector3.ONE
	var pos: Vector3
	var turn := 1.0 - absf(cos(ph))  # 1 at each end of its run, where it turns round
	match z.kind:
		"float":  # ghosts weave and drift up and down the road too
			var along := sin(ph * 0.5) * 2.5
			var s := int(floor(along))
			pos = track.point(z.sample + s, along - s, lat) + Vector3(0, 14 + sin(time * 3) * 8, 0)
			rot.z = -cos(ph) * 0.25
		"swing":  # a pendulum from high above: lowest in the middle of the road
			var ang := asin(clampf(lat / SWING_H, -0.95, 0.95))
			pos = track.point(z.sample, 0, lat) + Vector3(0, SWING_H * (1 - cos(ang)) + 6, 0)
			rot = Vector3(0, track.yaw_at(z.sample), ang)  # hangs off the rope, across the road
		_:
			pos = track.point(z.sample, 0, lat)
			match z.kind:
				"roll":  # rolls the way it's going
					rot.x = lat / 14.0 * (1.0 if cos(ph) > 0 else -1.0)
				"bounce":
					var hop := absf(sin(ph * 4))
					pos.y += hop * 26
					var land := 1.0 - smoothstep(0.0, 0.35, hop)  # squashed as it lands
					sc = Vector3(1 + 0.18 * land, 1 - 0.25 * land, 1 + 0.18 * land)
				"rock":
					rot.z = sin(time * 2.4 + z.phase) * 0.12
					rot.x = sin(time * 1.7 + z.phase) * 0.06
				"crawl":  # an inchworm: stretch, then bunch up
					var c := sin(ph * 6)
					sc = Vector3(1, 1 + 0.2 * maxf(c, 0), 1 + 0.3 * c)
	if z.kind != "swing" and z.kind != "crawl":
		# squash a little at each end of the run, as it turns round
		sc *= Vector3(1 + 0.12 * turn * turn, 1 - 0.14 * turn * turn, 1 + 0.12 * turn * turn)
	# a kart's brush wobbles it
	var j: Vector2 = z.jolt
	rot.z += j.x * 0.03
	sc *= Vector3(1 + j.x * 0.006, 1 - j.x * 0.01, 1 + j.x * 0.006)
	return [pos, rot, sc]


## One fixed step: wobbles, knocks and bumps. `collide`: off on players'
## screens in a class race (the host decides who's bumped; wobbles are just looks).
func step(dt: float, karts: Array, time: float, collide: bool) -> void:
	for z in hazards:
		var pos: Vector3 = _hazard_pose(z, time)[0]
		var high := pos.y - track.point(z.sample, 0, 0).y > 24  # bouncing or swinging over the karts
		var j: Vector2 = z.jolt
		for o in karts:
			var d := Vector2(o.x - pos.x, o.z - pos.z)
			if d.length_squared() >= 44 * 44 or high:
				continue
			if absf(j.x) < 4:
				j.y += 60 + absf(o.speed) * 0.1
			if not collide or o.asking or o.verdict_t > 0 or o.bump_t > 0 or o.immune():
				continue
			o.speed *= 0.8
			race._bump(o, race._side_toward(o, d), 170)
		j.y += (-j.x * 120 - j.y * 6) * dt
		j.x += j.y * dt
		z.jolt = j
	for l in loose:
		l.prev = l.pos
		if l.t < 0:
			if not collide:
				continue
			for o in karts:
				var d := Vector2(l.pos.x - o.x, l.pos.z - o.z)
				if d.length_squared() >= 24 * 24:
					continue
				var f := Kart.fwd_of(o.yaw)
				var away := d.normalized() if d.length() > 0.1 else f
				var sp := maxf(absf(o.speed), 120.0)
				l.vel = Vector3(f.x, 0, f.y) * sp * 0.7 + Vector3(away.x, 0, away.y) * sp * 0.5 + Vector3(0, 160 + sp * 0.25, 0)
				l.spin = Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
				l.t = 0.0
				if not (o.asking or o.verdict_t > 0 or o.immune()):
					o.speed *= 0.95  # a clatter, hardly a slowdown
					o.shake_t = maxf(o.shake_t, 0.08)
				break
			continue
		l.t += dt
		l.vel.y -= GRAVITY * dt
		l.pos += l.vel * dt
		l.rot += l.spin * dt
		if l.pos.y < l.home.y and l.vel.y < 0:  # bounce, losing most of it
			l.pos.y = l.home.y
			l.vel = Vector3(l.vel.x * 0.6, -l.vel.y * 0.35, l.vel.z * 0.6)
			l.spin *= 0.6
		if l.t > COME_BACK:
			l.t = -1.0
			l.pos = l.home
			l.prev = l.home
			l.vel = Vector3.ZERO
			l.rot = Vector3(0, l.yaw0, 0)


## Draw everything at race time `time`, part way between steps (a, 0..1).
func pose(time: float, a := 1.0) -> void:
	for z in hazards:
		var p := _hazard_pose(z, time)
		z.node.position = p[0]
		z.node.rotation = p[1]
		z.node.scale = p[2]
		var ahead := _hazard_pose(z, time + 0.8)[0] as Vector3
		var ground := track.point(z.sample, 0, 0).y
		z.tell.position = Vector3(ahead.x, ground + 1.2, ahead.z)
		if z.rope:
			var top := track.point(z.sample, 0, 0) + Vector3(0, SWING_H + 6, 0)
			var hang := (top - (p[0] as Vector3)).normalized()  # it hangs along its rope
			z.node.basis = Basis(Quaternion(Vector3.UP, hang)) * Basis(Vector3.UP, track.yaw_at(z.sample)) * Basis.from_scale(p[2])
			var bottom: Vector3 = p[0] + hang * 30
			var dir := (top - bottom).normalized()
			z.rope.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1, top.distance_to(bottom), 1)), (top + bottom) / 2)
	for l in loose:
		var n: Node3D = l.node
		n.position = (l.prev as Vector3).lerp(l.pos, a)
		n.rotation = l.rot
		var pop := 1.0
		if l.t > COME_BACK - 0.4:  # shrink away, ready to come back
			pop = clampf((COME_BACK - l.t) / 0.4, 0, 1)
		n.scale = Vector3.ONE * CLUTTER_SCALE * pop


## (host) Clutter that isn't at rest: [index, x, y, z, rx, ry, rz, t].
func snapshot() -> Array:
	var out := []
	for i in loose.size():
		var l: Dictionary = loose[i]
		if l.t >= 0:
			out.append([i, snappedf(l.pos.x, 0.1), snappedf(l.pos.y, 0.1), snappedf(l.pos.z, 0.1),
				snappedf(l.rot.x, 0.01), snappedf(l.rot.y, 0.01), snappedf(l.rot.z, 0.01), snappedf(l.t, 0.01)])
	return out


## (player) Show the host's flying clutter; the rest is at home.
func apply(a: Array) -> void:
	var moving := {}
	for e in a:
		moving[int(e[0])] = e
	for i in loose.size():
		var l: Dictionary = loose[i]
		if moving.has(i):
			var e: Array = moving[i]
			l.prev = l.pos if l.t >= 0 else Vector3(e[1], e[2], e[3])
			l.pos = Vector3(e[1], e[2], e[3])
			l.rot = Vector3(e[4], e[5], e[6])
			l.t = float(e[7])
		elif l.t >= 0:
			l.t = -1.0
			l.pos = l.home
			l.prev = l.home
			l.rot = Vector3(0, l.yaw0, 0)
