extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var vision_ray: RayCast3D = $VisionRay
@onready var presence_area: Area3D = $PresenceArea
@onready var target = null
@onready var enemy_fade: ColorRect = $CanvasLayer/EnemyFade
@onready var bgm_player: AudioStreamPlayer = get_tree().current_scene.get_node("MusicPlayer")
@onready var chase_player: AudioStreamPlayer = get_tree().current_scene.get_node("MusicPlayerChase")

@export var patrol_points_1: Array[Node3D] = []
@export var patrol_points_2: Array[Node3D] = []
@export var patrol_points_3: Array[Node3D] = []
@export var patrol_points_4: Array[Node3D] = []
@export var patrol_points_5: Array[Node3D] = []

@export var speed_walk: float = 1.7
@export var speed_run: float = 3.0

# NOVO: controle da velocidade da animação
@export var walk_anim_speed: float = 1.0
@export var run_anim_speed: float = 1.8

@export var attack_range: float = 2.0
@export var investigate_wait_time: float = 4.0
@export var patrol_wait_time: float = 3.0
@export var update_interval: float = 0.2
@export var attack_duration: float = 1.5
@export var patrol_reach_distance: float = 0.35

# TOLERÂNCIA DE DISTÂNCIA DA POSIÇÃO DE INVESTIGAÇÃO
@export var investigate_reach_distance: float = 3

@export var fade_time: float = 1.2

const VIEW_ANGLE: float = 190.0
const SMOOTHING_FACTOR = 0.2

enum State { IDLE, PATROL, INVESTIGATE, CHASE, ATTACK, RETURN }
var state: State = State.IDLE

var patrol_index := 0
var patrol_timer := 0.0
var investigate_timer := 0.0
var investigate_position: Vector3
var return_position: Vector3
var update_timer := 0.0
var is_attacking := false
var reached_point := false

var current_patrol_group: Array[Node3D] = []
var current_patrol_group_number: int = 1

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var can_trigger_chase_music := false
var music_transitioning := false
var fade_id := 0

# SISTEMA DE STEALTH DO JOGADOR
var player_is_hidden: bool = false
var last_known_player_position: Vector3


# UTILITÁRIO DE DISTÂNCIA HORIZONTAL
func _flat_distance(a: Vector3, b: Vector3) -> float:
	a.y = 0
	b.y = 0
	return a.distance_to(b)


# BUSCA AUTOMÁTICA DO PLAYER
func _find_player() -> Node3D:
	return get_tree().current_scene.get_node("Player/Player")


# CARREGA ROTAS AUTOMATICAMENTE
func _load_patrol_routes() -> void:
	var routes_root = get_tree().current_scene.get_node("PatrolRoutes")

	if not routes_root:
		print("PatrolRoutes não encontrado na cena!")
		return

	for i in range(1, 6):
		var route_node = routes_root.get_node_or_null("Route" + str(i))
		if route_node:
			var points: Array[Node3D] = []
			for child in route_node.get_children():
				if child is Node3D:
					points.append(child)

			match i:
				1: patrol_points_1 = points
				2: patrol_points_2 = points
				3: patrol_points_3 = points
				4: patrol_points_4 = points
				5: patrol_points_5 = points


# INICIALIZAÇÃO DO INIMIGO
func _ready() -> void:
	target = _find_player()
	_load_patrol_routes()

	if patrol_points_1.is_empty():
		print("Aviso: rota 1 vazia ou inexistente")

	_set_patrol_group(patrol_points_1, 1)
	_enter_state(State.IDLE if current_patrol_group.is_empty() else State.PATROL)

	_play_from_start(bgm_player)
	bgm_player.volume_db = 0
	
	await get_tree().create_timer(5.0).timeout
	can_trigger_chase_music = true


# LOOP PRINCIPAL DE FÍSICA
func _physics_process(delta: float) -> void:
	_update_path(delta)

	_check_hidden_interrupt()

	if target and not player_is_hidden and _can_see_player() and state not in [State.CHASE, State.ATTACK]:
		_enter_state(State.CHASE)

	match state:
		State.PATROL: _state_patrol(delta)
		State.INVESTIGATE: _state_investigate(delta)
		State.CHASE: _state_chase()
		State.ATTACK: _state_attack()
		State.RETURN: _state_return()

	_looking()
	_apply_gravity(delta)
	move_and_slide()


