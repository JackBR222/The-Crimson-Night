extends AudioStreamPlayer3D

@export var player: CharacterBody3D
@onready var raycast: RayCast3D = $RayCast3D

@export var walk_forward_step_interval := 0.5
@export var walk_backward_step_interval := 0.75
@export var run_step_interval := 0.35
@export var turn_left_step_interval := 0.45
@export var turn_right_step_interval := 0.45
@export var turn_180_step_interval := 0.2
@export var idle_step_interval := 999.0

var step_timer := 0.0
var last_anim := ""
var forced_stopped := false

var sounds := {
	"grass": preload("res://audio/sounds/footstep_grass.mp3"),
	"concrete": preload("res://audio/sounds/footstep_concrete.mp3")
}

func _ready() -> void:
	if raycast:
		raycast.force_raycast_update()


func _physics_process(delta: float) -> void:
	if forced_stopped or player == null:
		return

	if not player.is_on_floor():
		step_timer = 0.0
		return

	var anim := _get_player_anim()
	var speed := player.velocity.length()

	# parado total
	if speed < 0.1 and anim == "":
		_stop_steps()
		return

	# troca de animação reinicia timer
	if anim != last_anim:
		last_anim = anim
		step_timer = _get_interval(anim)

	step_timer -= delta

	if step_timer <= 0.0:
		var interval := _get_interval(anim)

		if interval < idle_step_interval:
			_play_step()

		step_timer = interval


# ANIMAÇÃO DO PLAYER
func _get_player_anim() -> String:
	return player.get_current_anim() if player and player.has_method("get_current_anim") else ""


# INTERVALOS CENTRALIZADOS
func _get_interval(anim: String) -> float:
	match anim:
		"Figner|Run": return run_step_interval
		"Figner|Forward Move": return walk_forward_step_interval
		"Figner|Backward Move": return walk_backward_step_interval
		"Figner|Turn Left": return turn_left_step_interval
		"Figner|Turn Right": return turn_right_step_interval
		"Figner|Turn 180": return turn_180_step_interval
		_: return idle_step_interval


# SOM DO PASSO
func _play_step() -> void:
	var type := _get_floor_type()

	stream = sounds.get(type, sounds["concrete"])
	pitch_scale = randf_range(0.9, 1.1)
	play()


func _get_floor_sound() -> String:
	var type := _get_floor_type()
	return "res://audio/sounds/footstep_grass.mp3" if type == "grass" \
	else "res://audio/sounds/footstep_concrete.mp3"


func _get_floor_type() -> String:
	if raycast == null:
		return "default"

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var c = raycast.get_collider()

		if c and c.has_meta("floor_type"):
			return str(c.get_meta("floor_type"))

		if c and c.is_in_group("grass"):
			return "grass"
		elif c and c.is_in_group("concrete"):
			return "concrete"

	return "default"


func _stop_steps() -> void:
	if is_playing():
		stop()
	step_timer = 0.0


func force_stop_steps() -> void:
	stop()
	forced_stopped = true
	step_timer = 0.0
	last_anim = ""


func restore_steps() -> void:
	forced_stopped = false
	step_timer = 0.0
	last_anim = ""
