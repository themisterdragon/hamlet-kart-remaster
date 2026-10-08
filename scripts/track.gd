class_name Track
extends Node3D
## One race track, built from data/tracks.json (the N64 edition's own layouts).
## Everything is in N64 units (road half width 150), so the handling numbers
## carry over unchanged; the maths matches the N64's src/track.c.

const CURB_W := 14.0
const WALL_H := 26.0
const WALL_T := 10.0  # barrier thickness
# the road's material: 0 cobbles, 1 flagstones, 2 planks, 3 carpet, 4 earth, 5 sand
const ROAD_MATERIAL := [0, 3, 4, 0, 0, 0, 4, 2, 1, 3, 1, 4, 4, 5, 4, 1]
const TEX_MEAN := 214.0 / 255.0  # the road textures' average brightness

static var _data: Dictionary

var index := 0
var road_half := 150.0
var shoulder := 20.0
var wall_dist := 170.0
var pts := PackedVector3Array()
var fwd := PackedVector2Array()  # unit direction along the road at each sample (x, z)
var n := 0
var split_a := -1
var split_b := -1
var split_peak := 0.0
var theme: Dictionary
var props: Array
var ground_y := 0.0
var centre := Vector2.ZERO


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/tracks.json"))
	return _data


func load_track(i: int) -> void:
	index = i
	var d := data()
	var t: Dictionary = d.tracks[i]
	road_half = d.road_half
	shoulder = d.shoulder
	wall_dist = road_half + shoulder
	theme = t.theme
	props = t.props
	pts.clear()
	for p in t.points:
		pts.append(Vector3(p[0], p[1], p[2]))
	n = pts.size()
	if t.split != null:
		split_a = int(t.split.a)
		split_b = int(t.split.b)
		split_peak = float(t.split.peak)
	fwd.resize(n)
	ground_y = INF
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in n:
		var a := P(k - 1)
		var b := P(k + 1)
		fwd[k] = Vector2(b.x - a.x, b.z - a.z).normalized()
		ground_y = minf(ground_y, pts[k].y)
		lo = lo.min(Vector2(pts[k].x, pts[k].z))
		hi = hi.max(Vector2(pts[k].x, pts[k].z))
	centre = (lo + hi) / 2
	_build()


func wrapi_n(k: int) -> int:
	return posmod(k, n)


func P(k: int) -> Vector3:
	return pts[posmod(k, n)]


func right(k: int) -> Vector2:
	var f := fwd[posmod(k, n)]
	return Vector2(-f.y, f.x)


func height(k: int, t: float) -> float:
	return lerpf(P(k).y, P(k + 1).y, t)


func point(k: int, t: float, lat: float) -> Vector3:
	var a := P(k)
	var b := P(k + 1)
	var r := right(k)
	return Vector3(lerpf(a.x, b.x, t) + r.x * lat, lerpf(a.y, b.y, t), lerpf(a.z, b.z, t) + r.y * lat)


func yaw_at(k: int) -> float:
	var f := fwd[posmod(k, n)]
	return atan2(f.x, f.y)


