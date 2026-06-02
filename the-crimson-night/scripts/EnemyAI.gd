extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var vision_ray: RayCast3D = $VisionRay
@onready var presence_area: Area3D = $PresenceArea
@onready var enemy_fade: ColorRect = $CanvasLayer/EnemyFade

@onready var bgm_player: AudioStreamPlayer = get_tree().current_scene.get_node("MusicPlayer")
@onready var chase_player: AudioStreamPlayer = get_tree().current_scene.get_node("MusicPlayerChase")

@onready var target = get_tree().current_scene.get_node("Player/Player")

# Rotas de patrulha
@export var patrol_points_1: Array[Node3D] = []
@export var patrol_points_2: Array[Node3D] = []
@export var patrol_points_3: Array[Node3D] = []
@export var patrol_points_4: Array[Node3D] = []
@export var patrol_points_5: Array[Node3D] = []
@export var patrol_points_6: Array[Node3D] = []
@export var patrol_points_7: Array[Node3D] = []
@export var patrol_points_8: Array[Node3D] = []

# Movimento
@export var speed_walk := 4.5
@export var speed_run := 7.2

# Velocidade da animação
@export var walk_anim_speed := 1.0
@export var run_anim_speed := 1.8

# Distâncias e tempos
@export var attack_range := 2.0
@export var patrol_reach_distance := 0.35
@export var investigate_reach_distance := 3.0

@export var patrol_wait_time := 3.0
@export var investigate_wait_time := 4.0
@export var max_investigate_duration := 6.0

@export var update_interval := 0.2
@export var fade_time := 1.2

# Visão
@export var base_ray_z := -24.0
@export var flashlight_multiplier := 2.0

const VIEW_ANGLE := 190.0
const SMOOTHING_FACTOR := 0.2

enum State {
	IDLE,
	PATROL,
	INVESTIGATE,
	CHASE,
	ATTACK,
	RETURN
}

var state: State = State.IDLE

var patrol_index := 0
var patrol_timer := 0.0

var investigate_timer := 0.0
var investigate_elapsed := 0.0
var investigate_position: Vector3

var update_timer := 0.0
var is_attacking := false

var current_patrol_group: Array[Node3D] = []

var player_is_hidden := false
var last_known_player_position: Vector3

var flashlight_ref: Node
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var patrol_groups := {}

func _ready() -> void:
	_find_flashlight()
	_load_patrol_routes()

	add_to_group("enemies")

	patrol_groups = {
		1: patrol_points_1,
		2: patrol_points_2,
		3: patrol_points_3,
		4: patrol_points_4,
		5: patrol_points_5,
		6: patrol_points_6,
		7: patrol_points_7,
		8: patrol_points_8
	}

	_set_patrol_group(patrol_points_1)

	_enter_state(
		State.IDLE if current_patrol_group.is_empty()
		else State.PATROL
	)

	Dialogic.signal_event.connect(_on_dialogic_signal)

func _physics_process(delta: float) -> void:
	_update_path(delta)

	# Perdeu visão do player escondido
	if state == State.CHASE and player_is_hidden:
		_start_investigation(last_known_player_position)

	# Detectou jogador
	elif _can_start_chase():
		_enter_state(State.CHASE)

	match state:
		State.PATROL:
			_state_patrol(delta)

		State.INVESTIGATE:
			_state_investigate(delta)

		State.CHASE:
			_state_chase()

		State.ATTACK:
			_state_attack()

		State.RETURN:
			_state_return()

	_looking()
	_update_vision_ray()
	_apply_gravity(delta)

	move_and_slide()

# ESTADOS
func _state_patrol(delta: float) -> void:
	if current_patrol_group.is_empty():
		return

	var point = current_patrol_group[patrol_index].global_position

	if _flat_distance(global_position, point) > patrol_reach_distance:
		_move(speed_walk)
		return

	global_position.x = point.x
	global_position.z = point.z

	_slow_stop(0.2)

	patrol_timer -= delta

	if patrol_timer <= 0:
		patrol_index = (patrol_index + 1) % current_patrol_group.size()
		patrol_timer = patrol_wait_time

		_update_agent_target()

