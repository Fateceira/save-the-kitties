extends Control

@export var level_scenes: Array[String] = [
	"res://Scenes/Fases/Level1.tscn",
	"res://Scenes/Fases/Level2.tscn", 
	"res://Scenes/Fases/Level3.tscn",
	"res://Scenes/Fases/Level4.tscn",
	"res://Scenes/Fases/Level5.tscn"
]

@export var level_buttons: Array[TextureButton] = []
@export var level_labels: Array[Label] = []

var game_progress_singleton: Node
var locked_texture: Texture2D = preload("res://assets/Menu/Locked_level.png")
var normal_texture: Texture2D = preload("res://assets/Menu/btnNormal.png")
var pressed_texture: Texture2D = preload("res://assets/Menu/btnPressed.png")

func _ready() -> void:
	# Tenta acessar o singleton ou cria um temporário
	game_progress_singleton = get_singleton_or_create()
	
	print("Fases: Iniciando seletor - Desbloqueados: ", game_progress_singleton.unlocked_levels)
	update_level_buttons()
	connect_button_signals()
	
	# Conecta ao sinal se existir
	if game_progress_singleton.has_signal("progress_updated"):
		game_progress_singleton.progress_updated.connect(update_level_buttons)

func get_singleton_or_create() -> Node:
	# Tenta acessar o singleton
	if Engine.has_singleton("GameProgress"):
		return Engine.get_singleton("GameProgress")
	
	# Se não existir, tenta encontrar na árvore
	var existing = get_tree().get_first_node_in_group("game_progress_singleton")
	if existing:
		return existing
	
	# Se não encontrar, cria um novo
	print("Fases: Criando GameProgress temporário")
	var temp_progress = preload("res://Scripts/Core/GameProgress.gd").new()
	temp_progress.add_to_group("game_progress_singleton")
	get_tree().root.add_child(temp_progress)
	return temp_progress

func connect_button_signals() -> void:
	for i in range(level_buttons.size()):
		var button = level_buttons[i]
		if button and not button.pressed.is_connected(_on_level_button_pressed):
			button.pressed.connect(_on_level_button_pressed.bind(i + 1))

func update_level_buttons() -> void:
	if not game_progress_singleton:
		return
		
	print("Fases: Atualizando botões - Desbloqueados: ", game_progress_singleton.unlocked_levels)
	
	for i in range(level_buttons.size()):
		var level = i + 1
		var button = level_buttons[i]
		var label = level_labels[i] if i < level_labels.size() else null
		
		if not button:
			continue
		
		var is_unlocked = game_progress_singleton.is_level_unlocked(level)
		
		print("Fases: Level ", level, " - Desbloqueado: ", is_unlocked)
		
		button.disabled = not is_unlocked
		
		if is_unlocked:
			button.texture_normal = normal_texture
			button.texture_pressed = pressed_texture
			if label:
				label.text = str(level)
				label.visible = true
		else:
			button.texture_normal = locked_texture
			button.texture_pressed = locked_texture
			if label:
				label.text = ""
				label.visible = false

func _on_level_button_pressed(level: int) -> void:
	print("Fases: Indo para fase ", level)
	if level <= level_scenes.size() and level_scenes[level - 1] != "":
		get_tree().change_scene_to_file(level_scenes[level - 1])

func _on_back_pressed():
	get_tree().change_scene_to_file("res://Scenes/menu_principal.tscn")
