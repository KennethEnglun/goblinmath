extends Control

## A ten-stage chapter page that can browse an effectively endless adventure.
const MAP_SIZE: Vector2 = Vector2(1080, 4608)
const SEGMENT_HEIGHT: float = 1536.0
const MAP_DRAG_THRESHOLD: float = 12.0
const STAGE_NODE_SCRIPT = preload("res://scripts/map/stage_node.gd")
const START_EFFECTS_PATH: String = "res://assets/ui/start/start_effects_v2.png"

const BACKGROUNDS: Dictionary = {
	"starlight_hill": "res://assets/ui/map/world1_starlight_hill_bg.png",
	"sakura_woods": "res://assets/ui/map/world1_sakura_woods_bg.png",
	"flower_meadow": "res://assets/ui/map/world1_flower_meadow_bg.png"
}
const FOREGROUNDS: Dictionary = {
	"starlight_hill": "res://assets/ui/map/world1_starlight_foreground.png",
	"sakura_woods": "res://assets/ui/map/world1_sakura_foreground.png",
	"flower_meadow": "res://assets/ui/map/world1_flower_foreground.png"
}

var current_chapter: int = 1
var scroll_container: ScrollContainer
var map_content: Control
var map_background_layer: Control
var zone_effects_layer: Control
var path_layer: Control
var decoration_back_layer: Control
var stage_node_layer: Control
var player_marker_layer: Control
var decoration_front_layer: Control
var fixed_hud_layer: Control
var stats_label: Label
var zone_label: Label
var chapter_label: Label
var previous_button: Button
var next_button: Button
var player_marker: TextureRect
var stage_nodes: Dictionary = {}
var world_stages: Array = []
var map_drag_active: bool = false
var map_dragged: bool = false
var map_drag_pointer_id: int = -1
var map_drag_last_position: Vector2 = Vector2.ZERO
var map_drag_start_position: Vector2 = Vector2.ZERO
var map_top_margin: float = 70.0
var map_bottom_margin: float = 42.0
var initial_focus_stage: int = 0
var world_name_label: Label

func _ready() -> void:
	initial_focus_stage = maxi(0, int(GameManager.map_focus_stage))
	if initial_focus_stage > 0:
		current_chapter = GameBalance.chapter_for_stage(initial_focus_stage)
		# Consume the focus once so a later map visit returns to normal progress
		# browsing instead of repeatedly snapping to an old boss milestone.
		GameManager.map_focus_stage = 0
	else:
		current_chapter = GameBalance.chapter_for_stage(int(GameManager.player_state.get("unlocked_stage", 1)))
	_build_screen()
	_load_chapter(current_chapter)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if scroll_container == null or not is_instance_valid(scroll_container):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			_begin_map_drag(mouse_event.position, 0)
		else:
			_end_map_drag()
		return
	if event is InputEventMouseMotion and map_drag_active:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		if motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_map_drag(motion_event.position)
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_map_drag(touch_event.position, touch_event.index)
		elif touch_event.index == map_drag_pointer_id:
			_end_map_drag()
		return
	if event is InputEventScreenDrag and map_drag_active:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if drag_event.index == map_drag_pointer_id:
			_update_map_drag(drag_event.position)

func _begin_map_drag(position: Vector2, pointer_id: int) -> void:
	if not scroll_container.get_global_rect().has_point(position):
		return
	map_drag_active = true
	map_dragged = false
	map_drag_pointer_id = pointer_id
	map_drag_start_position = position
	map_drag_last_position = position

func _update_map_drag(position: Vector2) -> void:
	if not map_drag_active:
		return
	if not map_dragged and position.distance_to(map_drag_start_position) >= MAP_DRAG_THRESHOLD:
		map_dragged = true
	if not map_dragged:
		map_drag_last_position = position
		return
	var delta_y: float = position.y - map_drag_last_position.y
	var max_scroll: float = maxf(0.0, map_content.size.y - scroll_container.size.y)
	scroll_container.scroll_vertical = int(clampf(float(scroll_container.scroll_vertical) - delta_y, 0.0, max_scroll))
	map_drag_last_position = position