func _state_investigate(delta: float) -> void:
	investigate_elapsed += delta

	if investigate_elapsed >= max_investigate_duration:
		_enter_state(State.RETURN)
		return

	if _flat_distance(global_position, investigate_position) > investigate_reach_distance:
		_move(speed_run)
		return

	_slow_stop(0.25)

	investigate_timer -= delta

	if investigate_timer <= 0:
		_enter_state(State.RETURN)

func _state_chase() -> void:
	if not target:
		_enter_state(State.RETURN)
		return

	if not _can_see_player():
		_start_investigation(last_known_player_position)
		return

	last_known_player_position = target.global_position

	agent.set_target_position(last_known_player_position)

	_move(speed_run)

	if _flat_distance(global_position, target.global_position) < attack_range:
		_enter_state(State.ATTACK)

func _state_attack() -> void:
	if is_attacking:
		return

	is_attacking = true

	velocity = Vector3.ZERO

	if target.has_method("freeze_input"):
		target.freeze_input()

	await get_tree().create_timer(0.2).timeout

	if enemy_fade:
		enemy_fade.fade_in(1.5)
		await enemy_fade.wait_finished()

	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _state_return() -> void:
	if current_patrol_group.is_empty():
		return

	var target_pos = current_patrol_group[patrol_index].global_position

	if _flat_distance(global_position, target_pos) > patrol_reach_distance:
		_move(speed_walk)
		return

	_slow_stop(0.25)

	if abs(velocity.x) < 0.05 and abs(velocity.z) < 0.05:
		anim.stop()
		_enter_state(State.PATROL)

# MOVIMENTO
func _move(speed: float) -> void:
	if agent.is_navigation_finished():
		return

	var next_pos = agent.get_next_path_position()

	if next_pos != Vector3.ZERO:
		_walk_to(next_pos, speed)

func _walk_to(next_pos: Vector3, speed: float) -> void:
	anim.play("Move")

	anim.speed_scale = (
		run_anim_speed if speed == speed_run
		else walk_anim_speed
	)

	var dir = next_pos - global_position

	dir.y = 0

	if dir.length() == 0:
		_slow_stop(0.2)
		return

	dir = dir.normalized()

	var smooth_dir = (
		-global_transform.basis.z
	).slerp(dir, 0.15).normalized()

	look_at(global_position + smooth_dir, Vector3.UP)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _slow_stop(weight: float) -> void:
	velocity.x = lerp(velocity.x, 0.0, weight)
	velocity.z = lerp(velocity.z, 0.0, weight)

func _apply_gravity(delta: float) -> void:
	velocity.y = (
		0.0 if is_on_floor()
		else velocity.y - gravity * delta
	)

# IA / VISÃO
func _can_start_chase() -> bool:
	return (
		target
		and not player_is_hidden
		and _can_see_player()
		and state not in [State.CHASE, State.ATTACK]
	)

func _can_see_player() -> bool:
	return (
		target
		and not player_is_hidden
		and (
			vision_ray.is_colliding()
			and vision_ray.get_collider() == target
			or presence_area.get_overlapping_bodies().has(target)
		)
	)

func _looking() -> void:
	if not target:
		return

	var to_player = (
		target.global_position - global_position
	).normalized()

	var angle = rad_to_deg(
		acos(
			clamp(
				(-global_transform.basis.z).dot(to_player),
				-1.0,
				1.0
			)
		)
	)

	if angle > VIEW_ANGLE * 0.39:
		return

	var new_dir = (
		-vision_ray.global_transform.basis.z
	).slerp(to_player, SMOOTHING_FACTOR).normalized()

	vision_ray.look_at(
		vision_ray.global_transform.origin + new_dir,
		Vector3.UP
	)

func _update_vision_ray() -> void:
	if not vision_ray:
		return

	vision_ray.target_position.z = (
		base_ray_z * flashlight_multiplier
		if flashlight_ref and flashlight_ref.is_on
		else base_ray_z
	)

