extends Area3D

# CONFIG

@export var spawn_enemy: bool = true
@export var change_patrol: bool = false

# SPAWN

@export var enemy_scene: PackedScene
@export var spawn_point: Node3D  # referência opcional de onde spawnar

# PATROL

@export var patrol_group_to_set: int = 1

# CONTROLE

@export var trigger_once: bool = true
var has_triggered: bool = false

@onready var player = get_tree().current_scene.get_node("Player/Player")


func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))


func _on_body_entered(body: Node) -> void:
	# executa só uma vez se ativado
	if trigger_once and has_triggered:
		return

	if not player or body != player:
		return

	# SPAWNAR INIMIGO
	if spawn_enemy and enemy_scene:
		var enemy_instance = enemy_scene.instantiate()

		# adiciona primeiro pra garantir que entra na árvore
		get_tree().current_scene.add_child(enemy_instance)

		# usa spawn deferred (evita erro de is_inside_tree)
		call_deferred("_setup_spawn", enemy_instance)

	else:
		if spawn_enemy:
			print("Erro: prefab não definido")

	# MUDAR ROTA (dinâmico)
	if change_patrol:
		var enemy = _find_enemy()

		if enemy and enemy.has_method("set_patrol_group"):
			var current_group = enemy.get("current_patrol_group_number")

			if current_group != patrol_group_to_set:
				enemy.set_patrol_group(patrol_group_to_set)
				print("Inimigo mudou para grupo:", patrol_group_to_set)
		else:
			print("Nenhum inimigo encontrado ou inválido")

	# marca como usado
	has_triggered = true

	# opcional: desativa área
	if trigger_once:
		set_deferred("monitoring", false)


# SPAWN SEGURO (executa no próximo frame)
func _setup_spawn(enemy_instance: Node3D) -> void:
	if not enemy_instance or not enemy_instance.is_inside_tree():
		return

	if spawn_point and spawn_point.is_inside_tree():
		enemy_instance.global_position = spawn_point.global_position
		enemy_instance.global_rotation = spawn_point.global_rotation
	else:
		enemy_instance.global_position = global_position
		enemy_instance.global_rotation = global_rotation


# BUSCA INIMIGO DINÂMICO
func _find_enemy() -> Node:
	return get_tree().get_root().find_child("Enemy", true, false)
