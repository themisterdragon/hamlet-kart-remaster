extends Node
## Every word in the game, from data/content.json (made by tools/import_content.py).

var acts: Array = []
var tracks: Array = []
var characters: Array = []
var items: Array = []
var wrong_lines: Array = []


func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://data/content.json")
	var data = JSON.parse_string(text)
	if data == null:
		push_error("data/content.json is missing or broken: run tools/import_content.py")
		return
	acts = data.acts
	tracks = data.tracks
	characters = data.characters
	items = data.items
	wrong_lines = data.wrong_lines


func tracks_in_act(act: int) -> Array:
	return tracks.filter(func(t): return int(t.act) == act)


## A question with its answers shuffled onto the four D-pad directions.
## Returns {q, answers: [up, right, down, left], correct: index}.
func deal(track: int, n: int) -> Dictionary:
	var src: Dictionary = tracks[track].questions[n]
	var answers: Array = [src.answer] + src.wrong
	answers.shuffle()
	return {"q": src.q, "answers": answers, "correct": answers.find(src.answer)}
