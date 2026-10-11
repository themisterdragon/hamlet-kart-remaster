class_name UiKit
## The menus' look, all drawn in code (nothing extra to download): gold-on-
## navy buttons that light up and lift when chosen, headings with a gold
## rule, stat bars, a vignette and drifting gold dust over the title art.
## Contrast: white on the navy buttons is over 15:1, navy on the lit gold
## over 10:1; nothing is shown by colour alone.

const NAVY := Color("101634")
const INK := Color("141a33")   # text on gold
const GOLD := Color("f2c94c")
const GOLD_SOFT := Color("c9a43e")
const GOLD_PALE := Color("f2d27a")
const CREAM := Color("fff3c4")

static var _styles := {}


## Shared button faces: "normal", "lit" (focus and hover) and "pressed".
static func styles() -> Dictionary:
	if _styles.is_empty():
		var n := StyleBoxFlat.new()
		n.bg_color = Color(NAVY, 0.9)
		n.border_color = GOLD_SOFT
		n.set_border_width_all(2)
		n.set_corner_radius_all(14)
		n.set_content_margin_all(10)
		n.shadow_color = Color(0, 0, 0, 0.45)
		n.shadow_size = 8
		n.shadow_offset = Vector2(0, 4)
		var lit := n.duplicate()
		lit.bg_color = GOLD
		lit.border_color = CREAM
		lit.set_border_width_all(3)
		lit.shadow_color = Color(1.0, 0.78, 0.25, 0.5)  # a gold glow
		lit.shadow_size = 18
		lit.shadow_offset = Vector2.ZERO
		var pressed := lit.duplicate()
		pressed.bg_color = Color("d9a92e")
		pressed.shadow_size = 8
		_styles = {"normal": n, "lit": lit, "pressed": pressed}
	return _styles


## Dress a button: the faces, ink on gold when lit, and a little lift (it
## grows from its middle) when it's the one chosen.
static func style_button(b: Button) -> void:
	var st := styles()
	b.add_theme_stylebox_override("normal", st.normal)
	b.add_theme_stylebox_override("hover", st.lit)
	b.add_theme_stylebox_override("focus", st.lit)
	b.add_theme_stylebox_override("pressed", st.pressed)
	b.add_theme_stylebox_override("hover_pressed", st.pressed)
	b.add_theme_color_override("font_color", Color.WHITE)
	for s in ["font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(s, INK)
	b.add_theme_color_override("icon_focus_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.resized.connect(func(): b.pivot_offset = b.size / 2)
	b.focus_entered.connect(func(): _lift(b, 1.05))
	b.focus_exited.connect(func(): _lift(b, 1.0))
	b.mouse_entered.connect(func():
		if b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())


static func _lift(b: Control, to: float) -> void:
	if not b.is_inside_tree():
		return
	b.create_tween().tween_property(b, "scale", Vector2.ONE * to, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The lit button's glow breathes (one shared face, so this is cheap).
static func breathe(t: float) -> void:
	styles().lit.shadow_size = int(16 + 6 * sin(t * 3.2))


## A gold rule with a diamond in the middle, fading out at both ends.
class Rule extends Control:
	var width := 520.0

	func _init(w := 520.0) -> void:
		width = w
		custom_minimum_size = Vector2(w, 18)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var steps := 24
		for i in steps:  # each half in short pieces, fading toward the end
			var f := float(i) / steps
			var col := Color(UiKit.GOLD, 1.0 - f)
			for s in [-1, 1]:
				var a := c + Vector2(s * (14 + f * (width / 2 - 14)), 0)
				var b := c + Vector2(s * (14 + (f + 1.0 / steps) * (width / 2 - 14)), 0)
				draw_line(a, b, col, 2.0, true)
		var d := 7.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), UiKit.GOLD)


## Four stats as bars of five pips that fill in when they change, with a
## ▲ or ▼ where the kart's parts change one (a shape, not colour alone).
class StatBars extends Control:
	var names: Array = []
	var shown: Array = [0.0, 0.0, 0.0, 0.0]
	var target: Array = [0, 0, 0, 0]
	var marks: Array = ["", "", "", ""]
	var font: Font
	const ROW := 46.0

	func _init(f: Font, stat_names: Array) -> void:
		font = f
		names = stat_names
		custom_minimum_size = Vector2(470, ROW * 4)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_stats(values: Array, changes: Array) -> void:
		target = values
		marks = changes

	func _process(delta: float) -> void:
		var moving := false
		for i in 4:
			var to := float(target[i])
			if absf(shown[i] - to) > 0.01:
				shown[i] = move_toward(shown[i], to, delta * 9.0)
				moving = true
		if moving or Engine.get_process_frames() % 30 == 0:
			queue_redraw()

	func _draw() -> void:
		for i in 4:
			var y := i * ROW + ROW / 2
			draw_string(font, Vector2(0, y + 10), names[i], HORIZONTAL_ALIGNMENT_RIGHT, 150, 28, Color.WHITE)
			for p in 5:
				var r := Rect2(172 + p * 46, y - 11, 38, 22)
				var fill := clampf(shown[i] - p, 0, 1)
				draw_rect(r, Color(UiKit.NAVY, 0.9))
				if fill > 0:
					draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), UiKit.GOLD)
				draw_rect(r, UiKit.GOLD_SOFT, false, 2.0)
			if marks[i] != "":
				var up: bool = marks[i] == "+"
				draw_string(font, Vector2(412, y + 11), "▲" if up else "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
					Color("7be08f") if up else Color("ff8a8a"))


## The title art's dressing: a vignette and gold dust drifting up.
static func vignette() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 0.8);
	float v = smoothstep(0.3, 0.78, length(d) * 1.35);
	float low = smoothstep(0.55, 1.0, UV.y) * 0.35;  // a little darker at the foot, under the buttons
	COLOR = vec4(0.02, 0.02, 0.07, clamp(v * 0.85 + low, 0.0, 0.92));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return r


static func dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d := Vector2(x - 11.5, y - 11.5).length() / 11.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0, 1) ** 2))
	p.texture = ImageTexture.create_from_image(img)
	p.amount = 40
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1100, 40)
	p.position = Vector2(960, 1120)
	p.direction = Vector2(0, -1)
	p.spread = 25
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 40
	p.initial_velocity_max = 110
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.9
	p.angular_velocity_min = 0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.0))
	g.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	g.add_point(0.15, Color(1.0, 0.85, 0.4, 0.55))
	g.add_point(0.7, Color(1.0, 0.78, 0.3, 0.35))
	p.color_ramp = g
	return p


## A light sweeping across a picture now and then (the logo).
static func shine() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float t = -1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float x = UV.x + UV.y * 0.4 - t;
	float band = smoothstep(0.07, 0.0, abs(x));
	c.rgb += band * 0.6 * c.a;
	COLOR = c * COLOR;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
