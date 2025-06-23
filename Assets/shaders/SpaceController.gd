@tool
extends TextureRect

@export_group("Pixelization")
@export var pixel_scale: float = 1.0 : set = _update_pixel_scale

@export_group("Stars")
@export var star_texture: Texture2D : set = _update_star_texture
@export var use_star_texture: bool = true : set = _update_use_star_texture
@export var star_tint: Color = Color.WHITE : set = _update_star_tint
@export_range(10.0, 200.0) var star_density: float = 80.0 : set = _update_star_density
@export_range(0.005, 1) var star_size_min: float = 0.01 : set = _update_star_size_min
@export_range(0.01, 1) var star_size_max: float = 0.03 : set = _update_star_size_max
@export_range(0.1, 2.0) var twinkle_speed: float = 0.5 : set = _update_twinkle_speed
@export_range(-0.1, 0.1) var parallax_speed: float = 0.02 : set = _update_parallax_speed

@export_group("Nebulas")
@export var nebula_color1: Color = Color(0.8, 0.4, 1.0, 1.0) : set = _update_nebula_color1
@export var nebula_color2: Color = Color(0.2, 0.4, 1.0, 1.0) : set = _update_nebula_color2
@export var nebula_color3: Color = Color(0.1, 0.8, 0.9, 1.0) : set = _update_nebula_color3
@export_range(0.5, 5.0) var nebula_size1: float = 2.0 : set = _update_nebula_size1
@export_range(0.5, 5.0) var nebula_size2: float = 3.0 : set = _update_nebula_size2
@export_range(0.5, 5.0) var nebula_size3: float = 1.5 : set = _update_nebula_size3
@export_range(0.1, 2.0) var nebula_density: float = 0.5 : set = _update_nebula_density

@export_group("Colors")
@export var space_color: Color = Color(0.03, 0.01, 0.1, 1.0) : set = _update_space_color
@export_range(0.0, 1.0) var color_variation: float = 0.2 : set = _update_color_variation

var shader_material: ShaderMaterial

func _ready():
	_setup_material()

func _setup_material():
	if not shader_material:
		shader_material = ShaderMaterial.new()
		shader_material.shader = load("res://assets/shaders/space_background.gdshader")
		material = shader_material
	
	_update_all_parameters()

func _update_all_parameters():
	if not shader_material:
		_setup_material()
		return
	
	shader_material.set_shader_parameter("pixel_scale", pixel_scale)
	shader_material.set_shader_parameter("star_texture", star_texture)
	shader_material.set_shader_parameter("use_star_texture", use_star_texture)
	shader_material.set_shader_parameter("star_tint", star_tint)
	shader_material.set_shader_parameter("star_density", star_density)
	shader_material.set_shader_parameter("star_size_min", star_size_min)
	shader_material.set_shader_parameter("star_size_max", star_size_max)
	shader_material.set_shader_parameter("twinkle_speed", twinkle_speed)
	shader_material.set_shader_parameter("parallax_speed", parallax_speed)
	shader_material.set_shader_parameter("nebula_color1", nebula_color1)
	shader_material.set_shader_parameter("nebula_color2", nebula_color2)
	shader_material.set_shader_parameter("nebula_color3", nebula_color3)
	shader_material.set_shader_parameter("nebula_size1", nebula_size1)
	shader_material.set_shader_parameter("nebula_size2", nebula_size2)
	shader_material.set_shader_parameter("nebula_size3", nebula_size3)
	shader_material.set_shader_parameter("nebula_density", nebula_density)
	shader_material.set_shader_parameter("space_color", space_color)
	shader_material.set_shader_parameter("color_variation", color_variation)

func _update_parameter(parameter_name: String, value):
	if not shader_material:
		_setup_material()
	else:
		shader_material.set_shader_parameter(parameter_name, value)

func _update_pixel_scale(value: float):
	pixel_scale = value
	_update_parameter("pixel_scale", value)

func _update_star_texture(value: Texture2D):
	star_texture = value
	_update_parameter("star_texture", value)

func _update_use_star_texture(value: bool):
	use_star_texture = value
	_update_parameter("use_star_texture", value)

func _update_star_tint(value: Color):
	star_tint = value
	_update_parameter("star_tint", value)

func _update_star_density(value: float):
	star_density = value
	_update_parameter("star_density", value)

func _update_star_size_min(value: float):
	star_size_min = value
	_update_parameter("star_size_min", value)

func _update_star_size_max(value: float):
	star_size_max = value
	_update_parameter("star_size_max", value)

func _update_twinkle_speed(value: float):
	twinkle_speed = value
	_update_parameter("twinkle_speed", value)

func _update_parallax_speed(value: float):
	parallax_speed = value
	_update_parameter("parallax_speed", value)

func _update_nebula_color1(value: Color):
	nebula_color1 = value
	_update_parameter("nebula_color1", value)

func _update_nebula_color2(value: Color):
	nebula_color2 = value
	_update_parameter("nebula_color2", value)

func _update_nebula_color3(value: Color):
	nebula_color3 = value
	_update_parameter("nebula_color3", value)

func _update_nebula_size1(value: float):
	nebula_size1 = value
	_update_parameter("nebula_size1", value)

func _update_nebula_size2(value: float):
	nebula_size2 = value
	_update_parameter("nebula_size2", value)

func _update_nebula_size3(value: float):
	nebula_size3 = value
	_update_parameter("nebula_size3", value)

func _update_nebula_density(value: float):
	nebula_density = value
	_update_parameter("nebula_density", value)

func _update_space_color(value: Color):
	space_color = value
	_update_parameter("space_color", value)

func _update_color_variation(value: float):
	color_variation = value
	_update_parameter("color_variation", value)
