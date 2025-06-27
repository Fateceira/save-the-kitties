extends Node2D

@export var trail_gradient: Gradient
@export var trail_spawn_interval: float = 0.04
@export var trail_fade_duration: float = 0.6
@export var max_trail_ghosts: int = 15

var player: CharacterBody2D
var player_sprite: Node2D
var trail_ghosts: Array[Dictionary] = []
var trail_spawn_timer: float = 0.0
var dash_shader: Shader
var is_dash_active: bool = false

func _ready() -> void:
	setup_trail_system()
	connect_player_signals()

func setup_trail_system() -> void:
	player = get_parent() as CharacterBody2D
	player_sprite = player.get_node_or_null("AnimatedSprite2D")
	if not player_sprite:
		player_sprite = player.get_node_or_null("Sprite2D")
	
	dash_shader = load("res://assets/shaders/dash_trail.gdshader")
	
	setup_default_gradient()

func setup_default_gradient() -> void:
	if not trail_gradient:
		trail_gradient = Gradient.new()
		trail_gradient.add_point(0.0, Color.CYAN)
		trail_gradient.add_point(0.3, Color.BLUE)
		trail_gradient.add_point(0.6, Color.MAGENTA)
		trail_gradient.add_point(1.0, Color.WHITE)

func connect_player_signals() -> void:
	if player and player.has_signal("dash_performed"):
		player.dash_performed.connect(on_dash_started)

func _process(delta: float) -> void:
	update_dash_state()
	
	if is_dash_active:
		update_trail_spawning(delta)
	
	update_all_ghosts(delta)

func update_dash_state() -> void:
	var was_dashing = is_dash_active
	
	if player and "is_dashing" in player:
		is_dash_active = player.is_dashing
	else:
		is_dash_active = false
	
	if was_dashing and not is_dash_active:
		on_dash_ended()

func on_dash_started() -> void:
	is_dash_active = true
	trail_spawn_timer = 0.0

func on_dash_ended() -> void:
	is_dash_active = false

func update_trail_spawning(delta: float) -> void:
	trail_spawn_timer -= delta
	
	if trail_spawn_timer <= 0.0:
		spawn_trail_ghost()
		trail_spawn_timer = trail_spawn_interval

func spawn_trail_ghost() -> void:
	cleanup_expired_ghosts()
	
	if trail_ghosts.size() >= max_trail_ghosts:
		remove_oldest_ghost()
	
	var ghost_data = create_ghost_data()
	if ghost_data.size() > 0:
		trail_ghosts.append(ghost_data)
		get_tree().current_scene.add_child(ghost_data.sprite)

func create_ghost_data() -> Dictionary:
	if not player_sprite:
		return {}
	
	var current_texture = get_current_sprite_texture()
	if not current_texture:
		return {}
	
	var ghost = Sprite2D.new()
	ghost.name = "DashGhost"
	ghost.texture = current_texture
	
	ghost.global_position = player_sprite.global_position
	ghost.global_rotation = player_sprite.global_rotation
	ghost.global_scale = player_sprite.global_scale
	ghost.z_index = player_sprite.z_index - 1
	
	copy_sprite_visual_properties(ghost)
	
	setup_ghost_material(ghost)
	
	return {
		"sprite": ghost,
		"age": 0.0,
		"max_age": trail_fade_duration,
		"initial_color": trail_gradient.sample(0.0)
	}

func get_current_sprite_texture() -> Texture2D:
	if player_sprite is AnimatedSprite2D:
		var animated_sprite = player_sprite as AnimatedSprite2D
		
		if not animated_sprite.sprite_frames:
			return null
		
		var current_animation = animated_sprite.animation
		if current_animation == "":
			return null
		
		var current_frame = animated_sprite.frame
		return animated_sprite.sprite_frames.get_frame_texture(current_animation, current_frame)
		
	elif player_sprite is Sprite2D:
		var sprite = player_sprite as Sprite2D
		return sprite.texture
	
	return null

