extends Control

# ============ 常量 ============
const SAVE_PATH := "user://games.json"
const MUSIC_SAVE_PATH := "user://music.json"
const SETTINGS_PATH := "user://settings.json"
const ICON_DIR := "user://icons"
const COVER_DIR := "user://covers"
const LOG_DIR := "user://logs"
const LOG_FILE := "user://logs/launcher.log"
const LOG_MAX_BYTES := 1024 * 1024

const LEFT_MIN_W := 160.0
const LEFT_MAX_RATIO := 0.5
const SPEED_STEPS: Array = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

# ============ 主题色（可运行时修改）============
var C_BG := Color("#1b2838")
var C_TOP_BAR := Color("#16202d")
var C_PANEL := Color("#16202d")
var C_ACCENT := Color("#66c0f4")
var C_TEXT := Color("#c7d5e0")
var C_TEXT_DIM := Color("#8f98a0")
const C_SELECT := Color("#2ecc71")

# 色板定义
const PRESET_DEFAULT := Color("#1b2838")
const PRESET_LIGHT := Color("#e8eaed")
const PRESET_RED := Color("#d9534f")
const PRESET_ORANGE := Color("#e08a3c")
const PRESET_YELLOW := Color("#d4b840")
const PRESET_GREEN := Color("#5cb85c")
const PRESET_CYAN := Color("#4bbfa8")
const PRESET_BLUE := Color("#4a90c2")
const PRESET_PURPLE := Color("#8e6fb5")

# 一键主题色
const UNIFIED_TOP := Color("#16202d")
const UNIFIED_SIDEBAR := Color("#16202d")
const UNIFIED_MAIN := Color("#1b2838")

# ============ 状态 ============
var games: Array = []
var filtered_indices: Array = []
var current_index: int = -1

var musics: Array = []
var music_filtered: Array = []
var music_current: int = -1

var running_pid: int = -1
var running_index: int = -1
var _last_check_time: float = 0.0

var _splitter_dragging: bool = false
var user_resized: bool = false

# 音乐播放器状态
var music_player: AudioStreamPlayer
var music_playing: bool = false
var music_speed: float = 1.0
var music_pending_seek: float = -1.0
var music_dragging: bool = false
var music_volume: float = 80.0

# 设置状态
var setting_top_color: Color = PRESET_DEFAULT
var setting_sidebar_color: Color = PRESET_DEFAULT
var setting_main_color: Color = PRESET_DEFAULT

# ============ UI 引用 ============
var page_tab_game: Button
var page_tab_music: Button
var page_tab_settings: Button
var game_page: Control
var music_page: Control
var settings_page: Control

var top_bar_bg: ColorRect
var bg_rect: ColorRect

# 游戏页
var search_box: LineEdit
var item_list: ItemList
var cover_rect: TextureRect
var cover_hint: Label
var launch_btn: Button
var title_label: Label
var desc_label: Label
var status_bar: Label
var game_left_panel: PanelContainer
var game_cover_panel: PanelContainer

# 音乐页
var music_search: LineEdit
var music_list: ItemList
var music_cover_rect: TextureRect
var music_cover_hint: Label
var music_title: Label
var music_meta: Label
var music_progress: HSlider
var music_time_label: Label
var music_play_btn: Button
var music_prev_btn: Button
var music_next_btn: Button
var music_back_btn: Button
var music_fwd_btn: Button
var music_speed_buttons: Array = []
var music_status: Label
var music_left_panel: PanelContainer
var music_cover_panel: PanelContainer

# 设置页
var settings_sidebar: PanelContainer
var settings_content: Control
var settings_module_list: ItemList
var settings_detail_box: VBoxContainer

# 弹窗和菜单
var file_dialog: FileDialog
var music_file_dialog: FileDialog
var manage_menu: PopupMenu
var blank_menu: PopupMenu
var music_manage_menu: PopupMenu
var music_blank_menu: PopupMenu

# 属性窗口
var prop_window: Window
var prop_name_edit: LineEdit
var prop_desc_edit: TextEdit
var prop_path_label: Label
var prop_size_label: Label
var prop_logo_rect: TextureRect
var prop_cover_rect: TextureRect

# 音乐属性窗口
var music_prop_window: Window
var mprop_name_edit: LineEdit
var mprop_desc_edit: TextEdit
var mprop_path_label: Label
var mprop_size_label: Label
var mprop_dur_label: Label
var mprop_fmt_label: Label
var mprop_full_name: Label

# 颜色选择器窗口
var color_picker_window: Window
var color_picker_target: String = ""
var color_picker_target_multi: bool = false
var color_picker_obj: ColorPicker
var color_swatch_buttons: Array = []

# ============================================================
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(ICON_DIR)
	DirAccess.make_dir_recursive_absolute(COVER_DIR)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)

	_load_settings()
	_build_ui()
	_load_games()
	_load_musics()
	_refresh_list()
	_refresh_music_list()
	_apply_theme_colors()
	_apply_music_volume()

	get_viewport().size_changed.connect(_auto_fit_left_width)
	_log("=== launcher started ===")

# ============================================================
func _build_ui() -> void:
	var th := Theme.new()
	var empty_panel := StyleBoxEmpty.new()
	th.set_stylebox("panel", "PanelContainer", empty_panel)
	th.set_stylebox("panel", "Panel", empty_panel)
	th.set_stylebox("panel", "ScrollContainer", empty_panel)
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_color", "LineEdit", C_TEXT)
	th.set_color("font_color", "TextEdit", C_TEXT)
	th.set_color("font_color", "ItemList", C_TEXT)
	th.set_color("font_color", "PopupMenu", C_TEXT)
	self.theme = th

	bg_rect = ColorRect.new()
	bg_rect.color = C_BG
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	var main_v := VBoxContainer.new()
	main_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_v.add_theme_constant_override("separation", 0)
	add_child(main_v)

	var top_stack := Control.new()
	top_stack.custom_minimum_size = Vector2(0, 44)
	main_v.add_child(top_stack)

	top_bar_bg = ColorRect.new()
	top_bar_bg.color = C_TOP_BAR
	top_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_stack.add_child(top_bar_bg)

	var tabs := HBoxContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.add_theme_constant_override("separation", 0)
	top_stack.add_child(tabs)

	page_tab_game = Button.new()
	page_tab_game.text = "游戏功能"
	page_tab_game.toggle_mode = true
	page_tab_game.button_pressed = true
	page_tab_game.custom_minimum_size = Vector2(140, 44)
	page_tab_game.pressed.connect(func() -> void: _switch_page(0))
	tabs.add_child(page_tab_game)

	page_tab_music = Button.new()
	page_tab_music.text = "音乐播放器功能"
	page_tab_music.toggle_mode = true
	page_tab_music.custom_minimum_size = Vector2(180, 44)
	page_tab_music.pressed.connect(func() -> void: _switch_page(1))
	tabs.add_child(page_tab_music)

	page_tab_settings = Button.new()
	page_tab_settings.text = "设置"
	page_tab_settings.toggle_mode = true
	page_tab_settings.custom_minimum_size = Vector2(120, 44)
	page_tab_settings.pressed.connect(func() -> void: _switch_page(2))
	tabs.add_child(page_tab_settings)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_v.add_child(content)

	_build_game_page(content)
	_build_music_page(content)
	_build_settings_page(content)
	_build_prop_window()
	_build_music_prop_window()
	_build_color_picker_window()

# ============================================================
func _switch_page(idx: int) -> void:
	game_page.visible = (idx == 0)
	music_page.visible = (idx == 1)
	settings_page.visible = (idx == 2)
	page_tab_game.button_pressed = (idx == 0)
	page_tab_music.button_pressed = (idx == 1)
	page_tab_settings.button_pressed = (idx == 2)
	if idx == 0:
		_refresh_list()
	elif idx == 1:
		_refresh_music_list()
	elif idx == 2:
		_refresh_settings()

