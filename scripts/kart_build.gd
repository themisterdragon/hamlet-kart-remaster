class_name KartBuild
## The garage: a kart built from parts (tools/kart_parts.py), saved per
## racer. A build is {body, wheels, orn, paint, trim}: orn is whose hood
## ornament (-1 none), paint and trim are hex colours. Every part trades one
## thing for another, so no build is simply best; the quiz is still the
## biggest turbo there is.

# id, name, what it does, stat multipliers: speed, pickup (accel), handling, weight
const BODIES := [
	["racer", "Racer", "good at everything", [1.0, 1.0, 1.0, 1.0]],
	["royal", "Royal Racer", "tail fins: faster, slower to start", [1.04, 0.94, 1.0, 1.05]],
	["coach", "Royal Coach", "heavy: shoves others aside, turns wide", [1.02, 0.94, 0.94, 1.3]],
	["coffin", "Gravediggers' Cart", "fast, but a handful", [1.06, 0.95, 0.92, 1.1]],
	["ship", "Pirate Ship", "light: quick off the line, nimble", [0.96, 1.1, 1.07, 0.8]],
]
const WHEELS := [
	["tread", "Treaded Tyres", "good at everything", [1.0, 1.0, 1.0, 1.0]],
	["spoked", "Carriage Wheels", "grip: quicker turns and starts", [0.97, 1.06, 1.06, 0.95]],
	["royal", "Gold Rims", "faster, but they slide", [1.04, 0.97, 0.95, 1.0]],
]
const PAINTS := ["2a2834", "a81830", "2a4c98", "c4b0e2", "7a5030", "2c7040", "2a3e66", "8cc0d2",
	"f2c94c", "d9662b", "e07aa8", "eee8dc", "2a8a8a", "5a2a7a"]
const TRIMS := ["d0d8e4", "f0b838", "c88840", "f4e8cc", "2a2630", "a81830"]
const STAT_NAMES := ["Speed", "Pickup", "Handling", "Weight"]
# the dots run over every racer and every build
const STAT_RANGE := [[0.9, 1.12], [0.72, 1.28], [0.8, 1.3], [0.55, 1.7]]
const SAVE := "user://garage.cfg"

static var _data: Dictionary


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/karts.json"))
	return _data


## The racer's own kart, as the N64 sculpted it.
static func own(ch: int) -> Dictionary:
	var o: Dictionary = data().own[ch]
	return {"body": o.body, "wheels": "tread", "orn": ch, "paint": o.paint, "trim": o.trim}


## The racer's saved build, else their own kart.
static func saved(ch: int) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		var b = cfg.get_value("karts", str(ch), null)
		if b is Dictionary:
			return clean(b, ch)
	return own(ch)


static func store(ch: int, b: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("karts", str(ch), clean(b, ch))
	cfg.save(SAVE)  # (the browser keeps user:// in its own storage)


## Any build (saved, or sent by another player) made safe: unknown parts
## become the racer's own.
static func clean(b, ch: int) -> Dictionary:
	var o := own(ch)
	if not b is Dictionary:
		return o
	var out := o.duplicate()
	if _ids(BODIES).has(b.get("body")):
		out.body = b.body
	if _ids(WHEELS).has(b.get("wheels")):
		out.wheels = b.wheels
	var orn = b.get("orn")
	if (orn is int or orn is float) and int(orn) >= -1 and int(orn) < 8:
		out.orn = int(orn)
	for k in ["paint", "trim"]:
		var c = b.get(k)
		if c is String and c.length() == 6 and c.is_valid_hex_number():
			out[k] = c
	return out


static func _ids(list: Array) -> Array:
	return list.map(func(p): return p[0])


static func part(list: Array, id: String) -> Array:
	for p in list:
		if p[0] == id:
			return p
	return list[0]


## The racer's handling with this build: speed, pickup, handling, weight.
static func stats(ch: int, b: Dictionary) -> Array:
	var st: Array = Kart.STATS[ch].duplicate()
	var bm: Array = part(BODIES, b.body)[3]
	var wm: Array = part(WHEELS, b.wheels)[3]
	for i in 4:
		st[i] *= bm[i] * wm[i]
	return st


## A stat as 1-5 dots.
static func dots(i: int, v: float) -> int:
	var r: Array = STAT_RANGE[i]
	return clampi(1 + roundi((v - r[0]) / (r[1] - r[0]) * 4), 1, 5)


## The seat: the racer's own, else the paint, darker.
static func seat(ch: int, b: Dictionary) -> Color:
	var o: Dictionary = data().own[ch]
	if b.paint == o.paint:
		return Color(o.seat)
	return Color(b.paint).darkened(0.45)
