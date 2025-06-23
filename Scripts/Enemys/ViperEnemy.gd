extends EnemyBase
class_name ViperEnemy

@export var rotation_speed: float = 10.0

var target_path: Path2D
var path_progress: float = 0.0
var path_offset: float = 0.0
var following_path: bool = false
var last_position: Vector2
var target_rotation: float = 0.0

func _ready() -> void:
	super._ready()

func setup_path_follow(path: Path2D, offset: float) -> void:
	target_path = path
	path_offset = offset
	path_progress = offset
	following_path = true
	
	if target_path and target_path.curve:
		var initial_pos = target_path.curve.sample_baked(path_progress * target_path.curve.get_baked_length())
		global_position = target_path.global_position + initial_pos
		last_position = global_position
		
		if path_progress < 1.0:
			var next_progress = min(path_progress + 0.01, 1.0)
			var next_pos = target_path.curve.sample_baked(next_progress * target_path.curve.get_baked_length())
			var next_global_pos = target_path.global_position + next_pos
			var direction = (next_global_pos - global_position).normalized()
			target_rotation = direction.angle() + PI/2  
			rotation = target_rotation
	

func _physics_process(delta: float) -> void:
	if following_path and target_path and is_instance_valid(target_path):
		follow_path_manual(delta)
	else:
		queue_free()

func follow_path_manual(delta: float) -> void:
	if not target_path.curve:
		queue_free()
		return
	
	var speed_factor = stats.speed  / 1000.0
	path_progress += speed_factor * delta
	
	if path_progress >= 1.0:
		queue_free()
		return
	
	var curve_length = target_path.curve.get_baked_length()
	var position_on_curve = target_path.curve.sample_baked(path_progress * curve_length)
	var new_position = target_path.global_position + position_on_curve
	
	var movement_direction = (new_position - global_position).normalized()
	
	if movement_direction.length() > 0.1: 
		target_rotation = movement_direction.angle() + PI/2  
		
		var angle_diff = angle_difference(rotation, target_rotation)
		rotation += angle_diff * rotation_speed * delta
	
	global_position = new_position

func _on_died() -> void:
	queue_free()