# INTERROMPER CHASE SE ESCONDIDO
func _check_hidden_interrupt() -> void:
	if state == State.CHASE and player_is_hidden:
		investigate_position = global_position
		_enter_state(State.INVESTIGATE)


# ESTADO: PATRULHA
func _state_patrol(delta: float) -> void:
	if current_patrol_group.is_empty():
		return

	var target_point = current_patrol_group[patrol_index].global_position
	var dist = _flat_distance(global_position, target_point)

	if dist <= patrol_reach_distance:
		global_position.x = target_point.x
		global_position.z = target_point.z

		patrol_timer -= delta

		velocity.x = lerp(velocity.x, 0.0, 0.2)
		velocity.z = lerp(velocity.z, 0.0, 0.2)

		if patrol_timer <= 0.0:
			_go_to_next_patrol_point()
			patrol_timer = patrol_wait_time
			_update_agent_target()
	else:
		_move(speed_walk)


# ESTADO: INVESTIGAÇÃO
func _state_investigate(delta: float) -> void:
	var dist = _flat_distance(global_position, investigate_position)

	if dist > investigate_reach_distance:
		_move(speed_walk)
		investigate_timer = investigate_wait_time
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.25)
		velocity.z = lerp(velocity.z, 0.0, 0.25)

		investigate_timer -= delta

		if investigate_timer <= 0.0:
			_enter_state(State.RETURN)


# ESTADO: PERSEGUIÇÃO
func _state_chase() -> void:
	if not target:
		_enter_state(State.RETURN)
		return

	if player_is_hidden:
		investigate_position = last_known_player_position
		_enter_state(State.INVESTIGATE)
		return

	last_known_player_position = target.global_position

	_move(speed_run)

	if _flat_distance(global_position, target.global_position) < attack_range:
		_enter_state(State.ATTACK)

	elif not _can_see_player():
		investigate_position = target.global_position
		_enter_state(State.INVESTIGATE)


# ESTADO: ATAQUE
func _state_attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	velocity = Vector3.ZERO

	if target and target.has_method("freeze_input"):
		target.freeze_input()

	await get_tree().create_timer(0.2).timeout

	if enemy_fade:
		enemy_fade.fade_in(1.5)
		await enemy_fade.wait_finished()

	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")


# ESTADO: RETORNAR
func _state_return() -> void:
	if current_patrol_group.is_empty():
		return

	var target_point = current_patrol_group[patrol_index].global_position

	if _flat_distance(global_position, target_point) > patrol_reach_distance:
		_move(speed_walk)
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.25)
		velocity.z = lerp(velocity.z, 0.0, 0.25)

		if abs(velocity.x) < 0.05 and abs(velocity.z) < 0.05:
			_enter_state(State.PATROL)


# MOVIMENTO GERAL
func _move(speed: float) -> void:
	if agent.is_navigation_finished():
		_update_agent_target()

	var next_pos = agent.get_next_path_position()
	_walk_to(next_pos, speed)


func _walk_to(next_pos: Vector3, speed: float) -> void:
	anim.play("Move")

	# NOVO: controla velocidade da animação
	if speed == speed_run:
		anim.speed_scale = run_anim_speed
	else:
		anim.speed_scale = walk_anim_speed

	var dir = next_pos - global_position
	dir.y = 0

	if dir.length() == 0:
		return

	dir = dir.normalized()

	var forward = -global_transform.basis.z
	var smooth_dir = forward.slerp(dir, 0.15).normalized()

	look_at(global_position + smooth_dir, Vector3.UP)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


# CONTROLE DE ESTADO
func _enter_state(new_state: State) -> void:
	if state == new_state:
		return

	state = new_state

	match state:
		State.PATROL:
			patrol_timer = patrol_wait_time
			_update_agent_target()

		State.INVESTIGATE:
			investigate_timer = investigate_wait_time
			agent.set_target_position(investigate_position)
			_switch_to_chase_music()

		State.CHASE:
			return_position = global_position
			_switch_to_chase_music()

		State.ATTACK:
			is_attacking = false

		State.RETURN:
			if current_patrol_group.size() > 0:
				agent.set_target_position(current_patrol_group[patrol_index].global_position)
				_switch_to_normal_music()

	_update_agent_target()


