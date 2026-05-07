extends CharacterBody3D
class_name PlayerController

# ESTADO
var is_hidden: bool = false
var input_enabled: bool = true

# CONFIGURAÇÕES
@export var turn_speed: float = 120.0
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.6
const GRAVITY: float = -9.81

# INPUT CACHE
var input_turn := 0.0
var input_forward := 0.0
var input_running := false

# NODES
@onready var interaction_rays: Array[RayCast3D] = [
	$InteractTop,
	$InteractMid,
	$InteractBottom
]

@onready var hold_position: Node3D = $Figner/Skeleton3D/BoneAttachment3D/HoldPosition
@onready var anim: AnimationPlayer = $AnimationPlayer

# ITENS / INTERAÇÕES
var held_item: Node = null

# ALVO
var current_target: Node = null

# QUICK TURN
@export var quick_turn_speed: float = 270.0
var is_quick_turning: bool = false
var target_rotation_y: float = 0.0

# ANIMAÇÃO
var current_anim: String = ""
func get_current_anim() -> String:
	return current_anim


# READY
func _ready() -> void:
	_setup_animation_loops()

# LOOP PRINCIPAL
func _physics_process(delta: float) -> void:
	if not input_enabled:
		_apply_gravity(delta)
		move_and_slide()
		return

	_read_input()
	_apply_rotation(delta)
	_apply_movement()
	_apply_gravity(delta)
	_update_animation()

	move_and_slide()


# DETECÇÃO CONTÍNUA
func _process(_delta: float) -> void:
	_update_target()


# SISTEMA DE ALVO
func _update_target() -> void:
	var new_target := _get_best_target()

	if new_target != current_target:
		_clear_target()

		current_target = new_target

		if current_target and current_target.has_method("set_targeted"):
			current_target.set_targeted(true)


func _get_best_target() -> Node:
	var best_item: Node = null
	var best_distance := INF

	for ray in interaction_rays:
		if not ray.is_colliding():
			continue

		var collider = ray.get_collider()

		if collider and collider.has_method("interact"):
			var dist = global_position.distance_to(collider.global_position)

			if dist < best_distance:
				best_distance = dist
				best_item = collider

	return best_item


func _clear_target() -> void:
	if current_target and current_target.has_method("set_targeted"):
		current_target.set_targeted(false)

	current_target = null


# INPUT
func _read_input() -> void:
	input_turn = Input.get_axis("turn_left", "turn_right")
	input_forward = Input.get_axis("move_backward", "move_forward")
	input_running = Input.is_action_pressed("run")

	if Input.is_action_just_pressed("quick_turn") and not is_quick_turning:
		_start_quick_turn()


func _start_quick_turn() -> void:
	is_quick_turning = true
	target_rotation_y = rotation_degrees.y + 180.0
	target_rotation_y = fmod(target_rotation_y, 360.0)
	
	velocity.x = 0.0
	velocity.z = 0.0


# ROTATION
func _apply_rotation(delta: float) -> void:
	if is_quick_turning:
		var difference = (target_rotation_y - rotation_degrees.y)
		difference = fmod(difference + 180.0, 360.0) - 180.0
		var step = quick_turn_speed * delta

		if abs(difference) <= step:
			rotation_degrees.y = target_rotation_y
			is_quick_turning = false
		else:
			rotation_degrees.y += step * sign(difference)
	else:
		rotation_degrees.y -= input_turn * turn_speed * delta


# MOVIMENTO
func _apply_movement() -> void:
	if is_quick_turning:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var speed = walk_speed

	if input_running and input_forward > 0.1:
		speed = run_speed

	var direction = -basis.z * input_forward

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


# GRAVIDADE
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y += GRAVITY * delta


# ANIMAÇÃO
func _setup_animation_loops() -> void:
	var loop_anims = [
		"Figner|Forward Move",
		"Figner|Backward Move",
		"Figner|Idle",
		"Figner|Turn Left",
		"Figner|Turn Right",
		"Figner|Run"
	]

	for anim_name in loop_anims:
		var animation = anim.get_animation(anim_name)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _update_animation() -> void:
	if is_quick_turning:
		_play_anim("Figner|Turn 180", 2.5)
		return

	var moving_forward = input_forward > 0.1
	var moving_backward = input_forward < -0.1
	var turning = abs(input_turn) > 0.1

	if moving_forward and input_running:
		_play_anim("Figner|Run")
	elif moving_forward:
		_play_anim("Figner|Forward Move")
	elif moving_backward:
		_play_anim("Figner|Backward Move")
	elif turning:
		if input_turn > 0:
			_play_anim("Figner|Turn Right")
		else:
			_play_anim("Figner|Turn Left")
	else:
		_play_anim("Figner|Idle")


func _play_anim(anim_name: String, speed: float = 1.0) -> void:
	if current_anim == anim_name and anim.speed_scale == speed:
		return

	current_anim = anim_name
	anim.play(anim_name)
	anim.speed_scale = speed


# INTERAÇÃO
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event.is_action_pressed("interact"):
		_handle_interaction()


func _handle_interaction() -> void:
	if current_target and current_target.has_method("interact"):
		current_target.interact(self)


# CONTROLE DE INPUT
func freeze_input() -> void:
	input_enabled = false
	input_turn = 0.0
	input_forward = 0.0
	input_running = false
	velocity = Vector3.ZERO
	is_quick_turning = false
	_play_anim("Figner|Idle")


func unfreeze_input() -> void:
	input_enabled = true


# MORTE
func die() -> void:
	print("Player morreu!")
	queue_free()