# NAVEGAÇÃO
func _update_path(delta: float) -> void:
	update_timer -= delta

	if update_timer > 0:
		return

	match state:
		State.CHASE:
			if _can_see_player():
				last_known_player_position = target.global_position
				agent.set_target_position(last_known_player_position)

		State.INVESTIGATE:
			agent.set_target_position(investigate_position)

		_:
			_update_agent_target()

	update_timer = update_interval

func _update_agent_target() -> void:
	if current_patrol_group.is_empty():
		return

	match state:
		State.PATROL, State.RETURN:
			agent.set_target_position(
				current_patrol_group[patrol_index].global_position
			)

		State.CHASE:
			if not player_is_hidden:
				agent.set_target_position(last_known_player_position)

		State.INVESTIGATE:
			agent.set_target_position(investigate_position)

# CONTROLE DE ESTADO
func _enter_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state

	match state:
		State.PATROL:
			patrol_timer = patrol_wait_time
			_switch_to_normal_music()

		State.INVESTIGATE:
			investigate_timer = investigate_wait_time
			investigate_elapsed = 0.0

			agent.set_target_position(investigate_position)

			_switch_to_chase_music()

		State.CHASE:
			last_known_player_position = target.global_position

			agent.set_target_position(last_known_player_position)

			_switch_to_chase_music()

		State.ATTACK:
			is_attacking = false

		State.RETURN:
			_switch_to_normal_music()

	_update_agent_target()

func _start_investigation(pos: Vector3) -> void:
	investigate_position = pos
	_enter_state(State.INVESTIGATE)

# SOM
func _play_from_start(player: AudioStreamPlayer) -> void:
	player.stop()
	player.play(0.0)

func _switch_to_chase_music() -> void:
	if chase_player.playing:
		return

	if bgm_player.playing:
		bgm_player.stop()

	_play_from_start(chase_player)

func _switch_to_normal_music() -> void:
	if bgm_player.playing:
		return

	if chase_player.playing:
		chase_player.stop()

	_play_from_start(bgm_player)

	await get_tree().create_timer(fade_time).timeout

	chase_player.stop()

# PATRULHA
func _set_patrol_group(group: Array[Node3D]) -> void:
	current_patrol_group = group

	patrol_index = 0

	velocity = Vector3.ZERO
	update_timer = 0.0

	if state in [State.CHASE, State.INVESTIGATE, State.ATTACK]:
		return

	if not current_patrol_group.is_empty():
		agent.set_target_position(
			current_patrol_group[0].global_position
		)

func set_patrol_group(group_number: int) -> void:
	if patrol_groups.has(group_number):
		_set_patrol_group(patrol_groups[group_number])

func _load_patrol_routes() -> void:
	var routes_root = get_tree().current_scene.get_node("PatrolRoutes")

	if not routes_root:
		return

	for i in range(1, 9):
		var route = routes_root.get_node_or_null("Route" + str(i))

		if not route:
			continue

		var points: Array[Node3D] = []

		for child in route.get_children():
			if child is Node3D:
				points.append(child)

		set("patrol_points_" + str(i), points)

# UTILITÁRIOS
func _find_flashlight() -> void:
	var nodes = get_tree().get_nodes_in_group("flashlight")

	flashlight_ref = (
		null if nodes.is_empty()
		else nodes[0]
	)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	a.y = 0
	b.y = 0

	return a.distance_to(b)

func set_player_hidden(value: bool) -> void:
	player_is_hidden = value

	if value and state == State.CHASE:
		_start_investigation(last_known_player_position)

func set_last_known_position(pos: Vector3) -> void:
	last_known_player_position = pos

	if state == State.CHASE:
		_start_investigation(pos)

func hear_noise(pos: Vector3) -> void:
	if state not in [State.CHASE, State.ATTACK]:
		_start_investigation(pos)

func _on_dialogic_signal(argument: String) -> void:
	if argument == "player_noise":
		hear_noise(target.global_position)
