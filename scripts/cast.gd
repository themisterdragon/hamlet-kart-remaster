class_name Cast
## The cast's 3D clay models (assets/models/cNN.glb, from tools/make_models.py),
## with a soft clay material that takes its colour from the sculpt.

static var _mat: StandardMaterial3D


static func clay() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.6
		_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_mat.rim_enabled = true  # a soft rim light, like the sprites had
		_mat.rim = 0.2
		_mat.rim_tint = 0.6
	return _mat


static func model(ch: int) -> Node3D:
	var path := "res://assets/models/c%02d.glb" % ch
	if not ResourceLoader.exists(path):
		return null
	var root: Node3D = load(path).instantiate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = clay()
	return root
