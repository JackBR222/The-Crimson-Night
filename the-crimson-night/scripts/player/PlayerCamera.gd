extends Camera3D

@export var distance: float = 3.5
@export var height: float = 7
@export var rotation_speed: float = 90.0
@export var smooth_speed: float = 5.0
@export var vertical_offset: float = 3.0

@export var auto_follow_delay: float = 1.0
@export var auto_follow_speed: float = 5.0

@export var run_speed_threshold: float = 4.5

@export var position_smoothness: float = 10.0
@export var rotation_smoothness: float = 10.0

var current_angle: float = 0.0
var last_input_time: float = 0.0

@onready var player = get_tree().current_scene.get_node("Player/Player")
@onready var spring_arm: SpringArm3D = get_parent() as SpringArm3D

func _ready():
	if not player:
		push_error("Camera precisa da referência ao player!")

	if not spring_arm:
		push_error("Camera precisa estar dentro de um SpringArm3D!")

# IMPORTANTE: usar physics para evitar jitter
func _physics_process(delta):
	handle_input(delta)
	update_camera(delta)

# INPUT DA CÂMERA
func handle_input(delta):
	var used_input := false

	if Input.is_action_pressed("cam_turn_left"):
		current_angle -= rotation_speed * delta
		used_input = true

	if Input.is_action_pressed("cam_turn_right"):
		current_angle += rotation_speed * delta
		used_input = true

	if used_input:
		last_input_time = 0.0
	else:
		last_input_time += delta

# DETECÇÃO DE CORRIDA
func is_running() -> bool:
	var input_dir = Input.get_vector("turn_left", "turn_right", "move_forward", "move_backward")

	var horizontal_velocity = player.velocity
	horizontal_velocity.y = 0

	var is_moving = input_dir.length() > 0.1
	var is_fast = horizontal_velocity.length() > run_speed_threshold

	return is_moving and is_fast

# ÂNGULO DO PLAYER
func get_player_angle() -> float:
	var forward = player.global_transform.basis.z
	var angle = atan2(forward.x, forward.z)
	return rad_to_deg(angle)

# CAMERA
func update_camera(delta):
	if not player or not spring_arm:
		return

	var player_pos = player.global_transform.origin

	var target_pos = player_pos + Vector3(0, height, 0)

	# suavização exponencial
	var t = 1.0 - exp(-position_smoothness * delta)

	spring_arm.global_position = spring_arm.global_position.lerp(
		target_pos,
		t
	)

	spring_arm.spring_length = distance

	# AUTO SEGUIR
	if is_running() and last_input_time >= auto_follow_delay:
		var target_angle = get_player_angle()

		var rot_t = 1.0 - exp(-rotation_smoothness * delta)

		current_angle = rad_to_deg(lerp_angle(
			deg_to_rad(current_angle),
			deg_to_rad(target_angle),
			rot_t
		))

	# rotação
	spring_arm.rotation.y = deg_to_rad(current_angle)

	look_at(player_pos + Vector3(0, vertical_offset, 0), Vector3.UP)