# ============================================================
func _build_game_page(parent: Control) -> void:
	game_page = Control.new()
	game_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(game_page)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	game_page.add_child(root)

	game_left_panel = PanelContainer.new()
	game_left_panel.custom_minimum_size = Vector2(LEFT_MIN_W, 0)
	game_left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(game_left_panel)

	var left_style := StyleBoxFlat.new()
	left_style.bg_color = C_PANEL
	game_left_panel.add_theme_stylebox_override("panel", left_style)

	var left_v := VBoxContainer.new()
	left_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 6)
	game_left_panel.add_child(left_v)

	search_box = LineEdit.new()
	search_box.placeholder_text = "🔍 搜索游戏..."
	search_box.custom_minimum_size = Vector2(0, 32)
	search_box.text_changed.connect(_on_search_changed)
	left_v.add_child(search_box)

	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list.icon_mode = ItemList.ICON_MODE_LEFT
	item_list.fixed_icon_size = Vector2i(32, 32)
	item_list.allow_rmb_select = true
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	item_list.gui_input.connect(_on_list_gui_input)
	left_v.add_child(item_list)

	var add_btn := Button.new()
	add_btn.text = "＋ 添加游戏"
	add_btn.custom_minimum_size = Vector2(0, 36)
	add_btn.pressed.connect(_on_add_pressed)
	left_v.add_child(add_btn)

	var splitter := Control.new()
	splitter.custom_minimum_size = Vector2(4, 0)
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	root.add_child(splitter)

	var split_line := ColorRect.new()
	split_line.color = C_PANEL
	split_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splitter.add_child(split_line)

	splitter.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_splitter_dragging = mb.pressed
				if mb.pressed:
					user_resized = true
		elif event is InputEventMouseMotion and _splitter_dragging:
			var mm: InputEventMouseMotion = event
			var max_w: float = get_viewport_rect().size.x * LEFT_MAX_RATIO
			var new_w: float = game_left_panel.size.x + mm.relative.x
			new_w = clampf(new_w, LEFT_MIN_W, max_w)
			game_left_panel.custom_minimum_size.x = new_w
	)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(right_margin)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	right_margin.add_child(right)

	game_cover_panel = PanelContainer.new()
	game_cover_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_cover_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_cover_panel.custom_minimum_size = Vector2(0, 260)
	right.add_child(game_cover_panel)

	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = C_PANEL
	cover_style.corner_radius_top_left = 6
	cover_style.corner_radius_top_right = 6
	cover_style.corner_radius_bottom_left = 6
	cover_style.corner_radius_bottom_right = 6
	game_cover_panel.add_theme_stylebox_override("panel", cover_style)

	var cover_stack := Control.new()
	cover_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game_cover_panel.add_child(cover_stack)

	cover_rect = TextureRect.new()
	cover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_stack.add_child(cover_rect)

	cover_hint = Label.new()
	cover_hint.text = "选择左侧游戏查看详情"
	cover_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover_hint.add_theme_color_override("font_color", C_TEXT_DIM)
	cover_hint.add_theme_font_size_override("font_size", 16)
	cover_stack.add_child(cover_hint)

	launch_btn = Button.new()
	launch_btn.text = "▶  启动游戏"
	launch_btn.custom_minimum_size = Vector2(0, 52)
	launch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_btn.add_theme_font_size_override("font_size", 18)
	launch_btn.disabled = true
	launch_btn.pressed.connect(_on_launch_pressed)
	right.add_child(launch_btn)

	title_label = Label.new()
	title_label.text = ""
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", C_TEXT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(title_label)

	var desc_scroll := ScrollContainer.new()
	desc_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.custom_minimum_size = Vector2(0, 80)
	right.add_child(desc_scroll)

	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", C_TEXT_DIM)
	desc_scroll.add_child(desc_label)

	status_bar = Label.new()
	status_bar.text = "就绪"
	status_bar.add_theme_color_override("font_color", C_TEXT_DIM)
	status_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(status_bar)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.exe ; 可执行文件"])
	file_dialog.use_native_dialog = true
	file_dialog.file_selected.connect(_on_exe_selected)
	add_child(file_dialog)

	manage_menu = PopupMenu.new()
	manage_menu.add_item("属性", 1)
	manage_menu.add_separator()
	manage_menu.add_item("浏览本地文件", 2)
	manage_menu.add_item("删除此游戏", 3)
	manage_menu.id_pressed.connect(_on_manage_menu)
	add_child(manage_menu)

	blank_menu = PopupMenu.new()
	blank_menu.add_item("刷新", 0)
	blank_menu.add_item("添加游戏", 1)
	blank_menu.add_separator()
	blank_menu.add_item("查看日志", 2)
	blank_menu.id_pressed.connect(_on_blank_menu)
	add_child(blank_menu)

# ============================================================
func _build_music_page(parent: Control) -> void:
	music_page = Control.new()
	music_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	music_page.visible = false
	parent.add_child(music_page)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	music_page.add_child(root)

	music_left_panel = PanelContainer.new()
	music_left_panel.custom_minimum_size = Vector2(LEFT_MIN_W, 0)
	music_left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(music_left_panel)

	var left_style := StyleBoxFlat.new()
	left_style.bg_color = C_PANEL
	music_left_panel.add_theme_stylebox_override("panel", left_style)

	var left_v := VBoxContainer.new()
	left_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_v.add_theme_constant_override("separation", 6)
	music_left_panel.add_child(left_v)

	music_search = LineEdit.new()
	music_search.placeholder_text = "🔍 搜索音乐..."
	music_search.custom_minimum_size = Vector2(0, 32)
	music_search.text_changed.connect(_on_music_search_changed)
	left_v.add_child(music_search)

	music_list = ItemList.new()
	music_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	music_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_list.icon_mode = ItemList.ICON_MODE_LEFT
	music_list.fixed_icon_size = Vector2i(48, 32)
	music_list.allow_rmb_select = true
	music_list.item_selected.connect(_on_music_selected)
	music_list.item_activated.connect(_on_music_activated)
	music_list.gui_input.connect(_on_music_list_gui_input)
	left_v.add_child(music_list)

	var add_music_btn := Button.new()
	add_music_btn.text = "＋ 导入音乐"
	add_music_btn.custom_minimum_size = Vector2(0, 36)
	add_music_btn.pressed.connect(_on_import_music_pressed)
	left_v.add_child(add_music_btn)

	var splitter := Control.new()
	splitter.custom_minimum_size = Vector2(4, 0)
	splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	splitter.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	root.add_child(splitter)

	var split_line := ColorRect.new()
	split_line.color = C_PANEL
	split_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splitter.add_child(split_line)

	splitter.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_splitter_dragging = mb.pressed
		elif event is InputEventMouseMotion and _splitter_dragging:
			var mm: InputEventMouseMotion = event
			var max_w: float = get_viewport_rect().size.x * LEFT_MAX_RATIO
			var new_w: float = music_left_panel.size.x + mm.relative.x
			new_w = clampf(new_w, LEFT_MIN_W, max_w)
			music_left_panel.custom_minimum_size.x = new_w
	)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(right_margin)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	right_margin.add_child(right)

	music_cover_panel = PanelContainer.new()
	music_cover_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_cover_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	music_cover_panel.custom_minimum_size = Vector2(0, 240)
	right.add_child(music_cover_panel)

	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = C_PANEL
	cover_style.corner_radius_top_left = 6
	cover_style.corner_radius_top_right = 6
	cover_style.corner_radius_bottom_left = 6
	cover_style.corner_radius_bottom_right = 6
	music_cover_panel.add_theme_stylebox_override("panel", cover_style)

	var cover_stack := Control.new()
	cover_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cover_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	music_cover_panel.add_child(cover_stack)

	music_cover_rect = TextureRect.new()
	music_cover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	music_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	music_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_stack.add_child(music_cover_rect)

	music_cover_hint = Label.new()
	music_cover_hint.text = "选择左侧音乐开始播放"
	music_cover_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	music_cover_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	music_cover_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	music_cover_hint.add_theme_color_override("font_color", C_TEXT_DIM)
	music_cover_hint.add_theme_font_size_override("font_size", 48)
	cover_stack.add_child(music_cover_hint)

	music_title = Label.new()
	music_title.text = ""
	music_title.add_theme_font_size_override("font_size", 22)
	music_title.add_theme_color_override("font_color", C_TEXT)
	music_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(music_title)

	music_meta = Label.new()
	music_meta.text = ""
	music_meta.add_theme_color_override("font_color", C_TEXT_DIM)
	music_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(music_meta)

	var progress_row := HBoxContainer.new()
	progress_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_theme_constant_override("separation", 8)
	right.add_child(progress_row)

	music_time_label = Label.new()
	music_time_label.text = "00:00 / 00:00"
	music_time_label.custom_minimum_size = Vector2(140, 0)
	music_time_label.add_theme_color_override("font_color", C_TEXT_DIM)
	progress_row.add_child(music_time_label)

	music_progress = HSlider.new()
	music_progress.min_value = 0.0
	music_progress.max_value = 100.0
	music_progress.step = 0.1
	music_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_progress.value_changed.connect(_on_music_progress_changed)
	music_progress.drag_started.connect(_on_music_progress_drag_started)
	music_progress.drag_ended.connect(_on_music_progress_drag_ended)
	progress_row.add_child(music_progress)

	var ctrl_row := HBoxContainer.new()
	ctrl_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ctrl_row.add_theme_constant_override("separation", 8)
	right.add_child(ctrl_row)

	music_prev_btn = Button.new()
	music_prev_btn.text = "⏮"
	music_prev_btn.custom_minimum_size = Vector2(52, 44)
	music_prev_btn.pressed.connect(_on_music_prev)
	ctrl_row.add_child(music_prev_btn)

	music_back_btn = Button.new()
	music_back_btn.text = "⏪ 5s"
	music_back_btn.custom_minimum_size = Vector2(72, 44)
	music_back_btn.pressed.connect(func() -> void: _music_seek_relative(-5.0))
	ctrl_row.add_child(music_back_btn)

	music_play_btn = Button.new()
	music_play_btn.text = "▶"
	music_play_btn.custom_minimum_size = Vector2(72, 44)
	music_play_btn.add_theme_font_size_override("font_size", 20)
	music_play_btn.pressed.connect(_on_music_play_pause)
	ctrl_row.add_child(music_play_btn)

	music_fwd_btn = Button.new()
	music_fwd_btn.text = "5s ⏩"
	music_fwd_btn.custom_minimum_size = Vector2(72, 44)
	music_fwd_btn.pressed.connect(func() -> void: _music_seek_relative(5.0))
	ctrl_row.add_child(music_fwd_btn)

	music_next_btn = Button.new()
	music_next_btn.text = "⏭"
	music_next_btn.custom_minimum_size = Vector2(52, 44)
	music_next_btn.pressed.connect(_on_music_next)
	ctrl_row.add_child(music_next_btn)

	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 4)
	right.add_child(speed_row)

	var speed_label := Label.new()
	speed_label.text = "速度："
	speed_label.add_theme_color_override("font_color", C_TEXT_DIM)
	speed_row.add_child(speed_label)

	for s in SPEED_STEPS:
		var b := Button.new()
		b.text = "%s×" % _fmt_speed(s)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(56, 36)
		b.button_pressed = (s == 1.0)
		b.pressed.connect(func() -> void: _on_music_speed_selected(s))
		speed_row.add_child(b)
		music_speed_buttons.append({"button": b, "speed": s})

	music_status = Label.new()
	music_status.text = "就绪"
	music_status.add_theme_color_override("font_color", C_TEXT_DIM)
	music_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(music_status)

	music_player = AudioStreamPlayer.new()
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	music_file_dialog = FileDialog.new()
	music_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	music_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	music_file_dialog.filters = PackedStringArray(["*.mp3, *.ogg, *.wav ; 音频文件"])
	music_file_dialog.use_native_dialog = true
	music_file_dialog.file_selected.connect(_on_music_file_selected)
	add_child(music_file_dialog)

	music_manage_menu = PopupMenu.new()
	music_manage_menu.add_item("属性", 1)
	music_manage_menu.add_separator()
	music_manage_menu.add_item("打开文件位置", 2)
	music_manage_menu.add_item("删除此音乐", 3)
	music_manage_menu.id_pressed.connect(_on_music_manage_menu)
	add_child(music_manage_menu)

	music_blank_menu = PopupMenu.new()
	music_blank_menu.add_item("刷新", 0)
	music_blank_menu.add_item("导入音乐", 1)
	music_blank_menu.id_pressed.connect(_on_music_blank_menu)
	add_child(music_blank_menu)

