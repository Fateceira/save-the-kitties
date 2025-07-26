extends Area2D
class_name DialogTrigger

@export var sequence_id: String = ""
@export var trigger_once: bool = true
@export var auto_trigger: bool = false # Triggera automaticamente quando o player entra
@export var require_interaction: bool = true # Requer pressionar uma tecla

var has_triggered: bool = false
var player_in_area: bool = false

signal dialog_triggered(sequence_id: String)

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Conecta ao sistema de eventos do DialogManager
	if DialogManager.instance:
		DialogManager.instance.dialog_event_triggered.connect(_on_dialog_event)

func _input(event):
	if player_in_area and require_interaction and event.is_action_pressed("ui_accept"):
		trigger_dialog()

func _on_body_entered(body):
	if body.name == "Player": # Assumindo que o player tem o nome "Player"
		player_in_area = true
		
		if auto_trigger and not has_triggered:
			trigger_dialog()

func _on_body_exited(body):
	if body.name == "Player":
		player_in_area = false

func trigger_dialog():
	if sequence_id == "" or (trigger_once and has_triggered):
		return
	
	has_triggered = true
	dialog_triggered.emit(sequence_id)
	DialogManager.start_dialog(sequence_id)

func reset_trigger():
	has_triggered = false

func _on_dialog_event(event_name: String):
	# Responde a eventos específicos se necessário
	match event_name:
		"unlock_dash":
			print("Dash desbloqueado!")
		"tutorial_complete":
			print("Tutorial completado!")
		_:
			print("Evento triggado: ", event_name)