## Closest point on segment k: returns [distance squared, t, lat].
func _project(k: int, x: float, z: float) -> Array:
	var a := P(k)
	var b := P(k + 1)
	var dx := b.x - a.x
	var dz := b.z - a.z
	var u := clampf(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	var px := a.x + dx * u
	var pz := a.z + dz * u
	var r := right(k)
	var lat := (x - a.x) * r.x + (z - a.z) * r.y
	return [(x - px) * (x - px) + (z - pz) * (z - pz), u, lat]


## Where a point is on the road, searching near `hint`: returns [seg, t, lat].
func locate(x: float, z: float, hint: int) -> Array:
	var best := hint
	var bd := INF
	var bt := 0.0
	var bl := 0.0
	for k in range(-6, 7):
		var i := posmod(hint + k, n)
		var r := _project(i, x, z)
		if r[0] < bd:
			bd = r[0]
			best = i
			bt = r[1]
			bl = r[2]
	var lost := wall_dist * 2 + absf(split_peak)  # (the other route of a split is this far out)
	if bd > lost * lost:
		var g := locate_global(x, z)
		if g != hint:
			return locate(x, z, g)
	return [best, bt, bl]


func locate_global(x: float, z: float) -> int:
	var best := 0
	var bd := INF
	for i in n:
		var d: float = _project(i, x, z)[0]
		if d < bd:
			bd = d
			best = i
	return best


## How far a split's other route swings out here (0 = no split here).
func split_off(seg: int, t: float) -> float:
	if split_a < 0:
		return 0.0
	var s := seg + t
	if s <= split_a or s >= split_b:
		return 0.0
	var k := sin(PI * (s - split_a) / (split_b - split_a))
	return split_peak * k * k


## The barriers either side of a kart: main road, or a split's other route.
func lat_range(seg: int, t: float, lat: float) -> Vector2:
	var lo := -wall_dist
	var hi := wall_dist
	var off := split_off(seg, t)
	if off == 0:
		return Vector2(lo, hi)
	if absf(off) <= 2 * wall_dist:  # side by side: one wide road
		return Vector2(minf(lo, off - wall_dist), maxf(hi, off + wall_dist))
	if (lat - off / 2) * off > 0:  # past the middle of the island: the other route
		return Vector2(off - wall_dist, off + wall_dist)
	return Vector2(lo, hi)


# ------------------------------------------------------------------ building

func _col(key: String) -> Color:
	return Color(theme[key])


func _edge(k: int, lat: float, dy: float) -> Vector3:
	var p := P(k)
	var r := right(k)
	return Vector3(p.x + r.x * lat, p.y + dy, p.z + r.y * lat)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) -> void:
	# a, b along one side, c, d back along the other: two triangles, facing up/in
	st.set_color(col)
	for v in [[a, uv[0]], [b, uv[1]], [c, uv[2]], [a, uv[0]], [c, uv[2]], [d, uv[3]]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])


## Road intervals across the track at sample k: the main road, plus a
## split's other route where it has swung clear of it.
func _intervals(k: int) -> Array:
	var off := split_off(k, 0)
	if off == 0:
		return [Vector2(-road_half, road_half)]
	if absf(off) <= 2 * wall_dist:
		return [Vector2(minf(-road_half, off - road_half), maxf(road_half, off + road_half))]
	return [Vector2(-road_half, road_half), Vector2(off - road_half, off + road_half)]


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var road := SurfaceTool.new()
	var deco := SurfaceTool.new()  # curbs, shoulders, barriers: untextured
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	deco.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb := _col("curb")
	var curb_dark := curb.darkened(0.55)
	var shoulder_col := _col("shoulder")
	var skirt := _col("skirt")
	var v := 0.0  # texture runs along the road
	for i in n:
		var j := i + 1
		var r0 := _road_colour(i)
		var iv0: Array = _intervals(i)
		var iv1: Array = _intervals(j)
		var dv := P(i).distance_to(P(j)) / 128.0
		var pairs := []  # (interval at i, interval at j)
		if iv0.size() == iv1.size():
			for m in iv0.size():
				pairs.append([iv0[m], iv1[m]])
		else:  # where a split's routes part or meet: the island's tip
			var wide0: Array = iv0 if iv0.size() == 2 else [Vector2(-road_half, road_half), Vector2(split_off(i, 0) - road_half, split_off(i, 0) + road_half)]
			var wide1: Array = iv1 if iv1.size() == 2 else [Vector2(-road_half, road_half), Vector2(split_off(j, 0) - road_half, split_off(j, 0) + road_half)]
			pairs = [[wide0[0], wide1[0]], [wide0[1], wide1[1]]]
		for m in pairs.size():
			var a: Vector2 = pairs[m][0]
			var b: Vector2 = pairs[m][1]
			var lift := 0.4 * m  # the other route sits a hair higher where they overlap
			_quad(road, _edge(i, a.x, lift), _edge(j, b.x, lift), _edge(j, b.y, lift), _edge(i, a.y, lift), r0,
				[Vector2(a.x / 128.0, v), Vector2(b.x / 128.0, v + dv), Vector2(b.y / 128.0, v + dv), Vector2(a.y / 128.0, v)])
			var stripe := curb if (i / 2) % 2 == 0 else curb_dark
			for side in [-1, 1]:
				var e0: float = a.y if side > 0 else a.x
				var e1: float = b.y if side > 0 else b.x
				var in0: float = e0 - side * CURB_W
				var in1: float = e1 - side * CURB_W
				var out0: float = e0 + side * shoulder
				var out1: float = e1 + side * shoulder
				# curb on the road's edge, shoulder out to the barrier
				_quad(deco, _edge(i, in0, 0.6 + lift), _edge(j, in1, 0.6 + lift), _edge(j, e1, 0.6 + lift), _edge(i, e0, 0.6 + lift), stripe)
				_quad(deco, _edge(i, e0, 0.2 + lift), _edge(j, e1, 0.2 + lift), _edge(j, out1, 0.2 + lift), _edge(i, out0, 0.2 + lift), shoulder_col)
		_walls(deco, i, j, pairs, curb, curb_dark, skirt)
		v += dv
	var road_mat := StandardMaterial3D.new()
	road_mat.vertex_color_use_as_albedo = true
	road_mat.albedo_texture = load("res://assets/images/tex/%02d.png" % ROAD_MATERIAL[index])
	road_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.generate_normals()
	_add_mesh(road.commit(), road_mat)
	var deco_mat := StandardMaterial3D.new()
	deco_mat.vertex_color_use_as_albedo = true
	deco_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	deco.generate_normals()
	_add_mesh(deco.commit(), deco_mat)
	_ground()
	_props()


