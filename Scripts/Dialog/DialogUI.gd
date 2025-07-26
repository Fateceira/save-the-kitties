extends Control
class_name DialogUI

signal dialog_finished
signal dialog_event_triggered(event_name: String)

@export_category("UI Elements")
@export var background: ColorRect
@export var character_name: Label
@export var dialog_text: RichTextLabel
@export var character_portrait: TextureRect
@export var skip_indicator: Label

var current_sequence: DialogSequence
var current_dialog_index: int = 0
var is_typing: bool = false
var can_advance: bool = false
var text_tween: Tween

var emotion_frames: Dictionary = {
	"neutral": Vector2(0, 0),
	"happy": Vector2(1, 0),
	"sad": Vector2(2, 0),
	"angry": Vector2(3, 0),
	"surprised": Vector2(4, 0)
}

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	
	visible = false
	
	if skip_indicator:
		skip_indicator.text = "Pressione ESPAÇO para continuar"
		skip_indicator.modulate.a = 0.0

func _input(event):
	if not visible or not current_sequence:
		return
	
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_handle_input()
	
	if event.is_action_pressed("ui_cancel") and current_sequence.can_skip:
		_skip_dialog()

func start_sequence(sequence: DialogSequence):
	current_sequence = sequence
	current_dialog_index = 0
	visible = true
	_show_current_dialog()

func _show_current_dialog():
	if current_dialog_index >= current_sequence.dialogs.size():
		_finish_sequence()
		return
	
	var dialog_data = current_sequence.dialogs[current_dialog_index]
	
	if character_name:
		character_name.text = dialog_data.character_name
	
	if character_portrait and dialog_data.character_portrait:
		character_portrait.texture = dialog_data.character_portrait
		_update_character_emotion(dialog_data.emotion)
	
	if dialog_text:
		dialog_text.text = ""
		dialog_text.visible_characters = 0
	
	if skip_indicator:
		skip_indicator.modulate.a = 0.0
	
	_start_text_animation(dialog_data)

func _start_text_animation(dialog_data: DialogData):
	is_typing = true
	can_advance = false
	
	if dialog_text:
		dialog_text.text = dialog_data.dialog_text
		dialog_text.visible_characters = 0
		
		if text_tween:
			text_tween.kill()
		
		text_tween = create_tween()
		var total_chars = dialog_text.text.length()
		var duration = total_chars * dialog_data.text_speed
		
		text_tween.tween_method(_update_visible_characters, 0, total_chars, duration)
		text_tween.tween_callback(_on_text_finished)

func _update_visible_characters(chars: int):
	if dialog_text:
		dialog_text.visible_characters = chars

func _on_text_finished():
	is_typing = false
	can_advance = true
	
	if skip_indicator:
		skip_indicator.modulate.a = 1.0

func _handle_input():
	if is_typing:
		if text_tween:
			text_tween.kill()
		if dialog_text:
			dialog_text.visible_characters = dialog_text.text.length()
		_on_text_finished()
		return
	
	if can_advance:
		_advance_dialog()

func _advance_dialog():
	var current_dialog = current_sequence.dialogs[current_dialog_index]
	
	if current_dialog.trigger_event != "":
		dialog_event_triggered.emit(current_dialog.trigger_event)
	
	current_dialog_index += 1
	_show_current_dialog()

func _skip_dialog():
	_finish_sequence()

func _finish_sequence():
	if current_sequence.trigger_on_complete != "":
		dialog_event_triggered.emit(current_sequence.trigger_on_complete)
	
	visible = false
	dialog_finished.emit()

func _update_character_emotion(emotion: String):
	if not character_portrait or not emotion_frames.has(emotion):
		return
	
	var frame_pos = emotion_frames[emotion]
