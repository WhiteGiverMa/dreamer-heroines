class_name CrateSpawner
extends Node2D

# Supply crate spawner with periodic timer
# Spawns ammo/health crates at designated Marker2D positions

@export var spawn_points: Array[Marker2D] = []
@export var crate_types: Array[String] = ["ammo", "health", "ammo"]
@export var spawn_interval: float = 30.0

const CRATE_SCENES := {
	"ammo": "res://scenes/pickups/ammo_crate.tscn",
	"health": "res://scenes/pickups/health_crate.tscn"
}

const SPAWN_PROXIMITY_THRESHOLD: float = 50.0

var _spawn_timer: Timer


func _ready() -> void:
	_create_spawn_timer()
	_spawn_crates()
	_spawn_timer.start(spawn_interval)


func _create_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = spawn_interval
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func _on_spawn_timer_timeout() -> void:
	_spawn_crates()


func _spawn_crates() -> void:
	for i: int in spawn_points.size():
		var spawn_point: Marker2D = spawn_points[i]
		if spawn_point == null:
			continue

		if _is_spawn_point_occupied(spawn_point):
			continue

		var crate_type: String = _get_crate_type_for_index(i)
		_spawn_crate(crate_type, spawn_point)


func _get_crate_type_for_index(index: int) -> String:
	if crate_types.is_empty():
		return "ammo"

	var type_index: int = index % crate_types.size()
	return crate_types[type_index]


func _is_spawn_point_occupied(spawn_point: Marker2D) -> bool:
	var existing_crates: Array[Node] = get_tree().get_nodes_in_group("supply_crate")
	for crate: Node in existing_crates:
		if crate is Node2D:
			var distance: float = crate.global_position.distance_to(spawn_point.global_position)
			if distance < SPAWN_PROXIMITY_THRESHOLD:
				return true
	return false


func _spawn_crate(crate_type: String, spawn_point: Marker2D) -> void:
	var scene_path: String = CRATE_SCENES.get(crate_type, "")
	if scene_path.is_empty():
		push_warning("CrateSpawner: unknown crate type '%s'" % crate_type)
		return

	var crate_scene: PackedScene = load(scene_path) as PackedScene
	if crate_scene == null:
		push_error("CrateSpawner: failed to load crate scene: %s" % scene_path)
		return

	var crate: Node = crate_scene.instantiate()
	if crate == null:
		push_error("CrateSpawner: failed to instantiate crate")
		return

	if crate is Node2D:
		crate.global_position = spawn_point.global_position

	var spawn_parent: Node = (
		get_tree().current_scene if get_tree() and get_tree().current_scene else self
	)
	spawn_parent.add_child(crate)
