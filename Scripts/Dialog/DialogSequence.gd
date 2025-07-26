extends Resource
class_name DialogSequence

@export var sequence_id: String = ""
@export var dialogs: Array[DialogData] = []
@export var can_skip: bool = true
@export var trigger_on_complete: String = "" # Evento ao finalizar toda sequência