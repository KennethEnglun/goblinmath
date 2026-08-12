extends Control

## Layered three-tab character, equipment, and inventory screen.
const TAB_PROFILE: String = "profile"
const TAB_EQUIPMENT: String = "equipment"
const TAB_BAG: String = "bag"
const TAB_IDS: Array[String] = [TAB_PROFILE, TAB_EQUIPMENT, TAB_BAG]
const INVENTORY_SORT_MODES: Array[String] = ["rarity", "slot", "level"]
const SCROLL_DRAG_THRESHOLD: float = 12.0
const BAG_HEADER_HEIGHT: float = 128.0
const BAG_CARD_HEIGHT: float = 448.0
const BAG_CARD_MARGIN: int = 24
const BAG_ITEM_ICON_SIZE: Vector2 = Vector2(252, 252)
const BAG_ICON_OFFSET: int = 32
const BAG_ICON_COLUMN_WIDTH: float = 252.0 + BAG_ICON_OFFSET
const BAG_ACTION_COLUMN_WIDTH: float = 220.0
const BAG_ACTION_BUTTON_SIZE: Vector2 = Vector2(220, 100)
const BAG_ACTION_GAP: int = 8
const BAG_ACTION_STACK_HEIGHT: float = 316.0

const BACKGROUND_PATH: String = "res://assets/ui/character/character_upgrade_bg_v1.png"
const AMBIENT_PATH: String = "res://assets/ui/start/start_effects_v2.png"
const PLAYER_PATH: String = "res://assets/ui/start/goblin_start_v2.png"
const PLAYER_FALLBACK_PATH: String = "res://assets/characters/goblin_placeholder.svg"
const PANEL_SKIN_PATH: String = "res://assets/ui/character/character_panel_skin_v1.png"
const TAB_SKIN_PATH: String = "res://assets/ui/character/character_tab_skin_v1.png"
const ACTION_BUTTON_SKIN_PATH: String = "res://assets/ui/character/character_action_button_skin_v1.png"
const SLOT_FRAME_PATH: String = "res://assets/ui/character/character_slot_frame_v1.png"
const SLOT_EMPTY_PATH: String = "res://assets/ui/character/character_slot_empty_v1.png"
const COIN_BADGE_PATH: String = "res://assets/ui/character/character_coin_badge_v1.png"
const DIAMOND_ICON_PATH: String = "res://assets/ui/gacha/gacha_diamond_icon_v1.png"

const SLOT_ORDER: Array[String] = ["weapon", "head", "body"]
const SLOT_NAMES: Dictionary = {
	"weapon": {"primary": "WEAPON", "secondary": "武器"},
	"head": {"primary": "HEAD", "secondary": "頭部"},
	"body": {"primary": "BODY", "secondary": "身體"}
}
const SLOT_ICON_PATHS: Dictionary = {
	"weapon": "res://assets/equipment/icons/equipment_weapon_v1.png",
	"head": "res://assets/equipment/icons/equipment_head_v1.png",
	"body": "res://assets/equipment/icons/equipment_body_v1.png"
}

var active_tab: String = TAB_PROFILE
var pending_sell_uid: String = ""
var inventory_sort_mode: String = "rarity"
var character_top_offset: float = 0.0
var scroll_drag_active: bool = false
var scroll_dragged: bool = false
var scroll_drag_pointer_id: int = -1
var scroll_drag_start_position: Vector2 = Vector2.ZERO
var scroll_drag_last_position: Vector2 = Vector2.ZERO
var scroll_drag_scroll: ScrollContainer

var character_background_layer: TextureRect
var character_ambient_layer: TextureRect
var character_goblin_layer: Control
var character_panel_layer: Control
var character_hud_layer: Control
var character_tab_layer: Control
var character_toast_layer: Control
var character_action_layer: Control
var character_equipment_layer: Control

var profile_portrait: TextureRect
var equipment_portrait: TextureRect
var profile_scroll: ScrollContainer
var equipment_scroll: ScrollContainer
var bag_scroll: ScrollContainer
var profile_content: Control
var equipment_content: Control
var bag_content: Control
var equipment_row: HBoxContainer
var inventory_list: VBoxContainer
var tab_buttons: Dictionary = {}
var stat_buttons: Dictionary = {}

var level_label: Label
var exp_label: Label
var stats_label: Label
var points_label: Label
var coin_label: Label
var inventory_count_label: Label
var inventory_sort_button: Button
var equipment_bonus_label: Label
var message_label: Label

func _ready() -> void:
	set_process_input(true)
	_build_screen()
	_refresh_all()

func _input(event: InputEvent) -> void:
	var active_scroll: ScrollContainer = _get_active_scroll()
	if active_scroll == null or not is_instance_valid(active_scroll):
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_begin_scroll_drag(mouse_event.position, 0, active_scroll)
		elif scroll_drag_active and scroll_drag_pointer_id == 0:
			_end_scroll_drag()
		return
	if event is InputEventMouseMotion and scroll_drag_active and scroll_drag_pointer_id == 0:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_scroll_drag(mouse_motion.position)
		return
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_begin_scroll_drag(touch_event.position, touch_event.index, active_scroll)
		elif scroll_drag_active and scroll_drag_pointer_id == touch_event.index:
			_end_scroll_drag()
		return
	if event is InputEventScreenDrag and scroll_drag_active:
		var screen_drag: InputEventScreenDrag = event as InputEventScreenDrag
		if screen_drag.index == scroll_drag_pointer_id:
			_update_scroll_drag(screen_drag.position)

