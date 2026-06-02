extends CharacterBody3D
class_name PlayerController

# ESTADO
var is_hidden := false
var input_enabled := true

# CONFIGURAÇÕES
@export var turn_speed := 120.0
@export var walk_speed := 3.0
@export var run_speed := 6.6
@export var stick_deadzone := 0.2
@export var stick_snap_threshold := 0.65
const GRAVITY := -9.81

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

# INTERAÇÃO
var held_item: Node = null
var current_target: Node = null

# QUICK TURN
@export var quick_turn_speed := 270.0
var is_quick_turning := false
var target_rotation_y := 0.0

var current_anim := ""

func get_current_anim() -> String:
	return current_anim

func _ready() -> void:
	_setup_animation_loops()

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

func _process(_delta: float) -> void:
	_update_target()

# TARGET SYSTEM
func _update_target() -> void:
	var new_target := _get_best_target()

	if new_target == current_target:
		return

	_clear_target()
	current_target = new_target

	if current_target and current_target.has_method("set_targeted"):
		current_target.set_targeted(true)

func _get_best_target() -> Node:
	var best: Node = null
	var best_dist := INF

	for ray in interaction_rays:
		if not ray.is_colliding():
			continue

		var c = ray.get_collider()

		if c and c.has_method("interact"):
			var d := global_position.distance_to(c.global_position)
			if d < best_dist:
				best_dist = d
				best = c

	return best

func _clear_target() -> void:
	if current_target and current_target.has_method("set_targeted"):
		current_target.set_targeted(false)
	current_target = null

# INPUT
func _read_input() -> void:
	input_turn = Input.get_axis("turn_left", "turn_right")
	input_forward = Input.get_axis("move_backward", "move_forward")
	input_running = Input.is_action_pressed("run")

	# deadzone
	if abs(input_turn) < stick_deadzone:
		input_turn = 0.0
	if abs(input_forward) < stick_deadzone:
		input_forward = 0.0

	# snap digital
	input_turn = sign(input_turn) if abs(input_turn) > stick_snap_threshold else 0.0
	input_forward = sign(input_forward) if abs(input_forward) > stick_snap_threshold else 0.0

	if Input.is_action_just_pressed("quick_turn") and not is_quick_turning:
		_start_quick_turn()

func _start_quick_turn() -> void:
	is_quick_turning = true
	target_rotation_y = fmod(rotation_degrees.y + 180.0, 360.0)
	velocity.x = 0
	velocity.z = 0

# ROTATION
func _apply_rotation(delta: float) -> void:
	if is_quick_turning:
		var diff := fmod(target_rotation_y - rotation_degrees.y + 180.0, 360.0) - 180.0
		var step := quick_turn_speed * delta

		if abs(diff) <= step:
			rotation_degrees.y = target_rotation_y
			is_quick_turning = false
		else:
			rotation_degrees.y += step * sign(diff)
		return

	rotation_degrees.y -= input_turn * turn_speed * delta

# MOVEMENT
func _apply_movement() -> void:
	if is_quick_turning:
		velocity.x = 0
		velocity.z = 0
		return

	var speed := walk_speed
	if input_running and input_forward > 0.1:
		speed = run_speed

	var dir: Vector3 = -basis.z * sign(input_forward)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

# GRAVITY
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = -2.0
	else:
		velocity.y += GRAVITY * delta

# ANIMATION
func _setup_animation_loops() -> void:
	var loop_anims = [
		"Figner|Forward Move",
		"Figner|Backward Move",
		"Figner|Idle",
		"Figner|Turn Left",
		"Figner|Turn Right",
		"Figner|Run"
	]

	for a in loop_anims:
		var anim_res = anim.get_animation(a)
		if anim_res:
			anim_res.loop_mode = Animation.LOOP_LINEAR

func _update_animation() -> void:
	if is_quick_turning:
		_play_anim("Figner|Turn 180", 2.5)
		return

	var fwd := input_forward > 0.1
	var back := input_forward < -0.1
	var turn: bool = abs(input_turn) > 0.1

	if fwd and input_running:
		_play_anim("Figner|Run")
	elif fwd:
		_play_anim("Figner|Forward Move")
	elif back:
		_play_anim("Figner|Backward Move")
	elif turn:
		_play_anim("Figner|Turn Right" if input_turn > 0 else "Figner|Turn Left")
	else:
		_play_anim("Figner|Idle")

func _play_anim(anim_name: String, speed := 1.0) -> void:
	if current_anim == anim_name and anim.speed_scale == speed:
		return

	current_anim = anim_name
	anim.speed_scale = speed
	anim.play(anim_name)

# INPUT INTERACTION
func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event.is_action_pressed("interact"):
		if current_target and current_target.has_method("interact"):
			current_target.interact(self)

# CONTROL
func freeze_input() -> void:
	input_enabled = false
	input_turn = 0
	input_forward = 0
	input_running = false
	velocity = Vector3.ZERO
	is_quick_turning = false
	_play_anim("Figner|Idle")

func unfreeze_input() -> void:
	input_enabled = true

func die() -> void:
	print("Player morreu!")
	queue_free()
