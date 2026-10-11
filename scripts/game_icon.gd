class_name GameIcon
extends Control
## The game's own icons, drawn as shapes rather than taken from a font, so
## they look the same on every phone, tablet and computer: arrows, the drift
## swoosh, the item star, pause, a diamond and the delete key. Chunky and
## rounded to match the buttons; smooth edges come from an antialiased
## outline over each filled shape.

var kind := "up"
var color := Color.WHITE:
	set(c):
		color = c
		queue_redraw()


func _init(k: String = "up", size_px: float = 48) -> void:
	kind = k
	custom_minimum_size = Vector2(size_px, size_px)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _shape(pts: PackedVector2Array) -> void:
	draw_colored_polygon(pts, color)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, color, maxf(1.5, size.x * 0.03), true)


## A triangle pointing up, turned for the other directions.
func _arrow(turn: float) -> void:
	var s := size.x
	var c := Vector2(s / 2, s / 2)
	var pts := PackedVector2Array([Vector2(0, -0.40), Vector2(0.42, 0.32), Vector2(-0.42, 0.32)])
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p.rotated(turn) * s)
	_shape(out)


func _draw() -> void:
	var s := size.x
	var c := size / 2
	match kind:
		"up":
			_arrow(0)
		"right":
			_arrow(PI / 2)
		"down":
			_arrow(PI)
		"left":
			_arrow(-PI / 2)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := s * (0.47 if i % 2 == 0 else 0.2)
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			_shape(pts)
		"diamond":
			_shape(PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.45, 0), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.45, 0)]))
		"pause":
			for x in [-0.2, 0.2]:
				var r := Rect2(c + Vector2(x * s - s * 0.1, -s * 0.34), Vector2(s * 0.2, s * 0.68))
				_shape(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
		"drift":
			# a swoosh round to the left with an arrowhead: the kart sliding round a bend
			var w := s * 0.15
			var rad := s * 0.36
			var from := deg_to_rad(200.0)
			var to := deg_to_rad(-55.0)
			draw_arc(c + Vector2(0, s * 0.04), rad, from, to, 28, color, w, true)
			var tip_a := to
			var end := c + Vector2(0, s * 0.04) + Vector2(cos(tip_a), sin(tip_a)) * rad
			var along := Vector2(cos(tip_a - PI / 2), sin(tip_a - PI / 2))  # direction of travel at the end
			var side := along.orthogonal()
			_shape(PackedVector2Array([end + along * s * 0.24, end + side * s * 0.2 - along * s * 0.02, end - side * s * 0.2 - along * s * 0.02]))
		"delete":
			# the delete key: a tag pointing left with a cross in it
			var pts := PackedVector2Array([c + Vector2(-s * 0.46, 0), c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.44, -s * 0.3),
				c + Vector2(s * 0.44, s * 0.3), c + Vector2(-s * 0.2, s * 0.3)])
			_shape(pts)
			var k := s * 0.12
			var m := c + Vector2(s * 0.1, 0)
			var ink := Color(0.08, 0.1, 0.2) if color.get_luminance() > 0.5 else Color.WHITE
			draw_line(m + Vector2(-k, -k), m + Vector2(k, k), ink, s * 0.07, true)
			draw_line(m + Vector2(-k, k), m + Vector2(k, -k), ink, s * 0.07, true)
