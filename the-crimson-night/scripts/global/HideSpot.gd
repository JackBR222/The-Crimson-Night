extends StaticBody3D
class_name HideSpot

@export var hidden_distance: float = 2
@export var hidden_height: float = 2.5
@export var hidden_rotation_speed: float = 45.0

@export var interaction_cooldown: float = 1.0

@onready var exit_position: Node3D = $ExitPosition
@onready var hide_point: MeshInstance3D = _find_hide_point()
@onready var player_camera = get_tree().current_scene.get_node("Player/SpringArm3D/Camera3D")
@onready var vignette = get_tree().current_scene.get_node("CanvasLayer/Vignette")
@onready var icon: Sprite3D = $InteractionIcon

var hidden_player: PlayerController = null
var player_footsteps: Node = null

var original_distance: float
var original_height: float
var original_rotation_speed: float

var can_interact: bool = true
var is_targeted: bool = false

# INIT 
func _ready() -> void:
	if vignette:
		vignette.visible = false

	if icon:
		icon.visible = false


func _find_hide_point() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null


# INTERAÇÃO 
func interact(player: Node) -> void:
	if not player is PlayerController or not can_interact:
		return

	can_interact = false
	_start_interact_cooldown()

	if hidden_player:
		unhide_player()
	else:
		hide_player(player)


func _start_interact_cooldown() -> void:
	await get_tree().create_timer(interaction_cooldown).timeout
	can_interact = true


func set_targeted(value: bool) -> void:
	is_targeted = value
	if icon and hidden_player == null:
		icon.visible = value


# ESCONDER
func hide_player(player: PlayerController) -> void:

	hidden_player = player

	# SALVA POSIÇÃO REAL ANTES DE ESCONDER
	var pre_hide_position = player.global_position

	# AVISA TODOS OS INIMIGOS
	for enemy in get_tree().get_nodes_in_group("enemies"):

		if enemy.has_method("set_last_known_position"):
			enemy.set_last_known_position(pre_hide_position)

	# AGORA ESCONDE
	if hide_point:
		player.global_transform = hide_point.global_transform

	original_distance = player_camera.distance
	original_height = player_camera.height
	original_rotation_speed = player_camera.rotation_speed

	player_camera.distance = hidden_distance
	player_camera.height = hidden_height
	player_camera.rotation_speed = hidden_rotation_speed

	player.input_enabled = false
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)

	player.set_collision_layer(0)
	player.set_collision_mask(0)

	player.visible = false
	player.is_hidden = true

	player_footsteps = find_footstep_system(player)

	if player_footsteps:
		player_footsteps.force_stop_steps()

	if vignette:
		vignette.visible = true

	if icon:
		icon.visible = false


# INPUT PARA SAIR
func _unhandled_input(event: InputEvent) -> void:
	if hidden_player == null:
		return

	if event.is_action_pressed("interact") and can_interact:
		can_interact = false
		_start_interact_cooldown()
		unhide_player()


# SAIR
func unhide_player() -> void:
	if hidden_player == null:
		return

	var player = hidden_player

	if exit_position:
		player.global_transform = exit_position.global_transform

	if player_camera:
		player_camera.distance = original_distance
		player_camera.height = original_height
		player_camera.rotation_speed = original_rotation_speed

	player.input_enabled = true
	player.set_physics_process(true)

	player.set_collision_layer(1)
	player.set_collision_mask(1)

	player.visible = true
	player.is_hidden = false

	if player_footsteps:
		player_footsteps.restore_steps()

	if vignette:
		vignette.visible = false

	hidden_player = null

	if icon and is_targeted:
		icon.visible = true


# CONTROLE DO SISTEMA DE PASSOS
func find_footstep_system(player: Node) -> Node:
	for child in player.get_children():
		if child.has_method("force_stop_steps") and child.has_method("restore_steps"):
			return child
		var result = search_deep(child)
		if result:
			return result
	return null


func search_deep(node: Node) -> Node:
	for child in node.get_children():
		if child.has_method("force_stop_steps") and child.has_method("restore_steps"):
			return child
		var result = search_deep(child)
		if result:
			return result
	return null
