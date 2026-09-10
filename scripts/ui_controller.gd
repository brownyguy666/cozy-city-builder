extends Control

var builder: Node3D

# Top Bar Nodes
var cash_label: Label
var building_count_label: Label
var btn_save: Button
var btn_load: Button
var btn_sample: Button
var btn_clear: Button
var btn_help: Button
var btn_traffic: Button

var traffic_manager: Node3D
var btn_traffic_tool: Button

# Left Action Bar Nodes
var btn_build_mode: Button
var btn_demolish_mode: Button
var btn_rotate: Button
var btn_center_cam: Button

# Inspector Card Nodes
var inspector_icon: TextureRect
var inspector_name: Label
var inspector_price: Label
var inspector_category: Label
var btn_prev: Button
var btn_next: Button

# Bottom Bar Nodes
var tab_road: Button
var tab_suburban: Button
var tab_commercial: Button
var tab_industrial: Button
var tab_nature: Button
var tab_cars: Button
var items_container: HBoxContainer

# Modals & Alerts
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var help_modal: PanelContainer
var generator_modal: PanelContainer
var btn_generate: Button

# Generator State
var gen_blocks_x: int = 3
var gen_blocks_y: int = 3
var gen_block_size: int = 4
var gen_style: String = "balanced"
var gen_block_btns: Array[Button] = []
var gen_size_btns: Array[Button] = []
var gen_style_btns: Array[Button] = []

var current_category: String = "Jalan"
var item_buttons: Dictionary = {} # Map global structure index -> Button
var font: FontFile
var coin_texture: Texture2D

func play_sfx(sound_path: String, volume_db: float = -10.0):
	if not is_inside_tree():
		return
	var audio_node = get_node_or_null("/root/Audio")
	if audio_node and audio_node.has_method("play"):
		audio_node.play(sound_path, volume_db)


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load assets
	font = load("res://fonts/lilita_one_regular.ttf")
	if ResourceLoader.exists("res://sprites/coin.png"):
		coin_texture = load("res://sprites/coin.png")
		
	# Find Builder node
	if is_inside_tree() and get_tree() and get_tree().current_scene:
		builder = get_tree().current_scene.get_node_or_null("Builder")
	if not builder:
		builder = get_node_or_null("../../Builder")
	if not builder:
		builder = get_node_or_null("../Builder")
	if not builder:
		builder = get_node_or_null("/root/Main/Builder")
		
	# Find TrafficManager node
	if is_inside_tree() and get_tree() and get_tree().current_scene:
		traffic_manager = get_tree().current_scene.get_node_or_null("TrafficManager")
	if not traffic_manager:
		traffic_manager = get_node_or_null("../../TrafficManager")
	if not traffic_manager:
		traffic_manager = get_node_or_null("/root/Main/TrafficManager")
	if traffic_manager and traffic_manager.has_signal("simulation_state_changed"):
		if not traffic_manager.simulation_state_changed.is_connected(_on_traffic_state_changed):
			traffic_manager.simulation_state_changed.connect(_on_traffic_state_changed)
		
	# Build the entire UI layout
	if get_child_count() == 0:
		_build_ui_layout()
	
	# Connect to Builder signals
	if builder:
		if not builder.cash_updated.is_connected(_on_cash_updated):
			builder.cash_updated.connect(_on_cash_updated)
		if not builder.structure_changed.is_connected(_on_structure_changed):
			builder.structure_changed.connect(_on_structure_changed)
		if not builder.demolish_mode_changed.is_connected(_on_demolish_mode_changed):
			builder.demolish_mode_changed.connect(_on_demolish_mode_changed)
		if not builder.building_count_updated.is_connected(_on_building_count_updated):
			builder.building_count_updated.connect(_on_building_count_updated)
		if not builder.toast_notification.is_connected(show_toast):
			builder.toast_notification.connect(show_toast)
		
		# Initial state
		_on_cash_updated(builder.map.cash if builder.map else 10000)
		_on_demolish_mode_changed(builder.demolish_mode)
		_on_building_count_updated(builder.gridmap.get_used_cells().size() if builder.gridmap else 0)
		
		# Populate items
		populate_category_items()
		
		# Select first category and structure
		select_category("Jalan")
		if not builder.structures.is_empty():
			_on_structure_changed(builder.index, builder.structures[builder.index])

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if generator_modal and generator_modal.visible:
			toggle_generator_modal()
		elif help_modal and help_modal.visible:
			toggle_help_modal()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_H:
		toggle_help_modal()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		toggle_generator_modal()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_toggle_traffic()

