extends CanvasLayer

@export var default_fade_time: float = 1.0
@export var initial_delay: float = 1.5

@export var fade_speed_intro: float = 1.0
@export var fade_speed_menu: float = 0.2

@export var start_scene: PackedScene

# PANELS
@export var press_start_panel: Control
@export var main_panel: Control
@export var options_panel: Control
@export var help_panel: Control
@export var credits_panel: Control

# UI
@export var menu_background: TextureRect
@export var fade_overlay: ColorRect
@export var any_press_start: TextureRect

# BOTÕES
@export var start_button: BaseButton
@export var continue_button: BaseButton
@export var options_button: BaseButton
@export var help_button: BaseButton
@export var credits_button: BaseButton
@export var quit_button: BaseButton
@export var options_back_button: BaseButton
@export var help_back_button: BaseButton
@export var credits_back_button: BaseButton

# ÁUDIO
@export var music_slider: HSlider
@export var sfx_slider: HSlider

@onready var sfx_preview_player: AudioStreamPlayer = $SFXPreviewPlayer

# BACKGROUNDS
@export var bg_press_start: Texture2D
@export var bg_main_menu: Texture2D
@export var bg_options_menu: Texture2D
@export var bg_help_menu: Texture2D
@export var bg_credits_menu: Texture2D

# SONS DE UI
@export var ui_click_sound: AudioStream
@export var ui_hover_sound: AudioStream

var tween: Tween
var any_press_tween: Tween

var started := false
var in_options := false
var in_credits := false
var input_locked := false

var has_checkpoint := false
var any_press_active := true

# sistema de pulse de foco
var focus_tweens := {}

var can_play_music_preview := false
var can_play_sfx_preview := true

# SONS DE UI
@onready var ui_sfx: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var ui_hover_sfx: AudioStreamPlayer = AudioStreamPlayer.new()


# INIT
func _ready() -> void:
	fade_overlay.modulate.a = 1.0

	add_child(ui_sfx)
	ui_sfx.bus = "SFX"
	ui_sfx.stream = ui_click_sound

	add_child(ui_hover_sfx)
	ui_hover_sfx.bus = "SFX"
	ui_hover_sfx.stream = ui_hover_sound

	press_start_panel.visible = true
	main_panel.visible = false
	options_panel.visible = false
	credits_panel.visible = false
	help_panel.visible = false

	menu_background.texture = bg_press_start

	setup_audio_sliders()
	check_checkpoint_state()
	connect_button_sounds()

	start_any_press_pulse()
	await initial_sequence()
	set_focus(start_button)


# BLOQUEIO DE INPUT
func set_ui_blocked(blocked: bool) -> void:
	var mode := Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP

	var controls := [
		press_start_panel,
		main_panel,
		options_panel,
		credits_panel,

		start_button,
		continue_button,
		options_button,
		credits_button,
		quit_button,

		options_back_button,
		credits_back_button,

		music_slider,
		sfx_slider,
		any_press_start
	]

	for c in controls:
		if c:
			c.mouse_filter = mode

	for b in [
		start_button,
		continue_button,
		options_button,
		credits_button,
		quit_button,
		options_back_button,
		credits_back_button
	]:
		if b:
			b.disabled = blocked


# SONS DE UI
func play_ui_click() -> void:
	if ui_sfx.stream:
		ui_sfx.play()


func play_ui_hover() -> void:
	if ui_hover_sfx.stream and not any_press_active:
		ui_hover_sfx.play()


# FOCO + PULSE
func connect_button_sounds() -> void:
	var buttons = [
		start_button,
		continue_button,
		options_button,
		credits_button,
		quit_button,
		options_back_button,
		credits_back_button
	]

	for btn in buttons:
		if not btn:
			continue

		btn.focus_entered.connect(func(): on_button_focus(btn))
		btn.focus_exited.connect(func(): on_button_unfocus(btn))


func on_button_focus(btn: Control) -> void:
	play_ui_hover()
	start_focus_pulse(btn)


func on_button_unfocus(btn: Control) -> void:
	stop_focus_pulse(btn)
	btn.modulate = Color.WHITE


func start_focus_pulse(btn: Control) -> void:
	stop_focus_pulse(btn)

	var t := create_tween().set_loops()
	focus_tweens[btn] = t

	t.tween_property(btn, "modulate", Color(1.6,1.6,1.6), 0.4)
	t.tween_property(btn, "modulate", Color(1.1,1.1,1.1), 0.4)


func stop_focus_pulse(btn: Control) -> void:
	if focus_tweens.has(btn):
		focus_tweens[btn].kill()
		focus_tweens.erase(btn)


# FOCO INICIAL
func set_focus(node: Control) -> void:
	if not node:
		return

	await get_tree().process_frame

	if node.is_inside_tree() and node.visible:
		node.grab_focus()


# CHECKPOINT
func check_checkpoint_state() -> void:
	has_checkpoint = Checkpoint.has_checkpoint if "has_checkpoint" in Checkpoint else false

	if continue_button:
		continue_button.visible = has_checkpoint
		continue_button.disabled = not has_checkpoint


# AUDIO
func setup_audio_sliders() -> void:
	var buses = {
		"Music": music_slider,
		"SFX": sfx_slider
	}

	for bus_name in buses:
		var slider = buses[bus_name]

		if not slider:
			continue

		var idx = AudioServer.get_bus_index(bus_name)

		slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx))

		slider.value_changed.connect(func(v):
			AudioServer.set_bus_volume_db(idx, linear_to_db(v))
			_play_preview(sfx_preview_player, bus_name.to_lower())
		)


