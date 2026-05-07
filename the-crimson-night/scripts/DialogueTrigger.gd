extends StaticBody3D

@export var dialog_timeline: Resource

var current_player: PlayerController = null

var is_targeted: bool = false

@onready var icon: Sprite3D = $InteractionIcon


func _ready() -> void:
	if icon:
		icon.visible = false


# INTERAÇÃO
func interact(player: Node) -> void:
	if not player is PlayerController:
		return

	set_targeted(false)

	current_player = player as PlayerController
	start_dialog()


# CONTROLE DO ÍCONE (igual ao Item)
func set_targeted(state: bool) -> void:
	is_targeted = state

	if icon:
		icon.visible = state


# START DIALOG
func start_dialog() -> void:
	if current_player:
		current_player.freeze_input()

	# evita múltiplas conexões
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)

	Dialogic.timeline_ended.connect(_on_timeline_ended)

	Dialogic.start(dialog_timeline)


# END DIALOG
func _on_timeline_ended() -> void:
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)

	if current_player:
		current_player.unfreeze_input()
		current_player = null