func _build_screen() -> void:
	_build_visual_layers()
	_build_hud()
	_build_tabs()
	_build_tab_contents()
	set_active_tab(TAB_PROFILE)

func _build_visual_layers() -> void:
	var safe_insets: Vector4 = UITheme.safe_area_insets(self)
	character_top_offset = maxf(0.0, safe_insets.y - 86.0)
	character_background_layer = TextureRect.new()
	character_background_layer.name = "CharacterBackgroundLayer"
	character_background_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_background_layer.stretch_mode = TextureRect.STRETCH_SCALE
	character_background_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_background_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKGROUND_PATH):
		character_background_layer.texture = load(BACKGROUND_PATH)
	add_child(character_background_layer)
	move_child(character_background_layer, 0)
	if character_background_layer.texture == null:
		var fallback_background: TextureRect = UITheme.add_gradient_background(self, Color("#f7ccdc"), Color("#fff1cf"))
		fallback_background.name = "CharacterBackgroundFallback"

	character_ambient_layer = TextureRect.new()
	character_ambient_layer.name = "CharacterAmbientLayer"
	character_ambient_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_ambient_layer.stretch_mode = TextureRect.STRETCH_SCALE
	character_ambient_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_ambient_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(AMBIENT_PATH):
		character_ambient_layer.texture = load(AMBIENT_PATH)
	character_ambient_layer.modulate = Color(1.0, 1.0, 1.0, 0.38)
	add_child(character_ambient_layer)

	character_goblin_layer = _make_layer("CharacterGoblinLayer", Control.MOUSE_FILTER_IGNORE)
	profile_portrait = _make_sprite(_get_player_sprite_path(), Vector2(350, 350))
	profile_portrait.name = "ProfileGoblinPortrait"
	profile_portrait.position = Vector2(365, 355 + character_top_offset)
	character_goblin_layer.add_child(profile_portrait)
	equipment_portrait = _make_sprite(_get_player_sprite_path(), Vector2(210, 210))
	equipment_portrait.name = "EquipmentGoblinPortrait"
	equipment_portrait.position = Vector2(435, 355 + character_top_offset)
	character_goblin_layer.add_child(equipment_portrait)

	# These layers are full-screen layout canvases. They must not swallow taps
	# meant for a scroll view or action button below them; their child Buttons
	# still receive input through the ignore parent.
	character_panel_layer = _make_layer("CharacterPanelLayer", Control.MOUSE_FILTER_IGNORE)
	character_hud_layer = _make_layer("CharacterHudLayer", Control.MOUSE_FILTER_IGNORE)
	character_tab_layer = _make_layer("CharacterTabLayer", Control.MOUSE_FILTER_IGNORE)
	character_toast_layer = _make_layer("CharacterToastLayer", Control.MOUSE_FILTER_IGNORE)
	UITheme.set_layer_order(character_goblin_layer, 5)
	UITheme.set_layer_order(character_panel_layer, 10)
	UITheme.set_layer_order(character_hud_layer, 30)
	UITheme.set_layer_order(character_tab_layer, 40)
	UITheme.set_layer_order(character_toast_layer, 50)

func _build_hud() -> void:
	var header: Control = Control.new()
	header.name = "CharacterHeader"
	header.position = Vector2(46, 86 + character_top_offset)
	header.size = Vector2(988, 124)
	character_hud_layer.add_child(header)

	var back_button: Button = _make_small_button("MAP\n地圖", Color("#d9edf0"), Vector2(202, 124))
	back_button.name = "BackToMapButton"
	back_button.position = Vector2(0, 0)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var title: VBoxContainer = UITheme.make_dual_label("CHARACTER", "角色", 39, 19, UITheme.INK)
	title.position = Vector2(222, 0)
	title.size = Vector2(300, 104)
	header.add_child(title)
	var gacha_button: Button = _make_small_button("GACHA\n轉蛋", Color("#e5d7ff"), Vector2(160, 124))
	gacha_button.name = "GachaButton"
	gacha_button.position = Vector2(535, 0)
	gacha_button.pressed.connect(_on_gacha_pressed)
	header.add_child(gacha_button)

	var coin_badge: Panel = UITheme.make_panel(Color("#fff4c9"), Color("#d9a85c"), 28, 4)
	coin_badge.name = "CoinBadge"
	coin_badge.position = Vector2(710, 8)
	coin_badge.size = Vector2(278, 104)
	var clear_badge_style: StyleBoxFlat = StyleBoxFlat.new()
	clear_badge_style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	clear_badge_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	clear_badge_style.shadow_color = Color(1.0, 1.0, 1.0, 0.0)
	clear_badge_style.shadow_size = 0
	coin_badge.add_theme_stylebox_override("panel", clear_badge_style)
	var badge_background: TextureRect = TextureRect.new()
	badge_background.name = "CurrencyBadgeBackground"
	badge_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge_background.stretch_mode = TextureRect.STRETCH_SCALE
	var badge_atlas: AtlasTexture = AtlasTexture.new()
	badge_atlas.atlas = load(COIN_BADGE_PATH) as Texture2D
	badge_atlas.region = Rect2(0, 150, 1693, 630)
	badge_background.texture = badge_atlas
	badge_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_background.z_index = 0
	coin_badge.add_child(badge_background)
	var diamond_icon: TextureRect = _make_sprite(DIAMOND_ICON_PATH, Vector2(38, 38))
	diamond_icon.name = "DiamondCurrencyIcon"
	diamond_icon.position = Vector2(82, 10)
	diamond_icon.z_index = 2
	coin_badge.add_child(diamond_icon)
	coin_label = UITheme.make_label("", 20, Color("#a87531"))
	coin_label.position = Vector2(122, 8)
	coin_label.size = Vector2(144, 88)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_label.z_index = 2
	coin_badge.add_child(coin_label)
	header.add_child(coin_badge)

