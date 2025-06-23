extends EnemyBase
class_name ViperEnemy

@export var formation_offset: Vector2 = Vector2.ZERO
@export var formation_delay: float = 0.0

var formation_timer: float = 0.0
var can_move: bool = false

func _ready() -> void:
	super._ready()
	global_position += formation_offset
	formation_timer = formation_delay

func _physics_process(delta: float) -> void:
	if not can_move:
		formation_timer -= delta
		if formation_timer <= 0.0:
			can_move = true
	
	if can_move and stats:
		velocity.y = stats.speed
		move_and_slide()
		check_collisions()
