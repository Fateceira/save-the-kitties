class_name Player extends CharacterBody2D

signal laser_shot(laser_scene, location)

@export var speed = 250
@onready var muzzle = $Muzzle
@export var fire_rate = 0.21 
var time_since_last_shot = 0.0
var laser_scene = preload("res://Scenes/laser.tscn")

func _process(delta):
	time_since_last_shot += delta
	if Input.is_action_pressed("shoot") and time_since_last_shot >= fire_rate:
		shoot()

func _physics_process(_delta):
	var direction = Vector2(Input.get_axis("move_left", "move_right"), 0)
	velocity = direction * speed
	move_and_slide()
	
	global_position = global_position.clamp(Vector2.ZERO, get_viewport_rect().size)

func shoot():
	laser_shot.emit(laser_scene, muzzle.global_position)
	time_since_last_shot = 0.0

func die():
	queue_free()