func copy_sprite_visual_properties(ghost: Sprite2D) -> void:
	if player_sprite is AnimatedSprite2D:
		var animated_sprite = player_sprite as AnimatedSprite2D
		
		ghost.centered = animated_sprite.centered
		ghost.offset = animated_sprite.offset
		ghost.flip_h = animated_sprite.flip_h
		ghost.flip_v = animated_sprite.flip_v
		
	elif player_sprite is Sprite2D:
		var sprite = player_sprite as Sprite2D
		
		ghost.centered = sprite.centered
		ghost.offset = sprite.offset
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v

func setup_ghost_material(ghost: Sprite2D) -> void:
	var material = ShaderMaterial.new()
	material.shader = dash_shader
	
	var initial_color = trail_gradient.sample(0.0)
	
	if dash_shader and dash_shader.get_path().ends_with("dash_trail.gdshader"):
		material.set_shader_parameter("white_intensity", 1.0)
		material.set_shader_parameter("trail_color", initial_color)
		material.set_shader_parameter("alpha_fade", 1.0)
	else:
		if dash_shader:
			material.set_shader_parameter("white_intensity", 1.0)
		ghost.modulate = initial_color
	
	ghost.material = material

func update_all_ghosts(delta: float) -> void:
	var ghosts_to_remove: Array[int] = []
	
	for i in range(trail_ghosts.size()):
		var ghost_data = trail_ghosts[i]
		ghost_data.age += delta
		
		var progress = ghost_data.age / ghost_data.max_age
		
		if progress >= 1.0:
			ghosts_to_remove.append(i)
			continue
		
		update_ghost_visual(ghost_data, progress)
	
	for i in range(ghosts_to_remove.size() - 1, -1, -1):
		var ghost_index = ghosts_to_remove[i]
		remove_ghost_at_index(ghost_index)

func update_ghost_visual(ghost_data: Dictionary, progress: float) -> void:
	var ghost = ghost_data.sprite as Sprite2D
	if not is_instance_valid(ghost):
		return
	
	var current_color = trail_gradient.sample(progress)
	
	var alpha_fade = lerp(0.8, 0.0, progress)
	
	var scale_factor = lerp(1.0, 0.85, progress)
	ghost.scale = player_sprite.global_scale * scale_factor
	
	if ghost.material and dash_shader and dash_shader.get_path().ends_with("dash_trail.gdshader"):
		ghost.material.set_shader_parameter("trail_color", current_color)
		ghost.material.set_shader_parameter("alpha_fade", alpha_fade)
	else:
		current_color.a = alpha_fade
		ghost.modulate = current_color

func remove_ghost_at_index(index: int) -> void:
	if index >= 0 and index < trail_ghosts.size():
		var ghost_data = trail_ghosts[index]
		if is_instance_valid(ghost_data.sprite):
			ghost_data.sprite.queue_free()
		trail_ghosts.remove_at(index)

func remove_oldest_ghost() -> void:
	if trail_ghosts.size() > 0:
		remove_ghost_at_index(0)

func cleanup_expired_ghosts() -> void:
	var valid_ghosts: Array[Dictionary] = []
	for ghost_data in trail_ghosts:
		if is_instance_valid(ghost_data.sprite):
			valid_ghosts.append(ghost_data)
	trail_ghosts = valid_ghosts

func clear_all_ghosts() -> void:
	for ghost_data in trail_ghosts:
		if is_instance_valid(ghost_data.sprite):
			ghost_data.sprite.queue_free()
	trail_ghosts.clear()

func set_trail_color_gradient(new_gradient: Gradient) -> void:
	trail_gradient = new_gradient

func _exit_tree() -> void:
	clear_all_ghosts()

func get_player_sprite_type() -> String:
	if not player_sprite:
		return "None"
	elif player_sprite is AnimatedSprite2D:
		return "AnimatedSprite2D"
	elif player_sprite is Sprite2D:
		return "Sprite2D"
	else:
		return "Unknown"
