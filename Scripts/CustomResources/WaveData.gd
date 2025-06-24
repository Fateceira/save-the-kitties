extends Resource
class_name WaveData

@export var wave_name: String = "Wave 1"
@export var enemy_spawns: Array[SpawnData] = []
@export var enemies_per_spawn: int = 1
@export var spawn_delay: float = 2.0
@export var wave_duration: float = 30.0
@export var break_duration: float = 3.0
@export var is_boss_wave: bool = false
