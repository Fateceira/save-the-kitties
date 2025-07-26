extends Node

signal dialog_started
signal dialog_finished
signal dialog_event_triggered(event_name: String)

static var instance: DialogManager

@export var dialog_sequences: Array[DialogSequence] = []
var dialog_ui_scene: PackedScene = preload("res://assets/Prefabs/Components/pf_DialogScreen.tscn")
var current_dialog_ui: DialogUI = null
var game_paused: bool = false

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

static func start_dialog(sequence_id: String):
	if instance:
		instance._start_dialog_sequence(sequence_id)

static func trigger_event(event_name: String):
	if instance:
		instance.dialog_event_triggered.emit(event_name)

func _start_dialog_sequence(sequence_id: String):
	var sequence = _find_sequence(sequence_id)
	if not sequence:
		push_error("Dialog sequence not found: " + sequence_id)
		return
	
	if current_dialog_ui:
		current_dialog_ui.queue_free()
		await current_dialog_ui.tree_exited
	
	if sequence.dialogs.size() > 0 and sequence.dialogs[0].pause_game:
		game_paused = true
		get_tree().paused = true
	
	current_dialog_ui = dialog_ui_scene.instantiate()
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(current_dialog_ui)
	
	current_dialog_ui.dialog_finished.connect(_on_dialog_finished)
	current_dialog_ui.dialog_event_triggered.connect(_on_dialog_event)
	
	current_dialog_ui.start_sequence(sequence)
	dialog_started.emit()

func _find_sequence(sequence_id: String) -> DialogSequence:
	for sequence in dialog_sequences:
		if sequence.sequence_id == sequence_id:
			return sequence
	return null

func _on_dialog_finished():
	if game_paused:
		get_tree().paused = false
		game_paused = false
	
	if current_dialog_ui and current_dialog_ui.get_parent():
		var canvas_layer = current_dialog_ui.get_parent()
		if canvas_layer is CanvasLayer:
			canvas_layer.queue_free()
		current_dialog_ui = null
	
	dialog_finished.emit()

func _on_dialog_event(event_name: String):
	dialog_event_triggered.emit(event_name)
