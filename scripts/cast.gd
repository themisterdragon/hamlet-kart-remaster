class_name Cast
## The soft clay material for the sculpts (riders, ornaments, scenery), which
## takes its colour from the sculpt. Karts are built by scripts/kart_rig.gd.

static var _mat: StandardMaterial3D


static func clay() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.6
		_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_mat.rim_enabled = true  # a soft rim light, like the sprites had
		_mat.rim = 0.08  # (stronger, it greys the colours out)
		_mat.rim_tint = 0.3
	return _mat


static var _stone: StandardMaterial3D


## Clay with dressed stone blocks pressed into it (the castle and towers),
## projected from the model's own sides so nothing needs UVs.
static func stone() -> StandardMaterial3D:
	if _stone == null:
		_stone = clay().duplicate()
		_stone.albedo_texture = load("res://assets/images/surface/ashlar.png")
		_stone.normal_enabled = true
		_stone.normal_texture = load("res://assets/images/surface/ashlar_n.png")
		_stone.uv1_triplanar = true
		_stone.uv1_scale = Vector3.ONE / 96.0
		_stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_stone.roughness = 0.85
	return _stone


## A rider's clay with their painted face (tools/faces.py) laid over it: the
## face texture sits in UV, and the colour's alpha marks the bare skin it may
## paint (hair, beards and spectacles in front stay on top). Riders without a
## painted face get plain clay.
static var _faces := {}
static var _face_shader: Shader


static func face(ch: int) -> Material:
	var path := "res://assets/images/faces/c%02d.png" % ch
	if not ResourceLoader.exists(path):
		return clay()
	if not _faces.has(ch):
		if _face_shader == null:
			_face_shader = Shader.new()
			_face_shader.code = """
shader_type spatial;
render_mode specular_schlick_ggx;
uniform sampler2D face : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float glow = 0.0;
void fragment() {
	// the sculpt's colours are sRGB, as in Cast.clay() (Godot's own rule:
	// converted only where the renderer works in linear light)
	vec3 base = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = mix(pow((base + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), base * (1.0 / 12.92), lessThan(base, vec3(0.04045)));
	}
	vec4 f = texture(face, UV);
	float a = f.a * smoothstep(0.45, 0.55, COLOR.a);
	ALBEDO = mix(base, f.rgb, a);
	ROUGHNESS = mix(0.6, 0.3, a);  // eyes catch the light
	// the Ghost's eyes glow: only its paint has bright greens like theirs
	EMISSION = f.rgb * a * glow * smoothstep(0.75, 0.95, f.g) * 1.6;
	RIM = 0.08;
	RIM_TINT = 0.3;
}
"""
		var m := ShaderMaterial.new()
		m.shader = _face_shader
		m.set_shader_parameter("face", load(path))
		m.set_shader_parameter("glow", 1.0 if ch == 7 else 0.0)  # the Ghost
		_faces[ch] = m
	return _faces[ch]