func _end_map_drag() -> void:
	map_drag_active = false
	map_dragged = false
	map_drag_pointer_id = -1
	map_drag_last_position = Vector2.ZERO
	map_drag_start_position = Vector2.ZERO

func _build_screen() -> void:
	UITheme.add_gradient_background(self, Color("#f8cbd8"), Color("#fff0cf"))
	var safe_insets: Vector4 = UITheme.safe_area_insets(self)
	map_top_margin = maxf(70.0, safe_insets.y)
	map_bottom_margin = maxf(42.0, safe_insets.w)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "WorldMapScroll"
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_container.offset_top = map_top_margin + 200.0
	scroll_container.offset_bottom = -(map_bottom_margin + 288.0)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.follow_focus = true
	scroll_container.scroll_deadzone = 18
	add_child(scroll_container)

	map_content = Control.new()
	map_content.name = "MapContent"
	map_content.custom_minimum_size = MAP_SIZE
	map_content.size = MAP_SIZE
	map_content.clip_contents = true
	scroll_container.add_child(map_content)

	map_background_layer = _make_map_layer("MapBackgroundLayer")
	zone_effects_layer = _make_map_layer("ZoneEffectsLayer")
	path_layer = _make_map_layer("PathLayer")
	decoration_back_layer = _make_map_layer("DecorationBackLayer")
	stage_node_layer = _make_map_layer("StageNodeLayer")
	player_marker_layer = _make_map_layer("PlayerMarkerLayer")
	decoration_front_layer = _make_map_layer("DecorationFrontLayer")
	_build_fixed_hud()

	var scrollbar: VScrollBar = scroll_container.get_v_scroll_bar()
	scrollbar.value_changed.connect(_on_scroll_value_changed)

func _load_chapter(chapter: int) -> void:
	current_chapter = maxi(1, chapter)
	world_stages = DataManager.get_stages_for_chapter(current_chapter)
	if world_stages.is_empty():
		push_warning("Chapter %d could not be generated." % current_chapter)
		return
	for layer: Control in [map_background_layer, zone_effects_layer, path_layer, decoration_back_layer, stage_node_layer, player_marker_layer, decoration_front_layer]:
		_clear_layer(layer)
	stage_nodes.clear()
	player_marker = null
	_build_backgrounds()
	_build_zone_effects()
	_build_path()
	_build_decorations()
	_build_stage_nodes()
	_build_foregrounds()
	_build_player_marker()
	_refresh_progress()
	_refresh_chapter_navigation()
	call_deferred("_scroll_to_current_stage")

func _make_map_layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.position = Vector2.ZERO
	layer.size = MAP_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(layer)
	return layer

func _clear_layer(layer: Control) -> void:
	for child: Node in layer.get_children():
		layer.remove_child(child)
		child.queue_free()

func _build_backgrounds() -> void:
	_add_background_segment("starlight_hill", 0.0, Color("#e5d8f7"), Color("#ffd7e5"))
	_add_background_segment("sakura_woods", SEGMENT_HEIGHT, Color("#ffd7e5"), Color("#f7d9d6"))
	_add_background_segment("flower_meadow", SEGMENT_HEIGHT * 2.0, Color("#f7e1d5"), Color("#eef1bd"))

func _add_background_segment(zone: String, y_position: float, top_color: Color, bottom_color: Color) -> void:
	var segment: TextureRect = TextureRect.new()
	segment.name = "%sBackground" % _pascal_case(zone)
	segment.position = Vector2(0, y_position)
	segment.size = Vector2(MAP_SIZE.x, SEGMENT_HEIGHT)
	segment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	segment.stretch_mode = TextureRect.STRETCH_SCALE
	segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image_path: String = str(BACKGROUNDS.get(zone, ""))
	segment.texture = load(image_path) if not image_path.is_empty() and ResourceLoader.exists(image_path) else _make_gradient_texture(top_color, bottom_color)
	map_background_layer.add_child(segment)

func _make_gradient_texture(top_color: Color, bottom_color: Color) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([top_color, bottom_color])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = int(MAP_SIZE.x)
	texture.height = int(SEGMENT_HEIGHT)
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture

