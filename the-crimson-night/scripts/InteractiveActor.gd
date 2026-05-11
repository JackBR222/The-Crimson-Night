extends StaticBody3D
class_name InteractiveActor


# TIMELINES
@export var dialog_timeline: Resource
@export var dialog_timeline_alt: Resource


# MODELS
@export var model_main: Node3D
@export var model_alt: Node3D


# DATA
@export var actor_id: String = "A"

# se começar já bloqueado (Inspector)
@export var start_locked: bool = false


var current_timeline: Resource
var pending_timeline: Resource

var pending_model_alt := false

var current_player: PlayerController

var interaction_locked := false


# INTERACTION ICON
@onready var icon: Sprite3D = $InteractionIcon
var is_targeted := false


# INICIALIZAÇÃO
func _ready():
	current_timeline = dialog_timeline
	Dialogic.signal_event.connect(_on_dialogic_signal)

	_apply_model(false)
	interaction_locked = start_locked

	if icon:
		icon.visible = false


# CONTROLE DO ÍCONE DE INTERAÇÃO
func set_targeted(state: bool) -> void:
	is_targeted = state
	_update_icon()


func _update_icon() -> void:
	if icon:
		icon.visible = is_targeted and not interaction_locked and current_player == null


# INTERAÇÃO
func interact(player: Node) -> void:
	if interaction_locked or not player is PlayerController:
		return

	current_player = player
	set_targeted(false)

	_update_dialogic_context()
	start_dialog()


func start_dialog() -> void:
	if current_player:
		current_player.freeze_input()

	_disconnect_dialogic()

	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start(current_timeline)


# FIM DO DIÁLOGO
func _on_timeline_ended() -> void:
	_disconnect_dialogic()

	if current_player:
		current_player.unfreeze_input()
		current_player = null

	Dialogic.VAR.set("current_door_id", "NONE")

	if pending_timeline:
		current_timeline = pending_timeline
		pending_timeline = null

	_apply_model(pending_model_alt)

	is_targeted = true
	_update_icon()


# SINAIS DO DIALOGIC
func _on_dialogic_signal(argument: String) -> void:

	match argument:

		"lock_interaction":
			if Dialogic.VAR.get("current_door_id") == actor_id:
				lock_interaction()

		"change_timeline_main":
			if Dialogic.VAR.get("current_door_id") == actor_id:
				change_timeline(dialog_timeline)

		"change_timeline_alt":
			if Dialogic.VAR.get("current_door_id") == actor_id:
				change_timeline(dialog_timeline_alt)

		"change_model_main":
			if Dialogic.VAR.get("current_door_id") == actor_id:
				change_model(false)

		"change_model_alt":
			if Dialogic.VAR.get("current_door_id") == actor_id:
				change_model(true)

		"checkpoint_test":
			Checkpoint.definir_checkpoint(-1)

		"end_game":
			await get_tree().create_timer(3.0).timeout
			get_tree().change_scene_to_file("res://scenes/Ending.tscn")

		_:
			if argument.begins_with("checkpoint_"):
				Checkpoint.definir_checkpoint(int(argument.replace("checkpoint_", "")))


# CONTROLE DE TIMELINE
func change_timeline(new_timeline: Resource) -> void:
	pending_timeline = new_timeline


# CONTROLE DE MODELO
func change_model(use_alt: bool) -> void:
	pending_model_alt = use_alt


func _apply_model(use_alt: bool) -> void:
	if model_main:
		model_main.visible = not use_alt
		_set_physics_enabled(model_main, not use_alt)

	if model_alt:
		model_alt.visible = use_alt
		_set_physics_enabled(model_alt, use_alt)


func _set_physics_enabled(root: Node, enabled: bool) -> void:
	for child in root.get_children():

		if child is CollisionShape3D:
			child.disabled = not enabled

		if child is CollisionObject3D:
			child.set_deferred("disabled", not enabled)

		if child.get_child_count() > 0:
			_set_physics_enabled(child, enabled)


# BLOQUEIO DE INTERAÇÃO
func lock_interaction() -> void:
	interaction_locked = true

	if current_player:
		current_player.unfreeze_input()
		current_player = null

	_update_icon()

	print("Interação bloqueada: ", actor_id)


# CONTEXTO DO DIALOGIC
func _update_dialogic_context() -> void:
	Dialogic.VAR.set("current_door_id", actor_id)


# HELPERS
func _disconnect_dialogic() -> void:
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)
