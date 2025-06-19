extends Node2D

@export var enemy_scenes: Array[PackedScene] = []

@onready var player_spawn_pos = $playerspawnpos
@onready var laser_container = $laser_container
@onready var timer = $EnemySpawnTimer
@onready var enemy_container = $EnemyContainer

var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	player.global_position = player_spawn_pos.global_position
	player.laser_shot.connect(_on_layer_laser_shot)

func _process(_delta):
	if Input.is_action_just_pressed("Sair"):
		get_tree().quit()
	elif Input.is_action_just_pressed("Resetar"):
		get_tree().reload_current_scene()

func _on_layer_laser_shot(laser_scene, location):
	var laser = laser_scene.instantiate()
	laser.global_position = location
	laser_container.add_child(laser)


func _on_enemy_spawn_timer_timeout() -> void:
	var e = enemy_scenes.pick_random().instantiate()
	e.global_position = Vector2(randf_range(50, 450), -50)
	enemy_container.add_child(e)
