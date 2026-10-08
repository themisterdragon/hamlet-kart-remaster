class_name DpadArrow
extends Control
## A D-pad direction drawn as a triangle (fonts can't be trusted to have
## the arrow glyphs on every computer). dir: 0 up, 1 right, 2 down, 3 left.

var dir := 0
var color := Color.WHITE:
	set(c):
		color = c
		queue_redraw()


func _init(d: int = 0, size_px: float = 24) -> void:
	dir = d
	custom_minimum_size = Vector2(size_px, size_px)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var s := size.x
	var pts := PackedVector2Array([Vector2(s / 2, s * 0.1), Vector2(s * 0.95, s * 0.85), Vector2(s * 0.05, s * 0.85)])
	var xf := Transform2D(dir * PI / 2, Vector2(s / 2, s / 2)) * Transform2D(0, -Vector2(s / 2, s / 2))
	draw_colored_polygon(xf * pts, color)
