extends Node3D

const CityGenerator = preload("res://scripts/city_generator.gd")

signal cash_updated(amount: int)
signal structure_changed(new_index: int, structure: Structure)
signal demolish_mode_changed(is_demolish: bool)
signal building_count_updated(count: int)
signal toast_notification(message: String, is_warning: bool)

@export var structures: Array[Structure] = []

var map: DataMap
var index: int = 0 # Index of structure being built
var demolish_mode: bool = false # Demolish mode toggle

@export var selector: Node3D # The 'cursor'
@export var selector_container: Node3D # Node that holds a preview of the structure
@export var view_camera: Camera3D # Used for raycasting mouse
@export var gridmap: GridMap
@export var cash_display: Label

var plane: Plane # Used for raycasting mouse

func play_sfx(sound_path: String, volume_db: float = -10.0):
	if not is_inside_tree():
		return
	var audio_node = get_node_or_null("/root/Audio")
	if audio_node and audio_node.has_method("play"):
		audio_node.play(sound_path, volume_db)


func _ready():
	_ensure_all_structures_loaded()
	map = DataMap.new()
	plane = Plane(Vector3.UP, Vector3.ZERO)
	
	# Create new MeshLibrary dynamically
	var mesh_library = MeshLibrary.new()
	
	for structure in structures:
		var id = mesh_library.get_last_unused_item_id()
		mesh_library.create_item(id)
		
		var mesh = get_mesh(structure.model, structure.category)
		if mesh:
			mesh_library.set_item_mesh(id, mesh)
		mesh_library.set_item_mesh_transform(id, Transform3D())
		
	gridmap.mesh_library = mesh_library
	
	update_structure()
	update_cash()
	update_building_count()

func _ensure_all_structures_loaded():
	if structures.size() < 55:
		structures.clear()
		var ordered_files: Array[String] = [
			# 1. Jalan (7)
			"road-straight.tres",
			"road-straight-lightposts.tres",
			"road-corner.tres",
			"road-split.tres",
			"road-intersection.tres",
			"road-crossing.tres",
			"road-crossroad.tres",
			
			# 2. Perumahan (11)
			"suburban-house-a.tres",
			"suburban-house-b.tres",
			"suburban-house-c.tres",
			"suburban-house-d.tres",
			"suburban-house-e.tres",
			"suburban-house-f.tres",
			"building-small-a.tres",
			"building-small-b.tres",
			"building-small-c.tres",
			"building-small-d.tres",
			"building-garage.tres",
			
			# 3. Komersial (6)
			"commercial-shop-a.tres",
			"commercial-shop-b.tres",
			"commercial-shop-c.tres",
			"commercial-skyscraper-a.tres",
			"commercial-skyscraper-b.tres",
			"commercial-skyscraper-c.tres",
			
			# 4. Industri (7)
			"industrial-factory-a.tres",
			"industrial-factory-b.tres",
			"industrial-factory-c.tres",
			"industrial-water-tower.tres",
			"industrial-windmill.tres",
			"industrial-solar.tres",
			"industrial-containers.tres",
			
			# 5. Taman & Alam (10)
			"grass.tres",
			"grass-trees.tres",
			"grass-trees-tall.tres",
			"suburban-tree-large.tres",
			"pavement.tres",
			"pavement-fountain.tres",
			"suburban-planter.tres",
			"suburban-fence.tres",
			"commercial-parasol.tres",
			"commercial-awning.tres",
			
			# 6. Kendaraan & Fasilitas Jalan (18)
			"car-sedan.tres",
			"car-sedan-sports.tres",
			"car-suv.tres",
			"car-suv-luxury.tres",
			"car-taxi.tres",
			"car-police.tres",
			"car-ambulance.tres",
			"car-firetruck.tres",
			"car-delivery.tres",
			"car-garbage-truck.tres",
			"car-van.tres",
			"car-truck.tres",
			"road-traffic-light.tres",
			"road-barrier.tres",
			"road-dumpster.tres",
			"prop-cone.tres",
			"prop-cone-flat.tres",
			"prop-box.tres"
		]
		for fname in ordered_files:
			var path = "res://structures/" + fname
			if ResourceLoader.exists(path):
				var res = ResourceLoader.load(path)
				if res is Structure:
					structures.append(res)
		print("Loaded all ", structures.size(), " structures in Builder.")

func _process(delta):
	# Keyboard Hotkeys
	action_rotate() # Rotates selection 90 degrees
	action_structure_toggle() # Toggles between structures
	
	if Input.is_action_just_pressed("save"):
		save_city()
	if Input.is_action_just_pressed("load"):
		load_city()
	if Input.is_action_just_pressed("load_resources"):
		load_sample_city()
	
	# Map position based on mouse raycast
	if view_camera:
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = view_camera.project_ray_origin(mouse_pos)
		var ray_normal = view_camera.project_ray_normal(mouse_pos)
		var world_position = plane.intersects_ray(ray_origin, ray_normal)

		if world_position != null and selector:
			var gridmap_position = Vector3(round(world_position.x), 0, round(world_position.z))
			selector.position = lerp(selector.position, gridmap_position, min(delta * 40.0, 1.0))
			
			if not is_mouse_over_ui():
				action_build(gridmap_position)
				action_demolish(gridmap_position)

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport:
		var gui_focus = viewport.gui_get_focus_owner()
		var hovered = viewport.gui_get_hovered_control()
		if hovered != null and hovered.visible and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return true
	return false