func _build_zone_effects() -> void:
	if ResourceLoader.exists(START_EFFECTS_PATH):
		var stars: TextureRect = TextureRect.new()
		stars.name = "SharedStarlightEffects"
		stars.texture = load(START_EFFECTS_PATH)
		stars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stars.stretch_mode = TextureRect.STRETCH_SCALE
		stars.position = Vector2.ZERO
		stars.size = Vector2(MAP_SIZE.x, SEGMENT_HEIGHT)
		stars.modulate.a = 0.26
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone_effects_layer.add_child(stars)
		var shimmer: Tween = create_tween().set_loops()
		shimmer.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		shimmer.tween_property(stars, "modulate:a", 0.42, 1.6)
		shimmer.tween_property(stars, "modulate:a", 0.26, 1.6)

	for index: int in range(12):
		var petal: Label = UITheme.make_label("•", 34 + (index % 3) * 5, Color(1.0, 0.72, 0.8, 0.55))
		petal.name = "SakuraPetal%d" % index
		petal.position = Vector2(90 + ((index * 173) % 880), SEGMENT_HEIGHT + 120 + ((index * 257) % 1250))
		petal.size = Vector2(42, 42)
		petal.rotation = deg_to_rad(float((index * 29) % 70) - 35.0)
		petal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone_effects_layer.add_child(petal)

func _build_path() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for stage: Dictionary in world_stages:
		points.append(_stage_position(stage))
	var outline: Line2D = Line2D.new()
	outline.name = "PathOutline"
	outline.points = points
	outline.width = 76.0
	outline.default_color = Color("#bd817c")
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	path_layer.add_child(outline)
	var path: Line2D = Line2D.new()
	path.name = "AdventurePath"
	path.points = points
	path.width = 58.0
	path.default_color = Color("#ffe4d4")
	path.joint_mode = Line2D.LINE_JOINT_ROUND
	path.begin_cap_mode = Line2D.LINE_CAP_ROUND
	path.end_cap_mode = Line2D.LINE_CAP_ROUND
	path_layer.add_child(path)

func _build_decorations() -> void:
	_add_zone_banner("星光丘・第%d章" % current_chapter, Vector2(300, 56), Color("#f6e7ff"), Color("#ad83bc"))
	_add_zone_banner("櫻林・第%d章" % current_chapter, Vector2(300, 1558), Color("#ffe5ec"), Color("#d88ea5"))
	_add_zone_banner("花野・第%d章" % current_chapter, Vector2(300, 3092), Color("#fff0cf"), Color("#c9a666"))
	_add_soft_shape(decoration_back_layer, Vector2(-130, 1150), Vector2(480, 250), Color("#d7c7ef"), 170)
	_add_soft_shape(decoration_back_layer, Vector2(760, 920), Vector2(430, 280), Color("#ebd5f2"), 170)
	_add_soft_shape(decoration_back_layer, Vector2(-120, 2410), Vector2(460, 310), Color("#f2bccc"), 180)
	_add_soft_shape(decoration_back_layer, Vector2(790, 1920), Vector2(410, 320), Color("#f6c8d7"), 180)
	_add_soft_shape(decoration_back_layer, Vector2(-120, 4060), Vector2(440, 340), Color("#bfdca8"), 190)
	_add_soft_shape(decoration_back_layer, Vector2(800, 3500), Vector2(410, 360), Color("#c9e2ad"), 190)

func _add_zone_banner(text_value: String, at: Vector2, fill: Color, border: Color) -> void:
	var banner: Panel = UITheme.make_panel(fill, border, 34, 4)
	banner.name = "ZoneBanner%d" % banner.get_instance_id()
	banner.position = at
	banner.size = Vector2(480, 94)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decoration_back_layer.add_child(banner)
	var label: Label = UITheme.make_label(text_value, 36, UITheme.INK)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(label)

func _build_stage_nodes() -> void:
	var highest_unlocked_on_page: int = _highest_unlocked_stage_on_page()
	for stage: Dictionary in world_stages:
		var stage_id: int = int(stage.get("id", 0))
		var status: StringName = &"locked"
		if GameManager.is_stage_completed(stage_id):
			status = &"completed"
		elif GameManager.is_stage_unlocked(stage_id):
			status = &"current" if stage_id == highest_unlocked_on_page else &"unlocked"
		var node = STAGE_NODE_SCRIPT.new()
		node.configure(stage, status)
		node.position = _stage_position(stage) - Vector2(120, 120)
		node.stage_selected.connect(_on_stage_selected)
		stage_node_layer.add_child(node)
		stage_nodes[stage_id] = node

