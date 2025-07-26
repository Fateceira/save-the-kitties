extends Resource
class_name DialogData

@export var character_name: String = ""
@export var dialog_text: String = ""
@export var character_portrait: Texture2D
@export var emotion: String = "neutral" # neutral, happy, sad, angry, surprised
@export var text_speed: float = 0.05
@export var auto_advance: bool = false
@export var auto_advance_delay: float = 2.0
@export var trigger_event: String = "" # Para desbloquear skills, etc
@export var pause_game: bool = true