# Retrieve the mesh from a PackedScene, supporting both single and multi-mesh models with category scaling
func get_mesh(packed_scene: PackedScene, category: String = "") -> Mesh:
	if not packed_scene:
		return null
	var instance = packed_scene.instantiate()
	var mesh_instances: Array[MeshInstance3D] = []
	_find_mesh_instances(instance, Transform3D.IDENTITY, mesh_instances)
	
	if mesh_instances.is_empty():
		instance.queue_free()
		return null
	
	# Determine proportional scale factor
	var target_scale: float = 1.0
	if category == "Kendaraan":
		var path_lower = packed_scene.resource_path.to_lower()
		if path_lower.contains("cone") or path_lower.contains("box") or path_lower.contains("barrier") or path_lower.contains("dumpster") or path_lower.contains("traffic-light"):
			target_scale = 0.25 # Proportional scale for road cones and props
		else:
			target_scale = 0.18 # Proportional scale for 2-way traffic passing (0.27m width on 1.0m road)
	
	# If single mesh at identity and no scaling needed, duplicate directly
	if target_scale == 1.0 and mesh_instances.size() == 1 and mesh_instances[0].transform == Transform3D.IDENTITY:
		var m = mesh_instances[0].mesh.duplicate()
		instance.queue_free()
		return m
	
	# Combine multi-mesh (e.g. car body + wheels) or scale mesh into single ArrayMesh
	var combined_mesh = ArrayMesh.new()
	var scale_basis = Basis.from_scale(Vector3(target_scale, target_scale, target_scale))
	var scale_xform = Transform3D(scale_basis, Vector3.ZERO)
	
	for mi in mesh_instances:
		var m = mi.mesh
		if not m:
			continue
		var xform = scale_xform * mi.transform
		for surf_idx in range(m.get_surface_count()):
			var arrays = m.surface_get_arrays(surf_idx)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for v_idx in range(verts.size()):
				verts[v_idx] = xform * verts[v_idx]
			if not normals.is_empty():
				for n_idx in range(normals.size()):
					normals[n_idx] = (xform.basis.orthonormalized() * normals[n_idx]).normalized()
			arrays[Mesh.ARRAY_VERTEX] = verts
			if not normals.is_empty():
				arrays[Mesh.ARRAY_NORMAL] = normals
			
			var mat = m.surface_get_material(surf_idx)
			combined_mesh.add_surface_from_arrays(m.surface_get_primitive_type(surf_idx), arrays)
			if mat:
				combined_mesh.surface_set_material(combined_mesh.get_surface_count() - 1, mat)
				
	instance.queue_free()
	return combined_mesh

func _find_mesh_instances(node: Node, parent_xform: Transform3D, result: Array[MeshInstance3D]):
	var current_xform = parent_xform
	if node is Node3D:
		current_xform = parent_xform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		var dummy = MeshInstance3D.new()
		dummy.name = node.name
		dummy.mesh = node.mesh
		dummy.transform = current_xform
		result.append(dummy)
	for child in node.get_children():
		_find_mesh_instances(child, current_xform, result)

# Build (place) a structure or Demolish if in demolish mode
func action_build(gridmap_position: Vector3):
	if Input.is_action_just_pressed("build"):
		if demolish_mode:
			do_demolish(gridmap_position)
			return
		
		if structures.is_empty():
			return
			
		var structure = structures[index]
		var cost = structure.price
		var previous_tile = gridmap.get_cell_item(gridmap_position)
		
		# If replacing with same tile, ignore
		if previous_tile == index:
			return
			
		# Check funds
		if map.cash < cost:
			play_sfx("sounds/removal-c.ogg", -15)
			toast_notification.emit("Saldo tidak cukup! Butuh $" + str(cost), true)
			return
			
		# Place tile
		gridmap.set_cell_item(gridmap_position, index, gridmap.get_orthogonal_index_from_basis(selector.basis))
		map.cash -= cost
		update_cash()
		update_building_count()
		
		play_sfx("sounds/placement-a.ogg, sounds/placement-b.ogg, sounds/placement-c.ogg, sounds/placement-d.ogg", -20)

# Demolish (remove) a structure via Key
func action_demolish(gridmap_position: Vector3):
	if Input.is_action_just_pressed("demolish"):
		do_demolish(gridmap_position)

func do_demolish(gridmap_position: Vector3):
	var cell_item = gridmap.get_cell_item(gridmap_position)
	if cell_item != -1:
		# Refund 50%
		var refund = 10
		if cell_item >= 0 and cell_item < structures.size():
			refund = int(structures[cell_item].price * 0.5)
		
		gridmap.set_cell_item(gridmap_position, -1)
		map.cash += refund
		update_cash()
		update_building_count()
		
		play_sfx("sounds/removal-a.ogg, sounds/removal-b.ogg, sounds/removal-c.ogg, sounds/removal-d.ogg", -20)
		toast_notification.emit("Bangunan dibongkar! Refund +$" + str(refund), false)

