extends Node3D
## Test-only: shows one cast model (-- --model=N) under race-like light.

func _ready() -> void:
	var n := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			n = int(a.substr(8))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6a7484")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("868690")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.9
	add_child(sun)
	for i in 3:
		var m := Cast.model((n + i) % 8)
		if m == null:
			continue
		m.position = Vector3((i - 1) * 50, 0, 0)
		m.rotation.y = deg_to_rad(-140 + i * 50)
		add_child(m)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 40, 85)
	add_child(cam)
	cam.look_at(Vector3(0, 18, 0))