func _build_tabs() -> void:
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.name = "CharacterTabBar"
	tab_bar.position = Vector2(46, 210 + character_top_offset)
	tab_bar.size = Vector2(988, 132)
	tab_bar.add_theme_constant_override("separation", 12)
	character_tab_layer.add_child(tab_bar)
	var tab_specs: Array = [
		[TAB_PROFILE, "PROFILE\n角色", Color("#f6b6c8")],
		[TAB_EQUIPMENT, "EQUIPMENT\n裝備", Color("#bfe7d3")],
		[TAB_BAG, "BAG\n背包", Color("#ffe19a")]
	]
	for spec: Array in tab_specs:
		var tab_id: String = str(spec[0])
		var button: Button = _make_small_button(str(spec[1]), spec[2], Vector2(0, 132), TAB_SKIN_PATH)
		button.name = "%sTabButton" % tab_id.capitalize()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_active_tab.bind(tab_id))
		tab_bar.add_child(button)
		tab_buttons[tab_id] = button

func _build_tab_contents() -> void:
	var content_area: Control = Control.new()
	content_area.name = "CharacterContentArea"
	content_area.position = Vector2(46, 360 + character_top_offset)
	content_area.size = Vector2(988, maxf(900.0, 1450.0 - character_top_offset))
	character_panel_layer.add_child(content_area)

	profile_scroll = _make_scroll("ProfileScroll", content_area)
	equipment_scroll = _make_scroll("EquipmentScroll", content_area)
	bag_scroll = _make_scroll("BagScroll", content_area)

	profile_content = _make_stack("ProfileContent")
	profile_scroll.add_child(profile_content)
	profile_content.add_child(UITheme.make_spacer(350))
	profile_content.add_child(_make_profile_summary())
	character_action_layer = _make_profile_actions()
	profile_content.add_child(character_action_layer)

	equipment_content = _make_stack("EquipmentContent")
	equipment_scroll.add_child(equipment_content)
	equipment_content.add_child(UITheme.make_spacer(205))
	character_equipment_layer = VBoxContainer.new()
	character_equipment_layer.name = "CharacterEquipmentLayer"
	character_equipment_layer.add_theme_constant_override("separation", 12)
	equipment_content.add_child(character_equipment_layer)
	character_equipment_layer.add_child(UITheme.make_label("EQUIPPED GEAR\n目前裝備", 29, UITheme.INK))
	equipment_row = HBoxContainer.new()
	equipment_row.name = "EquipmentSlotRow"
	equipment_row.add_theme_constant_override("separation", 10)
	character_equipment_layer.add_child(equipment_row)
	var bag_button: Button = _make_small_button("BAG\n前往背包", Color("#ffe19a"), Vector2(0, 128))
	bag_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_button.pressed.connect(set_active_tab.bind(TAB_BAG))
	character_equipment_layer.add_child(bag_button)
	equipment_content.add_child(_make_equipment_summary_panel())

	bag_content = _make_stack("BagContent")
	bag_scroll.add_child(bag_content)
	var bag_header: Panel = UITheme.make_panel(Color(1.0, 0.98, 0.94, 0.82), Color("#f0c99d"), 26, 1)
	bag_header.name = "BagHeader"
	bag_header.custom_minimum_size = Vector2(988, BAG_HEADER_HEIGHT)
	bag_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_content.add_child(bag_header)
	var bag_header_row: Control = Control.new()
	bag_header_row.name = "BagHeaderRow"
	bag_header_row.position = Vector2(16, 16)
	bag_header_row.size = Vector2(956, BAG_HEADER_HEIGHT - 32)
	bag_header.add_child(bag_header_row)
	var capacity_panel: Panel = UITheme.make_panel(Color(1.0, 1.0, 1.0, 0.30), Color(1.0, 1.0, 1.0, 0.0), 18, 0)
	capacity_panel.name = "BagCapacityPanel"
	capacity_panel.position = Vector2.ZERO
	capacity_panel.size = Vector2(300, 96)
	capacity_panel.custom_minimum_size = Vector2(300, 96)
	inventory_count_label = UITheme.make_label("", 27, UITheme.INK)
	inventory_count_label.position = Vector2(14, 14)
	inventory_count_label.size = Vector2(272, 68)
	inventory_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inventory_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capacity_panel.add_child(inventory_count_label)
	bag_header_row.add_child(capacity_panel)
	var header_tools: Control = Control.new()
	header_tools.name = "BagHeaderTools"
	header_tools.position = Vector2(312, 0)
	header_tools.size = Vector2(644, 96)
	bag_header_row.add_child(header_tools)
	var items_label: Label = UITheme.make_label("ITEMS\n裝備清單", 21, UITheme.MUTED_INK)
	items_label.name = "BagItemsLabel"
	items_label.position = Vector2(272, 0)
	items_label.size = Vector2(170, 96)
	items_label.custom_minimum_size = Vector2(170, 96)
	items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	items_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_tools.add_child(items_label)
	inventory_sort_button = _make_small_button("SORT\n整理", Color("#d9edf0"), Vector2(190, 96))
	inventory_sort_button.name = "InventorySortButton"
	inventory_sort_button.position = Vector2(454, 0)
	inventory_sort_button.size = Vector2(190, 96)
	inventory_sort_button.pressed.connect(_on_sort_inventory_pressed)
	header_tools.add_child(inventory_sort_button)
	inventory_list = VBoxContainer.new()
	inventory_list.name = "InventoryList"
	inventory_list.custom_minimum_size = Vector2(988, 0)
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("separation", 12)
	bag_content.add_child(inventory_list)

	message_label = UITheme.make_label("", 22, UITheme.MUTED_INK)
	message_label.name = "CharacterMessageLabel"
	message_label.position = Vector2(46, minf(1800.0 + character_top_offset, 1920.0 - 64.0 - 64.0))
	message_label.size = Vector2(988, 64)
	character_toast_layer.add_child(message_label)