func _fmt_speed(s: float) -> String:
	if s == int(s):
		return str(int(s))
	return str(s)

# ============================================================
func _build_settings_page(parent: Control) -> void:
	settings_page = Control.new()
	settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_page.visible = false
	parent.add_child(settings_page)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	settings_page.add_child(root)

	settings_sidebar = PanelContainer.new()
	settings_sidebar.custom_minimum_size = Vector2(200, 0)
	settings_sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(settings_sidebar)

	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = C_PANEL
	settings_sidebar.add_theme_stylebox_override("panel", sb_style)

	var sb_v := VBoxContainer.new()
	sb_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sb_v.add_theme_constant_override("separation", 6)
	settings_sidebar.add_child(sb_v)

	var sb_title := Label.new()
	sb_title.text = "  设置模块"
	sb_title.add_theme_font_size_override("font_size", 14)
	sb_title.add_theme_color_override("font_color", C_TEXT_DIM)
	sb_title.custom_minimum_size = Vector2(0, 30)
	sb_v.add_child(sb_title)

	settings_module_list = ItemList.new()
	settings_module_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_module_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_module_list.add_item("🎨  画面模块")
	settings_module_list.add_item("🎵  音乐模块")
	settings_module_list.item_selected.connect(_on_settings_module_selected)
	sb_v.add_child(settings_module_list)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	root.add_child(right_margin)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right_scroll)

	settings_content = Control.new()
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(settings_content)

	settings_detail_box = VBoxContainer.new()
	settings_detail_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_detail_box.add_theme_constant_override("separation", 10)
	settings_content.add_child(settings_detail_box)

func _refresh_settings() -> void:
	if settings_module_list.item_count > 0 and settings_module_list.get_selected_items().is_empty():
		settings_module_list.select(0)
		_on_settings_module_selected(0)

func _on_settings_module_selected(idx: int) -> void:
	for c in settings_detail_box.get_children():
		c.queue_free()
	if idx == 0:
		_build_picture_module()
	elif idx == 1:
		_build_music_module()

# ============================================================
func _build_picture_module() -> void:
	var title := Label.new()
	title.text = "画面模块"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_TEXT)
	settings_detail_box.add_child(title)

	var sep := HSeparator.new()
	settings_detail_box.add_child(sep)

	var subtitle := Label.new()
	subtitle.text = "个性化"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", C_ACCENT)
	settings_detail_box.add_child(subtitle)

	var hint := Label.new()
	hint.text = "点击下方选项，选择对应的颜色。"
	hint.add_theme_color_override("font_color", C_TEXT_DIM)
	settings_detail_box.add_child(hint)

	settings_detail_box.add_child(_make_color_row("顶边框颜色", "top", setting_top_color))
	settings_detail_box.add_child(_make_color_row("侧栏颜色", "sidebar", setting_sidebar_color))
	settings_detail_box.add_child(_make_color_row("主界颜色", "main", setting_main_color))

	settings_detail_box.add_child(HSeparator.new())

	var unify_btn := Button.new()
	unify_btn.text = "一键更换颜色（三区统一）"
	unify_btn.custom_minimum_size = Vector2(280, 40)
	unify_btn.pressed.connect(_on_unify_colors)
	settings_detail_box.add_child(unify_btn)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认"
	reset_btn.custom_minimum_size = Vector2(140, 40)
	reset_btn.pressed.connect(_on_reset_colors)
	settings_detail_box.add_child(reset_btn)

func _make_color_row(label_text: String, target: String, cur_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 52)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", C_TEXT)
	row.add_child(lbl)

	var swatch := ColorRect.new()
	swatch.color = cur_color
	swatch.custom_minimum_size = Vector2(40, 40)
	swatch.name = "Swatch_" + target
	row.add_child(swatch)

	var info := Label.new()
	info.text = "#" + cur_color.to_html(false).to_upper()
	info.add_theme_color_override("font_color", C_TEXT_DIM)
	info.name = "Info_" + target
	row.add_child(info)

	var btn := Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(80, 36)
	btn.pressed.connect(func() -> void: _open_color_picker(target))
	row.add_child(btn)

	return row

func _on_unify_colors() -> void:
	# 打开颜色窗口，模式 = 三区同时改
	color_picker_target_multi = true
	color_picker_target = "all"
	color_picker_obj.color = setting_top_color
	color_picker_window.popup_centered()
	_update_swatch_selection(setting_top_color)

func _on_reset_colors() -> void:
	setting_top_color = PRESET_DEFAULT
	setting_sidebar_color = PRESET_DEFAULT
	setting_main_color = PRESET_DEFAULT
	_apply_theme_colors()
	_save_settings()
	_refresh_settings()
	_on_settings_module_selected(0)

# ============================================================
func _build_music_module() -> void:
	var title := Label.new()
	title.text = "音乐模块"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_TEXT)
	settings_detail_box.add_child(title)

	var sep := HSeparator.new()
	settings_detail_box.add_child(sep)

	var lbl := Label.new()
	lbl.text = "音乐音量"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_ACCENT)
	settings_detail_box.add_child(lbl)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vol_row.custom_minimum_size = Vector2(0, 44)
	settings_detail_box.add_child(vol_row)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = music_volume
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(_on_music_volume_changed)
	vol_row.add_child(slider)

	var vol_label := Label.new()
	vol_label.text = "%d%%" % int(music_volume)
	vol_label.custom_minimum_size = Vector2(60, 0)
	vol_label.add_theme_color_override("font_color", C_TEXT)
	vol_label.name = "VolLabel"
	vol_row.add_child(vol_label)

	var hint := Label.new()
	hint.text = "拖动滑块调整音乐播放音量，实时生效。"
	hint.add_theme_color_override("font_color", C_TEXT_DIM)
	settings_detail_box.add_child(hint)

