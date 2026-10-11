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