func _build_foregrounds() -> void:
	_add_foreground_segment("starlight_hill", 0.0)
	_add_foreground_segment("sakura_woods", SEGMENT_HEIGHT)
	_add_foreground_segment("flower_meadow", SEGMENT_HEIGHT * 2.0)
	if not _has_any_generated_foreground():
		_add_soft_shape(decoration_front_layer, Vector2(-160, 1380), Vector2(420, 190), Color(0.72, 0.57, 0.82, 0.62), 150)
		_add_soft_shape(decoration_front_layer, Vector2(820, 2860), Vector2(390, 220), Color(0.91, 0.58, 0.68, 0.6), 160)
		_add_soft_shape(decoration_front_layer, Vector2(-140, 4410), Vector2(410, 230), Color(0.55, 0.75, 0.55, 0.62), 170)

func _add_foreground_segment(zone: String, y_position: float) -> void:
	var image_path: String = str(FOREGROUNDS.get(zone, ""))
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		return
	var foreground: TextureRect = TextureRect.new()
	foreground.name = "%sForeground" % _pascal_case(zone)
	foreground.texture = load(image_path)
	foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foreground.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foreground.position = Vector2(0, y_position)
	foreground.size = Vector2(MAP_SIZE.x, SEGMENT_HEIGHT)
	foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decoration_front_layer.add_child(foreground)

func _has_any_generated_foreground() -> bool:
	for path_value: Variant in FOREGROUNDS.values():
		if ResourceLoader.exists(str(path_value)):
			return true
	return false

func _build_player_marker() -> void:
	var marker_stage: Dictionary = DataManager.get_stage(_highest_unlocked_stage_on_page())
	var character_sprite_path: String = GameManager.get_character_sprite_path()
	if marker_stage.is_empty() or not ResourceLoader.exists(character_sprite_path):
		return
	player_marker = TextureRect.new()
	player_marker.name = "CurrentGoblinMarker"
	player_marker.texture = load(character_sprite_path)
	player_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_marker.size = Vector2(176, 176)
	player_marker.position = _stage_position(marker_stage) + Vector2(-88, -255)
	player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_marker_layer.add_child(player_marker)
	call_deferred("_start_marker_animation")