func _on_music_volume_changed(v: float) -> void:
	music_volume = v
	var lbl := settings_detail_box.find_child("VolLabel", true, false) as Label
	if lbl:
		lbl.text = "%d%%" % int(v)
	_apply_music_volume()
	_save_settings()

func _apply_music_volume() -> void:
	if music_player == null:
		return
	if music_volume <= 0.0:
		music_player.volume_db = -80.0
	else:
		music_player.volume_db = linear_to_db(music_volume / 100.0)

# ============================================================
func _build_color_picker_window() -> void:
	color_picker_window = Window.new()
	color_picker_window.title = "选择颜色"
	color_picker_window.size = Vector2i(520, 520)
	color_picker_window.visible = false
	color_picker_window.close_requested.connect(func() -> void: color_picker_window.hide())
	add_child(color_picker_window)

	var pw_bg := ColorRect.new()
	pw_bg.color = C_BG
	pw_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pw_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_picker_window.add_child(pw_bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color_picker_window.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var preset_title := Label.new()
	preset_title.text = "预设颜色"
	preset_title.add_theme_font_size_override("font_size", 16)
	preset_title.add_theme_color_override("font_color", C_TEXT)
	root.add_child(preset_title)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	var presets: Array = [
		{"name": "默认", "color": PRESET_DEFAULT},
		{"name": "浅色", "color": PRESET_LIGHT},
		{"name": "红", "color": PRESET_RED},
		{"name": "橙", "color": PRESET_ORANGE},
		{"name": "黄", "color": PRESET_YELLOW},
		{"name": "绿", "color": PRESET_GREEN},
		{"name": "青", "color": PRESET_CYAN},
		{"name": "蓝", "color": PRESET_BLUE},
		{"name": "紫", "color": PRESET_PURPLE},
	]

	color_swatch_buttons.clear()
	for p in presets:
		var btn := _make_swatch_button(p["color"], p["name"])
		btn.pressed.connect(func() -> void: _on_swatch_clicked(p["color"]))
		grid.add_child(btn)
		color_swatch_buttons.append({"btn": btn, "color": p["color"]})

	var custom_btn := Button.new()
	custom_btn.text = "自定义"
	custom_btn.custom_minimum_size = Vector2(72, 72)
	custom_btn.pressed.connect(func() -> void: pass)
	grid.add_child(custom_btn)

	var sep := HSeparator.new()
	root.add_child(sep)

	var edit_title := Label.new()
	edit_title.text = "自定义颜色"
	edit_title.add_theme_font_size_override("font_size", 16)
	edit_title.add_theme_color_override("font_color", C_TEXT)
	root.add_child(edit_title)

	color_picker_obj = ColorPicker.new()
	color_picker_obj.edit_alpha = false
	color_picker_obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker_obj.custom_minimum_size = Vector2(0, 340)
	color_picker_obj.color_changed.connect(_on_picker_color_changed)
	root.add_child(color_picker_obj)

	var apply_btn := Button.new()
	apply_btn.text = "应用"
	apply_btn.custom_minimum_size = Vector2(0, 40)
	apply_btn.pressed.connect(_on_picker_apply)
	root.add_child(apply_btn)

func _make_swatch_button(color: Color, tooltip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 72)
	b.tooltip_text = tooltip
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0.3)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.border_color = Color(1, 1, 1, 0.6)
	b.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.border_color = C_SELECT
	sb_pressed.border_width_left = 3
	sb_pressed.border_width_right = 3
	sb_pressed.border_width_top = 3
	sb_pressed.border_width_bottom = 3
	b.add_theme_stylebox_override("pressed", sb_pressed)
	b.add_theme_stylebox_override("focus", sb_pressed)
	return b

func _open_color_picker(target: String) -> void:
	color_picker_target_multi = false
	color_picker_target = target
	var cur: Color
	match target:
		"top":
			cur = setting_top_color
		"sidebar":
			cur = setting_sidebar_color
		"main":
			cur = setting_main_color
	color_picker_obj.color = cur
	color_picker_window.popup_centered()
	_update_swatch_selection(cur)

func _update_swatch_selection(cur: Color) -> void:
	for item in color_swatch_buttons:
		var btn: Button = item["btn"]
		var c: Color = item["color"]
		var is_sel: bool = c.is_equal_approx(cur)
		var sb := btn.get_theme_stylebox("normal") as StyleBoxFlat
		if sb:
			if is_sel:
				sb.border_color = C_SELECT
				sb.border_width_left = 3
				sb.border_width_right = 3
				sb.border_width_top = 3
				sb.border_width_bottom = 3
			else:
				sb.border_color = Color(0, 0, 0, 0.3)
				sb.border_width_left = 2
				sb.border_width_right = 2
				sb.border_width_top = 2
				sb.border_width_bottom = 2
		var sp := btn.get_theme_stylebox("pressed") as StyleBoxFlat
		if sp:
			sp.bg_color = c
		var sf := btn.get_theme_stylebox("focus") as StyleBoxFlat
		if sf:
			sf.bg_color = c

func _on_swatch_clicked(color: Color) -> void:
	_set_color_for_target(color)
	_update_swatch_selection(color)

func _on_picker_color_changed(color: Color) -> void:
	_set_color_for_target(color)
	_update_swatch_selection(color)

func _on_picker_apply() -> void:
	_set_color_for_target(color_picker_obj.color)
	_save_settings()
	color_picker_window.hide()
	color_picker_target_multi = false

func _set_color_for_target(c: Color) -> void:
	if color_picker_target_multi or color_picker_target == "all":
		setting_top_color = c
		setting_sidebar_color = c
		setting_main_color = c
	else:
		match color_picker_target:
			"top":
				setting_top_color = c
			"sidebar":
				setting_sidebar_color = c
			"main":
				setting_main_color = c
	_apply_theme_colors()
	_save_settings()
	_update_color_row_preview()

func _update_color_row_preview() -> void:
	if settings_detail_box == null:
		return
	var rows: Array = [
		{"target": "top", "color": setting_top_color},
		{"target": "sidebar", "color": setting_sidebar_color},
		{"target": "main", "color": setting_main_color},
	]
	for r in rows:
		var sw := settings_detail_box.find_child("Swatch_" + r["target"], true, false) as ColorRect
		if sw:
			sw.color = r["color"]
		var info := settings_detail_box.find_child("Info_" + r["target"], true, false) as Label
		if info:
			info.text = "#" + (r["color"] as Color).to_html(false).to_upper()

# ============================================================
func _apply_theme_colors() -> void:
	if bg_rect:
		bg_rect.color = setting_main_color
	if top_bar_bg:
		top_bar_bg.color = setting_top_color
	_set_panel_color(game_left_panel, setting_sidebar_color)
	_set_panel_color(music_left_panel, setting_sidebar_color)
	_set_panel_color(settings_sidebar, setting_sidebar_color)
	_set_panel_color(game_cover_panel, setting_sidebar_color)
	_set_panel_color(music_cover_panel, setting_sidebar_color)
	C_BG = setting_main_color
	C_TOP_BAR = setting_top_color
	C_PANEL = setting_sidebar_color

func _set_panel_color(panel: PanelContainer, c: Color) -> void:
	if panel == null:
		return
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		sb = StyleBoxFlat.new()
		panel.add_theme_stylebox_override("panel", sb)
	sb.bg_color = c

