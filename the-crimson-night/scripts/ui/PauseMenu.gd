extends CanvasLayer

@onready var player = get_tree().current_scene.get_node_or_null("Player/Player")

# PANELS
@export var panel: Control
@export var options_panel: Control
@export var help_panel: Control

# UI
@export var background: TextureRect

# BOTÕES
@export var resume_button: TextureButton
@export var options_button: TextureButton
@export var main_menu_button: TextureButton
@export var options_back_button: BaseButton
@export var help_button: TextureButton
@export var help_back_button: BaseButton

# CENAS
@export_file("*.tscn", "*.scn") var main_menu_scene_path: String

# BACKGROUNDS
@export var bg_pause: Texture2D
@export var bg_options: Texture2D
@export var bg_help_pc: Texture2D
@export var bg_help_controller: Texture2D

# SONS DE UI
@export var ui_click_sound: AudioStream
@export var ui_hover_sound: AudioStream

@onready var music_preview_player: AudioStreamPlayer = $MusicPreviewPlayer
@onready var sfx_preview_player: AudioStreamPlayer = $SFXPreviewPlayer

@onready var music_slider: HSlider = $OptionsPanel/Center/MusicSlider
@onready var sfx_slider: HSlider = $OptionsPanel/Center/SFXSlider

var paused := false
var in_options := false
var in_help := false
var input_locked := false

var can_play_music_preview := true
var can_play_sfx_preview := true

var showing_controller_help := false

var focus_tweens := {}

@onready var ui_sfx: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var ui_hover_sfx: AudioStreamPlayer = AudioStreamPlayer.new()

var focus_target: Control

# INIT
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_set_vis(false, false, false, false)

	add_child(ui_sfx)
	add_child(ui_hover_sfx)

	ui_sfx.bus = "SFX"
	ui_hover_sfx.bus = "SFX"
	ui_sfx.stream = ui_click_sound
	ui_hover_sfx.stream = ui_hover_sound

	setup_audio_sliders()
	connect_button_sounds()


# HELPERS DA UI
func _set_vis(p: bool, o: bool, h: bool, bg: bool) -> void:
	panel.visible = p
	options_panel.visible = o
	help_panel.visible = h
	background.visible = bg


func set_ui_blocked(blocked: bool) -> void:
	var mode := Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP

	for c in [
		panel, options_panel, help_panel, background,
		resume_button, options_button, help_button,
		main_menu_button, options_back_button, help_back_button,
		music_slider, sfx_slider
	]:
		if c:
			c.mouse_filter = mode

	for b in [
		resume_button, options_button, help_button,
		main_menu_button, options_back_button, help_back_button
	]:
		if b:
			b.disabled = blocked


# INPUT
func _input(event: InputEvent) -> void:
	if input_locked:
		return

	if event.is_action_pressed("pause_game"):
		if paused:
			if in_options:
				close_options()
			elif in_help:
				close_help()
			else:
				close_pause_menu()
		else:
			open_pause_menu()

	elif event.is_action_pressed("ui_cancel") and paused:
		if in_help:
			close_help()
		elif in_options:
			close_options()
		else:
			close_pause_menu()


# CONGELAR JOGO
func freeze_game() -> void:
	get_tree().paused = true
	get_tree().call_group("enemies", "set_process_mode", Node.PROCESS_MODE_DISABLED)
	if player:
		player.set_process_mode(Node.PROCESS_MODE_DISABLED)


func unfreeze_game() -> void:
	get_tree().paused = false
	get_tree().call_group("enemies", "set_process_mode", Node.PROCESS_MODE_INHERIT)
	if player:
		player.set_process_mode(Node.PROCESS_MODE_INHERIT)


# SONS DE UI

func play_ui_click() -> void:
	if ui_sfx.stream:
		ui_sfx.play()


func play_ui_hover() -> void:
	if ui_hover_sfx.stream:
		ui_hover_sfx.play()


# FOCO
func connect_button_sounds() -> void:
	for btn in [
		resume_button, options_button, help_button,
		main_menu_button, options_back_button, help_back_button
	]:
		if not btn:
			continue

		btn.focus_entered.connect(func(): _on_focus(btn))
		btn.focus_exited.connect(func(): _off_focus(btn))

		btn.mouse_entered.connect(func():
			if not input_locked:
				btn.grab_focus()
		)