func _road_colour(i: int) -> Color:
	# alternating bands every 6 samples, like the N64; the texture carries its
	# own brightness, so divide it back out
	var c := _col("road") if (i / 6) % 2 == 0 else _col("road2")
	return Color(minf(c.r / TEX_MEAN, 1), minf(c.g / TEX_MEAN, 1), minf(c.b / TEX_MEAN, 1))


## Bumper barriers on the outer edges, and around a split's island where the
## two routes run apart.
func _walls(st: SurfaceTool, i: int, j: int, pairs: Array, curb: Color, dark: Color, skirt: Color) -> void:
	var stripe := curb if (i / 2) % 2 == 0 else dark
	var edges := []  # [lat at i, lat at j, side]
	if pairs.size() == 1:
		edges = [[pairs[0][0].x - shoulder, pairs[0][1].x - shoulder, -1], [pairs[0][0].y + shoulder, pairs[0][1].y + shoulder, 1]]
	else:
		var lo := 0 if split_peak > 0 else 1  # which interval is on the left
		var hi := 1 - lo
		edges = [[pairs[lo][0].x - shoulder, pairs[lo][1].x - shoulder, -1], [pairs[hi][0].y + shoulder, pairs[hi][1].y + shoulder, 1]]
		var apart := absf(split_off(i, 0)) > 2 * wall_dist and absf(split_off(j, 0)) > 2 * wall_dist
		if apart:  # the island between the routes
			edges.append([pairs[lo][0].y + shoulder, pairs[lo][1].y + shoulder, 1])
			edges.append([pairs[hi][0].x - shoulder, pairs[hi][1].x - shoulder, -1])
	for e in edges:
		var l0: float = e[0]
		var l1: float = e[1]
		var s: float = e[2]
		var t0 := l0 + s * WALL_T
		var t1 := l1 + s * WALL_T
		var down := ground_y - 4
		# inner face, padded top, outer skirt down to the ground
		_quad(st, _edge(i, l0, 0), _edge(j, l1, 0), _edge(j, l1, WALL_H), _edge(i, l0, WALL_H), stripe)
		_quad(st, _edge(i, l0, WALL_H), _edge(j, l1, WALL_H), _edge(j, t1, WALL_H), _edge(i, t0, WALL_H), stripe.lightened(0.15))
		var a := _edge(i, t0, WALL_H)
		var b := _edge(j, t1, WALL_H)
		_quad(st, a, b, Vector3(b.x, down, b.z), Vector3(a.x, down, a.z), skirt)


func _add_mesh(mesh: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(20000, 20000)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _col("ground")
	mat.albedo_texture = load("res://assets/images/tex/04.png")  # earth, shared by every track's ground
	mat.uv1_scale = Vector3(120, 120, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(centre.x, ground_y - 6, centre.y)
	add_child(mi)


func _props() -> void:
	for p in props:
		var node := Props.make(p.prop, theme)
		node.scale = Vector3.ONE * float(p.scale)
		var s := int(p.sample)
		if s < 0:  # the castle of Elsinore looms in the middle of every loop
			node.position = Vector3(centre.x, ground_y - 6, centre.y)
		else:
			var at := point(s, 0, float(p.side) * float(p.dist))
			node.position = at
			node.rotation.y = yaw_at(s)
		add_child(node)