func _create_panel_style(bg_col: Color, radius: int = 12, border_col: Color = Color(1, 1, 1, 0.15)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border_col
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb

func _create_btn_style(bg_col: Color, radius: int = 8, border_col: Color = Color(1, 1, 1, 0.12)) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border_col
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _build_ui_layout():
	# 1. TOP BAR
	var top_bar = PanelContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 16
	top_bar.offset_top = 16
	top_bar.offset_right = -16
	top_bar.offset_bottom = 68
	top_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.14, 0.18, 0.90), 14))
	add_child(top_bar)
	
	var tb_margin = MarginContainer.new()
	tb_margin.add_theme_constant_override("margin_left", 12)
	tb_margin.add_theme_constant_override("margin_right", 12)
	tb_margin.add_theme_constant_override("margin_top", 6)
	tb_margin.add_theme_constant_override("margin_bottom", 6)
	top_bar.add_child(tb_margin)
	
	var tb_hbox = HBoxContainer.new()
	tb_hbox.add_theme_constant_override("separation", 16)
	tb_margin.add_child(tb_hbox)
	
	# Cash Card
	var cash_card = PanelContainer.new()
	cash_card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.18, 0.20, 0.26, 0.95), 10, Color(1, 0.84, 0.25, 0.4)))
	tb_hbox.add_child(cash_card)
	
	var cash_m = MarginContainer.new()
	cash_m.add_theme_constant_override("margin_left", 10)
	cash_m.add_theme_constant_override("margin_right", 14)
	cash_m.add_theme_constant_override("margin_top", 4)
	cash_m.add_theme_constant_override("margin_bottom", 4)
	cash_card.add_child(cash_m)
	
	var cash_box = HBoxContainer.new()
	cash_box.add_theme_constant_override("separation", 8)
	cash_m.add_child(cash_box)
	
	if coin_texture:
		var coin_icon = TextureRect.new()
		coin_icon.texture = coin_texture
		coin_icon.custom_minimum_size = Vector2(26, 26)
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cash_box.add_child(coin_icon)
		
	cash_label = Label.new()
	cash_label.text = "$10,000"
	if font: cash_label.add_theme_font_override("font", font)
	cash_label.add_theme_font_size_override("font_size", 22)
	cash_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	cash_box.add_child(cash_label)
	
	# Stats Card
	var stats_card = PanelContainer.new()
	stats_card.add_theme_stylebox_override("panel", _create_panel_style(Color(0.18, 0.20, 0.26, 0.95), 10))
	tb_hbox.add_child(stats_card)
	
	var stats_m = MarginContainer.new()
	stats_m.add_theme_constant_override("margin_left", 12)
	stats_m.add_theme_constant_override("margin_right", 12)
	stats_m.add_theme_constant_override("margin_top", 4)
	stats_m.add_theme_constant_override("margin_bottom", 4)
	stats_card.add_child(stats_m)
	
	var stats_box = HBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	stats_m.add_child(stats_box)
	
	var stats_title = Label.new()
	stats_title.text = "Kota:"
	if font: stats_title.add_theme_font_override("font", font)
	stats_title.add_theme_font_size_override("font_size", 16)
	stats_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	stats_box.add_child(stats_title)
	
	building_count_label = Label.new()
	building_count_label.text = "0 Unit"
	if font: building_count_label.add_theme_font_override("font", font)
	building_count_label.add_theme_font_size_override("font_size", 18)
	building_count_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	stats_box.add_child(building_count_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_hbox.add_child(spacer)
	
	# Top Action Buttons
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	tb_hbox.add_child(actions)
	
	btn_save = _create_action_button("💾 Simpan (F1)", Color(0.2, 0.5, 0.75))
	actions.add_child(btn_save)
	btn_save.pressed.connect(func(): if builder: builder.save_city())
	
	btn_load = _create_action_button("📂 Muat (F2)", Color(0.3, 0.45, 0.65))
	actions.add_child(btn_load)
	btn_load.pressed.connect(func(): if builder: builder.load_city())
	
	btn_sample = _create_action_button("🗺️ Sampel (F3)", Color(0.4, 0.4, 0.6))
	actions.add_child(btn_sample)
	btn_sample.pressed.connect(func(): if builder: builder.load_sample_city())
	
	btn_generate = _create_action_button("🏗️ Buat Kota (G)", Color(0.45, 0.35, 0.65))
	actions.add_child(btn_generate)
	btn_generate.pressed.connect(toggle_generator_modal)
	
	btn_clear = _create_action_button("🧹 Kosongkan", Color(0.65, 0.3, 0.3))
	actions.add_child(btn_clear)
	btn_clear.pressed.connect(func(): if builder: builder.clear_city())
	
	btn_traffic = _create_action_button("🚦 Jalankan Mobil (T)", Color(0.22, 0.60, 0.42))
	actions.add_child(btn_traffic)
	btn_traffic.pressed.connect(_toggle_traffic)
	
	btn_help = _create_action_button("❓ Panduan (H)", Color(0.35, 0.55, 0.45))
	actions.add_child(btn_help)
	btn_help.pressed.connect(toggle_help_modal)
	
	# -------------------------------------------------------------
	# 2. LEFT ACTION BAR (Mode Bangun, Mode Bongkar, Putar, Center)
	# -------------------------------------------------------------
	var left_bar = PanelContainer.new()
	left_bar.name = "LeftBar"
	left_bar.offset_left = 16
	left_bar.offset_top = 80
	left_bar.offset_right = 72
	left_bar.offset_bottom = 330
	left_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.14, 0.18, 0.90), 14))
	add_child(left_bar)
	
	var lb_m = MarginContainer.new()
	lb_m.add_theme_constant_override("margin_left", 6)
	lb_m.add_theme_constant_override("margin_right", 6)
	lb_m.add_theme_constant_override("margin_top", 8)
	lb_m.add_theme_constant_override("margin_bottom", 8)
	left_bar.add_child(lb_m)
	
	var lb_vbox = VBoxContainer.new()
	lb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lb_vbox.add_theme_constant_override("separation", 10)
	lb_m.add_child(lb_vbox)
	
	btn_build_mode = _create_tool_button("🔨", "Mode Bangun (Pasang bangunan)")
	lb_vbox.add_child(btn_build_mode)
	btn_build_mode.pressed.connect(func(): if builder: builder.set_demolish_mode(false))
	
	btn_demolish_mode = _create_tool_button("🗑️", "Mode Bongkar (Hancurkan & refund 50%)")
	lb_vbox.add_child(btn_demolish_mode)
	btn_demolish_mode.pressed.connect(func(): if builder: builder.set_demolish_mode(true))
	
	btn_rotate = _create_tool_button("🔄", "Putar Bangunan 90° (Klik Kanan)")
	lb_vbox.add_child(btn_rotate)
	btn_rotate.pressed.connect(func(): if builder: builder.rotate_structure())
	
	btn_center_cam = _create_tool_button("🎯", "Reset Kamera ke Tengah (F)")
	lb_vbox.add_child(btn_center_cam)
	btn_center_cam.pressed.connect(_on_center_camera)
	
	btn_traffic_tool = _create_tool_button("🚦", "Simulasi Lalu Lintas Kendaraan (T)")
	lb_vbox.add_child(btn_traffic_tool)
	btn_traffic_tool.pressed.connect(_toggle_traffic)
	
	# -------------------------------------------------------------
	# 3. INSPECTOR CARD (Selected Item Info)
	# -------------------------------------------------------------
	var inspector = PanelContainer.new()
	inspector.name = "InspectorCard"
	inspector.anchor_left = 0.0
	inspector.anchor_top = 1.0
	inspector.anchor_right = 0.0
	inspector.anchor_bottom = 1.0
	inspector.offset_left = 16
	inspector.offset_top = -250
	inspector.offset_right = 330
	inspector.offset_bottom = -165
	inspector.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.14, 0.18, 0.92), 14, Color(0.4, 0.7, 1.0, 0.35)))
	add_child(inspector)
	
	var insp_m = MarginContainer.new()
	insp_m.add_theme_constant_override("margin_left", 8)
	insp_m.add_theme_constant_override("margin_right", 8)
	insp_m.add_theme_constant_override("margin_top", 6)
	insp_m.add_theme_constant_override("margin_bottom", 6)
	inspector.add_child(insp_m)
	
	var insp_hbox = HBoxContainer.new()
	insp_hbox.add_theme_constant_override("separation", 8)
	insp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	insp_m.add_child(insp_hbox)
	
	btn_prev = Button.new()
	btn_prev.text = "◀ Q"
	btn_prev.custom_minimum_size = Vector2(36, 52)
	btn_prev.focus_mode = Control.FOCUS_NONE
	btn_prev.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: btn_prev.add_theme_font_override("font", font)
	btn_prev.add_theme_font_size_override("font_size", 12)
	btn_prev.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.23, 0.3), 8))
	insp_hbox.add_child(btn_prev)
	btn_prev.pressed.connect(func():
		if builder and builder.structures.size() > 0:
			var prev_idx = wrap(builder.index - 1, 0, builder.structures.size())
			builder.set_structure_index(prev_idx)
	)
	
	var icon_box = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(64, 64)
	icon_box.add_theme_stylebox_override("panel", _create_panel_style(Color(0.18, 0.22, 0.28, 0.9), 10))
	insp_hbox.add_child(icon_box)
	
	inspector_icon = TextureRect.new()
	inspector_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspector_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inspector_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_box.add_child(inspector_icon)
	
	var info_box = VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_hbox.add_child(info_box)
	
	inspector_category = Label.new()
	inspector_category.text = "JALAN"
	if font: inspector_category.add_theme_font_override("font", font)
	inspector_category.add_theme_font_size_override("font_size", 11)
	inspector_category.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	info_box.add_child(inspector_category)
	
	inspector_name = Label.new()
	inspector_name.text = "Jalan Lurus"
	if font: inspector_name.add_theme_font_override("font", font)
	inspector_name.add_theme_font_size_override("font_size", 16)
	inspector_name.add_theme_color_override("font_color", Color.WHITE)
	info_box.add_child(inspector_name)
	
	inspector_price = Label.new()
	inspector_price.text = "$25"
	if font: inspector_price.add_theme_font_override("font", font)
	inspector_price.add_theme_font_size_override("font_size", 15)
	inspector_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	info_box.add_child(inspector_price)
	
	btn_next = Button.new()
	btn_next.text = "E ▶"
	btn_next.custom_minimum_size = Vector2(36, 52)
	btn_next.focus_mode = Control.FOCUS_NONE
	btn_next.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: btn_next.add_theme_font_override("font", font)
	btn_next.add_theme_font_size_override("font_size", 12)
	btn_next.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.23, 0.3), 8))
	insp_hbox.add_child(btn_next)
	btn_next.pressed.connect(func():
		if builder and builder.structures.size() > 0:
			var next_idx = wrap(builder.index + 1, 0, builder.structures.size())
			builder.set_structure_index(next_idx)
	)
	
	# -------------------------------------------------------------
	# 4. BOTTOM BAR (Category Tabs + Item Scroll Hotbar)
	# -------------------------------------------------------------
	var bottom_bar = PanelContainer.new()
	bottom_bar.name = "BottomBar"
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 16
	bottom_bar.offset_top = -155
	bottom_bar.offset_right = -16
	bottom_bar.offset_bottom = -16
	bottom_bar.add_theme_stylebox_override("panel", _create_panel_style(Color(0.12, 0.14, 0.18, 0.92), 16))
	add_child(bottom_bar)
	
	var bb_m = MarginContainer.new()
	bb_m.add_theme_constant_override("margin_left", 12)
	bb_m.add_theme_constant_override("margin_right", 12)
	bb_m.add_theme_constant_override("margin_top", 8)
	bb_m.add_theme_constant_override("margin_bottom", 8)
	bottom_bar.add_child(bb_m)
	
	var bb_vbox = VBoxContainer.new()
	bb_vbox.add_theme_constant_override("separation", 6)
	bb_m.add_child(bb_vbox)
	
	# Category Tabs
	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	bb_vbox.add_child(tabs)
	
	tab_road = _create_tab_button("🛣️ Jalan")
	tabs.add_child(tab_road)
	tab_road.pressed.connect(func(): select_category("Jalan"))
	
	tab_suburban = _create_tab_button("🏡 Perumahan")
	tabs.add_child(tab_suburban)
	tab_suburban.pressed.connect(func(): select_category("Perumahan"))
	
	tab_commercial = _create_tab_button("🏢 Komersial")
	tabs.add_child(tab_commercial)
	tab_commercial.pressed.connect(func(): select_category("Komersial"))

	tab_industrial = _create_tab_button("🏭 Industri")
	tabs.add_child(tab_industrial)
	tab_industrial.pressed.connect(func(): select_category("Industri"))
	
	tab_nature = _create_tab_button("🌳 Taman & Alam")
	tabs.add_child(tab_nature)
	tab_nature.pressed.connect(func(): select_category("Taman & Alam"))
	
	tab_cars = _create_tab_button("🚗 Kendaraan")
	tabs.add_child(tab_cars)
	tab_cars.pressed.connect(func(): select_category("Kendaraan"))
	
	# ScrollContainer for Items
	var scroll = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 96)
	bb_vbox.add_child(scroll)
	
	items_container = HBoxContainer.new()
	items_container.add_theme_constant_override("separation", 8)
	scroll.add_child(items_container)
	
	# -------------------------------------------------------------
	# 5. TOAST NOTIFICATION BANNER
	# -------------------------------------------------------------
	toast_panel = PanelContainer.new()
	toast_panel.anchor_left = 0.5
	toast_panel.anchor_top = 0.0
	toast_panel.anchor_right = 0.5
	toast_panel.anchor_bottom = 0.0
	toast_panel.offset_left = -220
	toast_panel.offset_top = 76
	toast_panel.offset_right = 220
	toast_panel.offset_bottom = 118
	toast_panel.add_theme_stylebox_override("panel", _create_panel_style(Color(0.18, 0.65, 0.35, 0.95), 10))
	add_child(toast_panel)
	
	var toast_m = MarginContainer.new()
	toast_m.add_theme_constant_override("margin_left", 16)
	toast_m.add_theme_constant_override("margin_right", 16)
	toast_m.add_theme_constant_override("margin_top", 6)
	toast_m.add_theme_constant_override("margin_bottom", 6)
	toast_panel.add_child(toast_m)
	
	toast_label = Label.new()
	toast_label.text = "Selamat Datang di Cozy City Builder!"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font: toast_label.add_theme_font_override("font", font)
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_m.add_child(toast_label)
	toast_panel.modulate.a = 0.0

	# -------------------------------------------------------------
	# 6. HELP MODAL
	# -------------------------------------------------------------
	help_modal = PanelContainer.new()
	help_modal.anchor_left = 0.5
	help_modal.anchor_top = 0.5
	help_modal.anchor_right = 0.5
	help_modal.anchor_bottom = 0.5
	help_modal.offset_left = -280
	help_modal.offset_top = -220
	help_modal.offset_right = 280
	help_modal.offset_bottom = 220
	help_modal.add_theme_stylebox_override("panel", _create_panel_style(Color(0.10, 0.12, 0.16, 0.98), 16, Color(0.4, 0.7, 1.0, 0.5)))
	add_child(help_modal)
	help_modal.visible = false
	
	var help_m = MarginContainer.new()
	help_m.add_theme_constant_override("margin_left", 20)
	help_m.add_theme_constant_override("margin_right", 20)
	help_m.add_theme_constant_override("margin_top", 16)
	help_m.add_theme_constant_override("margin_bottom", 16)
	help_modal.add_child(help_m)
	
	var help_vbox = VBoxContainer.new()
	help_vbox.add_theme_constant_override("separation", 12)
	help_m.add_child(help_vbox)
	
	var help_head = HBoxContainer.new()
	help_vbox.add_child(help_head)
	
	var help_title = Label.new()
	help_title.text = "🎮 Panduan Kontrol Kota"
	help_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font: help_title.add_theme_font_override("font", font)
	help_title.add_theme_font_size_override("font_size", 20)
	help_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	help_head.add_child(help_title)
	
	var btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(32, 32)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: btn_close.add_theme_font_override("font", font)
	btn_close.add_theme_font_size_override("font_size", 16)
	help_head.add_child(btn_close)
	btn_close.pressed.connect(toggle_help_modal)
	
	var help_text = Label.new()
	help_text.text = """• WASD: Menggerakkan kamera (Pan)
• Tahan Klik Tengah: Memutar sudut kamera 360°
• Scroll Wheel: Memperbesar / Memperkecil (Zoom)
• F: Mengembalikan kamera ke titik tengah kota
• Klik Kiri: Memasang bangunan / objek pilihan
• Klik Kanan: Memutar bangunan 90 derajat
• Q / E: Memilih bangunan sebelumnya / selanjutnya
• DEL atau Tombol 🗑️: Mode Bongkar (Refund saldo 50%)
• F1: Simpan kota (Save)  |  F2: Muat kota (Load)
• F3: Muat peta contoh (Sample Map)
• G atau Tombol 🏗️: Buka Generator Kota Otomatis
• T atau Tombol 🚦: Jalankan / Hentikan simulasi mobil
• H atau ESC: Buka / Tutup panduan ini"""
	if font: help_text.add_theme_font_override("font", font)
	help_text.add_theme_font_size_override("font_size", 14)
	help_text.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	help_vbox.add_child(help_text)

	# -------------------------------------------------------------
	# 7. GENERATOR MODAL
	# -------------------------------------------------------------
	_create_generator_modal()

