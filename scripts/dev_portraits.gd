extends Node
## (tool) Renders every racer's head and shoulders, lit as on character
## select, to OUT/rNN.png for tools/make_portraits.py (which frames them
## as the menu's medallions). Run by that script: --out=DIR.

const SIZE := 384
var out := ""
var vps: Array[SubViewport] = []
var frames := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	for ch in Content.characters.size():
		var vp := SubViewport.new()
		vp.size = Vector2i(SIZE, SIZE)
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_8X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		Studio.light(vp)
		var mi := MeshInstance3D.new()
		mi.mesh = KartRig._mesh("rider_c%02d" % ch)
		mi.material_override = Cast.face(ch)
		vp.add_child(mi)
		var cam := Camera3D.new()
		cam.fov = 30
		var look := Vector3(0, 34.5, 0.5)  # the head (y 36) and shoulders
		var eye := look + Vector3(0.36, 0.1, 1).normalized() * 72.0
		vp.add_child(cam)
		cam.look_at_from_position(eye, look)
		vps.append(vp)


func _process(_dt: float) -> void:
	frames += 1
	if frames < 8:
		return
	for ch in vps.size():
		vps[ch].get_texture().get_image().save_png(out.path_join("r%02d.png" % ch))
	print("portraits: %d rendered to %s" % [vps.size(), out])
	get_tree().quit()