# ============================================================
func _save_settings() -> void:
	var data: Dictionary = {
		"top_color": setting_top_color.to_html(false),
		"sidebar_color": setting_sidebar_color.to_html(false),
		"main_color": setting_main_color.to_html(false),
		"music_volume": music_volume
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var d: Dictionary = parsed
		if d.has("top_color"):
			setting_top_color = Color.html(str(d["top_color"]))
		if d.has("sidebar_color"):
			setting_sidebar_color = Color.html(str(d["sidebar_color"]))
		if d.has("main_color"):
			setting_main_color = Color.html(str(d["main_color"]))
		if d.has("music_volume"):
			music_volume = float(d["music_volume"])
	C_BG = setting_main_color
	C_TOP_BAR = setting_top_color
	C_PANEL = setting_sidebar_color

# ============================================================
func _build_prop_window() -> void:
	prop_window = Window.new()
	prop_window.title = "属性"
	prop_window.size = Vector2i(560, 620)
	prop_window.visible = false
	prop_window.close_requested.connect(func() -> void: prop_window.hide())
	add_child(prop_window)

	var pw_bg := ColorRect.new()
	pw_bg.color = C_BG
	pw_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pw_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prop_window.add_child(pw_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	prop_window.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var info_title := Label.new()
	info_title.text = "基本信息"
	info_title.add_theme_font_size_override("font_size", 18)
	info_title.add_theme_color_override("font_color", C_ACCENT)
	root.add_child(info_title)

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 12)
	root.add_child(info_grid)

	var l1 := Label.new()
	l1.text = "路径："
	l1.add_theme_color_override("font_color", C_TEXT_DIM)
	info_grid.add_child(l1)

	prop_path_label = Label.new()
	prop_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prop_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_path_label.add_theme_color_override("font_color", C_TEXT)
	info_grid.add_child(prop_path_label)

	var l2 := Label.new()
	l2.text = "大小："
	l2.add_theme_color_override("font_color", C_TEXT_DIM)
	info_grid.add_child(l2)

	prop_size_label = Label.new()
	prop_size_label.add_theme_color_override("font_color", C_TEXT)
	info_grid.add_child(prop_size_label)

	root.add_child(HSeparator.new())

	var custom_title := Label.new()
	custom_title.text = "自定义"
	custom_title.add_theme_font_size_override("font_size", 18)
	custom_title.add_theme_color_override("font_color", C_ACCENT)
	root.add_child(custom_title)

	var name_l := Label.new()
	name_l.text = "游戏名称"
	name_l.add_theme_color_override("font_color", C_TEXT_DIM)
	root.add_child(name_l)

	prop_name_edit = LineEdit.new()
	root.add_child(prop_name_edit)

	var desc_l := Label.new()
	desc_l.text = "游戏描述"
	desc_l.add_theme_color_override("font_color", C_TEXT_DIM)
	root.add_child(desc_l)

	prop_desc_edit = TextEdit.new()
	prop_desc_edit.custom_minimum_size = Vector2(0, 100)
	prop_desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(prop_desc_edit)

	var img_row := HBoxContainer.new()
	img_row.add_theme_constant_override("separation", 12)
	root.add_child(img_row)

	var logo_col := VBoxContainer.new()
	img_row.add_child(logo_col)

	var logo_l := Label.new()
	logo_l.text = "徽标"
	logo_l.add_theme_color_override("font_color", C_TEXT_DIM)
	logo_col.add_child(logo_l)

	prop_logo_rect = TextureRect.new()
	prop_logo_rect.custom_minimum_size = Vector2(96, 96)
	prop_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prop_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_col.add_child(prop_logo_rect)

	var logo_btn := Button.new()
	logo_btn.text = "更换徽标"
	logo_btn.pressed.connect(_on_pick_logo)
	logo_col.add_child(logo_btn)

	var cover_col := VBoxContainer.new()
	cover_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img_row.add_child(cover_col)

	var cover_l := Label.new()
	cover_l.text = "封面图片"
	cover_l.add_theme_color_override("font_color", C_TEXT_DIM)
	cover_col.add_child(cover_l)

	prop_cover_rect = TextureRect.new()
	prop_cover_rect.custom_minimum_size = Vector2(0, 96)
	prop_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prop_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover_col.add_child(prop_cover_rect)

	var cover_btn := Button.new()
	cover_btn.text = "更换封面"
	cover_btn.pressed.connect(_on_pick_cover)
	cover_col.add_child(cover_btn)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func() -> void: prop_window.hide())
	btn_row.add_child(cancel_btn)

	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_prop_save)
	btn_row.add_child(save_btn)

# ============================================================
func _build_music_prop_window() -> void:
	music_prop_window = Window.new()
	music_prop_window.title = "音乐属性"
	music_prop_window.size = Vector2i(560, 520)
	music_prop_window.visible = false
	music_prop_window.close_requested.connect(func() -> void: music_prop_window.hide())
	add_child(music_prop_window)

	var pw_bg := ColorRect.new()
	pw_bg.color = C_BG
	pw_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pw_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	music_prop_window.add_child(pw_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	music_prop_window.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var info_title := Label.new()
	info_title.text = "基本信息"
	info_title.add_theme_font_size_override("font_size", 18)
	info_title.add_theme_color_override("font_color", C_ACCENT)
	root.add_child(info_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	root.add_child(grid)

	var l_full := Label.new()
	l_full.text = "全名："
	l_full.add_theme_color_override("font_color", C_TEXT_DIM)
	grid.add_child(l_full)
	mprop_full_name = Label.new()
	mprop_full_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mprop_full_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mprop_full_name.add_theme_color_override("font_color", C_TEXT)
	grid.add_child(mprop_full_name)

	var l_path := Label.new()
	l_path.text = "路径："
	l_path.add_theme_color_override("font_color", C_TEXT_DIM)
	grid.add_child(l_path)
	mprop_path_label = Label.new()
	mprop_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mprop_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mprop_path_label.add_theme_color_override("font_color", C_TEXT)
	grid.add_child(mprop_path_label)

	var l_size := Label.new()
	l_size.text = "大小："
	l_size.add_theme_color_override("font_color", C_TEXT_DIM)
	grid.add_child(l_size)
	mprop_size_label = Label.new()
	mprop_size_label.add_theme_color_override("font_color", C_TEXT)
	grid.add_child(mprop_size_label)

	var l_dur := Label.new()
	l_dur.text = "时长："
	l_dur.add_theme_color_override("font_color", C_TEXT_DIM)
	grid.add_child(l_dur)
	mprop_dur_label = Label.new()
	mprop_dur_label.add_theme_color_override("font_color", C_TEXT)
	grid.add_child(mprop_dur_label)

	var l_fmt := Label.new()
	l_fmt.text = "格式："
	l_fmt.add_theme_color_override("font_color", C_TEXT_DIM)
	grid.add_child(l_fmt)
	mprop_fmt_label = Label.new()
	mprop_fmt_label.add_theme_color_override("font_color", C_TEXT)
	grid.add_child(mprop_fmt_label)

	root.add_child(HSeparator.new())

	var custom_title := Label.new()
	custom_title.text = "自定义"
	custom_title.add_theme_font_size_override("font_size", 18)
	custom_title.add_theme_color_override("font_color", C_ACCENT)
	root.add_child(custom_title)

	var name_l := Label.new()
	name_l.text = "显示名称"
	name_l.add_theme_color_override("font_color", C_TEXT_DIM)
	root.add_child(name_l)

	mprop_name_edit = LineEdit.new()
	root.add_child(mprop_name_edit)

	var desc_l := Label.new()
	desc_l.text = "描述"
	desc_l.add_theme_color_override("font_color", C_TEXT_DIM)
	root.add_child(desc_l)

	mprop_desc_edit = TextEdit.new()
	mprop_desc_edit.custom_minimum_size = Vector2(0, 80)
	mprop_desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(mprop_desc_edit)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(func() -> void: music_prop_window.hide())
	btn_row.add_child(cancel_btn)

	var save_btn := Button.new()
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_music_prop_save)
	btn_row.add_child(save_btn)
	# ============================================================
func _log(msg: String) -> void:
	if FileAccess.file_exists(LOG_FILE):
		var chk := FileAccess.open(LOG_FILE, FileAccess.READ)
		if chk and chk.get_length() > LOG_MAX_BYTES:
			chk.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_FILE))
	var f: FileAccess
	if FileAccess.file_exists(LOG_FILE):
		f = FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	if f == null:
		return
	var ts: String = Time.get_datetime_string_from_system()
	f.store_line("[%s] %s" % [ts, msg])
	f.close()

# ============================================================
func _auto_fit_left_width() -> void:
	if item_list == null:
		return
	if user_resized:
		return
	var needed: float = item_list.get_minimum_size().x + 24.0
	var max_w: float = get_viewport_rect().size.x * LEFT_MAX_RATIO
	var target: float = clampf(needed, LEFT_MIN_W, max_w)
	if game_page and game_page.visible and game_left_panel:
		game_left_panel.custom_minimum_size.x = target
	if music_page and music_page.visible and music_left_panel:
		music_left_panel.custom_minimum_size.x = target

# ============================================================
# 游戏列表
# ============================================================
func _refresh_list() -> void:
	var keyword: String = search_box.text.strip_edges().to_lower()
	filtered_indices.clear()
	item_list.clear()
	for i in games.size():
		var g: Dictionary = games[i]
		var gname: String = str(g.get("name", ""))
		if keyword != "" and not gname.to_lower().contains(keyword):
			continue
		filtered_indices.append(i)
		var idx: int = item_list.add_item(gname)
		var logo: String = _resolve_icon(g)
		if logo != "":
			var tex: Texture2D = _load_texture(logo)
			if tex != null:
				item_list.set_item_icon(idx, tex)
		item_list.set_item_tooltip(idx, str(g.get("exe_path", "")))
	if current_index >= 0 and current_index < games.size():
		var pos: int = filtered_indices.find(current_index)
		if pos >= 0:
			item_list.select(pos)
			_update_detail()
	_auto_fit_left_width()