func _create_action_button(text: String, col: Color) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("normal", _create_btn_style(col, 8))
	b.add_theme_stylebox_override("hover", _create_btn_style(col.lightened(0.15), 8))
	b.add_theme_stylebox_override("pressed", _create_btn_style(col.darkened(0.15), 8))
	return b

func _create_tool_button(icon_char: String, tooltip: String) -> Button:
	var b = Button.new()
	b.text = icon_char
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(44, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.23, 0.3), 8))
	b.add_theme_stylebox_override("hover", _create_btn_style(Color(0.28, 0.32, 0.42), 8))
	b.add_theme_stylebox_override("pressed", _create_btn_style(Color(0.15, 0.17, 0.22), 8))
	return b

func _create_tab_button(label: String) -> Button:
	var b = Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", _create_btn_style(Color(0.22, 0.26, 0.34), 8))
	b.add_theme_stylebox_override("hover", _create_btn_style(Color(0.30, 0.36, 0.46), 8))
	return b

func toggle_help_modal():
	help_modal.visible = !help_modal.visible
	if help_modal.visible:
		if generator_modal and generator_modal.visible:
			generator_modal.visible = false
		play_sfx("sounds/toggle.ogg", -20)

func toggle_generator_modal():
	if not generator_modal:
		return
	generator_modal.visible = !generator_modal.visible
	if generator_modal.visible:
		if help_modal and help_modal.visible:
			help_modal.visible = false
		_update_generator_buttons_visual()
		play_sfx("sounds/toggle.ogg", -20)

