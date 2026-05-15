extends Node3D

@export var open_scene: PackedScene  # Prefab do portão aberto

# CÂMERA CINEMATIC
@export var use_open_camera: bool = false
@export var open_camera_time: float = 2.5

@onready var open_camera: Camera3D = $OpenCamera
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var player = get_tree().current_scene.get_node("Player/Player")
@onready var open_sfx: AudioStreamPlayer3D = $OpenGateSound

var is_opening: bool = false
var is_open: bool = false


func _ready():
	_set_closed_pose()
	Dialogic.signal_event.connect(_on_dialogic_signal)

	# garante que a câmera não inicia ativa
	if open_camera:
		open_camera.current = false

	#await get_tree().create_timer(1.0).timeout
	#open_gate()


# FUNÇÕES EXTERNAS
func open_gate():
	if is_open or is_opening:
		return

	is_opening = true
	
	# SOM DE ABERTURA
	if open_sfx:
		open_sfx.play()

	# CÂMERA CINEMATIC
	if use_open_camera and open_camera:

		# congela durante a cinematic
		freeze_game()

		# ativa câmera antes da animação
		open_camera.current = true

	anim_player.play("Armature|OPEN GATE_001")

	if not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)


func force_close():
	is_opening = false
	is_open = false
	_set_closed_pose()


# CONTROLE DO JOGO
func freeze_game() -> void:

	# congela inimigos
	get_tree().call_group(
		"enemies",
		"set_process_mode",
		Node.PROCESS_MODE_DISABLED
	)

	# congela player
	if player:
		player.set_process_mode(Node.PROCESS_MODE_DISABLED)


func unfreeze_game() -> void:

	# descongela inimigos
	get_tree().call_group(
		"enemies",
		"set_process_mode",
		Node.PROCESS_MODE_INHERIT
	)

	# descongela player
	if player:
		player.set_process_mode(Node.PROCESS_MODE_INHERIT)


# INTERNO
func _set_closed_pose():
	anim_player.stop()

	# garante que o primeiro frame da animação seja aplicado e “travado”
	anim_player.play("Armature|OPEN GATE_001")
	anim_player.seek(0.0, true)
	anim_player.stop()

	# reforça que o pose do frame 0 fica aplicado
	anim_player.advance(0)


func _on_anim_finished(anim_name: StringName):
	if anim_name == "Armature|OPEN GATE_001":
		_finish_opening()


func _finish_opening():
	is_opening = false
	is_open = true

	# espera o tempo cinematic
	if use_open_camera and open_camera:

		await get_tree().create_timer(open_camera_time).timeout

		open_camera.current = false

		unfreeze_game()

	# troca pelo prefab aberto
	if open_scene:
		var opened_gate = open_scene.instantiate()

		get_parent().add_child(opened_gate)

		opened_gate.global_transform = global_transform

	queue_free()


func _on_dialogic_signal(argument: String) -> void:

	if argument == "open_gate":
		open_gate()
