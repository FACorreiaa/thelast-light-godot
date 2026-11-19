class_name StoryPresenter
extends RefCounted
## Holds the story files, the saved decisions and the scene being played. Port of StoryPresenter.swift.
## The game scene starts scenes; the dialogue panel shows them and sends back "continue" or a choice.

signal changed


var runner: Story.Runner
var state := Story.State.new()
var library: Story.Library


func _init() -> void:
	# One story file per chapter, named by the chapter's id.
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/index.json"))
	library = Story.Library.load_chapters(index.chapters.map(func(c: Dictionary) -> String: return c.id))
	if FileAccess.file_exists(SaveDir.path("story.json")):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveDir.path("story.json")))
		if saved is Dictionary:
			state = Story.State.from_json(saved)


func is_active() -> bool:
	return runner != null


## Starts a scene unless it was already played. Returns whether it started.
func begin(id: String) -> bool:
	if runner != null or state.seen.has(id):
		return false
	runner = Story.Runner.start(id, library, state)
	if runner == null:
		return false
	_settle()
	changed.emit()
	return runner != null


func advance() -> void:
	if runner != null:
		runner.advance()
	_settle()
	changed.emit()


func choose(index: int) -> void:
	if runner != null:
		runner.choose(index)
	_settle()
	changed.emit()


## Playing a level again from its start plays its scenes again, so a decision can be made differently.
func forget(scenes: Array) -> void:
	var any := false
	for id: String in scenes:
		if state.seen.has(id):
			state.seen.erase(id)
			any = true
	if any:
		_save()


## A new game: every decision and every scene played is forgotten. With a lead, remembers who is leading,
## so shared scenes can speak to them.
func reset_all(lead := "") -> void:
	runner = null
	state = Story.State.new()
	if lead != "":
		state.flags["lead"] = lead
	_save()
	changed.emit()


func _settle() -> void:
	if runner == null or not runner.is_finished():
		return
	state = runner.state
	runner = null
	_save()


func _save() -> void:
	var f := FileAccess.open(SaveDir.path("story.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(state.to_json()))
