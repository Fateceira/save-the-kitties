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
	print("DialogManager inicializado")

static func start_dialog(sequence_id: String):
	if instance:
		instance._start_dialog_sequence(sequence_id)
	else:
		push_error("DialogManager.instance é null!")

static func trigger_event(event_name: String):
	print("DialogManager.trigger_event chamado com: ", event_name)
	if instance:
		instance.dialog_event_triggered.emit(event_name)
		print("Evento emitido: ", event_name)
	else:
		push_error("DialogManager.instance é null ao tentar triggerar evento!")

func _start_dialog_sequence(sequence_id: String):
	print("Iniciando sequência de diálogo: ", sequence_id)
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
	
	var connection_result = current_dialog_ui.dialog_finished.connect(_on_dialog_finished)
	if connection_result != OK:
		push_error("Falha ao conectar dialog_finished signal")
	
	connection_result = current_dialog_ui.dialog_event_triggered.connect(_on_dialog_event)
	if connection_result != OK:
		push_error("Falha ao conectar dialog_event_triggered signal")
	
	current_dialog_ui.start_sequence(sequence)
	dialog_started.emit()
	print("Diálogo iniciado com sucesso")

func _find_sequence(sequence_id: String) -> DialogSequence:
	for sequence in dialog_sequences:
		if sequence.sequence_id == sequence_id:
			return sequence
	return null

func _on_dialog_finished():
	print("Diálogo finalizado - evento interno")
	
	if game_paused:
		get_tree().paused = false
		game_paused = false
	
	if current_dialog_ui and current_dialog_ui.get_parent():
		var canvas_layer = current_dialog_ui.get_parent()
		if canvas_layer is CanvasLayer:
			canvas_layer.queue_free()
		current_dialog_ui = null
	
	dialog_finished.emit()
	print("Signal dialog_finished emitido")

func _on_dialog_event(event_name: String):
	print("Evento de diálogo recebido internamente: ", event_name)
	dialog_event_triggered.emit(event_name)
	print("Signal dialog_event_triggered emitido com: ", event_name)

func debug_trigger_event(event_name: String):
	print("DEBUG: Trigando evento manualmente: ", event_name)
	_on_dialog_event(event_name)

func debug_check_connections():
	print("=== DEBUG CONEXÕES ===")
	print("Listeners conectados ao dialog_event_triggered: ", dialog_event_triggered.get_connections().size())
	for connection in dialog_event_triggered.get_connections():
		print("- Conectado a: ", connection.callable.get_object(), " método: ", connection.callable.get_method())
	print("=====================")
