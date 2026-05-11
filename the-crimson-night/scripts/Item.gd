extends RigidBody3D
class_name Item

@export var item_type: String = "generic"
@export var start_invisible: bool = false

@export var hold_offset: Vector3 = Vector3(0, 0, 0)
@export var hold_rotation: Vector3 = Vector3(0, 0, 0)

# VISUAL
@export var glow_speed: float = 3.0
@export var glow_strength: float = 0.25

# PULSE
@export var pulse_visible_time: float = 0.5
@export var pulse_hidden_time: float = 2.0

# SOM
@export var pickup_sound: AudioStream

# ÍCONE UI
@export var item_icon: Texture2D

# ÍCONE VAZIO
@export var empty_icon_texture: Texture2D
@export var use_empty_icon: bool = true

var is_being_held := false
var is_targeted := false
var item_visible := true

var original_position: Vector3
var original_rotation: Vector3
var glow_time: float = 0.0

var holder: PlayerController = null

@onready var icon: Sprite3D = $InteractionIcon
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var glow_sprite: GlowPulse = $GlowPulse
@onready var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()

# REGISTRO GLOBAL (pra Dialogic encontrar o item)
static var item_registry: Dictionary = {}


func _enter_tree() -> void:
	item_registry[item_type] = self


func _exit_tree() -> void:
	item_registry.erase(item_type)


func _ready() -> void:
	original_position = global_position
	original_rotation = global_rotation

	freeze = true

	icon.visible = false

	add_child(audio)

	if glow_sprite:
		glow_sprite.set_active(not start_invisible)

	if start_invisible:
		set_item_visible(false)

	Dialogic.signal_event.connect(_on_dialogic_signal)

	var player = get_tree().get_first_node_in_group("player")

	if player and player is PlayerController:
		_update_ui_icon(player)


func _process(delta: float) -> void:
	_update_glow(delta)


# FEEDBACK VISUAL
func _update_glow(delta: float) -> void:
	if is_being_held or not item_visible:
		return

	glow_time += delta * glow_speed

	if mesh and mesh.material_override:
		mesh.material_override.emission_energy = (
			0.2 +
			(sin(glow_time) + 1.0) * 0.5 * glow_strength
		)


func set_targeted(state: bool) -> void:
	is_targeted = state
	icon.visible = state and not is_being_held and item_visible


# VISIBILIDADE
func set_item_visible(value: bool) -> void:
	item_visible = value

	if mesh:
		mesh.visible = value

	if glow_sprite:
		glow_sprite.set_active(value and not is_being_held)

	icon.visible = value and is_targeted and not is_being_held


# INTERAÇÃO PRINCIPAL
func interact(player: Node) -> void:
	if not item_visible or not player is PlayerController:
		return

	set_targeted(false)

	if player.held_item == null:
		_pick_up(player)

	elif player.held_item != self:
		_swap_with_player(player)

	_update_dialogic(player)


# DIALOGIC SISTEMA DE SINAL
func _on_dialogic_signal(argument: String) -> void:
	var parts = argument.split(":")

	if parts.size() < 2 or not item_registry.has(parts[1]):
		return

	var item = item_registry[parts[1]]

	match parts[0]:
		"reveal":
			item.set_item_visible(true)

		"hide":
			item.set_item_visible(false)

		"consume":
			item.consume()


# PEGAR ITEM
func _pick_up(player: PlayerController) -> void:
	is_being_held = true

	holder = player
	player.held_item = self

	freeze = true

	# MUDA O ITEM PARA O PONTO DE SEGURAR
	reparent(player.hold_position)

	# GARANTE QUE O ITEM SEMPRE USE
	# O OFFSET LOCAL DEFINIDO NO INSPECTOR
	position = hold_offset

	rotation = Vector3(
		deg_to_rad(hold_rotation.x),
		deg_to_rad(hold_rotation.y),
		deg_to_rad(hold_rotation.z)
	)

	# EVITA HERANÇA DE ESCALA
	scale = Vector3.ONE

	icon.visible = false

	# toca som
	if pickup_sound:
		audio.stream = pickup_sound
		audio.play()

	# atualiza UI
	_update_ui_icon(player)

	# bloqueia glow
	if glow_sprite:
		glow_sprite.set_active(false)
		
	$CollisionShape3D.disabled = true


# SOLTAR ITEM
func put_down(
	target_position: Vector3,
	target_rotation: Vector3 = Vector3.ZERO
) -> void:

	is_being_held = false

	var prev_holder = holder
	holder = null

	reparent(get_tree().current_scene)

	global_position = target_position

	global_rotation = (
		original_rotation
		if target_rotation == Vector3.ZERO
		else target_rotation
	)

	freeze = true

	# limpa UI
	if prev_holder:
		_update_ui_icon(prev_holder)

	if glow_sprite and item_visible:
		glow_sprite.set_active(true)
		
	$CollisionShape3D.disabled = false



# TROCA
func _swap_with_player(player: PlayerController) -> void:
	if player.held_item == self:
		return

	var current_item = player.held_item

	current_item.put_down(global_position, global_rotation)

	player.held_item = null
	
	$CollisionShape3D.disabled = false

	_pick_up(player)


# CONSUMIR
func consume() -> void:
	if not is_being_held:
		return

	if holder:
		holder.held_item = null

		_update_ui_icon(holder)
		_update_dialogic(holder)

	queue_free()


# ATUALIZA UI
func _find_ui_icon() -> TextureRect:
	var nodes = get_tree().get_nodes_in_group("item_ui")

	for node in nodes:
		if node is TextureRect:
			return node  # pega o primeiro válido

	return null


func _update_ui_icon(player: PlayerController) -> void:
	if not player:
		return

	var ui_icon: TextureRect = _find_ui_icon()

	if ui_icon:
		if player.held_item:
			ui_icon.texture = player.held_item.item_icon
			ui_icon.visible = true

		else:
			if use_empty_icon and empty_icon_texture:
				ui_icon.texture = empty_icon_texture
				ui_icon.visible = true

			else:
				ui_icon.visible = false


# DIALOGIC VAR
func _update_dialogic(player: PlayerController) -> void:
	Dialogic.VAR.set(
		"player_item_type",
		player.held_item.item_type if player.held_item else "none"
	)
