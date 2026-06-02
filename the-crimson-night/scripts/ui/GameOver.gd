extends CanvasLayer

@export var default_fade_time: float = 1.0
@export var initial_delay: float = 1.0

# UI
@export var fade_overlay: ColorRect
@export var vbox_container: VBoxContainer
@export var background: TextureRect

# Background opcional
@export var bg_game_over: Texture2D

var tween: Tween
var started: bool = false

# TEXTORES DOS BOTÕES
var original_textures := {}

# HOVER PULSE
var hover_tweens = {}


# INICIALIZAÇÃO
func _ready() -> void:
	fade_overlay.modulate.a = 1.0
	background.texture = bg_game_over

	register_buttons()
	await initial_sequence()


# REGISTRAR BOTÕES
func register_buttons() -> void:
	for child in vbox_container.get_children():
		if child is TextureButton:
			var btn := child as TextureButton

			original_textures[btn] = {
				"normal": btn.texture_normal,
				"hover": btn.texture_hover,
				"pressed": btn.texture_pressed
			}

			btn.focus_entered.connect(_on_button_focus_entered.bind(btn))
			btn.focus_exited.connect(_on_button_focus_exited.bind(btn))
			btn.button_down.connect(_on_button_down.bind(btn))
			btn.button_up.connect(_on_button_up.bind(btn))

			# CONTROLE DE MOUSE (NOVO)
			btn.mouse_entered.connect(_on_button_mouse_entered.bind(btn))
			btn.mouse_exited.connect(_on_button_mouse_exited.bind(btn))


# FEEDBACK VISUAL DOS BOTÕES (MESMO DO MAIN MENU)
func _on_button_focus_entered(btn: TextureButton) -> void:
	btn.texture_normal = original_textures[btn]["hover"]
	start_hover_pulse(btn)


func _on_button_focus_exited(btn: TextureButton) -> void:
	btn.texture_normal = original_textures[btn]["normal"]
	stop_hover_pulse(btn)


func _on_button_down(btn: TextureButton) -> void:
	btn.texture_normal = original_textures[btn]["pressed"]


func _on_button_up(btn: TextureButton) -> void:
	if btn.has_focus():
		btn.texture_normal = original_textures[btn]["hover"]
	else:
		btn.texture_normal = original_textures[btn]["normal"]


# CONTROLE DE MOUSE → GARANTE FOCO ÚNICO
func _on_button_mouse_entered(btn: TextureButton) -> void:
	btn.grab_focus() # força apenas um foco ativo


func _on_button_mouse_exited(btn: TextureButton) -> void:
	if not btn.has_focus():
		btn.texture_normal = original_textures[btn]["normal"]
		stop_hover_pulse(btn)


# PULSE DE HOVER (OSCILAÇÃO DE COR)
func start_hover_pulse(btn: TextureButton) -> void:
	stop_hover_pulse(btn)

	var t := create_tween().set_loops()
	hover_tweens[btn] = t

	t.tween_property(btn, "modulate", Color(1.8, 1.8, 1.8, 1), 0.6)
	t.tween_property(btn, "modulate", Color(0.5, 0.5, 0.5, 1), 0.6)


func stop_hover_pulse(btn: TextureButton) -> void:
	if hover_tweens.has(btn):
		hover_tweens[btn].kill()
		hover_tweens.erase(btn)
		btn.modulate = Color(1, 1, 1, 1)


# FADE IN INICIAL
func initial_sequence() -> void:
	await get_tree().create_timer(initial_delay).timeout
	await fade_out()
	focus_first_button()


# FOCO INICIAL
func focus_first_button() -> void:
	for child in vbox_container.get_children():
		if child is BaseButton:
			child.grab_focus()
			return


# CONTROLE DE INPUT
func _input(event: InputEvent) -> void:
	if not started and event.is_pressed():
		started = true


# BOTÕES
func _on_retry_button_pressed() -> void:
	await fade_in()

	if Checkpoint != null and Checkpoint.tem_checkpoint():
		Checkpoint.carregar_checkpoint()
	else:
		get_tree().change_scene_to_file("res://scenes/Game.scn")


func _on_menu_button_pressed() -> void:
	await fade_in()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


# FADE SYSTEM
func fade_in(time: float = -1.0) -> void:
	if time <= 0:
		time = default_fade_time
	start_fade(1.0, time)
	await wait_fade()


func fade_out(time: float = -1.0) -> void:
	if time <= 0:
		time = default_fade_time
	start_fade(0.0, time)
	await wait_fade()


func start_fade(target: float, time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", target, time)


func wait_fade() -> void:
	if tween:
		await tween.finished
