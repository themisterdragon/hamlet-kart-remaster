extends Node
## Online class races over PeerJS (web/net.js, browser builds only).
## The host's browser runs the race; players send their controls and get
## the race state back. Messages are JSON strings.

signal opened(id: String)
signal peer_joined(peer: String)
signal peer_left(peer: String)
signal message(peer: String, data: Dictionary)
signal failed(why: String)

const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no 0/O or 1/I mix-ups

var active := false


func available() -> bool:
	if not OS.has_feature("web"):
		return false
	var v = JavaScriptBridge.eval("(window.hk && hk.ready()) ? 1 : 0", true)
	print("online bridge: ", v, " (type ", typeof(v), ")")
	return v != null and int(v) == 1


static func new_code() -> String:
	var c := ""
	for i in 5:
		c += CODE_CHARS[randi() % CODE_CHARS.length()]
	return c


func host(code: String) -> void:
	active = true
	JavaScriptBridge.eval("hk.host(%s)" % JSON.stringify(code))


func join(code: String) -> void:
	active = true
	JavaScriptBridge.eval("hk.join(%s)" % JSON.stringify(code.strip_edges().to_upper()))


func send(peer: String, data: Dictionary) -> void:
	JavaScriptBridge.eval("hk.send(%s, %s)" % [JSON.stringify(peer), JSON.stringify(JSON.stringify(data))])


func broadcast(data: Dictionary) -> void:
	JavaScriptBridge.eval("hk.broadcast(%s)" % JSON.stringify(JSON.stringify(data)))


func close() -> void:
	if active:
		JavaScriptBridge.eval("hk.close()")
	active = false


func _process(_delta: float) -> void:
	if not active:
		return
	var raw = JavaScriptBridge.eval("hk.poll()")
	if typeof(raw) != TYPE_STRING or raw == "[]":
		return
	for e in JSON.parse_string(raw):
		match e.t:
			"open":
				opened.emit(e.id)
			"conn":
				peer_joined.emit(e.peer)
			"close":
				peer_left.emit(e.peer)
			"error":
				failed.emit(e.msg)
			"data":
				var d = JSON.parse_string(e.msg)
				if d is Dictionary:
					message.emit(e.peer, d)
