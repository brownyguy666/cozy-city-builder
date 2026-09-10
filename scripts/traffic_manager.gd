extends Node3D
class_name TrafficManager

signal simulation_state_changed(is_running: bool, car_count: int)

@export var builder: Node3D
@export var gridmap: GridMap

var is_running: bool = false
var max_cars: int = 8
var car_speed: float = 2.2 # Grid units per second
var car_scale: float = 0.18 # Proportional scale for 2-way traffic passing

var car_scenes: Array[PackedScene] = []
var active_cars: Array[Dictionary] = []

var car_model_paths = [
	"res://models/cars/sedan.glb",
	"res://models/cars/sedan-sports.glb",
	"res://models/cars/taxi.glb",
	"res://models/cars/police.glb",
	"res://models/cars/suv.glb",
	"res://models/cars/van.glb",
	"res://models/cars/delivery.glb",
	"res://models/cars/ambulance.glb"
]

func _ready():
	# Preload car scenes
	for path in car_model_paths:
		if ResourceLoader.exists(path):
			var scn = ResourceLoader.load(path)
			if scn:
				car_scenes.append(scn)
				
	_ensure_references()

func _ensure_references():
	if not builder:
		if get_tree() and get_tree().current_scene:
			builder = get_tree().current_scene.get_node_or_null("Builder")
		if not builder:
			builder = get_node_or_null("../Builder")
		if not builder:
			builder = get_node_or_null("/root/Main/Builder")
	if not gridmap and builder and "gridmap" in builder:
		gridmap = builder.gridmap
	if not gridmap:
		gridmap = get_node_or_null("../GridMap")

func toggle_simulation() -> bool:
	if is_running:
		stop_simulation()
	else:
		start_simulation()
	return is_running

func start_simulation() -> bool:
	_ensure_references()
	if not gridmap or not builder:
		return false
		
	var road_cells = get_all_road_cells()
	if road_cells.is_empty():
		if builder:
			builder.toast_notification.emit("Bangun jalan terlebih dahulu untuk menjalankan kendaraan!", true)
		return false
		
	is_running = true
	clear_all_cars()
	
	# Spawn cars across road network
	var spawn_count = min(max_cars, max(1, road_cells.size() / 2))
	# Shuffle road cells for varied spawn points
	road_cells.shuffle()
	
	for i in range(spawn_count):
		if i < road_cells.size():
			spawn_car_at(road_cells[i])
			
	simulation_state_changed.emit(is_running, active_cars.size())
	if builder:
		builder.toast_notification.emit("Simulasi Lalu Lintas AKTIF (" + str(active_cars.size()) + " Mobil)!", false)
		builder.play_sfx("sounds/toggle.ogg", -15)
	return true

func stop_simulation():
	is_running = false
	clear_all_cars()
	simulation_state_changed.emit(is_running, 0)
	if builder:
		builder.toast_notification.emit("Simulasi Lalu Lintas Dihentikan.", false)
		builder.play_sfx("sounds/toggle.ogg", -15)

func clear_all_cars():
	for car_data in active_cars:
		if is_instance_valid(car_data["node"]):
			car_data["node"].queue_free()
	active_cars.clear()

func is_road_tile(cell_pos: Vector3i) -> bool:
	if not gridmap or not builder:
		return false
	var item_id = gridmap.get_cell_item(cell_pos)
	if item_id >= 0 and item_id < builder.structures.size():
		var struct = builder.structures[item_id]
		if struct.category == "Jalan":
			var path_lower = struct.resource_path.to_lower()
			if path_lower.contains("barrier") or path_lower.contains("dumpster") or path_lower.contains("traffic-light"):
				return false
			return true
	return false

func get_all_road_cells() -> Array[Vector3i]:
	var roads: Array[Vector3i] = []
	if not gridmap:
		return roads
	for cell in gridmap.get_used_cells():
		if is_road_tile(cell):
			roads.append(cell)
	return roads

func get_connected_road_neighbors(current_cell: Vector3i) -> Array[Vector3i]:
	var dirs = [
		Vector3i(1, 0, 0),
		Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(0, 0, -1)
	]
	var result: Array[Vector3i] = []
	for d in dirs:
		var n = current_cell + d
		if is_road_tile(n):
			result.append(n)
	return result

