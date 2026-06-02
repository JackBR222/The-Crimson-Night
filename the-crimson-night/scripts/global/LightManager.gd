extends Node
class_name DialogicLight

@export var light_id := "park_lights"
@export var start_enabled := false

static var registry := {}

func _enter_tree() -> void:
	registry[light_id] = self

func _exit_tree() -> void:
	registry.erase(light_id)

func _ready() -> void:
	if not start_enabled:
		_set_group_enabled(false)

	Dialogic.signal_event.connect(_on_dialogic_signal)

func _on_dialogic_signal(argument: String) -> void:
	var parts = argument.split(":")

	if parts.size() < 2:
		return

	if not registry.has(parts[1]):
		return

	var target = registry[parts[1]]

	match parts[0]:
		"light_on":
			target._set_group_enabled(true)

		"light_off":
			target._set_group_enabled(false)

func _set_group_enabled(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group(light_id):
		if node is Light3D:
			node.visible = enabled
