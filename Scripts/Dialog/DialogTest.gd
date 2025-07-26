extends Node
class_name DialogTest

# Script de teste para o sistema de diálogo
# Adicione este script a um Node na sua cena principal

@export var test_on_ready: bool = true
@export var test_sequence_id: String = "tutorial_intro"
@export var delay_before_test: float = 1.0

func _ready():
	print("🧪 DialogTest inicializado")
	
	if test_on_ready:
		print("⏰ Aguardando ", delay_before_test, " segundos antes do teste...")
		await get_tree().create_timer(delay_before_test).timeout
		test_dialog_system()

func _input(event):
	# Pressione T para testar o diálogo a qualquer momento
	if event.is_action_pressed("ui_select") or (event is InputEventKey and event.keycode == KEY_T and event.pressed):
		test_dialog_system()

func test_dialog_system():
	print("🔍 === INICIANDO TESTE DO SISTEMA DE DIÁLOGO ===")
	
	# 1. Verificar se DialogManager existe
	if not DialogManager:
		print("❌ ERRO: DialogManager class não encontrada!")
		return
	
	if not DialogManager.instance:
		print("❌ ERRO: DialogManager.instance é null!")
		print("   Certifique-se que há um node DialogManager na cena")
		return
	
	print("✅ DialogManager encontrado")
	
	# 2. Verificar sequências disponíveis
	print("📋 Sequências disponíveis no DialogManager:")
	var sequences = DialogManager.instance.dialog_sequences
	
	if sequences.size() == 0:
		print("❌ ERRO: Nenhuma sequência cadastrada!")
		print("   Adicione DialogSequence resources no array dialog_sequences do DialogManager")
		create_test_sequence()
		return
	
	for i in range(sequences.size()):
		var seq = sequences[i]
		if seq:
			print("   [", i, "] ID: '", seq.sequence_id, "' - Diálogos: ", seq.dialogs.size())
		else:
			print("   [", i, "] ❌ Sequência null!")
	
	# 3. Verificar se a sequência de teste existe
	var found_sequence = false
	for seq in sequences:
		if seq and seq.sequence_id == test_sequence_id:
			found_sequence = true
			print("✅ Sequência de teste '", test_sequence_id, "' encontrada!")
			
			# Verificar detalhes da sequência
			print("   📝 Número de diálogos: ", seq.dialogs.size())
			print("   ⏩ Pode pular: ", seq.can_skip)
			
			# Verificar cada diálogo
			for j in range(seq.dialogs.size()):
				var dialog = seq.dialogs[j]
				if dialog:
					print("     Diálogo [", j, "]: '", dialog.character_name, "' - '", dialog.dialog_text.substr(0, 30), "...'")
				else:
					print("     Diálogo [", j, "]: ❌ null!")
			
			break
	
	if not found_sequence:
		print("❌ ERRO: Sequência '", test_sequence_id, "' não encontrada!")
		print("   IDs disponíveis:")
		for seq in sequences:
			if seq:
				print("     - '", seq.sequence_id, "'")
		return
	
	# 4. Verificar se a scene do dialog está configurada
	var dialog_scene = DialogManager.instance.dialog_ui_scene
	if not dialog_scene:
		print("❌ ERRO: dialog_ui_scene não configurado no DialogManager!")
		return
	
	print("✅ Dialog UI Scene configurado: ", dialog_scene.resource_path)
	
	# 5. Tentar iniciar o diálogo
	print("🚀 Iniciando diálogo de teste...")
	DialogManager.start_dialog(test_sequence_id)
	
	# Conectar sinais para acompanhar o resultado
	if not DialogManager.instance.dialog_started.is_connected(_on_dialog_started):
		DialogManager.instance.dialog_started.connect(_on_dialog_started)
	
	if not DialogManager.instance.dialog_finished.is_connected(_on_dialog_finished):
		DialogManager.instance.dialog_finished.connect(_on_dialog_finished)
	
	if not DialogManager.instance.dialog_event_triggered.is_connected(_on_dialog_event):
		DialogManager.instance.dialog_event_triggered.connect(_on_dialog_event)

func create_test_sequence():
	print("🔧 Criando sequência de teste temporária...")
	
	# Criar DialogData de teste
	var test_dialog1 = DialogData.new()
	test_dialog1.character_name = "Sistema"
	test_dialog1.dialog_text = "Este é um diálogo de teste criado automaticamente."
	test_dialog1.text_speed = 0.05
	test_dialog1.pause_game = true
	
	var test_dialog2 = DialogData.new()
	test_dialog2.character_name = "Sistema"
	test_dialog2.dialog_text = "Se você está vendo isto, o sistema de diálogo está funcionando!"
	test_dialog2.text_speed = 0.05
	test_dialog2.trigger_event = "test_complete"
	
	# Criar DialogSequence de teste
	var test_sequence = DialogSequence.new()
	test_sequence.sequence_id = test_sequence_id
	test_sequence.dialogs = [test_dialog1, test_dialog2]
	test_sequence.can_skip = true
	test_sequence.trigger_on_complete = "test_sequence_complete"
	
	# Adicionar à lista de sequências
	DialogManager.instance.dialog_sequences.append(test_sequence)
	
	print("✅ Sequência de teste criada e adicionada!")
	print("🚀 Tentando iniciar novamente...")
	
	await get_tree().create_timer(0.5).timeout
	DialogManager.start_dialog(test_sequence_id)

func _on_dialog_started():
	print("✅ SUCESSO: Diálogo iniciado!")

func _on_dialog_finished():
	print("✅ SUCESSO: Diálogo finalizado!")

func _on_dialog_event(event_name: String):
	print("🎯 Evento triggado: ", event_name)

# Função para testar diálogos específicos via código
func test_specific_dialog(sequence_id: String):
	test_sequence_id = sequence_id
	test_dialog_system()

# Função para listar todas as sequências
func list_all_sequences():
	print("📋 === LISTA DE TODAS AS SEQUÊNCIAS ===")
	
	if not DialogManager.instance:
		print("❌ DialogManager não disponível")
		return
	
	var sequences = DialogManager.instance.dialog_sequences
	
	if sequences.size() == 0:
		print("❌ Nenhuma sequência cadastrada")
		return
	
	for i in range(sequences.size()):
		var seq = sequences[i]
		if seq:
			print("[", i, "] ID: '", seq.sequence_id, "'")
			print("    Diálogos: ", seq.dialogs.size())
			print("    Pode pular: ", seq.can_skip)
			print("    Evento final: '", seq.trigger_on_complete, "'")
			print()

# Função para debug completo
func full_debug():
	print("🔍 === DEBUG COMPLETO DO SISTEMA ===")
	
	# Verificar game tree
	print("🌳 Verificando scene tree...")
	var main_scene = get_tree().current_scene
	print("   Cena atual: ", main_scene.name)
	
	# Procurar DialogManager
	var dialog_managers = get_tree().get_nodes_in_group("dialog_manager")
	print("   DialogManagers no grupo: ", dialog_managers.size())
	
	# Verificar se está pausado
	print("   Jogo pausado: ", get_tree().paused)
	
	# Verificar nodes filhos da cena principal
	print("   Filhos da cena principal:")
	for child in main_scene.get_children():
		print("     - ", child.name, " (", child.get_class(), ")")
	
	list_all_sequences()
