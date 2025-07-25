extends EnemyBase
class_name ZigZagEnemy

@export var zigzag_amplitude: float = 100.0
@export var zigzag_frequency: float = 3.0
@export var movement_direction: int = 1

var start_x: float
var time_alive: float = 0.0

func _ready() -> void:
	super._ready()
	start_x = global_position.x

func _physics_process(delta: float) -> void:
	time_alive += delta
	
	if stats:
		velocity.y = stats.speed
		velocity.x = sin(time_alive * zigzag_frequency) * zigzag_amplitude * movement_direction
		move_and_slide()

func set_movement_direction(direction: int) -> void:
	movement_direction = direction
