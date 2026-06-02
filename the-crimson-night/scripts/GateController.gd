extends Node3D

@export var open_scene: PackedScene

@export var use_open_camera := false
@export var open_camera_time := 1.5

@onready var open_camera: Camera3D = $OpenCamera
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var open_sfx: AudioStreamPlayer3D = $OpenGateSound
@onready var player = get_tree().current_scene.get_node("Player/Player")

const OPEN_ANIM := "Armature|OPEN GATE_001"

var is_opening := false
var is_open := false

func _ready() -> void:
	_set_closed_pose()

	Dialogic.signal_event.connect(_on_dialogic_signal)

	if open_camera:
		open_camera.current = false

	if not anim_player.animation_finished.is_connected(_on_anim_finished):
		anim_player.animation_finished.connect(_on_anim_finished)

func open_gate() -> void:
	if is_open or is_opening:
		return

	is_opening = true

	if open_sfx:
		open_sfx.play()

	if use_open_camera and open_camera:
		freeze_game()
		open_camera.current = true

	anim_player.play(OPEN_ANIM)

func force_close() -> void:
	is_opening = false
	is_open = false

	_set_closed_pose()

func freeze_game() -> void:
	_set_game_process_mode(Node.PROCESS_MODE_DISABLED)

func unfreeze_game() -> void:
	_set_game_process_mode(Node.PROCESS_MODE_INHERIT)

func _set_game_process_mode(mode: ProcessMode) -> void:
	get_tree().call_group(
		"enemies",
		"set_process_mode",
		mode
	)

	if player:
		player.set_process_mode(mode)

func _set_closed_pose() -> void:
	anim_player.stop()
	anim_player.play(OPEN_ANIM)

	anim_player.seek(0.0, true)
	anim_player.stop()

	anim_player.advance(0)

func _on_anim_finished(anim_name: StringName) -> void:
	if anim_name == OPEN_ANIM:
		_finish_opening()

func _finish_opening() -> void:
	is_opening = false
	is_open = true

	if use_open_camera and open_camera:
		await get_tree().create_timer(open_camera_time).timeout

		open_camera.current = false

		unfreeze_game()

	if open_scene:
		var opened_gate = open_scene.instantiate()

		get_parent().add_child(opened_gate)

		opened_gate.global_transform = global_transform

	queue_free()

func _on_dialogic_signal(argument: String) -> void:
	if argument == "open_gate":
		open_gate()
