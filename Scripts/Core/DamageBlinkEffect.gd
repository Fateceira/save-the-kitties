extends Node
class_name DamageBlinkEffect

@export var blink_duration: float = 0.08
@export var blink_intensity: float = 1.0
@export var base_material: ShaderMaterial

var sprite_node: Node
var original_material: Material
var instance_material: ShaderMaterial
var is_blinking: bool = false
var blink_timer: Timer
var damageable_component: DamageableComponent

func _ready() -> void:
	setup_sprite_component()
	setup_instance_material()
	setup_timer()
	connect_to_damageable_component()

func setup_sprite_component() -> void:
	var current_node = get_parent()
	sprite_node = find_sprite_recursive(current_node)
	
	original_material = sprite_node.material

func find_sprite_recursive(node: Node) -> Node:
	if node is Sprite2D or node is AnimatedSprite2D:
		return node
	
	for child in node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
		
		var found = find_sprite_recursive(child)
		if found:
			return found
	
	return null

func setup_instance_material() -> void:
	if not sprite_node:
		return
	
	if not base_material:
		var shader = load("res://shaders/damage_blink.gdshader")
		base_material = ShaderMaterial.new()
		base_material.shader = shader
	
	instance_material = base_material.duplicate()
	instance_material.set_shader_parameter("white_intensity", 0.0)
	
func setup_timer() -> void:
	blink_timer = Timer.new()
	blink_timer.wait_time = blink_duration
	blink_timer.one_shot = true
	blink_timer.timeout.connect(_on_blink_timeout)
	add_child(blink_timer)

func connect_to_damageable_component() -> void:
	var parent = get_parent()
	
	if parent is DamageableComponent:
		damageable_component = parent
	else:
		for sibling in parent.get_children():
			if sibling is DamageableComponent:
				damageable_component = sibling
				break
	
	if not damageable_component:
		damageable_component = find_damageable_recursive(parent)
	
	if damageable_component:
		if not damageable_component.damaged.is_connected(_on_damaged):
			damageable_component.damaged.connect(_on_damaged)

func find_damageable_recursive(node: Node) -> DamageableComponent:
	if node is DamageableComponent:
		return node
	
	for child in node.get_children():
		if child is DamageableComponent:
			return child
		
		var found = find_damageable_recursive(child)
		if found:
			return found
	
	return null

func _on_damaged(damage_info) -> void:
	trigger_blink()

func trigger_blink() -> void:
	if not sprite_node or not instance_material or is_blinking:
		return
	
	is_blinking = true
	
	sprite_node.material = instance_material
	instance_material.set_shader_parameter("white_intensity", blink_intensity)
	
	blink_timer.wait_time = blink_duration
	blink_timer.start()

func _on_blink_timeout() -> void:
	if sprite_node:
		sprite_node.material = original_material
	
	if instance_material:
		instance_material.set_shader_parameter("white_intensity", 0.0)
	
	is_blinking = false

func _exit_tree() -> void:
	if blink_timer:
		blink_timer.queue_free()
	
	if damageable_component and damageable_component.damaged.is_connected(_on_damaged):
		damageable_component.damaged.disconnect(_on_damaged)
