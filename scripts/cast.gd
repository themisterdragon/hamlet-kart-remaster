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
## paint (hair, beards and spectacles in front stay on top), or the hair, which
## gets fine strands (UV2: round the head, down it). Riders without a
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
varying vec3 across;  // view space, across the hair's strands (round the head)

// the hair's strands: clumps and fine strands as a sum of waves round the
// head (UV2.x), each bending a little as it falls (UV2.y); returns the
// height and its slope across the strands. Waves finer than a pixel or two
// (fw: how far UV2.x moves per pixel) fade out, so nothing shimmers far off.
vec2 strands(vec2 s, float fw) {
	float u = s.x + 0.35 * sin(s.y * 0.45 + s.x * 0.2);
	float h = 0.0, d = 0.0;
	// (frequency, size, phase): two clumps, then finer strands
	vec3 w[5] = vec3[5](vec3(1.3, 0.5, 0.0), vec3(2.9, 0.3, 1.7), vec3(6.1, 0.18, 4.2), vec3(11.3, 0.1, 2.3), vec3(19.7, 0.06, 5.1));
	for (int i = 0; i < 5; i++) {
		float k = w[i].y * clamp(1.6 - fw * w[i].x * 0.6, 0.0, 1.0);
		h += k * sin(w[i].x * u + w[i].z);
		d += k * w[i].x * cos(w[i].x * u + w[i].z);
	}
	return vec2(h, d);
}

void vertex() {
	// round the head, in view space: the model's up crossed with the normal
	vec3 up = (MODELVIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	vec3 n = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	across = cross(up, n);
}

void fragment() {
	// the sculpt's colours are sRGB, as in Cast.clay() (Godot's own rule:
	// converted only where the renderer works in linear light)
	vec3 base = COLOR.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = mix(pow((base + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), base * (1.0 / 12.92), lessThan(base, vec3(0.04045)));
	}
	vec4 f = texture(face, UV);
	float a = f.a * smoothstep(0.45, 0.55, COLOR.a);
	// hair: COLOR.a is 0.25 there (tools/faces.py HAIR)
	float hair = 1.0 - smoothstep(0.06, 0.12, abs(COLOR.a - 0.25));
	// elsewhere COLOR.a is the sculpt's shine (0..1) x 0.12: gold, silver and
	// armour polished, cloth matte
	float shine = clamp(COLOR.a / 0.12, 0.0, 1.0) * (1.0 - step(0.18, COLOR.a));
	float metal = smoothstep(0.75, 0.92, shine);
	vec2 st = strands(UV2, fwidth(UV2.x));
	// light hair (Polonius' white) shows its strands by relief more than by shade
	float light = smoothstep(0.5, 0.9, max(base.r, max(base.g, base.b)));
	float tone = mix(0.14, 0.05, light);
	ALBEDO = mix(base, f.rgb, a) * mix(1.0, 1.0 - tone + 2.0 * tone * (st.x * 0.5 + 0.5) - tone * 0.3, hair);
	ROUGHNESS = mix(mix(mix(0.62, 0.3, shine), 0.3, a), 0.42 - 0.1 * st.x, hair);  // eyes and hair catch the light
	SPECULAR = mix(0.5, 0.75, max(hair, shine));
	METALLIC = metal * 0.55;  // (half: still bright where the sky's reflections are off, on slow computers)
	// strands in relief: the normal tips across them with the waves' slope
	float l = length(across);
	if (hair > 0.0 && l > 0.05) {
		NORMAL = normalize(NORMAL + (across / l) * st.y * mix(0.22, 0.12, light) * hair);
	}
	RIM = 0.08;
	RIM_TINT = 0.3;
	// the Ghost's eyes glow: only its paint has bright greens like theirs
	EMISSION = f.rgb * a * glow * smoothstep(0.75, 0.95, f.g) * 1.6;
}
"""
		var m := ShaderMaterial.new()
		m.shader = _face_shader
		m.set_shader_parameter("face", load(path))
		m.set_shader_parameter("glow", 1.0 if ch == 7 else 0.0)  # the Ghost
		_faces[ch] = m
	return _faces[ch]