func _create_generator_modal():
	generator_modal = PanelContainer.new()
	generator_modal.anchor_left = 0.5
	generator_modal.anchor_top = 0.5
	generator_modal.anchor_right = 0.5
	generator_modal.anchor_bottom = 0.5
	generator_modal.offset_left = -280
	generator_modal.offset_top = -250
	generator_modal.offset_right = 280
	generator_modal.offset_bottom = 250
	generator_modal.add_theme_stylebox_override("panel", _create_panel_style(Color(0.11, 0.13, 0.18, 0.98), 16, Color(0.45, 0.75, 1.0, 0.5)))
	add_child(generator_modal)
	generator_modal.visible = false
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 22)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 18)
	generator_modal.add_child(m)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	m.add_child(vbox)
	
	# Header
	var head = HBoxContainer.new()
	vbox.add_child(head)
	
	var title = Label.new()
	title.text = "🏗️ Generator Kota Otomatis"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font: title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	head.add_child(title)
	
	var btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(32, 32)
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: btn_close.add_theme_font_override("font", font)
	btn_close.add_theme_font_size_override("font_size", 16)
	head.add_child(btn_close)
	btn_close.pressed.connect(toggle_generator_modal)
	
	# Subtitle
	var sub = Label.new()
	sub.text = "Pilih konfigurasi tata ruang blok untuk membangun kota otomatis yang rapi dan terhubung langsung ke sistem lalu lintas."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font: sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	vbox.add_child(sub)
	
	# Section 1: Jumlah Blok
	var lbl_sec1 = Label.new()
	lbl_sec1.text = "1. Jumlah Blok Kota:"
	if font: lbl_sec1.add_theme_font_override("font", font)
	lbl_sec1.add_theme_font_size_override("font_size", 14)
	lbl_sec1.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(lbl_sec1)
	
	var box_blocks = HBoxContainer.new()
	box_blocks.add_theme_constant_override("separation", 8)
	vbox.add_child(box_blocks)
	
	var block_options = [
		{"val": 2, "label": "2 x 2 Blok\n(Kompak)"},
		{"val": 3, "label": "3 x 3 Blok\n(Standar)"},
		{"val": 4, "label": "4 x 4 Blok\n(Metropolis)"}
	]
	gen_block_btns.clear()
	for opt in block_options:
		var b = _create_option_button(opt["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box_blocks.add_child(b)
		gen_block_btns.append(b)
		var val = opt["val"]
		b.pressed.connect(func():
			gen_blocks_x = val
			gen_blocks_y = val
			_update_generator_buttons_visual()
		)
		
	# Section 2: Dimensi per Blok
	var lbl_sec2 = Label.new()
	lbl_sec2.text = "2. Ukuran Tiap Blok (Panjang x Lebar):"
	if font: lbl_sec2.add_theme_font_override("font", font)
	lbl_sec2.add_theme_font_size_override("font_size", 14)
	lbl_sec2.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(lbl_sec2)
	
	var box_size = HBoxContainer.new()
	box_size.add_theme_constant_override("separation", 8)
	vbox.add_child(box_size)
	
	var size_options = [
		{"val": 3, "label": "3 x 3 Petak\n(Padat Rapat)"},
		{"val": 4, "label": "4 x 4 Petak\n(Proporsional)"},
		{"val": 5, "label": "5 x 5 Petak\n(Luas Bertaman)"}
	]
	gen_size_btns.clear()
	for opt in size_options:
		var b = _create_option_button(opt["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box_size.add_child(b)
		gen_size_btns.append(b)
		var val = opt["val"]
		b.pressed.connect(func():
			gen_block_size = val
			_update_generator_buttons_visual()
		)

	# Section 3: Gaya Zonasi
	var lbl_sec3 = Label.new()
	lbl_sec3.text = "3. Gaya Zonasi Wilayah:"
	if font: lbl_sec3.add_theme_font_override("font", font)
	lbl_sec3.add_theme_font_size_override("font_size", 14)
	lbl_sec3.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(lbl_sec3)
	
	var box_style = HBoxContainer.new()
	box_style.add_theme_constant_override("separation", 8)
	vbox.add_child(box_style)
	
	var style_options = [
		{"val": "balanced", "label": "🏙️ Seimbang\n(Campuran)"},
		{"val": "residential", "label": "🏡 Hunian\n(Perumahan)"},
		{"val": "metropolis", "label": "🏢 Metropolis\n(Gedung Tinggi)"}
	]
	gen_style_btns.clear()
	for opt in style_options:
		var b = _create_option_button(opt["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box_style.add_child(b)
		gen_style_btns.append(b)
		var val = opt["val"]
		b.pressed.connect(func():
			gen_style = val
			_update_generator_buttons_visual()
		)
		
	# Action Buttons (Batal & Bangun)
	var foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	vbox.add_child(foot)
	
	var btn_cancel = _create_action_button("Batal", Color(0.35, 0.38, 0.45))
	btn_cancel.custom_minimum_size = Vector2(90, 42)
	foot.add_child(btn_cancel)
	btn_cancel.pressed.connect(toggle_generator_modal)
	
	var btn_build_gen = _create_action_button("✨ Bangun Kota Sekarang", Color(0.20, 0.65, 0.45))
	btn_build_gen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_build_gen.custom_minimum_size = Vector2(0, 42)
	foot.add_child(btn_build_gen)
	btn_build_gen.pressed.connect(func():
		toggle_generator_modal()
		if builder and builder.has_method("generate_city"):
			builder.generate_city(gen_blocks_x, gen_blocks_y, gen_block_size, gen_style)
	)
	
	_update_generator_buttons_visual()

func _create_option_button(text: String) -> Button:
	var b = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if font: b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 12)
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_stylebox_override("normal", _create_btn_style(Color(0.2, 0.24, 0.32, 0.95), 8))
	return b

func _update_generator_buttons_visual():
	var active_col = Color(0.25, 0.60, 0.85, 1.0)
	var normal_col = Color(0.20, 0.24, 0.32, 0.95)
	
	# Block count buttons (2x2, 3x3, 4x4)
	var block_vals = [2, 3, 4]
	for i in range(gen_block_btns.size()):
		var b = gen_block_btns[i]
		if i < block_vals.size() and block_vals[i] == gen_blocks_x:
			b.add_theme_stylebox_override("normal", _create_btn_style(active_col, 8, Color(0.6, 0.9, 1.0, 0.8)))
			b.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			b.add_theme_stylebox_override("normal", _create_btn_style(normal_col, 8))
			b.modulate = Color(0.85, 0.85, 0.85, 1.0)
			
	# Block size buttons (3x3, 4x4, 5x5)
	var size_vals = [3, 4, 5]
	for i in range(gen_size_btns.size()):
		var b = gen_size_btns[i]
		if i < size_vals.size() and size_vals[i] == gen_block_size:
			b.add_theme_stylebox_override("normal", _create_btn_style(active_col, 8, Color(0.6, 0.9, 1.0, 0.8)))
			b.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			b.add_theme_stylebox_override("normal", _create_btn_style(normal_col, 8))
			b.modulate = Color(0.85, 0.85, 0.85, 1.0)

	# Zoning style buttons
	var style_vals = ["balanced", "residential", "metropolis"]
	for i in range(gen_style_btns.size()):
		var b = gen_style_btns[i]
		if i < style_vals.size() and style_vals[i] == gen_style:
			b.add_theme_stylebox_override("normal", _create_btn_style(active_col, 8, Color(0.6, 0.9, 1.0, 0.8)))
			b.modulate = Color(1.2, 1.2, 1.2, 1.0)
		else:
			b.add_theme_stylebox_override("normal", _create_btn_style(normal_col, 8))
			b.modulate = Color(0.85, 0.85, 0.85, 1.0)

func _on_center_camera():
	var view_node = null
	if is_inside_tree() and get_tree() and get_tree().current_scene:
		view_node = get_tree().current_scene.get_node_or_null("View")
	if not view_node:
		view_node = get_node_or_null("../../View")
	if not view_node:
		view_node = get_node_or_null("/root/Main/View")
	if view_node and "camera_position" in view_node:
		view_node.camera_position = Vector3.ZERO
		play_sfx("sounds/toggle.ogg", -20)

func _toggle_traffic():
	if not traffic_manager:
		if is_inside_tree() and get_tree() and get_tree().current_scene:
			traffic_manager = get_tree().current_scene.get_node_or_null("TrafficManager")
		if not traffic_manager:
			traffic_manager = get_node_or_null("../../TrafficManager")
		if not traffic_manager:
			traffic_manager = get_node_or_null("/root/Main/TrafficManager")
	if traffic_manager and traffic_manager.has_method("toggle_simulation"):
		traffic_manager.toggle_simulation()

func _on_traffic_state_changed(is_running: bool, car_count: int):
	if btn_traffic:
		if is_running:
			btn_traffic.text = "🛑 Hentikan Mobil (" + str(car_count) + ")"
			btn_traffic.modulate = Color(1.3, 1.3, 1.3, 1.0)
		else:
			btn_traffic.text = "🚦 Jalankan Mobil (T)"
			btn_traffic.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if btn_traffic_tool:
		if is_running:
			btn_traffic_tool.modulate = Color(0.4, 1.0, 0.5, 1.0)
		else:
			btn_traffic_tool.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_cash_updated(amount: int):
	if cash_label:
		cash_label.text = "$" + _format_number(amount)

func _on_building_count_updated(count: int):
	if building_count_label:
		building_count_label.text = str(count) + " Unit"

func _on_demolish_mode_changed(is_demolish: bool):
	if btn_demolish_mode and btn_build_mode:
		if is_demolish:
			btn_demolish_mode.modulate = Color(1.0, 0.3, 0.3, 1.0)
			btn_build_mode.modulate = Color(0.6, 0.6, 0.6, 1.0)
		else:
			btn_demolish_mode.modulate = Color(0.6, 0.6, 0.6, 1.0)
			btn_build_mode.modulate = Color(0.35, 1.0, 0.55, 1.0)

func _on_structure_changed(idx: int, structure: Structure):
	if not structure:
		return
		
	inspector_name.text = structure.get_title()
	inspector_price.text = "$" + str(structure.price)
	inspector_category.text = structure.category.to_upper()
	
	if structure.icon:
		inspector_icon.texture = structure.icon
	
	# If current category doesn't match, switch tab
	if structure.category != current_category:
		select_category(structure.category)
	else:
		_highlight_selected_button(idx)

func select_category(category_name: String):
	current_category = category_name
	
	# Style active tabs
	if tab_road: tab_road.modulate = Color(1.2, 1.2, 1.2, 1.0) if category_name == "Jalan" else Color(0.65, 0.65, 0.65, 1.0)
	if tab_suburban: tab_suburban.modulate = Color(1.2, 1.2, 1.2, 1.0) if category_name == "Perumahan" else Color(0.65, 0.65, 0.65, 1.0)
	if tab_commercial: tab_commercial.modulate = Color(1.2, 1.2, 1.2, 1.0) if category_name == "Komersial" else Color(0.65, 0.65, 0.65, 1.0)
	if tab_industrial: tab_industrial.modulate = Color(1.2, 1.2, 1.2, 1.0) if category_name == "Industri" else Color(0.65, 0.65, 0.65, 1.0)
	if tab_nature: tab_nature.modulate = Color(1.2, 1.2, 1.2, 1.0) if category_name == "Taman & Alam" else Color(0.65, 0.65, 0.65, 1.0)
	if tab_cars: tab_cars.modulate = Color(1.2, 1.2, 1.2, 1.0) if category_name == "Kendaraan" else Color(0.65, 0.65, 0.65, 1.0)
	
	# Show only buttons of this category
	for idx in item_buttons:
		var btn: Button = item_buttons[idx]
		if builder and idx < builder.structures.size():
			var struct = builder.structures[idx]
			btn.visible = (struct.category == category_name)
		
	if builder:
		_highlight_selected_button(builder.index)

func populate_category_items():
	if not items_container:
		return
		
	for child in items_container.get_children():
		child.queue_free()
	item_buttons.clear()
	
	if not builder:
		return
		
	for i in range(builder.structures.size()):
		var s = builder.structures[i]
		var btn = create_structure_button(i, s)
		items_container.add_child(btn)
		item_buttons[i] = btn

func create_structure_button(global_index: int, structure: Structure) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(85, 95)
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", _create_btn_style(Color(0.18, 0.22, 0.28, 0.95), 10))
	btn.add_theme_stylebox_override("hover", _create_btn_style(Color(0.24, 0.29, 0.38, 1.0), 10, Color(0.5, 0.8, 1.0, 0.5)))
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(46, 46)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if structure.icon:
		icon_rect.texture = structure.icon
	vbox.add_child(icon_rect)
	
	# Name Label
	var lbl_name = Label.new()
	lbl_name.text = structure.get_title()
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_name.clip_text = true
	if font: lbl_name.add_theme_font_override("font", font)
	lbl_name.add_theme_font_size_override("font_size", 10)
	lbl_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl_name)
	
	# Price Label
	var lbl_price = Label.new()
	lbl_price.text = "$" + str(structure.price)
	lbl_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: lbl_price.add_theme_font_override("font", font)
	lbl_price.add_theme_font_size_override("font_size", 11)
	lbl_price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl_price)
	
	btn.pressed.connect(func():
		if builder:
			builder.set_structure_index(global_index)
			play_sfx("sounds/toggle.ogg", -25)
	)
	
	return btn

func _highlight_selected_button(selected_index: int):
	for idx in item_buttons:
		var btn: Button = item_buttons[idx]
		if idx == selected_index:
			btn.modulate = Color(1.4, 1.4, 1.4, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 0.85)

func show_toast(message: String, is_warning: bool):
	if not toast_panel or not toast_label:
		return
		
	toast_label.text = message
	if is_warning:
		toast_panel.self_modulate = Color(0.95, 0.3, 0.3, 0.95)
	else:
		toast_panel.self_modulate = Color(0.2, 0.7, 0.35, 0.95)
		
	if toast_tween and toast_tween.is_running():
		toast_tween.kill()
		
	toast_tween = create_tween()
	toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.2)
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)

func _format_number(n: int) -> String:
	var s = str(n)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i > 0 and s[i - 1] != '-':
			result = "," + result
	return result
