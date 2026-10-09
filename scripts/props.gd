class_name Props
## Scenery: the sculpted clay props (assets/models/props, from
## tools/sculpt_props.py) where there is one, else a simple stand-in shape
## in the prop's colours. World units; the names match the N64's.

const COLOURS := {
	"PINE": "2f5d34", "SNOWPINE": "dfe8f0", "TOWER": "8a8a94", "TORCH": "ffb040",
	"TABLE": "7a4a2a", "THRONE": "d8a830", "BOOKS": "8a3a3a", "GHOST": "c8ffe8",
	"SPYBUSH": "3a6a2a", "STAGE": "8a2a2a", "CHAPEL": "b0a8c0", "ARRAS": "8a2a4a",
	"PORTRAIT": "c09040", "TENT": "d8c8a0", "FLOWERS": "e080b0", "WILLOW": "6a9a4a",
	"SHIP": "6a4a2a", "TOMB": "9a9a90", "SKULLS": "e8e0c8", "GOBLET": "e0b030",
	"SWORDS": "c8c8d0", "BANNER": "a02830", "ROOSTER": "d06030", "WORM": "c08080",
	"ICEROCK": "c8d8e8", "CASTLE": "8a8494", "HILL": "4e7a3e", "CROWN": "f0c030",
	"LETTER": "f0e8d0", "BARREL": "8a5a30", "CENSER": "c0a060",
}

static var _mats := {}


static func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		_mats[hex] = m
	return _mats[hex]


static func _part(root: Node3D, mesh: PrimitiveMesh, hex: String, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mesh.material = _mat(hex)
	mi.mesh = mesh
	mi.position = pos
	root.add_child(mi)


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 12
	return c


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static var _scenes := {}


static func make(name: String, _theme: Dictionary) -> Node3D:
	var path := "res://assets/models/props/%s.glb" % name.to_lower()
	if ResourceLoader.exists(path):
		if not _scenes.has(path):
			_scenes[path] = load(path)
		var m: Node3D = _scenes[path].instantiate()
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = Cast.clay()
		return m
	var root := Node3D.new()
	root.name = name.capitalize()
	var c: String = COLOURS.get(name, "888888")
	match name:
		"PINE", "SNOWPINE", "SPYBUSH", "WILLOW":
			_part(root, _cyl(3, 5, 24), "5a3a20", Vector3(0, 12, 0))
			_part(root, _cyl(0, 30, 70), c, Vector3(0, 55, 0))
		"TOWER", "CHAPEL":
			_part(root, _cyl(40, 44, 160), c, Vector3(0, 80, 0))
			_part(root, _cyl(0, 50, 60), "6a3a3a", Vector3(0, 190, 0))
		"CASTLE":
			_part(root, _box(420, 220, 300), c, Vector3(0, 110, 0))
			for x in [-210, 210]:
				for z in [-150, 150]:
					_part(root, _cyl(46, 50, 340), c, Vector3(x, 170, z))
					_part(root, _cyl(0, 60, 110), "4a3a6a", Vector3(x, 395, z))
			_part(root, _cyl(60, 64, 460), c, Vector3(0, 230, 0))
			_part(root, _cyl(0, 74, 140), "4a3a6a", Vector3(0, 530, 0))
		"TORCH", "CENSER":
			_part(root, _cyl(2, 3, 50), "4a3a2a", Vector3(0, 25, 0))
			_part(root, _cyl(6, 3, 10), c, Vector3(0, 55, 0))
		"BANNER":
			_part(root, _cyl(2, 2, 90), "4a3a2a", Vector3(0, 45, 0))
			_part(root, _box(40, 50, 2), c, Vector3(20, 60, 0))
		"GHOST":
			_part(root, _cyl(14, 22, 60), c, Vector3(0, 50, 0))
		"HILL":
			var s := SphereMesh.new()
			s.radius = 90
			s.height = 90
			_part(root, s, c, Vector3(0, 0, 0))
		"SHIP", "STAGE", "TENT", "TABLE":
			_part(root, _box(120, 40, 70), c, Vector3(0, 20, 0))
		"TOMB", "ICEROCK", "THRONE":
			_part(root, _box(50, 60, 40), c, Vector3(0, 30, 0))
		_:
			_part(root, _box(30, 30, 30), c, Vector3(0, 15, 0))
	return root