# PREVIEW AUDIO
func _play_preview(player: AudioStreamPlayer, type: String) -> void:
	var flags = {
		"music": "can_play_music_preview",
		"sfx": "can_play_sfx_preview"
	}

	var flag = flags[type]

	if not self.get(flag):
		return

	self.set(flag, false)

	player.play()

	await get_tree().create_timer(0.5).timeout

	self.set(flag, true)


# INPUT
func _input(event: InputEvent) -> void:
	if input_locked:
		return

	if not started and any_press_active and event.is_pressed():
		started = true
		any_press_active = false

		stop_any_press_pulse()

		play_ui_click()

		await open_main_menu()
		return

	if in_options and event.is_action_pressed("ui_cancel"):
		close_options()

	elif in_credits and event.is_action_pressed("ui_cancel"):
		close_credits()

	elif started and event.is_action_pressed("ui_cancel"):
		return_to_press_start()


# STATES
func return_to_press_start() -> void:
	input_locked = true

	await fade_in(fade_speed_menu)

	started = false
	in_options = false
	in_credits = false
	any_press_active = true

	press_start_panel.visible = true
	main_panel.visible = false
	options_panel.visible = false
	credits_panel.visible = false

	menu_background.texture = bg_press_start

	start_any_press_pulse()

	await fade_out(fade_speed_menu)

	set_focus(start_button)

	input_locked = false


func open_main_menu() -> void:
	input_locked = true

	await fade_in(fade_speed_intro)

	press_start_panel.visible = false
	main_panel.visible = true
	options_panel.visible = false
	credits_panel.visible = false

	menu_background.texture = bg_main_menu

	await get_tree().process_frame

	set_focus(start_button)

	await fade_out(fade_speed_intro)

	input_locked = false


# OPTIONS
func open_options() -> void:
	play_ui_click()

	input_locked = true
	in_options = true

	await fade_in(fade_speed_menu)

	main_panel.visible = false
	options_panel.visible = true

	menu_background.texture = bg_options_menu

	await get_tree().process_frame

	if music_slider:
		set_focus(music_slider)
	else:
		set_focus(options_back_button)

	await fade_out(fade_speed_menu)

	input_locked = false


func close_options() -> void:
	play_ui_click()

	input_locked = true
	in_options = false

	await fade_in(fade_speed_menu)

	options_panel.visible = false
	main_panel.visible = true

	menu_background.texture = bg_main_menu

	await get_tree().process_frame

	set_focus(options_button)

	await fade_out(fade_speed_menu)

	input_locked = false


# CONTROLES (HELP)
func open_options_help() -> void:
	play_ui_click()

	input_locked = true
	in_credits = true

	await fade_in(fade_speed_menu)

	options_panel.visible = false
	help_panel.visible = true

	menu_background.texture = bg_help_menu

	await get_tree().process_frame

	set_focus(help_back_button)

	await fade_out(fade_speed_menu)

	input_locked = false


func close_options_help() -> void:
	play_ui_click()

	input_locked = true
	in_credits = false

	await fade_in(fade_speed_menu)

	help_panel.visible = false
	options_panel.visible = true

	menu_background.texture = bg_options_menu

	await get_tree().process_frame

	set_focus(help_button)

	await fade_out(fade_speed_menu)

	input_locked = false


# CRÉDITOS
func open_credits() -> void:
	play_ui_click()

	input_locked = true
	in_credits = true

	await fade_in(fade_speed_menu)

	main_panel.visible = false
	credits_panel.visible = true

	menu_background.texture = bg_credits_menu

	await get_tree().process_frame

	set_focus(credits_back_button)

	await fade_out(fade_speed_menu)

	input_locked = false


func close_credits() -> void:
	play_ui_click()

	input_locked = true
	in_credits = false

	await fade_in(fade_speed_menu)

	credits_panel.visible = false
	main_panel.visible = true

	menu_background.texture = bg_main_menu

	await get_tree().process_frame

	set_focus(credits_button)

	await fade_out(fade_speed_menu)

	input_locked = false


# BOTÕES
func _on_start_button_pressed() -> void:
	play_ui_click()

	input_locked = true

	await fade_in(fade_speed_intro)

	get_tree().change_scene_to_packed(start_scene)


func _on_continue_button_pressed() -> void:
	play_ui_click()

	input_locked = true

	await fade_in(fade_speed_intro)

	Checkpoint.carregar_checkpoint()


func _on_options_button_pressed() -> void:
	open_options()


func _on_credits_button_pressed() -> void:
	open_credits()


func _on_help_button_pressed() -> void:
	open_options_help()


func _on_options_back_button_pressed() -> void:
	close_options()


func _on_help_back_button_pressed() -> void:
	close_options_help()


func _on_credits_back_button_pressed() -> void:
	close_credits()


func _on_quit_button_pressed() -> void:
	play_ui_click()
	get_tree().quit()


# ANY PRESS
func start_any_press_pulse() -> void:
	stop_any_press_pulse()

	any_press_tween = create_tween().set_loops()

	any_press_tween.tween_property(any_press_start, "modulate", Color(1.4,1.4,1.4), 0.8)
	any_press_tween.tween_property(any_press_start, "modulate", Color(0.8,0.8,0.8), 0.8)


func stop_any_press_pulse() -> void:
	if any_press_tween:
		any_press_tween.kill()

	any_press_start.modulate = Color.WHITE


# FADE
func initial_sequence() -> void:
	await get_tree().create_timer(initial_delay).timeout
	await fade_out(fade_speed_intro)


func fade_in(t: float) -> void:
	set_ui_blocked(true)
	await _fade(1.0, t)


func fade_out(t: float) -> void:
	set_ui_blocked(true)
	await _fade(0.0, t)


func _fade(target: float, time: float) -> void:
	if tween:
		tween.kill()

	tween = create_tween()

	tween.tween_property(fade_overlay, "modulate:a", target, time)

	await tween.finished

	set_ui_blocked(false)