# NAVEGAÇÃO
func _update_agent_target() -> void:
	if current_patrol_group.is_empty():
		return

	match state:
		State.PATROL:
			agent.set_target_position(current_patrol_group[patrol_index].global_position)

		State.CHASE:
			if target and not player_is_hidden:
				agent.set_target_position(target.global_position)

		State.RETURN:
			agent.set_target_position(current_patrol_group[patrol_index].global_position)


# ATUALIZAÇÃO DE CAMINHO
func _update_path(delta: float) -> void:
	update_timer -= delta
	if update_timer <= 0.0:
		_update_agent_target()
		update_timer = update_interval


# DETECÇÃO DO JOGADOR
func _can_see_player() -> bool:
	if not target or player_is_hidden:
		return false

	return (
		(vision_ray.is_colliding() and vision_ray.get_collider() == target) or
		presence_area.get_overlapping_bodies().has(target)
	)


# SISTEMA DE STEALTH
func set_player_hidden(value: bool) -> void:
	player_is_hidden = value

	if value:
		last_known_player_position = target.global_position

		if state == State.CHASE:
			investigate_position = last_known_player_position
			_enter_state(State.INVESTIGATE)


# SISTEMA DE SOM
func hear_noise(pos: Vector3) -> void:
	if state not in [State.CHASE, State.ATTACK]:
		investigate_position = pos
		_enter_state(State.INVESTIGATE)


# PRÓXIMO PONTO DE PATRULHA
func _go_to_next_patrol_point() -> void:
	if current_patrol_group.is_empty():
		return

	patrol_index = (patrol_index + 1) % current_patrol_group.size()


# DEFINIÇÃO DE GRUPO DE PATRULHA
func _set_patrol_group(group: Array[Node3D], group_number: int) -> void:
	current_patrol_group = group
	current_patrol_group_number = group_number

	patrol_index = 0
	reached_point = false

	velocity = Vector3.ZERO
	update_timer = 0.0

	if current_patrol_group.size() > 0:
		agent.set_target_position(current_patrol_group[0].global_position)
		agent.velocity = Vector3.ZERO

	if state == State.PATROL:
		_enter_state(State.PATROL)


func set_patrol_group(group_number: int) -> void:
	var new_group: Array[Node3D]

	match group_number:
		1: new_group = patrol_points_1
		2: new_group = patrol_points_2
		3: new_group = patrol_points_3
		4: new_group = patrol_points_4
		5: new_group = patrol_points_5
		_: return

	_set_patrol_group(new_group, group_number)


# SISTEMA DE VISÃO
func _looking() -> void:
	if not target:
		return

	var to_player = (target.global_position - global_position).normalized()
	var forward = -global_transform.basis.z

	var angle = rad_to_deg(acos(clamp(forward.dot(to_player), -1.0, 1.0)))
	if angle > VIEW_ANGLE * 0.5:
		return

	var ray_forward = -vision_ray.global_transform.basis.z
	var new_dir = ray_forward.slerp(to_player, SMOOTHING_FACTOR).normalized()

	vision_ray.look_at(vision_ray.global_transform.origin + new_dir, Vector3.UP)


# GRAVIDADE
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0


# SISTEMA DE MÚSICA

func _play_from_start(player: AudioStreamPlayer) -> void:
	player.stop()
	player.play(0.0)


# TROCA DIRETA PARA MÚSICA DE CHASE
func _switch_to_chase_music() -> void:
	if not can_trigger_chase_music:
		return

	# Se já estiver tocando a música de chase, não reinicia
	if chase_player.playing:
		return

	# Para música normal
	if bgm_player.playing:
		bgm_player.stop()

	# Inicia música de perseguição
	_play_from_start(chase_player)


# TROCA DIRETA PARA MÚSICA NORMAL
func _switch_to_normal_music() -> void:
	if not can_trigger_chase_music:
		return

	# Se música normal já estiver tocando, não reinicia
	if bgm_player.playing:
		return

	# Para música de chase
	if chase_player.playing:
		chase_player.stop()

	# Volta música normal
	_play_from_start(bgm_player)
	await get_tree().create_timer(fade_time).timeout

	chase_player.stop()

	music_transitioning = false
