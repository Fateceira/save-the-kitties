extends Sprite2D

@export var move_force : int = 1

func _physics_process(delta: float) -> void:
	position += (get_global_mouse_position() / move_force * delta) - position