func _make_profile_summary() -> Panel:
	var summary: Panel = UITheme.make_panel(Color(1, 0.97, 0.92, 0.96), Color("#dd9ba7"), 34, 5)
	summary.name = "ProfileSummaryPanel"
	summary.custom_minimum_size = Vector2(0, 430)
	UITheme.apply_texture_panel_skin(summary, PANEL_SKIN_PATH, 34)
	var margin: MarginContainer = _panel_margin(summary, 24)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	level_label = UITheme.make_label("", 38, UITheme.INK)
	level_label.name = "ProfileLevelLabel"
	exp_label = UITheme.make_label("", 24, UITheme.MUTED_INK)
	exp_label.name = "ProfileExpLabel"
	stats_label = UITheme.make_label("", 21, UITheme.MUTED_INK)
	stats_label.name = "ProfileStatsLabel"
	stats_label.custom_minimum_size = Vector2(0, 250)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [level_label, exp_label, stats_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(label)
	return summary

func _make_profile_actions() -> Control:
	var layer: Control = Control.new()
	layer.name = "CharacterActionLayer"
	layer.custom_minimum_size = Vector2(0, 540)
	var growth: Panel = UITheme.make_panel(Color("#fff8e8"), Color("#efc979"), 30, 4)
	growth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UITheme.apply_texture_panel_skin(growth, PANEL_SKIN_PATH, 30)
	layer.add_child(growth)
	var margin: MarginContainer = _panel_margin(growth, 20)
	margin.add_theme_constant_override("margin_top", 86)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	points_label = UITheme.make_label("", 28, UITheme.INK)
	points_label.name = "StatPointsLabel"
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.custom_minimum_size = Vector2(0, 76)
	stack.add_child(points_label)
	var grid: GridContainer = GridContainer.new()
	grid.name = "StatButtonGrid"
	grid.columns = 2
	grid.custom_minimum_size = Vector2(800, 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	stack.add_child(grid)
	_add_stat_button(grid, "ATK +1\n攻擊 +1", "attack")
	_add_stat_button(grid, "MAX HP +3\n生命 +3", "max_hp")
	_add_stat_button(grid, "DEF +1\n防禦 +1", "defense")
	_add_stat_button(grid, "LUCK +1\n幸運 +1", "luck")
	return layer

func _make_equipment_summary_panel() -> Panel:
	var panel: Panel = UITheme.make_panel(Color("#f4fbf6"), Color("#82c8ad"), 30, 4)
	panel.name = "EquipmentSummaryPanel"
	panel.custom_minimum_size = Vector2(0, 260)
	UITheme.apply_texture_panel_skin(panel, PANEL_SKIN_PATH, 30)
	var margin: MarginContainer = _panel_margin(panel, 20)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(stack)
	stack.add_child(UITheme.make_label("EQUIPMENT BONUS\n裝備加成", 25, UITheme.INK))
	equipment_bonus_label = UITheme.make_label("", 21, UITheme.MUTED_INK)
	equipment_bonus_label.name = "EquipmentBonusValueLabel"
	equipment_bonus_label.custom_minimum_size = Vector2(0, 48)
	equipment_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(equipment_bonus_label)
	return panel

func _make_scroll(scroll_name: String, parent: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = scroll_name
	scroll.position = Vector2.ZERO
	scroll.size = parent.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.scroll_deadzone = 18
	parent.add_child(scroll)
	return scroll

func _make_stack(stack_name: String) -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = stack_name
	stack.custom_minimum_size = Vector2(988, 0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 16)
	return stack

func _get_active_scroll() -> ScrollContainer:
	match active_tab:
		TAB_PROFILE:
			return profile_scroll
		TAB_EQUIPMENT:
			return equipment_scroll
		TAB_BAG:
			return bag_scroll
	return null

func _begin_scroll_drag(position: Vector2, pointer_id: int, scroll: ScrollContainer) -> void:
	if scroll == null or not scroll.visible or not scroll.get_global_rect().has_point(position):
		return
	scroll_drag_active = true
	scroll_dragged = false
	scroll_drag_pointer_id = pointer_id
	scroll_drag_start_position = position
	scroll_drag_last_position = position
	scroll_drag_scroll = scroll

func _update_scroll_drag(position: Vector2) -> void:
	if not scroll_drag_active or scroll_drag_scroll == null:
		return
	if not scroll_dragged and position.distance_to(scroll_drag_start_position) >= SCROLL_DRAG_THRESHOLD:
		scroll_dragged = true
	if not scroll_dragged:
		scroll_drag_last_position = position
		return
	var delta_y: float = position.y - scroll_drag_last_position.y
	var max_scroll: int = maxi(0, int(ceil(scroll_drag_scroll.get_v_scroll_bar().max_value)))
	scroll_drag_scroll.scroll_vertical = clampi(int(round(float(scroll_drag_scroll.scroll_vertical) - delta_y)), 0, max_scroll)
	scroll_drag_last_position = position
	get_viewport().set_input_as_handled()

func _end_scroll_drag() -> void:
	if scroll_dragged:
		get_viewport().set_input_as_handled()
	_clear_scroll_drag()

func _clear_scroll_drag() -> void:
	scroll_drag_active = false
	scroll_dragged = false
	scroll_drag_pointer_id = -1
	scroll_drag_start_position = Vector2.ZERO
	scroll_drag_last_position = Vector2.ZERO
	scroll_drag_scroll = null

func set_active_tab(tab_id: String) -> void:
	if not TAB_IDS.has(tab_id):
		return
	_clear_scroll_drag()
	active_tab = tab_id
	_refresh_active_tab()

func _refresh_active_tab() -> void:
	if profile_scroll == null:
		return
	profile_scroll.visible = active_tab == TAB_PROFILE
	equipment_scroll.visible = active_tab == TAB_EQUIPMENT
	bag_scroll.visible = active_tab == TAB_BAG
	character_goblin_layer.visible = active_tab != TAB_BAG
	profile_portrait.visible = active_tab == TAB_PROFILE
	equipment_portrait.visible = active_tab == TAB_EQUIPMENT
	character_action_layer.visible = active_tab == TAB_PROFILE
	character_equipment_layer.visible = active_tab == TAB_EQUIPMENT
	for tab_id: String in TAB_IDS:
		var button: Button = tab_buttons.get(tab_id) as Button
		if button != null:
			button.button_pressed = tab_id == active_tab
	if active_tab == TAB_PROFILE:
		profile_scroll.scroll_vertical = 0
	elif active_tab == TAB_EQUIPMENT:
		equipment_scroll.scroll_vertical = 0
	else:
		bag_scroll.scroll_vertical = 0
	_clear_scroll_drag()

func _refresh_all(message: String = "") -> void:
	if level_label == null:
		return
	level_label.text = "LV.%d  ·  第%d章" % [GameManager.get_level(), GameBalance.chapter_for_stage(int(GameManager.player_state.get("unlocked_stage", 1)))]
	exp_label.text = "EXP %d / %d" % [GameManager.get_exp(), GameManager.get_required_exp()]
	var stat_breakdown: Dictionary = GameManager.get_stat_breakdown()
	stats_label.text = _format_stat_breakdown(stat_breakdown)
	_refresh_stat_buttons(stat_breakdown)
	if equipment_bonus_label != null:
		equipment_bonus_label.text = "目前套用：%s" % _format_stats(GameManager.get_equipped_stats())
	var total_stat_points: int = GameManager.get_total_stat_points()
	var available_stat_points: int = GameManager.get_stat_points()
	points_label.text = "STAT POINTS %d / %d\n總能力點數：%d　可分配：%d" % [available_stat_points, total_stat_points, total_stat_points, available_stat_points]
	inventory_count_label.text = "BAG %d / ∞\n背包容量" % GameManager.get_inventory().size()
	coin_label.text = "%d  鑽石\n%d  金幣" % [GameManager.get_gems(), GameManager.get_coins()]
	message_label.text = message
	_refresh_equipment_slots()
	_refresh_inventory()
	_refresh_active_tab()

func _format_stat_breakdown(stat_breakdown: Dictionary) -> String:
	var lines: PackedStringArray = ["能力總值 / 分拆"]
	var specs: Array = [
		["attack", "ATK", "攻擊"],
		["max_hp", "HP", "生命"],
		["defense", "DEF", "防禦"],
		["luck", "LUCK", "幸運"]
	]
	for spec: Array in specs:
		var stat: String = str(spec[0])
		var data: Dictionary = stat_breakdown.get(stat, {})
		lines.append("%s %d（等級 %d + 加點 %d + 裝備 %d）" % [
			str(spec[1]),
			int(data.get("total", 0)),
			int(data.get("level", 0)),
			int(data.get("allocated_value", 0)),
			int(data.get("equipment", 0))
		])
	return "\n".join(lines)

func _refresh_stat_buttons(stat_breakdown: Dictionary) -> void:
	var specs: Array = [
		["attack", "ATK", "攻擊 +1"],
		["max_hp", "MAX HP", "生命 +3"],
		["defense", "DEF", "防禦 +1"],
		["luck", "LUCK", "幸運 +1"]
	]
	for spec: Array in specs:
		var stat: String = str(spec[0])
		var button: Button = stat_buttons.get(stat) as Button
		var data: Dictionary = stat_breakdown.get(stat, {})
		if button != null:
			UITheme.set_dual_button_text(button, "%s %d" % [str(spec[1]), int(data.get("total", 0))], str(spec[2]))

func _refresh_equipment_slots() -> void:
	if equipment_row == null:
		return
	_clear_children(equipment_row)
	for slot: String in SLOT_ORDER:
		equipment_row.add_child(_make_equipment_slot_card(slot))

func _make_equipment_slot_card(slot: String) -> Panel:
	var color: Color = Color("#d8f0e4")
	var card: Panel = UITheme.make_panel(color, Color("#82c8ad"), 25, 4)
	card.name = "EquipmentSlot_%s" % slot.capitalize()
	card.custom_minimum_size = Vector2(0, 420)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_texture_panel_skin(card, SLOT_FRAME_PATH, 26)
	var margin: MarginContainer = _panel_margin(card, 13)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var slot_name: Dictionary = SLOT_NAMES[slot]
	stack.add_child(UITheme.make_dual_label(str(slot_name["primary"]), str(slot_name["secondary"]), 22, 16, UITheme.INK))
	var uid: String = GameManager.get_equipped_uid(slot)
	var item: Dictionary = EquipmentSystem.find_item(GameManager.get_inventory(), uid)
	stack.add_child(_make_item_icon(slot, not item.is_empty(), Vector2(112, 112), item))
	var item_text: String = EquipmentSystem.describe_item(item) if not item.is_empty() else "EMPTY\n未裝備"
	var item_label: Label = UITheme.make_label(item_text, 18, EquipmentSystem.rarity_color(str(EquipmentSystem.get_item_template(item).get("rarity", "common"))) if not item.is_empty() else UITheme.MUTED_INK)
	item_label.custom_minimum_size = Vector2(0, 42)
	stack.add_child(item_label)
	if item.is_empty():
		var empty_action: Control = Control.new()
		empty_action.custom_minimum_size = Vector2(0, 128)
		stack.add_child(empty_action)
	else:
		var unequip: Button = _make_small_button("UNEQUIP\n卸下", Color("#d9edf0"), Vector2(0, 120))
		unequip.name = "UnequipButton_%s" % slot
		unequip.pressed.connect(_on_unequip_pressed.bind(slot))
		stack.add_child(unequip)
	return card

func _refresh_inventory() -> void:
	if inventory_list == null:
		return
	_clear_children(inventory_list)
	var inventory: Array = GameManager.get_inventory()
	if inventory_sort_button != null:
		UITheme.set_dual_button_text(inventory_sort_button, "SORT", "整理：%s" % _inventory_sort_label())
	if inventory.is_empty():
		inventory_list.add_child(UITheme.make_label("EMPTY BAG\n尚未取得裝備，通過關卡就有機會掉落。", 24, UITheme.MUTED_INK))
		return
	for raw_item: Variant in _sorted_inventory(inventory):
		if raw_item is Dictionary:
			inventory_list.add_child(_make_item_card(raw_item))

func _make_item_card(item: Dictionary) -> Panel:
	var template: Dictionary = EquipmentSystem.get_item_template(item)
	var rarity: String = str(template.get("rarity", "common"))
	var slot: String = str(template.get("slot", "weapon"))
	var card: Panel = UITheme.make_panel(Color(1, 0.98, 0.94, 0.98), EquipmentSystem.rarity_color(rarity), 25, 4)
	card.name = "ItemCard_%s" % str(item.get("uid", "unknown"))
	card.custom_minimum_size = Vector2(988, BAG_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_texture_panel_skin(card, PANEL_SKIN_PATH, 26)
	var row: Control = Control.new()
	row.name = "ItemRow_%s" % str(item.get("uid", "unknown"))
	row.position = Vector2(BAG_CARD_MARGIN, BAG_CARD_MARGIN)
	row.size = Vector2(988 - BAG_CARD_MARGIN * 2, BAG_CARD_HEIGHT - BAG_CARD_MARGIN * 2)
	card.add_child(row)
	var icon_column: Control = Control.new()
	icon_column.name = "ItemIconColumn_%s" % str(item.get("uid", "unknown"))
	icon_column.position = Vector2(0, 0)
	icon_column.size = Vector2(BAG_ICON_COLUMN_WIDTH, row.size.y)
	icon_column.custom_minimum_size = Vector2(BAG_ICON_COLUMN_WIDTH, 0)
	var item_icon: Panel = _make_item_icon(slot, true, BAG_ITEM_ICON_SIZE, item)
	item_icon.position = Vector2(BAG_ICON_OFFSET, (row.size.y - BAG_ITEM_ICON_SIZE.y) * 0.5)
	item_icon.size = BAG_ITEM_ICON_SIZE
	icon_column.add_child(item_icon)
	row.add_child(icon_column)
	var info: VBoxContainer = VBoxContainer.new()
	var action_start_x: float = row.size.x - BAG_ACTION_COLUMN_WIDTH
	var info_start_x: float = BAG_ICON_COLUMN_WIDTH + 16.0
	info.position = Vector2(info_start_x, 0)
	info.size = Vector2(action_start_x - 16.0 - info_start_x, row.size.y)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var equipped_text: String = "\nEQUIPPED / 已裝備" if EquipmentSystem.is_equipped(GameManager.player_state, str(item.get("uid", ""))) else ""
	var name_label: Label = UITheme.make_label("%s%s" % [EquipmentSystem.describe_item(item), equipped_text], 25, EquipmentSystem.rarity_color(rarity))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(name_label)
	var slot_name: Dictionary = SLOT_NAMES.get(slot, {"primary": "ITEM", "secondary": "裝備"})
	var detail: Label = UITheme.make_label("%s · %s\n%s" % [str(slot_name["secondary"]), _rarity_name(rarity), _format_stats(EquipmentSystem.get_item_stats(item))], 20, UITheme.MUTED_INK)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(detail)
	var action_column: Control = Control.new()
	action_column.name = "ItemActionColumn_%s" % str(item.get("uid", "unknown"))
	action_column.position = Vector2(action_start_x, 0)
	action_column.size = Vector2(BAG_ACTION_COLUMN_WIDTH, row.size.y)
	action_column.custom_minimum_size = Vector2(BAG_ACTION_COLUMN_WIDTH, 0)
	var actions: VBoxContainer = VBoxContainer.new()
	actions.name = "ItemActions_%s" % str(item.get("uid", "unknown"))
	actions.position = Vector2(0, (row.size.y - BAG_ACTION_STACK_HEIGHT) * 0.5)
	actions.size = Vector2(BAG_ACTION_COLUMN_WIDTH, BAG_ACTION_STACK_HEIGHT)
	actions.custom_minimum_size = Vector2(BAG_ACTION_COLUMN_WIDTH, BAG_ACTION_STACK_HEIGHT)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", BAG_ACTION_GAP)
	action_column.add_child(actions)
	row.add_child(action_column)
	var uid: String = str(item.get("uid", ""))
	var is_equipped: bool = EquipmentSystem.is_equipped(GameManager.player_state, uid)
	var equip_button: Button = _make_small_button("EQUIPPED\n已穿戴" if is_equipped else "EQUIP\n穿戴", Color("#a8d8c4") if is_equipped else Color("#bfe7d3"), BAG_ACTION_BUTTON_SIZE)
	equip_button.name = "EquipButton_%s" % uid
	equip_button.disabled = is_equipped
	equip_button.pressed.connect(_on_equip_pressed.bind(uid))
	actions.add_child(equip_button)
	var cost: int = EquipmentSystem.upgrade_cost(item)
	var upgrade_button: Button = _make_small_button("UPGRADE\n強化 %d 金幣" % cost, Color("#ffe19a"), BAG_ACTION_BUTTON_SIZE)
	upgrade_button.name = "UpgradeButton_%s" % uid
	upgrade_button.disabled = GameManager.get_coins() < cost
	upgrade_button.pressed.connect(_on_upgrade_pressed.bind(uid))
	actions.add_child(upgrade_button)
	var sell_text: String = "CONFIRM SELL\n確認出售 +%d" % EquipmentSystem.sell_value(item) if pending_sell_uid == uid else "SELL\n出售 +%d" % EquipmentSystem.sell_value(item)
	var sell_color: Color = Color("#efa7b5") if pending_sell_uid == uid else Color("#f5ccd3")
	var sell_button: Button = _make_small_button(sell_text, sell_color, BAG_ACTION_BUTTON_SIZE)
	sell_button.name = "SellButton_%s" % uid
	sell_button.disabled = EquipmentSystem.is_equipped(GameManager.player_state, uid)
	sell_button.pressed.connect(_on_sell_pressed.bind(uid))
	actions.add_child(sell_button)
	return card

func _make_item_icon(slot: String, equipped: bool, icon_size: Vector2, item: Dictionary = {}) -> Panel:
	var icon_box: Panel = Panel.new()
	icon_box.name = "EquipmentArt_%s" % str(item.get("template_id", slot)) if not item.is_empty() else "EquipmentArtEmpty_%s" % slot
	icon_box.custom_minimum_size = icon_size
	icon_box.size = icon_size
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.clip_contents = true
	var skin_path: String = SLOT_FRAME_PATH if equipped else SLOT_EMPTY_PATH
	UITheme.apply_texture_panel_skin(icon_box, skin_path, 18)
	var generated_path: String = EquipmentSystem.get_equipment_sprite_path(str(item.get("template_id", ""))) if not item.is_empty() else ""
	var icon_path: String = generated_path if not generated_path.is_empty() else str(SLOT_ICON_PATHS.get(slot, ""))
	if ResourceLoader.exists(icon_path):
		var icon: TextureRect = _make_sprite(icon_path, icon_size - Vector2(16, 16))
		icon.name = "EquipmentArtSprite"
		icon.position = Vector2(8, 8)
		icon_box.add_child(icon)
	else:
		var fallback: Label = UITheme.make_label(str(SLOT_NAMES.get(slot, {}).get("secondary", "裝備")), 18, UITheme.MUTED_INK)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_box.add_child(fallback)
	return icon_box

func _add_stat_button(parent: GridContainer, title: String, stat: String) -> void:
	var button: Button = _make_small_button(title, Color("#ffe19a"), Vector2(0, 132))
	button.name = "StatButton_%s" % stat
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_stat_pressed.bind(stat))
	stat_buttons[stat] = button
	parent.add_child(button)

func _on_stat_pressed(stat: String) -> void:
	pending_sell_uid = ""
	var success: bool = GameManager.spend_stat_point(stat)
	_refresh_all("STAT UP!\n能力提升！" if success else "NO POINTS\n升級後會獲得可分配屬性點。")

func _on_equip_pressed(uid: String) -> void:
	pending_sell_uid = ""
	_refresh_all("EQUIPPED!\n已穿戴裝備。" if GameManager.equip_item(uid) else "CANNOT EQUIP\n無法穿戴這件裝備。")

func _on_unequip_pressed(slot: String) -> void:
	pending_sell_uid = ""
	var success: bool = GameManager.unequip_slot(slot)
	_refresh_all("UNEQUIPPED\n已卸下裝備。" if success else "EMPTY SLOT\n這個槽位沒有裝備。")

func _on_upgrade_pressed(uid: String) -> void:
	pending_sell_uid = ""
	var result: Dictionary = GameManager.upgrade_item(uid)
	_refresh_all("UPGRADE SUCCESS\n強化成功！" if bool(result.get("success", false)) else "NOT ENOUGH COINS\n金幣不足，繼續冒險吧。")

func _on_sell_pressed(uid: String) -> void:
	if pending_sell_uid != uid:
		pending_sell_uid = uid
		_refresh_all("CONFIRM SELL\n再次按「確認出售」才會賣出這件裝備。")
		return
	pending_sell_uid = ""
	var result: Dictionary = GameManager.sell_item(uid)
	_refresh_all("SOLD\n已出售裝備，獲得 %d 金幣。" % int(result.get("coins", 0)) if bool(result.get("success", false)) else "EQUIPPED ITEM\n穿戴中的裝備不能出售。")

func _on_sort_inventory_pressed() -> void:
	var current_index: int = INVENTORY_SORT_MODES.find(inventory_sort_mode)
	inventory_sort_mode = INVENTORY_SORT_MODES[posmod(current_index + 1, INVENTORY_SORT_MODES.size())]
	AudioManager.play_sfx("button_click")
	_refresh_all("SORTED\n背包已依%s整理。" % _inventory_sort_label())

func _sorted_inventory(inventory: Array) -> Array:
	var result: Array = inventory.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_template: Dictionary = EquipmentSystem.get_item_template(a)
		var b_template: Dictionary = EquipmentSystem.get_item_template(b)
		var a_rarity: int = EquipmentSystem.RARITY_ORDER.find(str(a_template.get("rarity", "common")))
		var b_rarity: int = EquipmentSystem.RARITY_ORDER.find(str(b_template.get("rarity", "common")))
		var a_slot: int = EquipmentSystem.SLOTS.find(str(a_template.get("slot", "weapon")))
		var b_slot: int = EquipmentSystem.SLOTS.find(str(b_template.get("slot", "weapon")))
		if inventory_sort_mode == "slot" and a_slot != b_slot:
			return a_slot < b_slot
		if inventory_sort_mode == "level" and int(a.get("level", 1)) != int(b.get("level", 1)):
			return int(a.get("level", 1)) > int(b.get("level", 1))
		if a_rarity != b_rarity:
			return a_rarity > b_rarity
		if a_slot != b_slot:
			return a_slot < b_slot
		return str(a.get("uid", "")) < str(b.get("uid", ""))
	)
	return result

func _inventory_sort_label() -> String:
	return {"rarity": "稀有度", "slot": "部位", "level": "等級"}.get(inventory_sort_mode, "稀有度")

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_world_map()

func _on_gacha_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_gacha()

func _format_stats(stats: Dictionary) -> String:
	var parts: Array[String] = []
	if int(stats.get("attack", 0)) > 0:
		parts.append("ATK +%d" % int(stats["attack"]))
	if int(stats.get("max_hp", 0)) > 0:
		parts.append("HP +%d" % int(stats["max_hp"]))
	if int(stats.get("defense", 0)) > 0:
		parts.append("DEF +%d" % int(stats["defense"]))
	if int(stats.get("luck", 0)) > 0:
		parts.append("LUCK +%d" % int(stats["luck"]))
	if float(stats.get("exp_bonus", 0.0)) > 0.0:
		parts.append("EXP +%d%%" % int(round(float(stats["exp_bonus"]) * 100.0)))
	if float(stats.get("coin_bonus", 0.0)) > 0.0:
		parts.append("COIN +%d%%" % int(round(float(stats["coin_bonus"]) * 100.0)))
	return "  ".join(parts) if not parts.is_empty() else "—"

func _rarity_name(rarity: String) -> String:
	return {"common": "COMMON 普通", "uncommon": "UNCOMMON 精良", "rare": "RARE 稀有", "epic": "EPIC 史詩", "legendary": "LEGENDARY 傳說"}.get(rarity, "COMMON 普通")

func _make_small_button(text_value: String, color: Color, min_size: Vector2, logo_path: String = ACTION_BUTTON_SKIN_PATH) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(maxf(min_size.x, 96.0), maxf(min_size.y, 96.0))
	button.clip_contents = false
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_color_override("font_hover_color", UITheme.INK)
	button.add_theme_color_override("font_pressed_color", UITheme.INK)
	button.add_theme_color_override("font_disabled_color", UITheme.MUTED_INK)
	# The texture logo is the visual button. Keep the Button's stylebox
	# transparent so its enlarged touch target does not become a second,
	# blocky card around the artwork.
	var clear: Color = Color(1.0, 1.0, 1.0, 0.0)
	var clear_style: StyleBoxFlat = StyleBoxFlat.new()
	clear_style.bg_color = clear
	clear_style.border_color = clear
	clear_style.shadow_color = clear
	clear_style.shadow_size = 0
	button.add_theme_stylebox_override("normal", clear_style)
	button.add_theme_stylebox_override("hover", clear_style)
	button.add_theme_stylebox_override("pressed", clear_style)
	button.add_theme_stylebox_override("disabled", clear_style)
	UITheme.apply_font(button)
	var separator_index: int = text_value.find("\n")
	var primary: String = text_value if separator_index < 0 else text_value.substr(0, separator_index)
	var secondary: String = "" if separator_index < 0 else text_value.substr(separator_index + 1)
	var content: VBoxContainer = UITheme.make_dual_label(primary, secondary, 24, 17, UITheme.INK)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.z_index = 2
	button.add_child(content)
	_add_character_button_logo(button, logo_path, color)
	return button

func _add_character_button_logo(button: Button, logo_path: String, tint: Color) -> void:
	if button == null or logo_path.is_empty() or not ResourceLoader.exists(logo_path):
		return
	var logo: TextureRect = TextureRect.new()
	logo.name = "CharacterButtonLogo"
	logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.texture = load(logo_path) as Texture2D
	logo.modulate = tint
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.z_index = 1
	button.add_child(logo)

func _make_layer(layer_name: String, filter: int) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = filter
	add_child(layer)
	return layer

func _make_sprite(path: String, sprite_size: Vector2) -> TextureRect:
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = load(path) if ResourceLoader.exists(path) else null
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = sprite_size
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite

func _get_player_sprite_path() -> String:
	return PLAYER_PATH if ResourceLoader.exists(PLAYER_PATH) else PLAYER_FALLBACK_PATH

func _panel_margin(panel: Panel, margin_value: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, margin_value)
	panel.add_child(margin)
	return margin

func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