func _build_fixed_hud() -> void:
	fixed_hud_layer = Control.new()
	fixed_hud_layer.name = "FixedHudLayer"
	fixed_hud_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Only concrete buttons consume input; this transparent parent must not block map nodes.
	fixed_hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.set_layer_order(fixed_hud_layer, 100)
	add_child(fixed_hud_layer)

	var header: Panel = UITheme.make_panel(Color(1, 0.96, 0.93, 0.96), Color("#dc8f9e"), 42, 5)
	header.name = "MapHeader"
	header.anchor_right = 1.0
	header.offset_left = 42.0
	header.offset_top = map_top_margin
	header.offset_right = -42.0
	header.offset_bottom = map_top_margin + 180.0
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_hud_layer.add_child(header)

	var title: Label = UITheme.make_label("冒險地圖", 44, UITheme.INK)
	title.name = "MapTitle"
	title.position = Vector2(28, 4)
	title.size = Vector2(470, 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	world_name_label = UITheme.make_label(_world_name_for_chapter(current_chapter), 22, UITheme.MUTED_INK)
	world_name_label.name = "WorldNameLabel"
	world_name_label.position = Vector2(28, 72)
	world_name_label.size = Vector2(470, 35)
	world_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	world_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(world_name_label)
	chapter_label = UITheme.make_label("第1章", 30, Color("#b36d72"))
	chapter_label.name = "ChapterLabel"
	chapter_label.position = Vector2(650, 8)
	chapter_label.size = Vector2(300, 58)
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(chapter_label)
	zone_label = UITheme.make_label("花野", 23, UITheme.MUTED_INK)
	zone_label.name = "CurrentZoneLabel"
	zone_label.position = Vector2(690, 60)
	zone_label.size = Vector2(260, 45)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(zone_label)
	stats_label = UITheme.make_label("", 25, UITheme.MUTED_INK)
	stats_label.name = "PlayerStats"
	stats_label.position = Vector2(20, 110)
	stats_label.size = Vector2(950, 60)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(stats_label)

	var bottom_hud: Panel = UITheme.make_panel(Color(1, 0.96, 0.93, 0.97), Color("#dc8f9e"), 36, 5)
	bottom_hud.name = "BottomHud"
	bottom_hud.anchor_left = 0.04
	bottom_hud.anchor_right = 0.96
	bottom_hud.anchor_top = 1.0
	bottom_hud.anchor_bottom = 1.0
	bottom_hud.offset_top = -(map_bottom_margin + 288.0)
	bottom_hud.offset_bottom = -map_bottom_margin
	bottom_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed_hud_layer.add_child(bottom_hud)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hud.add_child(margin)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(rows)

	var page_row: HBoxContainer = HBoxContainer.new()
	page_row.add_theme_constant_override("separation", 12)
	page_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(page_row)
	previous_button = UITheme.make_button("‹", "上一章", Color("#d9edf0"), Vector2(220, 92))
	previous_button.name = "PreviousChapterButton"
	previous_button.pressed.connect(_on_previous_chapter_pressed)
	page_row.add_child(previous_button)
	var page_spacer: Control = Control.new()
	page_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_row.add_child(page_spacer)
	next_button = UITheme.make_button("›", "下一章", Color("#d9edf0"), Vector2(220, 92))
	next_button.name = "NextChapterButton"
	next_button.pressed.connect(_on_next_chapter_pressed)
	page_row.add_child(next_button)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(action_row)
	var home_button: Button = UITheme.make_button("首頁", "回到開始", Color("#ffe19a"), Vector2(0, 112))
	home_button.name = "HomeButton"
	home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_button.pressed.connect(_on_home_pressed)
	action_row.add_child(home_button)
	var character_button: Button = UITheme.make_button("角色", "裝備與升級", Color("#bfe7d3"), Vector2(0, 112))
	character_button.name = "CharacterButton"
	character_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_button.pressed.connect(_on_character_pressed)
	action_row.add_child(character_button)
	var gacha_button: Button = UITheme.make_button("GACHA", "轉蛋", Color("#e5d7ff"), Vector2(0, 112))
	gacha_button.name = "GachaButton"
	gacha_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gacha_button.pressed.connect(_on_gacha_pressed)
	action_row.add_child(gacha_button)

func _refresh_progress() -> void:
	if stats_label != null:
		var completed_count: int = 0
		var chapter_stars: int = 0
		for stage: Dictionary in world_stages:
			var stage_id: int = int(stage.get("id", 0))
			if GameManager.is_stage_completed(stage_id):
				completed_count += 1
				chapter_stars += GameManager.get_stage_stars(stage_id)
		stats_label.text = "LV.%d   HP %d   ATK %d   DEF %d   💎 %d   金幣 %d   進度 %d/%d   ★ %d" % [GameManager.get_level(), GameManager.get_max_hp(), GameManager.get_attack(), GameManager.get_defense(), GameManager.get_gems(), GameManager.get_coins(), completed_count, world_stages.size(), chapter_stars]
	if chapter_label != null:
		chapter_label.text = "第%d章" % current_chapter
	if world_name_label != null:
		world_name_label.text = _world_name_for_chapter(current_chapter)

func _refresh_chapter_navigation() -> void:
	if previous_button != null:
		previous_button.disabled = current_chapter <= 1
	if next_button != null:
		var next_first_stage: int = GameBalance.first_stage_for_chapter(current_chapter + 1)
		next_button.disabled = next_first_stage > int(GameManager.player_state.get("unlocked_stage", 1))

func _on_stage_selected(stage_id: int) -> void:
	if not GameManager.is_stage_unlocked(stage_id):
		return
	AudioManager.play_sfx("button_click")
	GameManager.start_stage(stage_id)

func _on_home_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_main_menu()

func _on_character_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_character()

func _on_gacha_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_gacha()

func _on_previous_chapter_pressed() -> void:
	if current_chapter <= 1:
		return
	AudioManager.play_sfx("button_click")
	_load_chapter(current_chapter - 1)

func _on_next_chapter_pressed() -> void:
	var next_first_stage: int = GameBalance.first_stage_for_chapter(current_chapter + 1)
	if next_first_stage > int(GameManager.player_state.get("unlocked_stage", 1)):
		return
	AudioManager.play_sfx("button_click")
	_load_chapter(current_chapter + 1)

func _scroll_to_current_stage() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var target_stage_id: int = _highest_unlocked_stage_on_page()
	if initial_focus_stage > 0:
		for stage: Dictionary in world_stages:
			if int(stage.get("id", 0)) == initial_focus_stage:
				target_stage_id = initial_focus_stage
				break
	var current_stage: Dictionary = DataManager.get_stage(target_stage_id)
	initial_focus_stage = 0
	if current_stage.is_empty() or scroll_container == null:
		return
	var target: float = _stage_position(current_stage).y - (scroll_container.size.y * 0.5)
	var max_scroll: float = maxf(0.0, MAP_SIZE.y - scroll_container.size.y)
	scroll_container.scroll_vertical = int(clampf(target, 0.0, max_scroll))
	_update_zone_label(float(scroll_container.scroll_vertical) + scroll_container.size.y * 0.5)

func _on_scroll_value_changed(value: float) -> void:
	if scroll_container != null:
		_update_zone_label(value + scroll_container.size.y * 0.5)

func _update_zone_label(map_y: float) -> void:
	if zone_label == null:
		return
	if map_y < SEGMENT_HEIGHT:
		zone_label.text = "星光丘"
	elif map_y < SEGMENT_HEIGHT * 2.0:
		zone_label.text = "櫻林"
	else:
		zone_label.text = "花野"

func _world_name_for_chapter(chapter: int) -> String:
	return "花漾原野" if chapter <= 1 else "花漾原野・第%d章" % chapter

func _highest_unlocked_stage_on_page() -> int:
	var requested: int = int(GameManager.player_state.get("unlocked_stage", GameBalance.STARTING_STAGE))
	for index: int in range(world_stages.size() - 1, -1, -1):
		var stage_id: int = int(world_stages[index].get("id", GameBalance.STARTING_STAGE))
		if stage_id <= requested:
			return stage_id
	return int(world_stages.front().get("id", GameBalance.STARTING_STAGE))

func _stage_position(stage: Dictionary) -> Vector2:
	var raw_position: Variant = stage.get("map_position", [MAP_SIZE.x * 0.5, MAP_SIZE.y * 0.5])
	if raw_position is Array and raw_position.size() >= 2:
		return Vector2(float(raw_position[0]), float(raw_position[1]))
	return MAP_SIZE * 0.5

func _start_marker_animation() -> void:
	if player_marker == null or not is_instance_valid(player_marker):
		return
	player_marker.pivot_offset = player_marker.size * 0.5
	var origin_y: float = player_marker.position.y
	var marker_tween: Tween = create_tween().set_loops()
	marker_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	marker_tween.set_parallel(true)
	marker_tween.tween_property(player_marker, "position:y", origin_y - 10.0, 1.1)
	marker_tween.tween_property(player_marker, "scale", Vector2(1.025, 1.025), 1.1)
	marker_tween.chain().set_parallel(true)
	marker_tween.tween_property(player_marker, "position:y", origin_y, 1.1)
	marker_tween.tween_property(player_marker, "scale", Vector2.ONE, 1.1)

func _add_soft_shape(parent: Control, at: Vector2, shape_size: Vector2, color: Color, radius: int) -> void:
	var shape: Panel = Panel.new()
	shape.position = at
	shape.size = shape_size
	shape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape.add_theme_stylebox_override("panel", UITheme.rounded_style(color, Color.TRANSPARENT, radius, 0))
	parent.add_child(shape)

func _pascal_case(value: String) -> String:
	var result: String = ""
	for part: String in value.split("_"):
		result += part.capitalize()
	return result.replace(" ", "")
