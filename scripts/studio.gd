class_name Studio
## Studio lighting for showing a racer off (character select, the garage,
## portraits, the lineup test): a warm key with shadows, a cool fill, and a
## strong rim from behind so the silhouette reads on the dark cards; a soft
## sky for ambient light and reflections. Linear tone mapping, as on the
## track (filmic washed the racers' colours out).

static func light(root: Node, shadows := true) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3a3a6a")
	sky_mat.sky_horizon_color = Color("b89a88")
	sky_mat.ground_horizon_color = Color("6a5a68")
	sky_mat.ground_bottom_color = Color("1c1830")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 35, 0)
	key.light_color = Color("fff0d8")
	key.light_energy = 0.9
	key.shadow_enabled = shadows
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-8, -60, 0)
	fill.light_color = Color("9fb4ff")
	fill.light_energy = 0.22
	fill.light_specular = 0.2
	root.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-28, 165, 0)
	rim.light_color = Color("d8e6ff")
	rim.light_energy = 0.6
	rim.light_specular = 0.5
	root.add_child(rim)
