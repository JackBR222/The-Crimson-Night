extends SpotLight3D

@export var starts_on: bool = true
@export var can_use: bool = true
@export var locked_state: bool = false

@onready var sfx: AudioStreamPlayer3D = $AudioStreamPlayer3D

# Estado atual (para uso em outros scripts)
var is_on: bool = false

func _ready() -> void:
	add_to_group("flashlight")

	is_on = starts_on
	_update_light()


func _process(_delta: float) -> void:
	if not can_use:
		return

	if locked_state:
		return

	# Troca estado via input
	if Input.is_action_just_pressed("toggle_flashlight"):
		toggle_flashlight()

		if sfx:
			sfx.play()


func toggle_flashlight() -> void:
	if not can_use or locked_state:
		return

	is_on = not is_on
	_update_light()


func force_state(state: bool) -> void:
	# Permite outros scripts forçarem estado
	if not can_use:
		return

	is_on = state
	_update_light()


func _update_light() -> void:
	visible = is_on
	light_energy = 2.0 if is_on else 0.0