func _resolve_icon(g: Dictionary) -> String:
	var logo: String = str(g.get("logo_path", ""))
	if logo != "" and FileAccess.file_exists(logo):
		return logo
	var ic: String = str(g.get("icon_path", ""))
	if ic != "" and FileAccess.file_exists(ic):
		return ic
	return ""

func _load_texture(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	return ImageTexture.create_from_image(img)

# ============================================================
func _update_detail() -> void:
	if current_index < 0 or current_index >= games.size():
		cover_rect.texture = null
		cover_hint.visible = true
		cover_hint.text = "选择左侧游戏查看详情"
		title_label.text = ""
		desc_label.text = ""
		_update_launch_button()
		return
	var g: Dictionary = games[current_index]
	title_label.text = str(g.get("name", "未命名"))
	var desc: String = str(g.get("desc", ""))
	desc_label.text = desc if desc != "" else "（暂无描述）"
	var cover: String = str(g.get("cover_path", ""))
	if cover != "" and FileAccess.file_exists(cover):
		cover_rect.texture = _load_texture(cover)
		cover_hint.visible = false
	else:
		cover_rect.texture = null
		cover_hint.visible = true
		cover_hint.text = "（尚未设置封面）\n右键游戏 → 属性 → 更换封面"
	_update_launch_button()

# ============================================================
func _on_search_changed(_t: String) -> void:
	_refresh_list()

func _on_item_selected(idx: int) -> void:
	if idx < 0 or idx >= filtered_indices.size():
		return
	current_index = int(filtered_indices[idx])
	_update_detail()

func _on_item_activated(idx: int) -> void:
	if idx < 0 or idx >= filtered_indices.size():
		return
	current_index = int(filtered_indices[idx])
	_update_detail()
	if running_pid <= 0:
		_launch_current()

func _on_launch_pressed() -> void:
	if running_pid > 0:
		_stop_game()
	else:
		_launch_current()

func _update_launch_button() -> void:
	if running_pid > 0:
		launch_btn.text = "■  停止游戏"
		launch_btn.disabled = false
	else:
		launch_btn.text = "▶  启动游戏"
		launch_btn.disabled = (current_index < 0 or current_index >= games.size())

# ============================================================
func _launch_current() -> void:
	if current_index < 0 or current_index >= games.size():
		return
	if running_pid > 0:
		return
	var g: Dictionary = games[current_index]
	var exe_path: String = str(g.get("exe_path", ""))
	if not FileAccess.file_exists(exe_path):
		_set_status("文件不存在：" + exe_path)
		_log("launch failed: file not exists: " + exe_path)
		return
	games[current_index]["last_played"] = Time.get_unix_time_from_system()
	_save_games()
	var pid: int = -1
	if OS.has_feature("windows"):
		pid = _launch_windows(exe_path)
	else:
		pid = OS.create_process(exe_path, PackedStringArray())
	if pid <= 0:
		_set_status("启动失败，详情见日志")
		_log("launch failed, see above: " + exe_path)
		return
	running_pid = pid
	running_index = current_index
	_last_check_time = 0.0
	_update_launch_button()
	_set_status("已启动 (PID %d)：%s" % [pid, str(g.get("name", ""))])
	_log("launched pid=%d exe=%s" % [pid, exe_path])

func _launch_windows(exe_path: String) -> int:
	var work_dir: String = exe_path.get_base_dir()
	var pid_file: String = "user://logs/_last_pid.txt"
	var abs_pid_file: String = ProjectSettings.globalize_path(pid_file)
	if FileAccess.file_exists(pid_file):
		DirAccess.remove_absolute(abs_pid_file)
	var ps_cmd: String = '$ProgressPreference = "SilentlyContinue"; '
	ps_cmd += '$ErrorActionPreference = "Stop"; '
	ps_cmd += '$p = Start-Process -FilePath "%s" -WorkingDirectory "%s" -PassThru; ' % [exe_path, work_dir]
	ps_cmd += '$p.Id | Out-File -FilePath "%s" -Encoding ascii -NoNewline' % abs_pid_file
	var utf16: PackedByteArray = ps_cmd.to_utf16_buffer()
	var b64: String = Marshalls.raw_to_base64(utf16)
	var out: Array = []
	var code: int = OS.execute("powershell",
		["-NoProfile", "-NonInteractive", "-EncodedCommand", b64],
		out, true)
	_log("ps exit=%d" % code)
	if not FileAccess.file_exists(pid_file):
		_log("pid file not created")
		return -1
	var f := FileAccess.open(pid_file, FileAccess.READ)
	if f == null:
		_log("cannot read pid file")
		return -1
	var txt: String = f.get_as_text().strip_edges()
	f.close()
	if not txt.is_valid_int():
		_log("pid file content invalid: '" + txt + "'")
		return -1
	return int(txt)

# ============================================================
func _stop_game() -> void:
	if running_pid <= 0:
		return
	var p: int = running_pid
	if OS.has_feature("windows"):
		OS.execute("taskkill", ["/PID", str(p), "/T", "/F"], [], false)
	else:
		OS.execute("kill", ["-9", str(p)], [], false)
	_log("stopped pid=%d" % p)
	running_pid = -1
	running_index = -1
	_update_launch_button()
	_set_status("游戏已停止")

func _process(delta: float) -> void:
	if running_pid > 0:
		_last_check_time += delta
		if _last_check_time >= 2.0:
			_last_check_time = 0.0
			if not _is_process_alive(running_pid):
				var p: int = running_pid
				running_pid = -1
				running_index = -1
				_update_launch_button()
				_set_status("游戏已退出")
				_log("process %d exited" % p)
	if music_player and music_player.stream and not music_dragging:
		var total: float = _music_get_total()
		var elapsed: float
		if music_player.stream_paused and music_pending_seek >= 0.0:
			elapsed = music_pending_seek
		else:
			elapsed = music_player.get_playback_position() / music_speed
		elapsed = clampf(elapsed, 0.0, total)
		music_progress.set_value(elapsed)
		music_time_label.text = "%s / %s" % [_fmt_time(elapsed), _fmt_time(total)]

func _is_process_alive(pid: int) -> bool:
	if pid <= 0:
		return false
	if not OS.has_feature("windows"):
		return FileAccess.file_exists("/proc/%d" % pid)
	var result_file: String = "user://logs/_alive.txt"
	var abs_result: String = ProjectSettings.globalize_path(result_file)
	if FileAccess.file_exists(result_file):
		DirAccess.remove_absolute(abs_result)
	var ps_cmd: String = '$ProgressPreference = "SilentlyContinue"; '
	ps_cmd += '$p = Get-Process -Id %d -ErrorAction SilentlyContinue; ' % pid
	ps_cmd += 'if ($p) { "1" | Out-File -FilePath "%s" -Encoding ascii -NoNewline }' % abs_result
	var utf16: PackedByteArray = ps_cmd.to_utf16_buffer()
	var b64: String = Marshalls.raw_to_base64(utf16)
	OS.execute("powershell",
		["-NoProfile", "-NonInteractive", "-EncodedCommand", b64],
		[], true)
	if not FileAccess.file_exists(result_file):
		return false
	var f := FileAccess.open(result_file, FileAccess.READ)
	if f == null:
		return false
	var txt: String = f.get_as_text().strip_edges()
	f.close()
	return txt == "1"

# ============================================================
func _on_add_pressed() -> void:
	file_dialog.popup_centered(Vector2i(800, 520))

func _on_exe_selected(path: String) -> void:
	var icon_path: String = _extract_icon(path)
	var default_name: String = path.get_file().get_basename()
	games.append({
		"name": default_name,
		"exe_path": path,
		"icon_path": icon_path,
		"logo_path": "",
		"cover_path": "",
		"desc": "",
		"last_played": 0
	})
	current_index = games.size() - 1
	_save_games()
	_refresh_list()
	_update_detail()
	_set_status("已添加：" + default_name)

func _extract_icon(exe_path: String) -> String:
	if not OS.has_feature("windows"):
		return ""
	var hash: String = exe_path.md5_text()
	var out_path: String = ICON_DIR.path_join(hash + ".png")
	if FileAccess.file_exists(out_path):
		return out_path
	var abs_out: String = ProjectSettings.globalize_path(out_path)
	var exe_safe: String = exe_path.replace("'", "''")
	var out_safe: String = abs_out.replace("'", "''")
	var ps: String = "$ProgressPreference = 'SilentlyContinue'; "
	ps += "Add-Type -AssemblyName System.Drawing; "
	ps += "$icon = [System.Drawing.Icon]::ExtractAssociatedIcon('%s'); " % exe_safe
	ps += "if ($icon) { $icon.ToBitmap().Save('%s', [System.Drawing.Imaging.ImageFormat]::Png) }" % out_safe
	var output: Array = []
	OS.execute("powershell",
		["-NoProfile", "-NonInteractive", "-Command", ps],
		output, true)
	if FileAccess.file_exists(out_path):
		return out_path
	return ""

# ============================================================
func _on_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var clicked_idx: int = item_list.get_item_at_position(mb.position)
			if clicked_idx >= 0:
				item_list.select(clicked_idx)
				_on_item_selected(clicked_idx)
				manage_menu.position = get_global_mouse_position()
				manage_menu.popup()
			else:
				blank_menu.position = get_global_mouse_position()
				blank_menu.popup()

func _on_manage_menu(id: int) -> void:
	if current_index < 0 or current_index >= games.size():
		return
	var g: Dictionary = games[current_index]
	match id:
		1:
			_open_prop_window()
		2:
			_open_in_explorer(str(g.get("exe_path", "")))
		3:
			if running_pid > 0 and running_index == current_index:
				_stop_game()
			games.remove_at(current_index)
			current_index = -1
			_save_games()
			_refresh_list()
			_update_detail()

func _on_blank_menu(id: int) -> void:
	match id:
		0:
			_refresh_all()
		1:
			_on_add_pressed()
		2:
			var log_dir: String = ProjectSettings.globalize_path(LOG_DIR).replace("/", "\\")
			OS.execute("explorer", [log_dir], [], false)

func _refresh_all() -> void:
	var removed: int = 0
	var i: int = games.size() - 1
	while i >= 0:
		var g: Dictionary = games[i]
		if not FileAccess.file_exists(str(g.get("exe_path", ""))):
			games.remove_at(i)
			removed += 1
		else:
			var ic: String = str(g.get("icon_path", ""))
			if ic == "" or not FileAccess.file_exists(ic):
				g["icon_path"] = _extract_icon(str(g.get("exe_path", "")))
		i -= 1
	current_index = -1
	_save_games()
	_refresh_list()
	_update_detail()
	if removed > 0:
		_set_status("已清理 %d 个失效游戏" % removed)
	else:
		_set_status("刷新完成")

func _open_in_explorer(path: String) -> void:
	if not FileAccess.file_exists(path):
		_set_status("文件不存在")
		return
	if OS.has_feature("windows"):
		var win_path: String = path.replace("/", "\\")
		OS.execute("explorer", ["/select,", win_path], [], false)
	else:
		OS.execute("xdg-open", [path.get_base_dir()], [], false)

# ============================================================
func _open_prop_window() -> void:
	if current_index < 0 or current_index >= games.size():
		return
	var g: Dictionary = games[current_index]
	prop_path_label.text = str(g.get("exe_path", ""))
	prop_size_label.text = _format_size(str(g.get("exe_path", "")))
	prop_name_edit.text = str(g.get("name", ""))
	prop_desc_edit.text = str(g.get("desc", ""))
	var logo: String = _resolve_icon(g)
	prop_logo_rect.texture = _load_texture(logo) if logo != "" else null
	var cover: String = str(g.get("cover_path", ""))
	if cover != "" and FileAccess.file_exists(cover):
		prop_cover_rect.texture = _load_texture(cover)
	else:
		prop_cover_rect.texture = null
	prop_window.popup_centered()

func _format_size(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "未知"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "未知"
	var bytes: int = f.get_length()
	f.close()
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.2f KB" % (float(bytes) / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.2f MB" % (float(bytes) / 1024.0 / 1024.0)
	else:
		return "%.2f GB" % (float(bytes) / 1024.0 / 1024.0 / 1024.0)

func _on_pick_logo() -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"])
	d.use_native_dialog = true
	d.file_selected.connect(_on_logo_picked)
	add_child(d)
	d.popup_centered(Vector2i(700, 500))

func _on_logo_picked(p: String) -> void:
	var ext: String = p.get_extension().to_lower()
	if ext == "":
		ext = "png"
	var dest: String = COVER_DIR.path_join("logo_%d.%s" % [Time.get_ticks_msec(), ext])
	var err: int = DirAccess.copy_absolute(p, ProjectSettings.globalize_path(dest))
	if err == OK and current_index >= 0:
		games[current_index]["logo_path"] = dest
		prop_logo_rect.texture = _load_texture(dest)
		_refresh_list()

func _on_pick_cover() -> void:
	var d := FileDialog.new()
	d.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; 图片"])
	d.use_native_dialog = true
	d.file_selected.connect(_on_cover_picked)
	add_child(d)
	d.popup_centered(Vector2i(700, 500))

func _on_cover_picked(p: String) -> void:
	var ext: String = p.get_extension().to_lower()
	if ext == "":
		ext = "png"
	var dest: String = COVER_DIR.path_join("cover_%d.%s" % [Time.get_ticks_msec(), ext])
	var err: int = DirAccess.copy_absolute(p, ProjectSettings.globalize_path(dest))
	if err == OK and current_index >= 0:
		games[current_index]["cover_path"] = dest
		prop_cover_rect.texture = _load_texture(dest)
		_update_detail()

func _on_prop_save() -> void:
	if current_index < 0 or current_index >= games.size():
		prop_window.hide()
		return
	games[current_index]["name"] = prop_name_edit.text.strip_edges()
	games[current_index]["desc"] = prop_desc_edit.text
	_save_games()
	_refresh_list()
	_update_detail()
	prop_window.hide()
	_set_status("已保存")

# ============================================================
func _save_games() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(games, "\t"))

func _load_games() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		games = parsed
		for g in games:
			if g is Dictionary:
				if not g.has("logo_path"):
					g["logo_path"] = ""
				if not g.has("cover_path"):
					g["cover_path"] = ""
				if not g.has("desc"):
					g["desc"] = ""

func _set_status(msg: String) -> void:
	if status_bar:
		status_bar.text = msg

# ============================================================
# 音乐播放器
# ============================================================
func _refresh_music_list() -> void:
	var keyword: String = music_search.text.strip_edges().to_lower()
	music_filtered.clear()
	music_list.clear()
	for i in musics.size():
		var m: Dictionary = musics[i]
		var mname: String = str(m.get("name", ""))
		if keyword != "" and not mname.to_lower().contains(keyword):
			continue
		music_filtered.append(i)
		var fmt: String = str(m.get("format", "?")).to_upper()
		var idx: int = music_list.add_item("%s  |  %s" % [fmt, mname])
		music_list.set_item_tooltip(idx, str(m.get("path", "")))
		music_list.set_item_custom_fg_color(idx, _format_color(fmt))
	if music_current >= 0 and music_current < musics.size():
		var pos: int = music_filtered.find(music_current)
		if pos >= 0:
			music_list.select(pos)
			_update_music_detail()

func _format_color(fmt: String) -> Color:
	match fmt:
		"MP3":
			return Color("#66c0f4")
		"OGG":
			return Color("#a4d007")
		"WAV":
			return Color("#d4a017")
		_:
			return C_TEXT

func _on_music_search_changed(_t: String) -> void:
	_refresh_music_list()

func _on_import_music_pressed() -> void:
	music_file_dialog.popup_centered(Vector2i(800, 520))

func _on_music_file_selected(path: String) -> void:
	var ext: String = path.get_extension().to_lower()
	if not (ext in ["mp3", "ogg", "wav"]):
		_set_music_status("不支持的格式：" + ext)
		return
	for m in musics:
		if str(m.get("path", "")) == path:
			_set_music_status("已存在：" + path.get_file())
			return
	musics.append({
		"name": path.get_file(),
		"path": path,
		"format": ext
	})
	music_current = musics.size() - 1
	_save_musics()
	_refresh_music_list()
	_update_music_detail()
	_set_music_status("已导入：" + path.get_file())

func _on_music_selected(idx: int) -> void:
	if idx < 0 or idx >= music_filtered.size():
		return
	music_current = int(music_filtered[idx])
	if music_player.stream != null:
		music_player.stop()
		music_player.stream = null
		music_playing = false
	_update_music_detail()

func _on_music_activated(idx: int) -> void:
	_on_music_selected(idx)
	_start_play_current()

func _update_music_detail() -> void:
	if music_current < 0 or music_current >= musics.size():
		music_title.text = ""
		music_meta.text = ""
		music_cover_hint.visible = true
		music_cover_hint.text = "选择左侧音乐开始播放"
		music_time_label.text = "00:00 / 00:00"
		music_progress.max_value = 100.0
		music_progress.set_value(0.0)
		_update_music_buttons()
		return
	var m: Dictionary = musics[music_current]
	var path: String = str(m.get("path", ""))
	var fmt: String = str(m.get("format", "?")).to_upper()
	music_title.text = str(m.get("name", ""))
	music_cover_hint.visible = true
	music_cover_hint.text = fmt
	var size_str: String = _format_size(path)
	var total_sec: float = 0.0
	var stream: AudioStream = _load_music_stream(path)
	if stream != null:
		total_sec = stream.get_length()
	var dur_str: String = _fmt_time(total_sec)
	music_meta.text = "%s · %s · %s" % [fmt, dur_str, size_str]
	music_progress.max_value = maxf(total_sec, 0.01)
	music_progress.set_value(0.0)
	music_time_label.text = "00:00 / %s" % dur_str
	_update_music_buttons()

func _update_music_buttons() -> void:
	var has: bool = music_current >= 0 and music_current < musics.size()
	music_prev_btn.disabled = not has
	music_next_btn.disabled = not has
	music_play_btn.disabled = not has
	music_back_btn.disabled = not has
	music_fwd_btn.disabled = not has
	for item in music_speed_buttons:
		item["button"].disabled = not has
	if music_playing:
		music_play_btn.text = "⏸"
	else:
		music_play_btn.text = "▶"

func _load_music_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	var ext: String = path.get_extension().to_lower()
	match ext:
		"mp3":
			var s := AudioStreamMP3.new()
			var f := FileAccess.open(path, FileAccess.READ)
			if f == null:
				return null
			var data: PackedByteArray = f.get_buffer(f.get_length())
			f.close()
			s.data = data
			return s
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
	return null

func _on_music_play_pause() -> void:
	if music_current < 0:
		return
	if music_playing:
		_pause_playback()
	else:
		if music_player.stream == null:
			_start_play_current()
		else:
			_resume_playback()

func _start_play_current() -> void:
	if music_current < 0 or music_current >= musics.size():
		return
	music_pending_seek = -1.0
	var m: Dictionary = musics[music_current]
	var path: String = str(m.get("path", ""))
	var stream: AudioStream = _load_music_stream(path)
	if stream == null:
		_set_music_status("无法加载：" + path.get_file())
		return
	music_player.stream = stream
	music_player.pitch_scale = music_speed
	_apply_music_volume()
	music_player.play()
	music_playing = true
	_update_music_buttons()
	_set_music_status("播放中：" + path.get_file())

func _pause_playback() -> void:
	music_player.stream_paused = true
	music_playing = false
	_update_music_buttons()
	_set_music_status("已暂停")

func _resume_playback() -> void:
	music_player.stream_paused = false
	if music_pending_seek >= 0.0:
		music_player.seek(music_pending_seek)
		music_pending_seek = -1.0
	music_playing = true
	_update_music_buttons()
	_set_music_status("播放中")

func _on_music_finished() -> void:
	music_playing = false
	_update_music_buttons()
	_set_music_status("播放结束")

func _on_music_prev() -> void:
	if music_current <= 0:
		return
	music_current -= 1
	_refresh_music_list()
	_update_music_detail()
	if music_player.stream != null:
		_start_play_current()

func _on_music_next() -> void:
	if music_current < 0 or music_current >= musics.size() - 1:
		return
	music_current += 1
	_refresh_music_list()
	_update_music_detail()
	if music_player.stream != null:
		_start_play_current()

# ============================================================
# 进度条
# ============================================================
func _on_music_progress_changed(v: float) -> void:
	if not music_player.stream:
		return
	if not music_dragging:
		return
	var total: float = _music_get_total()
	music_time_label.text = "%s / %s" % [_fmt_time(v), _fmt_time(total)]

func _on_music_progress_drag_started() -> void:
	music_dragging = true

func _on_music_progress_drag_ended(_value_changed: bool) -> void:
	music_dragging = false
	if not music_player.stream:
		return
	var v: float = music_progress.value
	if music_player.stream_paused:
		music_pending_seek = v
		var total: float = _music_get_total()
		music_time_label.text = "%s / %s" % [_fmt_time(v), _fmt_time(total)]
	else:
		music_player.seek(v)
		var total: float = _music_get_total()
		music_time_label.text = "%s / %s" % [_fmt_time(v), _fmt_time(total)]

func _music_seek_relative(delta_sec: float) -> void:
	if music_player.stream == null:
		return
	var total: float = _music_get_total()
	if total <= 0.0:
		return
	var base: float
	if music_player.stream_paused and music_pending_seek >= 0.0:
		base = music_pending_seek
	elif music_player.stream_paused:
		base = music_player.get_playback_position() / music_speed
	else:
		base = music_player.get_playback_position() / music_speed
	var pos: float = base + delta_sec
	pos = clampf(pos, 0.0, total - 0.05)
	if music_player.stream_paused:
		music_pending_seek = pos
	else:
		music_player.seek(pos)
	music_progress.set_value(pos)
	music_time_label.text = "%s / %s" % [_fmt_time(pos), _fmt_time(total)]

func _music_get_total() -> float:
	if music_player.stream == null:
		return 0.0
	return music_player.stream.get_length()

func _on_music_speed_selected(speed: float) -> void:
	music_speed = speed
	for item in music_speed_buttons:
		item["button"].button_pressed = (item["speed"] == speed)
	if music_player.stream != null:
		music_player.pitch_scale = music_speed
	_set_music_status("速度：%s×" % _fmt_speed(speed))

# ============================================================
func _on_music_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var clicked_idx: int = music_list.get_item_at_position(mb.position)
			if clicked_idx >= 0:
				music_list.select(clicked_idx)
				_on_music_selected(clicked_idx)
				music_manage_menu.position = get_global_mouse_position()
				music_manage_menu.popup()
			else:
				music_blank_menu.position = get_global_mouse_position()
				music_blank_menu.popup()

func _on_music_manage_menu(id: int) -> void:
	if music_current < 0 or music_current >= musics.size():
		return
	var m: Dictionary = musics[music_current]
	var path: String = str(m.get("path", ""))
	match id:
		1:
			_open_music_prop_window()
		2:
			_open_in_explorer(path)
		3:
			music_player.stop()
			music_player.stream = null
			music_playing = false
			musics.remove_at(music_current)
			music_current = -1
			_save_musics()
			_refresh_music_list()
			_update_music_detail()

func _on_music_blank_menu(id: int) -> void:
	match id:
		0:
			_refresh_music_list()
			_set_music_status("已刷新")
		1:
			_on_import_music_pressed()

func _fmt_time(sec: float) -> String:
	if sec < 0.0:
		sec = 0.0
	var total: int = int(sec)
	var mm: int = total / 60
	var ss: int = total % 60
	return "%02d:%02d" % [mm, ss]

func _set_music_status(msg: String) -> void:
	if music_status:
		music_status.text = msg

func _open_music_prop_window() -> void:
	if music_current < 0 or music_current >= musics.size():
		return
	var m: Dictionary = musics[music_current]
	var path: String = str(m.get("path", ""))
	var fmt: String = str(m.get("format", "?")).to_upper()
	mprop_full_name.text = path.get_file()
	mprop_path_label.text = path
	mprop_size_label.text = _format_size(path)
	var stream: AudioStream = _load_music_stream(path)
	if stream != null:
		mprop_dur_label.text = _fmt_time(stream.get_length())
	else:
		mprop_dur_label.text = "未知"
	mprop_fmt_label.text = fmt
	mprop_name_edit.text = str(m.get("name", path.get_file()))
	mprop_desc_edit.text = str(m.get("desc", ""))
	music_prop_window.popup_centered()

func _on_music_prop_save() -> void:
	if music_current < 0 or music_current >= musics.size():
		music_prop_window.hide()
		return
	var new_name: String = mprop_name_edit.text.strip_edges()
	if new_name == "":
		new_name = str(musics[music_current].get("path", "")).get_file()
	musics[music_current]["name"] = new_name
	musics[music_current]["desc"] = mprop_desc_edit.text
	_save_musics()
	_refresh_music_list()
	_update_music_detail()
	music_prop_window.hide()
	_set_music_status("已保存")

func _save_musics() -> void:
	var f := FileAccess.open(MUSIC_SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(musics, "\t"))

func _load_musics() -> void:
	if not FileAccess.file_exists(MUSIC_SAVE_PATH):
		return
	var f := FileAccess.open(MUSIC_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		musics = parsed
		for m in musics:
			if m is Dictionary:
				if not m.has("format"):
					m["format"] = str(m.get("path", "")).get_extension().to_lower()
