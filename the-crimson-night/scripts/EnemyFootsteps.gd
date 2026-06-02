extends AudioStreamPlayer3D

@export var enemy: CharacterBody3D
@onready var raycast: RayCast3D = $RayCast3D

const STEP_SOUNDS := {
	"grass": preload("res://audio/sounds/footstep_grass.mp3"),
	"default": preload("res://audio/sounds/footstep_concrete.mp3")
}

var anim: AnimationPlayer
var last_anim_position := 0.0
var forced_stopped := false


func _ready() -> void:
	if raycast:
		raycast.force_raycast_update()

	if enemy:
		anim = enemy.get_node("AnimationPlayer")


func _physics_process(_delta: float) -> void:
	if forced_stopped or enemy == null or anim == null or not enemy.is_on_floor():
		return

	if enemy.velocity.length() < 0.1:
		_stop_if_needed()
		return

	var current_pos := anim.current_animation_position

	if current_pos < last_anim_position and _is_moving():
		_play_step()

	last_anim_position = current_pos


# MOVIMENTO (simplificado)
func _is_moving() -> bool:
	return enemy.velocity.length() > 0.2


# SOM DO PASSO
func _play_step() -> void:
	stream = STEP_SOUNDS[_get_floor_type()]
	pitch_scale = 0.5
	play()


func _get_floor_type() -> String:
	if raycast == null:
		return "default"

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var c = raycast.get_collider()

		if c:
			if c.has_meta("floor_type"):
				return str(c.get_meta("floor_type"))
			if c.is_in_group("grass"):
				return "grass"

	return "default"


func _stop_if_needed() -> void:
	if is_playing():
		stop()


func force_stop_steps() -> void:
	stop()
	forced_stopped = true
	last_anim_position = 0.0


func restore_steps() -> void:
	forced_stopped = false
	last_anim_position = 0.0
