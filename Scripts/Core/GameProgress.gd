extends Node

const SAVE_FILE = "user://game_progress.save"

var unlocked_levels: Array[int] = [1]
var level_scores: Dictionary = {}
var level_completed: Dictionary = {}

signal level_unlocked(level: int)
signal progress_updated

func _ready() -> void:
	add_to_group("game_progress_singleton")
	print("=== GAMEMANAGER SINGLETON INICIADO ===")
	load_progress()
	print("GameProgress: Níveis desbloqueados: ", unlocked_levels)

func unlock_level(level: int) -> void:
	if level not in unlocked_levels:
		unlocked_levels.append(level)
		print("🔓 GameProgress: Fase ", level, " DESBLOQUEADA!")
		save_progress()
		level_unlocked.emit(level)
		progress_updated.emit()

func is_level_unlocked(level: int) -> bool:
	return level in unlocked_levels

func get_max_unlocked_level() -> int:
	if unlocked_levels.is_empty():
		return 1
	return unlocked_levels.max()

func complete_level(level: int, score: int) -> void:
	print("🏆 GameProgress: Completando fase ", level, " com score ", score)
	level_completed[level] = true
	set_level_score(level, score)
	
	# SEMPRE desbloqueia a próxima fase
	var next_level = level + 1
	if next_level <= 5:  # Assumindo 5 fases máximo
		unlock_level(next_level)
	
	save_progress()
	progress_updated.emit()
	print("✅ GameProgress: Fase ", level, " completada! Próxima fase desbloqueada: ", next_level)

func is_level_completed(level: int) -> bool:
	return level_completed.get(level, false)

func set_level_score(level: int, score: int) -> void:
	if not level_scores.has(level) or score > level_scores[level]:
		level_scores[level] = score
		save_progress()

func get_level_score(level: int) -> int:
	return level_scores.get(level, 0)

func save_progress() -> void:
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		var save_data = {
			"unlocked_levels": unlocked_levels,
			"level_scores": level_scores,
			"level_completed": level_completed
		}
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("💾 GameProgress: Salvo - Desbloqueados: ", unlocked_levels)
	else:
		print("❌ GameProgress: ERRO ao salvar!")

func load_progress() -> void:
	if FileAccess.file_exists(SAVE_FILE):
		var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var save_data = json.data
				
				var loaded_levels = save_data.get("unlocked_levels", [1])
				unlocked_levels.clear()
				for level in loaded_levels:
					var level_int = int(level)
					if level_int > 0:
						unlocked_levels.append(level_int)
				
				if unlocked_levels.is_empty():
					unlocked_levels = [1]
				
				var loaded_scores = save_data.get("level_scores", {})
				level_scores.clear()
				for key in loaded_scores.keys():
					var level_key = int(key) if key is String else key
					level_scores[level_key] = loaded_scores[key]
				
				var loaded_completed = save_data.get("level_completed", {})
				level_completed.clear()
				for key in loaded_completed.keys():
					var level_key = int(key) if key is String else key
					level_completed[level_key] = loaded_completed[key]
				
				print("📂 GameProgress: Carregado do save - Desbloqueados: ", unlocked_levels)
			else:
				print("❌ GameProgress: Erro ao parsear JSON")
	else:
		print("📂 GameProgress: Nenhum save, usando padrão - Desbloqueados: ", unlocked_levels)

func reset_progress() -> void:
	unlocked_levels = [1]
	level_scores.clear()
	level_completed.clear()
	save_progress()
	progress_updated.emit()
	print("🔄 GameProgress: Progresso resetado!")
