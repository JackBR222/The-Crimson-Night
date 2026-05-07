extends Node

@export var dialog_timeline: Resource
@export var start_delay: float = 0.0

@export var change_scene_on_end: bool = false
@export var next_scene: PackedScene

@export var ignore_player: bool = false

var current_player: Node = null
var has_played := false


func _ready() -> void:
	if dialog_timeline == null:
		push_warning("Nenhum dialog_timeline definido!")
		return

	if not ignore_player:
		await _wait_for_player()

	_start_dialog_once()


func _wait_for_player() -> void:
	while current_player == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			current_player = players[0]
		else:
			await get_tree().process_frame


func _start_dialog_once() -> void:
	if has_played:
		return

	has_played = true

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout

	_start_dialog()


func _start_dialog() -> void:
	if current_player and current_player.has_method("freeze_input"):
		current_player.freeze_input()

	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)

	Dialogic.timeline_ended.connect(_on_timeline_ended)

	Dialogic.start(dialog_timeline)


func _on_timeline_ended() -> void:
	if current_player and current_player.has_method("unfreeze_input"):
		current_player.unfreeze_input()

	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)

	print("Diálogo executado (one-shot).")

	if change_scene_on_end:
		if next_scene:
			get_tree().change_scene_to_packed(next_scene)
		else:
			push_warning("change_scene_on_end está ativo, mas nenhuma cena foi definida!")