# Rotates the 'cursor' 90 degrees
func action_rotate():
	if Input.is_action_just_pressed("rotate"):
		rotate_structure()

func rotate_structure():
	if selector:
		selector.rotate_y(deg_to_rad(90))
		play_sfx("sounds/rotate.ogg", -30)

# Toggle between structures to build via keys Q and E
func action_structure_toggle():
	if structures.is_empty():
		return
		
	if Input.is_action_just_pressed("structure_next"):
		set_structure_index(wrap(index + 1, 0, structures.size()))
		play_sfx("sounds/toggle.ogg", -30)
	
	if Input.is_action_just_pressed("structure_previous"):
		set_structure_index(wrap(index - 1, 0, structures.size()))
		play_sfx("sounds/toggle.ogg", -30)

func set_structure_index(new_index: int):
	if structures.is_empty():
		return
	index = clamp(new_index, 0, structures.size() - 1)
	if demolish_mode:
		set_demolish_mode(false)
	update_structure()
	structure_changed.emit(index, structures[index])

func toggle_demolish_mode():
	set_demolish_mode(!demolish_mode)

func set_demolish_mode(active: bool):
	demolish_mode = active
	demolish_mode_changed.emit(demolish_mode)
	if selector_container:
		selector_container.visible = !demolish_mode
	if demolish_mode:
		play_sfx("sounds/toggle.ogg", -20)
		toast_notification.emit("Mode Bongkar Aktif: Klik bangunan untuk menghancurkan", true)
	else:
		play_sfx("sounds/toggle.ogg", -20)
		toast_notification.emit("Mode Bangun Aktif", false)

# Update the structure visual in the 'cursor'
func update_structure():
	if not selector_container or structures.is_empty():
		return
	# Clear previous structure preview in selector
	for n in selector_container.get_children():
		selector_container.remove_child(n)
		n.queue_free()
		
	# Create new structure preview in selector
	if index < structures.size() and structures[index].model:
		var model_inst = structures[index].model.instantiate()
		selector_container.add_child(model_inst)
		if structures[index].category == "Kendaraan":
			var path_lower = structures[index].model.resource_path.to_lower()
			var s: float = 0.25 if (path_lower.contains("cone") or path_lower.contains("box") or path_lower.contains("barrier") or path_lower.contains("dumpster") or path_lower.contains("traffic-light")) else 0.18
			model_inst.scale = Vector3(s, s, s)
		model_inst.position.y += 0.25
	
	structure_changed.emit(index, structures[index])

func update_cash():
	if cash_display:
		cash_display.text = "$" + str(map.cash)
	cash_updated.emit(map.cash)

func update_building_count():
	var count = gridmap.get_used_cells().size() if gridmap else 0
	building_count_updated.emit(count)

# Saving / Loading
func save_city():
	print("Saving map...")
	map.structures.clear()
	for cell in gridmap.get_used_cells():
		var data_structure: DataStructure = DataStructure.new()
		data_structure.position = Vector2i(cell.x, cell.z)
		data_structure.orientation = gridmap.get_cell_item_orientation(cell)
		data_structure.structure = gridmap.get_cell_item(cell)
		map.structures.append(data_structure)
		
	var err = ResourceSaver.save(map, "user://map.res")
	if err == OK:
		play_sfx("sounds/placement-a.ogg", -15)
		toast_notification.emit("Kota berhasil disimpan!", false)
	else:
		toast_notification.emit("Gagal menyimpan kota!", true)

func load_city():
	print("Loading map...")
	if not ResourceLoader.exists("user://map.res"):
		toast_notification.emit("Belum ada file simpanan!", true)
		return
		
	gridmap.clear()
	map = ResourceLoader.load("user://map.res")
	if not map:
		map = DataMap.new()
	for cell in map.structures:
		gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)
		
	update_cash()
	update_building_count()
	play_sfx("sounds/placement-c.ogg", -15)
	toast_notification.emit("Kota berhasil dimuat!", false)

func load_sample_city():
	print("Loading sample map...")
	gridmap.clear()
	map = ResourceLoader.load("res://sample map/map.res")
	if not map:
		map = DataMap.new()
	for cell in map.structures:
		gridmap.set_cell_item(Vector3i(cell.position.x, 0, cell.position.y), cell.structure, cell.orientation)
		
	update_cash()
	update_building_count()
	play_sfx("sounds/placement-d.ogg", -15)
	toast_notification.emit("Peta contoh berhasil dimuat!", false)

func clear_city():
	if gridmap:
		gridmap.clear()
		update_building_count()
		play_sfx("sounds/removal-a.ogg", -15)
		toast_notification.emit("Kota telah dikosongkan!", false)

func generate_city(blocks_x: int = 3, blocks_y: int = 3, block_size: int = 4, zoning_style: String = "balanced") -> Dictionary:
	return CityGenerator.generate_city(self, blocks_x, blocks_y, block_size, zoning_style)
