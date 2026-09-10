class_name CityGenerator
extends RefCounted

## Procedural Cozy City Block Generator
## Generates a cohesive, fully connected road grid with zoned districts

static func generate_city(builder: Node3D, blocks_x: int = 3, blocks_y: int = 3, block_size: int = 4, zoning_style: String = "balanced") -> Dictionary:
	if not builder or not builder.gridmap:
		return {"success": false, "message": "GridMap tidak ditemukan!"}
		
	var gridmap: GridMap = builder.gridmap
	gridmap.clear()
	
	# Stop existing traffic if running
	var traffic = builder.get_node_or_null("../TrafficManager")
	if not traffic and builder.is_inside_tree() and builder.get_tree() and builder.get_tree().current_scene:
		traffic = builder.get_tree().current_scene.get_node_or_null("TrafficManager")
	if traffic and traffic.has_method("stop_simulation"):
		traffic.stop_simulation()
		
	# Build lookup map for structure filenames
	var struct_lookup: Dictionary = {}
	for i in range(builder.structures.size()):
		var s = builder.structures[i]
		if s:
			var fname = s.resource_path.get_file().get_basename()
			struct_lookup[fname] = i
			
	# Helper to safely get structure index
	var get_id = func(name: String, fallback_idx: int = 0) -> int:
		if struct_lookup.has(name):
			return struct_lookup[name]
		return fallback_idx
		
	# Grid Dimensions
	var road_step = block_size + 1
	var total_w = blocks_x * road_step + 1
	var total_h = blocks_y * road_step + 1
	
	# Offset to center city around (0, 0)
	var offset_x = -int(total_w / 2)
	var offset_z = -int(total_h / 2)
	
	var road_straight_idx = get_id.call("road-straight", 0)
	var road_lightposts_idx = get_id.call("road-straight-lightposts", road_straight_idx)
	var road_corner_idx = get_id.call("road-corner", road_straight_idx)
	var road_split_idx = get_id.call("road-split", road_straight_idx)
	var road_inter_idx = get_id.call("road-intersection", road_straight_idx)
	var road_crossing_idx = get_id.call("road-crossing", road_straight_idx)
	var road_crossroad_idx = get_id.call("road-crossroad", road_inter_idx)
	
	# Rotation indices for GridMap: 0 = 0°, 16 = 90°, 10 = 180°, 22 = 270°
	var rot_0 = 0
	var rot_90 = 16
	var rot_180 = 10
	var rot_270 = 22
	
	# Collections of structures for zoning
	var res_houses = [
		"suburban-house-a", "suburban-house-b", "suburban-house-c", 
		"suburban-house-d", "suburban-house-e", "suburban-house-f",
		"building-small-a", "building-small-b", "building-small-c", "building-small-d"
	]
	var res_greenery = ["grass", "grass-trees", "grass-trees-tall", "suburban-tree-large", "suburban-planter"]
	var comm_shops = ["commercial-shop-a", "commercial-shop-b", "commercial-shop-c"]
	var comm_towers = ["commercial-skyscraper-a", "commercial-skyscraper-b", "commercial-skyscraper-c"]
	var ind_factories = ["industrial-factory-a", "industrial-factory-b", "industrial-factory-c"]
	var ind_utilities = ["industrial-water-tower", "industrial-windmill", "industrial-solar", "industrial-containers"]
	
	var placed_count = 0
	
	# -------------------------------------------------------------
	# 1. BUILD ROAD NETWORK (Perimeter & Grid)
	# -------------------------------------------------------------
	for gz in range(total_h):
		var is_road_z = (gz % road_step == 0)
		var is_min_z = (gz == 0)
		var is_max_z = (gz == total_h - 1)
		
		for gx in range(total_w):
			var is_road_x = (gx % road_step == 0)
			var is_min_x = (gx == 0)
			var is_max_x = (gx == total_w - 1)
			
			var cell_pos = Vector3i(gx + offset_x, 0, gz + offset_z)
			
			if is_road_x and is_road_z:
				# --- INTERSECTION / CORNER / T-SPLIT ---
				if is_min_x and is_min_z:
					# Top-Left Corner
					gridmap.set_cell_item(cell_pos, road_corner_idx, rot_180)
				elif is_max_x and is_min_z:
					# Top-Right Corner
					gridmap.set_cell_item(cell_pos, road_corner_idx, rot_270)
				elif is_min_x and is_max_z:
					# Bottom-Left Corner
					gridmap.set_cell_item(cell_pos, road_corner_idx, rot_90)
				elif is_max_x and is_max_z:
					# Bottom-Right Corner
					gridmap.set_cell_item(cell_pos, road_corner_idx, rot_0)
				elif is_min_z:
					# Top edge T-split
					gridmap.set_cell_item(cell_pos, road_split_idx, rot_180)
				elif is_max_z:
					# Bottom edge T-split
					gridmap.set_cell_item(cell_pos, road_split_idx, rot_0)
				elif is_min_x:
					# Left edge T-split
					gridmap.set_cell_item(cell_pos, road_split_idx, rot_90)
				elif is_max_x:
					# Right edge T-split
					gridmap.set_cell_item(cell_pos, road_split_idx, rot_270)
				else:
					# Interior 4-way intersection (alternate intersection / crossroad)
					var inter_tile = road_crossroad_idx if (randf() < 0.35) else road_inter_idx
					gridmap.set_cell_item(cell_pos, inter_tile, rot_0)
				placed_count += 1
				
			elif is_road_x:
				# --- VERTICAL ROAD (runs along Z) ---
				# Orientation 0 is aligned with Z
				var dist_from_node = gz % road_step
				var item_to_place = road_straight_idx
				
				# Place zebra crossing near intersections
				if (dist_from_node == 1 or dist_from_node == road_step - 1) and randf() < 0.30:
					item_to_place = road_crossing_idx
				elif dist_from_node == int(road_step / 2) and randf() < 0.40:
					item_to_place = road_lightposts_idx
					
				gridmap.set_cell_item(cell_pos, item_to_place, rot_0)
				placed_count += 1
				
			elif is_road_z:
				# --- HORIZONTAL ROAD (runs along X) ---
				# Orientation 16 is aligned with X
				var dist_from_node = gx % road_step
				var item_to_place = road_straight_idx
				
				# Place zebra crossing near intersections
				if (dist_from_node == 1 or dist_from_node == road_step - 1) and randf() < 0.30:
					item_to_place = road_crossing_idx
				elif dist_from_node == int(road_step / 2) and randf() < 0.40:
					item_to_place = road_lightposts_idx
					
				gridmap.set_cell_item(cell_pos, item_to_place, rot_90)
				placed_count += 1

	# -------------------------------------------------------------
	# 2. FILL BLOCKS WITH ZONED DISTRICTS
	# -------------------------------------------------------------
	var center_bx = float(blocks_x - 1) / 2.0
	var center_by = float(blocks_y - 1) / 2.0
	
	for by in range(blocks_y):
		for bx in range(blocks_x):
			var dist_center = max(abs(bx - center_bx), abs(by - center_by))
			
			# Determine Block Zone Type
			var zone_type = "residential"
			if zoning_style == "residential":
				zone_type = "residential"
				if dist_center <= 0.6 and blocks_x >= 3:
					zone_type = "central_park"
			elif zoning_style == "metropolis":
				if dist_center <= 0.6:
					zone_type = "skyscrapers"
				elif dist_center <= 1.2:
					zone_type = "commercial"
				else:
					zone_type = "residential"
			else: # "balanced"
				if dist_center <= 0.6:
					if blocks_x >= 3 and randf() < 0.5:
						zone_type = "central_park"
					else:
						zone_type = "skyscrapers"
				elif bx == 0:
					zone_type = "industrial"
				elif dist_center <= 1.1:
					zone_type = "commercial"
				else:
					zone_type = "residential"
					
			# Fill tiles inside block [bx, by]
			var start_tile_x = bx * road_step + 1
			var start_tile_z = by * road_step + 1
			
			for lz in range(block_size):
				var world_z = start_tile_z + lz + offset_z
				var is_edge_z = (lz == 0 or lz == block_size - 1)
				
				for lx in range(block_size):
					var world_x = start_tile_x + lx + offset_x
					var is_edge_x = (lx == 0 or lx == block_size - 1)
					var cell_pos = Vector3i(world_x, 0, world_z)
					
					var chosen_name = ""
					var rot = rot_0
					
					# Determine orientation facing adjacent street:
					if lz == 0:
						rot = rot_180 # Facing North (-Z)
					elif lz == block_size - 1:
						rot = rot_0   # Facing South (+Z)
					elif lx == 0:
						rot = rot_270 # Facing West (-X)
					elif lx == block_size - 1:
						rot = rot_90  # Facing East (+X)
					else:
						rot = [rot_0, rot_90, rot_180, rot_270][randi() % 4]
					
					# Select structure based on Zone and Position inside Block
					match zone_type:
						"central_park":
							if lx == int(block_size / 2) and lz == int(block_size / 2):
								chosen_name = "pavement-fountain"
							elif is_edge_x or is_edge_z:
								if (lx + lz) % 2 == 0:
									chosen_name = "pavement"
								else:
									chosen_name = "suburban-planter" if randf() < 0.4 else "grass-trees"
							else:
								chosen_name = "suburban-tree-large" if randf() < 0.5 else "grass-trees-tall"
								
						"skyscrapers":
							if is_edge_x or is_edge_z:
								if randf() < 0.65:
									chosen_name = comm_towers[randi() % comm_towers.size()]
								else:
									chosen_name = comm_shops[randi() % comm_shops.size()]
							else:
								# Center plaza
								if randf() < 0.4:
									chosen_name = "pavement-fountain"
								elif randf() < 0.6:
									chosen_name = "commercial-parasol"
								else:
									chosen_name = "pavement"
									
						"commercial":
							if is_edge_x or is_edge_z:
								chosen_name = comm_shops[randi() % comm_shops.size()]
							else:
								chosen_name = "pavement" if randf() < 0.6 else "commercial-awning"
								
						"industrial":
							if is_edge_x or is_edge_z:
								chosen_name = ind_factories[randi() % ind_factories.size()]
							else:
								chosen_name = ind_utilities[randi() % ind_utilities.size()]
								
						"residential":
							if is_edge_x or is_edge_z:
								chosen_name = res_houses[randi() % res_houses.size()]
							else:
								# Backyard / Garden
								chosen_name = res_greenery[randi() % res_greenery.size()]
								
					var tile_id = get_id.call(chosen_name, 0)
					gridmap.set_cell_item(cell_pos, tile_id, rot)
					placed_count += 1
					
	# -------------------------------------------------------------
	# 3. POST-GENERATION UPDATES
	# -------------------------------------------------------------
	builder.update_building_count()
	
	# Recenter camera to (0, 0, 0)
	var view = null
	if builder.is_inside_tree() and builder.get_tree() and builder.get_tree().current_scene:
		view = builder.get_tree().current_scene.get_node_or_null("View")
	if not view:
		view = builder.get_node_or_null("../View")
	if not view:
		view = builder.get_node_or_null("/root/Main/View")
	if view and "camera_position" in view:
		view.camera_position = Vector3.ZERO
		
	builder.play_sfx("sounds/placement-a.ogg", -12)
	
	var preset_name = "Kompak (2x2 Blok)" if blocks_x == 2 else ("Standar (3x3 Blok)" if blocks_x == 3 else "Metropolis (" + str(blocks_x) + "x" + str(blocks_y) + " Blok)")
	builder.toast_notification.emit("Kota " + preset_name + " berhasil digenerate otomatis (" + str(placed_count) + " unit)!", false)
	
	return {
		"success": true,
		"placed_count": placed_count,
		"blocks_x": blocks_x,
		"blocks_y": blocks_y,
		"block_size": block_size,
		"zoning_style": zoning_style
	}
