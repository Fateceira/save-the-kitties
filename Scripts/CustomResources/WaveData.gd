extends Resource
class_name WaveData

@export var wave_name: String = "Wave"
@export var enemy_spawns: Array[SpawnData] = []
@export var enemies_per_spawn: int = 1
@export var spawn_delay: float = .5  
@export var wave_duration: float = 30.0
@export var break_duration: float = 3.0
@export var is_boss_wave: bool = false

@export_group("Dialog System")
@export var has_pre_wave_dialog: bool = false
@export var pre_wave_dialog_id: String = ""
@export var has_post_wave_dialog: bool = false  
@export var post_wave_dialog_id: String = ""
