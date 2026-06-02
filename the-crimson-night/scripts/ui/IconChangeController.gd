extends Sprite3D

@export var keyboard_texture: Texture2D

@export var xbox_texture: Texture2D
@export var playstation_texture: Texture2D
@export var nintendo_texture: Texture2D

enum InputType {
	KEYBOARD,
	XBOX,
	PLAYSTATION,
	NINTENDO
}

var current_input: InputType = InputType.KEYBOARD


func _ready() -> void:
	set_process_input(true)
	_update_icon()


func _input(event: InputEvent) -> void:
	# Controle
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var type = _detect_gamepad_type()

		if current_input != type:
			current_input = type
			_update_icon()

	# Teclado / Mouse
	elif event is InputEventKey or event is InputEventMouseButton:
		if current_input != InputType.KEYBOARD:
			current_input = InputType.KEYBOARD
			_update_icon()


# DETECTAR TIPO DE CONTROLE
func _detect_gamepad_type() -> InputType:
	var joypads = Input.get_connected_joypads()

	if joypads.is_empty():
		return InputType.KEYBOARD

	@warning_ignore("shadowed_variable_base_class")
	var _name = Input.get_joy_name(joypads[0]).to_lower()

	# PlayStation
	if "ps" in name or "playstation" in name or "dualshock" in name or "dualsense" in name:
		return InputType.PLAYSTATION

	# Xbox
	elif "xbox" in name or "xinput" in name or "microsoft" in name:
		return InputType.XBOX

	# Nintendo (Switch / Joy-Con / Pro Controller)
	elif "nintendo" in name or "switch" in name or "joy" in name:
		return InputType.NINTENDO

	# fallback → assume Xbox (melhor que genérico)
	return InputType.XBOX


# ATUALIZAR ÍCONE
func _update_icon() -> void:
	match current_input:
		InputType.KEYBOARD:
			texture = keyboard_texture

		InputType.XBOX:
			texture = xbox_texture if xbox_texture else keyboard_texture

		InputType.PLAYSTATION:
			texture = playstation_texture if playstation_texture else keyboard_texture

		InputType.NINTENDO:
			texture = nintendo_texture if nintendo_texture else keyboard_texture
