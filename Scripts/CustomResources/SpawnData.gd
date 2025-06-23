extends Resource
class_name SpawnData

@export var enemy_scene: PackedScene
@export var spawn_chance: float = 1.0
@export var spawn_interval: float = 1.0
@export var min_spawn_time: float = 0.0
@export var can_be_first_spawn: bool = true
@export var formation_count: int = 1
@export var formation_spacing: float = 50.0

var last_spawn_time: float = 0.0