func spawn_car_at(start_cell: Vector3i):
	if car_scenes.is_empty():
		return
		
	var neighbors = get_connected_road_neighbors(start_cell)
	var next_cell = start_cell
	var move_dir = Vector3.FORWARD
	if not neighbors.is_empty():
		next_cell = neighbors[randi() % neighbors.size()]
		move_dir = Vector3(next_cell - start_cell).normalized()
	
	# Pick random car model
	var scene = car_scenes[randi() % car_scenes.size()]
	var car_node = scene.instantiate()
	car_node.scale = Vector3(car_scale, car_scale, car_scale)
	add_child(car_node)
	
	# Initial position on right lane
	var start_pos_3d = Vector3(start_cell.x, 0.02, start_cell.z)
	var lane_offset = get_lane_offset(move_dir)
	car_node.position = start_pos_3d + lane_offset
	
	if move_dir.length_squared() > 0.01:
		car_node.rotation.y = atan2(move_dir.x, move_dir.z)
		
	active_cars.append({
		"node": car_node,
		"current_cell": start_cell,
		"target_cell": next_cell,
		"dir": move_dir,
		"progress": 0.0,
		"speed": randf_range(car_speed * 0.85, car_speed * 1.15)
	})

func get_lane_offset(move_dir: Vector3) -> Vector3:
	# Right-hand traffic: offset perpendicular to direction to the right
	# Right vector is dir.cross(Vector3.UP)
	if move_dir.length_squared() < 0.01:
		return Vector3.ZERO
	var right = move_dir.cross(Vector3.UP).normalized()
	return right * 0.20

func _process(delta):
	if not is_running:
		return
		
	# Update each car movement
	for i in range(active_cars.size() - 1, -1, -1):
		var car = active_cars[i]
		var node: Node3D = car["node"]
		if not is_instance_valid(node):
			active_cars.remove_at(i)
			continue
			
		var curr_cell: Vector3i = car["current_cell"]
		var target_cell: Vector3i = car["target_cell"]
		
		# Verify road still exists (in case player demolished road)
		if not is_road_tile(target_cell):
			# Try to find new road or remove car
			var roads = get_all_road_cells()
			if roads.is_empty():
				node.queue_free()
				active_cars.remove_at(i)
				continue
			curr_cell = roads[randi() % roads.size()]
			var n = get_connected_road_neighbors(curr_cell)
			target_cell = n[0] if not n.is_empty() else curr_cell
			car["current_cell"] = curr_cell
			car["target_cell"] = target_cell
			car["progress"] = 0.0
			
		var curr_world = Vector3(curr_cell.x, 0.02, curr_cell.z)
		var target_world = Vector3(target_cell.x, 0.02, target_cell.z)
		var move_dir = Vector3(target_cell - curr_cell).normalized()
		if move_dir.length_squared() < 0.01:
			move_dir = car["dir"]
		else:
			car["dir"] = move_dir
			
		var lane_offset = get_lane_offset(move_dir)
		var start_pos = curr_world + lane_offset
		var end_pos = target_world + lane_offset
		
		# Advance progress
		car["progress"] += delta * car["speed"]
		var t = clamp(car["progress"], 0.0, 1.0)
		
		node.position = start_pos.lerp(end_pos, t)
		
		# Smoothly align rotation to movement direction (forward facing +Z)
		var target_rot_y = atan2(move_dir.x, move_dir.z)
		node.rotation.y = lerp_angle(node.rotation.y, target_rot_y, delta * 10.0)
		
		# Reached target cell
		if car["progress"] >= 1.0:
			car["current_cell"] = target_cell
			car["progress"] = 0.0
			
			# Find next road cell
			var neighbors = get_connected_road_neighbors(target_cell)
			var valid_next: Array[Vector3i] = []
			
			# Filter out the cell we just came from to keep moving forward if possible
			for neighbor in neighbors:
				if neighbor != curr_cell:
					valid_next.append(neighbor)
					
			if not valid_next.is_empty():
				# Prefer moving straight in current direction if available
				var straight_target = target_cell + Vector3i(round(move_dir.x), 0, round(move_dir.z))
				if straight_target in valid_next and randf() < 0.65:
					car["target_cell"] = straight_target
				else:
					car["target_cell"] = valid_next[randi() % valid_next.size()]
			elif not neighbors.is_empty():
				# Dead end: turn around
				car["target_cell"] = curr_cell
			else:
				# No connected roads
				car["target_cell"] = target_cell