func _on_focus(btn: Control) -> void:
	play_ui_hover()
	_start_pulse(btn)


func _off_focus(btn: Control) -> void:
	_stop_pulse(btn)
	btn.modulate = Color.WHITE


func _start_pulse(btn: Control) -> void:
	_stop_pulse(btn)
	var t := create_tween().set_loops()
	focus_tweens[btn] = t
	t.tween_property(btn, "modulate", Color(1.6,1.6,1.6), 0.4)
	t.tween_property(btn, "modulate", Color(1.1,1.1,1.1), 0.4)


func _stop_pulse(btn: Control) -> void:
	if focus_tweens.has(btn):
		focus_tweens[btn].kill()
		focus_tweens.erase(btn)


func set_focus(node: Control) -> void:
	if not node:
		return
	await get_tree().process_frame
	if node.is_inside_tree() and node.visible:
		node.grab_focus()


# PAUSA
func open_pause_menu() -> void:
	input_locked = true
	set_ui_blocked(true)

	paused = true
	in_options = false
	in_help = false

	_set_vis(true, false, false, true)
	background.texture = bg_pause

	freeze_game()

	await get_tree().process_frame
	set_focus(resume_button)

	input_locked = false
	set_ui_blocked(false)


func close_pause_menu() -> void:
	input_locked = true
	set_ui_blocked(true)

	paused = false
	in_options = false
	in_help = false

	_set_vis(false, false, false, false)

	unfreeze_game()

	await get_tree().process_frame

	input_locked = false
	set_ui_blocked(false)


# OPÇÕES
func open_options() -> void:
	input_locked = true
	in_options = true

	panel.visible = false
	options_panel.visible = true

	background.texture = bg_options

	await get_tree().process_frame
	if music_slider:
		focus_target = music_slider
	else:
		focus_target = options_back_button

	set_focus(focus_target)

	input_locked = false


func close_options() -> void:
	input_locked = true
	in_options = false

	options_panel.visible = false
	panel.visible = true

	background.texture = bg_pause

	await get_tree().process_frame
	set_focus(options_button)

	input_locked = false


# AJUDA
func open_help() -> void:
	input_locked = true
	in_help = true

	options_panel.visible = false
	help_panel.visible = true

	background.texture = bg_help_pc

	await get_tree().process_frame
	set_focus(help_back_button)

	input_locked = false

func swap_help() -> void:
	if not in_help:
		return

	showing_controller_help = !showing_controller_help

	if showing_controller_help:
		background.texture = bg_help_controller
	else:
		background.texture = bg_help_pc

func close_help() -> void:
	input_locked = true
	in_help = false

	help_panel.visible = false
	options_panel.visible = true

	background.texture = bg_options

	await get_tree().process_frame
	set_focus(help_button)

	input_locked = false


# AUDIO
func setup_audio_sliders() -> void:
	var buses = {"Music": music_slider, "SFX": sfx_slider}

	for bus in buses:
		var slider = buses[bus]
		if not slider:
			continue

		var idx = AudioServer.get_bus_index(bus)

		slider.value = db_to_linear(AudioServer.get_bus_volume_db(idx))

		slider.value_changed.connect(func(v):
			AudioServer.set_bus_volume_db(idx, linear_to_db(v))
			_play_preview(sfx_preview_player, bus.to_lower())
		)


func _play_preview(preview_player: AudioStreamPlayer, type: String) -> void:
	var flags = {
		"music": "can_play_music_preview",
		"sfx": "can_play_sfx_preview"
	}

	if not self.get(flags[type]):
		return

	self.set(flags[type], false)
	preview_player.play()
	await get_tree().create_timer(0.5).timeout
	self.set(flags[type], true)


# BOTÕES
func _on_resume_pressed() -> void:
	play_ui_click()
	close_pause_menu()


func _on_options_pressed() -> void:
	play_ui_click()
	open_options()


func _on_options_back_pressed() -> void:
	play_ui_click()
	close_options()


func _on_main_menu_pressed() -> void:
	play_ui_click()
	unfreeze_game()
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_help_pressed() -> void:
	play_ui_click()
	open_help()


func _on_help_back_pressed() -> void:
	play_ui_click()
	close_help()
	showing_controller_help = false

func _on_help_swap_pressed() -> void:
	play_ui_click()
	swap_help()
