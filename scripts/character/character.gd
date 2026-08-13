extends Control

## Layered three-tab character, equipment, and inventory screen.
const TAB_PROFILE: String = "profile"
const TAB_EQUIPMENT: String = "equipment"
const TAB_BAG: String = "bag"
const TAB_IDS: Array[String] = [TAB_PROFILE, TAB_EQUIPMENT, TAB_BAG]
const INVENTORY_SORT_MODES: Array[String] = ["rarity", "slot", "level"]
const SCROLL_DRAG_THRESHOLD: float = 12.0
const BAG_HEADER_HEIGHT: float = 120.0
const BAG_CARD_HEIGHT: float = 376.0
const BAG_CARD_MARGIN: int = 24
const BAG_ITEM_ICON_SIZE: Vector2 = Vector2(196, 196)
const BAG_ICON_OFFSET: int = 12
const BAG_ICON_COLUMN_WIDTH: float = 220.0
const BAG_ACTION_COLUMN_WIDTH: float = 220.0
const BAG_ACTION_BUTTON_SIZE: Vector2 = Vector2(220, 96)
const BAG_ACTION_GAP: int = 8
const BAG_ACTION_STACK_HEIGHT: float = 304.0
const CHARACTER_CARD_WIDTH: float = 286.0
const CHARACTER_CARD_HEIGHT: float = 630.0

const BACKGROUND_PATH: String = "res://assets/ui/character/character_upgrade_bg_v1.png"
const AMBIENT_PATH: String = "res://assets/ui/start/start_effects_v2.png"
const PANEL_SKIN_PATH: String = "res://assets/ui/character/character_panel_skin_v1.png"
const TAB_SKIN_PATH: String = "res://assets/ui/character/character_tab_skin_v1.png"
const ACTION_BUTTON_SKIN_PATH: String = "res://assets/ui/character/character_action_button_skin_v1.png"
const SLOT_FRAME_PATH: String = "res://assets/ui/character/character_slot_frame_v1.png"
const SLOT_EMPTY_PATH: String = "res://assets/ui/character/character_slot_empty_v1.png"
const COIN_BADGE_PATH: String = "res://assets/ui/character/character_coin_badge_v1.png"
const DIAMOND_ICON_PATH: String = "res://assets/ui/gacha/gacha_diamond_icon_v1.png"
const CHARACTER_ICON_DIR: String = "res://assets/ui/character/icons/"
const ICON_PATHS: Dictionary = {
	"map": CHARACTER_ICON_DIR + "character_icon_map_v1.png",
	"gacha": CHARACTER_ICON_DIR + "character_icon_gacha_v1.png",
	"merge": CHARACTER_ICON_DIR + "character_icon_merge_v1.png",
	"profile": CHARACTER_ICON_DIR + "character_icon_profile_v1.png",
	"equipment": CHARACTER_ICON_DIR + "character_icon_equipment_v1.png",
	"bag": CHARACTER_ICON_DIR + "character_icon_bag_v1.png",
	"equip": CHARACTER_ICON_DIR + "character_icon_equip_v1.png",
	"upgrade": CHARACTER_ICON_DIR + "character_icon_upgrade_v1.png",
	"sell": CHARACTER_ICON_DIR + "character_icon_sell_v1.png",
	"sort": CHARACTER_ICON_DIR + "character_icon_sort_v1.png",
	"attack": CHARACTER_ICON_DIR + "character_icon_attack_v1.png",
	"max_hp": CHARACTER_ICON_DIR + "character_icon_health_v1.png",
	"defense": CHARACTER_ICON_DIR + "character_icon_defense_v1.png",
	"luck": CHARACTER_ICON_DIR + "character_icon_luck_v1.png"
}

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
var character_selector_layer: Control
var character_selector_panel: Panel
var character_card_row: HBoxContainer
var purchase_confirm_layer: Control
var purchase_confirm_label: Label

var profile_portrait: TextureRect
var equipment_portrait: TextureRect
var profile_scroll: ScrollContainer
var equipment_scroll: ScrollContainer
var bag_scroll: ScrollContainer
var bag_header_panel: Panel
var profile_content: Control
var equipment_content: Control
var bag_content: Control
var equipment_row: HBoxContainer
var inventory_list: VBoxContainer
var tab_buttons: Dictionary = {}
var stat_buttons: Dictionary = {}
var stat_summary_labels: Dictionary = {}
var equipment_bonus_values: Dictionary = {}

var level_label: Label
var exp_label: Label
var stats_label: Label
var exp_progress: ProgressBar
var points_label: Label
var coin_label: Label
var inventory_count_label: Label
var inventory_sort_button: Button
var equipment_bonus_label: Label
var message_label: Label
var choose_character_button: Button
var character_selector_currency_label: Label
var pending_character_purchase_id: String = ""

func _ready() -> void:
	set_process_input(true)
	_build_screen()
	_refresh_all()
	call_deferred("_play_page_entrance")

func _input(event: InputEvent) -> void:
	if character_selector_layer != null and character_selector_layer.visible:
		return
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
	_build_character_selector()
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
	profile_portrait = _make_sprite(_get_player_sprite_path(), Vector2(310, 310))
	profile_portrait.name = "ProfileGoblinPortrait"
	profile_portrait.position = Vector2(385, 366 + character_top_offset)
	character_goblin_layer.add_child(profile_portrait)
	equipment_portrait = _make_sprite(_get_player_sprite_path(), Vector2(176, 176))
	equipment_portrait.name = "EquipmentGoblinPortrait"
	equipment_portrait.position = Vector2(452, 370 + character_top_offset)
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
	header.position = Vector2(44, 82 + character_top_offset)
	header.size = Vector2(992, 128)
	character_hud_layer.add_child(header)

	var back_button: Button = _make_small_button("地圖\nMAP", Color("#e7f1e8"), Vector2(120, 124), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["map"]))
	back_button.name = "BackToMapButton"
	back_button.position = Vector2(0, 0)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var title: VBoxContainer = UITheme.make_zh_en_label("角色", "CHARACTER", 38, 14, UITheme.INK)
	title.name = "CharacterTitle"
	title.position = Vector2(136, 8)
	title.size = Vector2(240, 104)
	header.add_child(title)
	var gacha_button: Button = _make_small_button("轉蛋\nGACHA", Color("#eadff8"), Vector2(118, 124), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["gacha"]))
	gacha_button.name = "GachaButton"
	gacha_button.position = Vector2(392, 0)
	gacha_button.pressed.connect(_on_gacha_pressed)
	header.add_child(gacha_button)
	var merge_button: Button = _make_small_button("合成\nMERGE", Color("#d9ead8"), Vector2(118, 124), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["merge"]))
	merge_button.name = "MergeButton"
	merge_button.position = Vector2(522, 0)
	merge_button.pressed.connect(_on_merge_pressed)
	header.add_child(merge_button)

	var coin_badge: Panel = UITheme.make_panel(Color("#fff4c9"), Color("#d9a85c"), 28, 4)
	coin_badge.name = "CoinBadge"
	coin_badge.position = Vector2(656, 8)
	coin_badge.size = Vector2(336, 104)
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
	var diamond_icon: TextureRect = _make_sprite(DIAMOND_ICON_PATH, Vector2(30, 30))
	diamond_icon.name = "DiamondCurrencyIcon"
	diamond_icon.position = Vector2(116, 15)
	diamond_icon.z_index = 2
	coin_badge.add_child(diamond_icon)
	coin_label = UITheme.make_label("", 21, Color("#8b5d2b"), UITheme.FontRole.BOLD)
	coin_label.position = Vector2(148, 8)
	coin_label.size = Vector2(170, 88)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coin_label.z_index = 2
	coin_badge.add_child(coin_label)
	header.add_child(coin_badge)

func _build_tabs() -> void:
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.name = "CharacterTabBar"
	tab_bar.position = Vector2(44, 218 + character_top_offset)
	tab_bar.size = Vector2(992, 116)
	tab_bar.add_theme_constant_override("separation", 14)
	character_tab_layer.add_child(tab_bar)
	var tab_specs: Array = [
		[TAB_PROFILE, "角色\nPROFILE", Color("#f4bec9"), ICON_PATHS["profile"]],
		[TAB_EQUIPMENT, "裝備\nEQUIPMENT", Color("#f7efe0"), ICON_PATHS["equipment"]],
		[TAB_BAG, "背包\nBAG", Color("#f7efe0"), ICON_PATHS["bag"]]
	]
	for spec: Array in tab_specs:
		var tab_id: String = str(spec[0])
		var button: Button = _make_small_button(str(spec[1]), spec[2], Vector2(0, 116), TAB_SKIN_PATH, str(spec[3]))
		button.name = "%sTabButton" % tab_id.capitalize()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_active_tab.bind(tab_id))
		tab_bar.add_child(button)
		tab_buttons[tab_id] = button

func _build_tab_contents() -> void:
	var content_area: Control = Control.new()
	content_area.name = "CharacterContentArea"
	content_area.position = Vector2(44, 350 + character_top_offset)
	content_area.size = Vector2(992, maxf(900.0, 1480.0 - character_top_offset))
	character_panel_layer.add_child(content_area)

	profile_scroll = _make_scroll("ProfileScroll", content_area)
	equipment_scroll = _make_scroll("EquipmentScroll", content_area)
	bag_scroll = _make_scroll("BagScroll", content_area)

	profile_content = _make_stack("ProfileContent")
	profile_scroll.add_child(profile_content)
	profile_content.add_child(UITheme.make_spacer(340))
	choose_character_button = _make_small_button("選擇主角\nCHOOSE HERO", Color("#f5d9df"), Vector2(0, 104), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["profile"]))
	choose_character_button.name = "OpenCharacterSelectorButton"
	choose_character_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choose_character_button.pressed.connect(_on_open_character_selector_pressed)
	profile_content.add_child(choose_character_button)
	profile_content.add_child(_make_profile_summary())
	character_action_layer = _make_profile_actions()
	profile_content.add_child(character_action_layer)

	equipment_content = _make_stack("EquipmentContent")
	equipment_scroll.add_child(equipment_content)
	equipment_content.add_child(UITheme.make_spacer(190))
	character_equipment_layer = VBoxContainer.new()
	character_equipment_layer.name = "CharacterEquipmentLayer"
	character_equipment_layer.add_theme_constant_override("separation", 14)
	equipment_content.add_child(character_equipment_layer)
	character_equipment_layer.add_child(UITheme.make_zh_en_label("目前裝備", "EQUIPPED GEAR", 30, 14, UITheme.INK))
	equipment_row = HBoxContainer.new()
	equipment_row.name = "EquipmentSlotRow"
	equipment_row.add_theme_constant_override("separation", 14)
	character_equipment_layer.add_child(equipment_row)
	var bag_button: Button = _make_small_button("前往背包\nOPEN BAG", Color("#f5d88d"), Vector2(0, 112), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["bag"]))
	bag_button.name = "OpenBagButton"
	bag_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_button.pressed.connect(set_active_tab.bind(TAB_BAG))
	character_equipment_layer.add_child(bag_button)
	equipment_content.add_child(_make_equipment_summary_panel())

	bag_content = _make_stack("BagContent")
	bag_scroll.add_child(bag_content)
	bag_scroll.position = Vector2(0, BAG_HEADER_HEIGHT + 14)
	bag_scroll.size = Vector2(content_area.size.x, content_area.size.y - BAG_HEADER_HEIGHT - 14)
	bag_header_panel = UITheme.make_panel(Color(1.0, 0.98, 0.94, 0.94), Color("#e4b78c"), 28, 2)
	bag_header_panel.name = "BagHeader"
	bag_header_panel.position = Vector2.ZERO
	bag_header_panel.size = Vector2(992, BAG_HEADER_HEIGHT)
	content_area.add_child(bag_header_panel)
	var bag_header_row: Control = Control.new()
	bag_header_row.name = "BagHeaderRow"
	bag_header_row.position = Vector2(18, 12)
	bag_header_row.size = Vector2(956, BAG_HEADER_HEIGHT - 24)
	bag_header_panel.add_child(bag_header_row)
	var capacity_panel: Panel = UITheme.make_panel(Color(1.0, 1.0, 1.0, 0.30), Color(1.0, 1.0, 1.0, 0.0), 18, 0)
	capacity_panel.name = "BagCapacityPanel"
	capacity_panel.position = Vector2.ZERO
	capacity_panel.size = Vector2(272, 96)
	capacity_panel.custom_minimum_size = Vector2(272, 96)
	inventory_count_label = UITheme.make_label("", 23, UITheme.INK, UITheme.FontRole.BOLD)
	inventory_count_label.position = Vector2(14, 10)
	inventory_count_label.size = Vector2(244, 76)
	inventory_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	inventory_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capacity_panel.add_child(inventory_count_label)
	bag_header_row.add_child(capacity_panel)
	var header_tools: Control = Control.new()
	header_tools.name = "BagHeaderTools"
	header_tools.position = Vector2(286, 0)
	header_tools.size = Vector2(670, 96)
	bag_header_row.add_child(header_tools)
	var items_label: Label = UITheme.make_label("裝備清單\nINVENTORY", 22, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	items_label.name = "BagItemsLabel"
	items_label.position = Vector2(126, 0)
	items_label.size = Vector2(292, 96)
	items_label.custom_minimum_size = Vector2(292, 96)
	items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_tools.add_child(items_label)
	inventory_sort_button = _make_small_button("整理\n稀有度", Color("#e7f1e8"), Vector2(224, 96), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["sort"]))
	inventory_sort_button.name = "InventorySortButton"
	inventory_sort_button.position = Vector2(446, 0)
	inventory_sort_button.size = Vector2(224, 96)
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

func _build_character_selector() -> void:
	character_selector_layer = Control.new()
	character_selector_layer.name = "CharacterSelectorLayer"
	character_selector_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_selector_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	character_selector_layer.z_index = 100
	add_child(character_selector_layer)

	var dim: ColorRect = ColorRect.new()
	dim.name = "CharacterSelectorDim"
	dim.color = Color(0.20, 0.12, 0.14, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	character_selector_layer.add_child(dim)

	character_selector_panel = UITheme.make_panel(Color(1.0, 0.98, 0.93, 0.99), Color("#d98d9d"), 38, 5)
	character_selector_panel.name = "CharacterSelectorPanel"
	character_selector_panel.position = Vector2(52, 176 + character_top_offset)
	character_selector_panel.size = Vector2(976, maxf(1080.0, 1180.0 - character_top_offset * 0.5))
	character_selector_layer.add_child(character_selector_panel)
	var margin: MarginContainer = _panel_margin(character_selector_panel, 30)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)

	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 112)
	header.add_theme_constant_override("separation", 12)
	stack.add_child(header)
	var title: VBoxContainer = UITheme.make_zh_en_label("選擇主角", "CHOOSE YOUR HERO", 34, 14, UITheme.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	character_selector_currency_label = UITheme.make_label("", 21, Color("#9b6d31"), UITheme.FontRole.BOLD)
	character_selector_currency_label.name = "CharacterSelectorCurrencyLabel"
	character_selector_currency_label.custom_minimum_size = Vector2(190, 96)
	header.add_child(character_selector_currency_label)
	var close_button: Button = _make_small_button("關閉\nCLOSE", Color("#f1e4df"), Vector2(140, 96), ACTION_BUTTON_SKIN_PATH, "")
	close_button.name = "CloseCharacterSelectorButton"
	close_button.pressed.connect(_on_close_character_selector_pressed)
	header.add_child(close_button)

	var intro: Label = UITheme.make_label("角色共享等級、配點與裝備；選中的主角會提供專屬能力加成。", 20, UITheme.MUTED_INK)
	intro.custom_minimum_size = Vector2(0, 62)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(intro)

	var card_scroll: ScrollContainer = ScrollContainer.new()
	card_scroll.name = "CharacterCardScroll"
	card_scroll.custom_minimum_size = Vector2(0, 670)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.scroll_deadzone = 18
	card_scroll.follow_focus = true
	stack.add_child(card_scroll)
	character_card_row = HBoxContainer.new()
	character_card_row.name = "CharacterCardRow"
	character_card_row.add_theme_constant_override("separation", 14)
	card_scroll.add_child(character_card_row)

	var hint: Label = UITheme.make_label("左右滑動查看更多角色  ·  購買後永久解鎖", 19, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	hint.custom_minimum_size = Vector2(0, 54)
	stack.add_child(hint)
	_build_purchase_confirmation()
	character_selector_layer.visible = false

func _build_purchase_confirmation() -> void:
	purchase_confirm_layer = Control.new()
	purchase_confirm_layer.name = "CharacterPurchaseConfirmLayer"
	purchase_confirm_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	purchase_confirm_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	purchase_confirm_layer.z_index = 10
	character_selector_layer.add_child(purchase_confirm_layer)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.18, 0.10, 0.12, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	purchase_confirm_layer.add_child(dim)
	var panel: Panel = UITheme.make_panel(Color("#fff9ee"), Color("#d98d9d"), 34, 5)
	panel.name = "CharacterPurchaseConfirmPanel"
	panel.position = Vector2(186, 650 + character_top_offset * 0.35)
	panel.size = Vector2(708, 470)
	purchase_confirm_layer.add_child(panel)
	var margin: MarginContainer = _panel_margin(panel, 34)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)
	stack.add_child(UITheme.make_zh_en_label("確認解鎖", "UNLOCK HERO", 31, 14, UITheme.INK))
	purchase_confirm_label = UITheme.make_label("", 23, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	purchase_confirm_label.name = "CharacterPurchaseConfirmLabel"
	purchase_confirm_label.custom_minimum_size = Vector2(0, 170)
	purchase_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(purchase_confirm_label)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	stack.add_child(actions)
	var cancel_button: Button = _make_small_button("取消\nCANCEL", Color("#eee6df"), Vector2(0, 104), ACTION_BUTTON_SKIN_PATH, "")
	cancel_button.name = "CancelCharacterPurchaseButton"
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_on_cancel_character_purchase_pressed)
	actions.add_child(cancel_button)
	var confirm_button: Button = _make_small_button("確認解鎖\nUNLOCK", Color("#f6c7cf"), Vector2(0, 104), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["profile"]))
	confirm_button.name = "ConfirmCharacterPurchaseButton"
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.pressed.connect(_on_confirm_character_purchase_pressed)
	actions.add_child(confirm_button)
	purchase_confirm_layer.visible = false

func _make_character_card(character: Dictionary) -> Panel:
	var character_id: String = str(character.get("id", ""))
	var selected_id: String = str(GameManager.player_state.get("selected_character_id", GameBalance.DEFAULT_CHARACTER_ID))
	var selected: bool = character_id == selected_id
	var unlocked: bool = GameManager.is_character_unlocked(character_id)
	var fill: Color = Color("#f9dce2") if selected else Color("#fff9ed")
	var border: Color = Color("#d98d9d") if selected else Color("#dfc8a8")
	var card: Panel = UITheme.make_panel(fill, border, 28, 4)
	card.name = "CharacterCard_%s" % character_id
	card.custom_minimum_size = Vector2(CHARACTER_CARD_WIDTH, CHARACTER_CARD_HEIGHT)
	var margin: MarginContainer = _panel_margin(card, 16)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var portrait: TextureRect = _make_sprite(str(character.get("sprite", "")), Vector2(250, 250))
	portrait.name = "CharacterCardPortrait_%s" % character_id
	portrait.custom_minimum_size = Vector2(250, 250)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(portrait)
	var name_label: VBoxContainer = UITheme.make_zh_en_label(str(character.get("name_zh", "主角")), str(character.get("name", "HERO")), 25, 12, UITheme.INK)
	name_label.custom_minimum_size = Vector2(0, 72)
	stack.add_child(name_label)
	var bonus_label: Label = UITheme.make_label(_format_character_bonus(character.get("bonuses", {})), 18, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	bonus_label.name = "CharacterCardBonus_%s" % character_id
	bonus_label.custom_minimum_size = Vector2(0, 58)
	bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(bonus_label)
	var price: int = GameManager.get_effective_character_price(character_id)
	var price_text: String = "使用中" if selected else ("已擁有" if unlocked else "%d 鑽石" % price)
	if not unlocked and price == 0 and DataManager.is_character_test_price_enabled():
		price_text = "測試免費 · 0 鑽石"
	var price_label: Label = UITheme.make_label(price_text, 19, Color("#9b6d31"), UITheme.FontRole.BOLD)
	price_label.name = "CharacterCardPrice_%s" % character_id
	price_label.custom_minimum_size = Vector2(0, 42)
	stack.add_child(price_label)
	var action_text: String = "使用中\nSELECTED" if selected else ("使用角色\nSELECT" if unlocked else "購買並使用\nUNLOCK")
	var action_color: Color = Color("#eadfd8") if selected else (Color("#dcebdc") if unlocked else Color("#f6c7cf"))
	var action_button: Button = _make_small_button(action_text, action_color, Vector2(250, 98), ACTION_BUTTON_SKIN_PATH, "")
	action_button.name = "CharacterAction_%s" % character_id
	action_button.disabled = selected
	action_button.pressed.connect(_on_character_card_action_pressed.bind(character_id))
	stack.add_child(action_button)
	return card

func _refresh_character_selector() -> void:
	if character_card_row == null:
		return
	character_selector_currency_label.text = "%d 鑽石\nGEMS" % GameManager.get_gems()
	_clear_children(character_card_row)
	for character: Dictionary in GameManager.get_all_characters():
		character_card_row.add_child(_make_character_card(character))

func _format_character_bonus(raw_bonuses: Variant) -> String:
	if not raw_bonuses is Dictionary:
		return "無額外加成"
	var bonuses: Dictionary = raw_bonuses as Dictionary
	var parts: PackedStringArray = []
	for spec: Array in [["attack", "ATK"], ["max_hp", "HP"], ["defense", "DEF"], ["luck", "LUCK"]]:
		var value: int = maxi(0, int(bonuses.get(str(spec[0]), 0)))
		if value > 0:
			parts.append("%s +%d" % [str(spec[1]), value])
	return "無額外加成" if parts.is_empty() else "  ·  ".join(parts)

func _on_open_character_selector_pressed() -> void:
	pending_character_purchase_id = ""
	purchase_confirm_layer.visible = false
	_refresh_character_selector()
	character_selector_layer.visible = true
	character_selector_panel.pivot_offset = character_selector_panel.size * 0.5
	character_selector_panel.modulate.a = 0.0
	character_selector_panel.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_selector_panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(character_selector_panel, "scale", Vector2.ONE, 0.18)

func _on_close_character_selector_pressed() -> void:
	pending_character_purchase_id = ""
	purchase_confirm_layer.visible = false
	character_selector_layer.visible = false

func _on_character_card_action_pressed(character_id: String) -> void:
	if GameManager.is_character_unlocked(character_id):
		if GameManager.select_character(character_id):
			_refresh_all("已選用 %s" % str(GameManager.get_selected_character().get("name_zh", "主角")))
			_refresh_character_selector()
		return
	var character: Dictionary = DataManager.get_character(character_id)
	if character.is_empty():
		return
	pending_character_purchase_id = character_id
	var price: int = GameManager.get_effective_character_price(character_id)
	var price_text: String = "測試期間免費（0 鑽石）" if price == 0 and DataManager.is_character_test_price_enabled() else "%d 鑽石" % price
	purchase_confirm_label.text = "解鎖「%s」並立即使用？\n費用：%s\n目前持有：%d 鑽石" % [str(character.get("name_zh", "主角")), price_text, GameManager.get_gems()]
	purchase_confirm_layer.visible = true

func _on_cancel_character_purchase_pressed() -> void:
	pending_character_purchase_id = ""
	purchase_confirm_layer.visible = false

func _on_confirm_character_purchase_pressed() -> void:
	if pending_character_purchase_id.is_empty():
		return
	var result: Dictionary = GameManager.purchase_character(pending_character_purchase_id)
	if not bool(result.get("success", false)):
		var reason: String = str(result.get("reason", "purchase_failed"))
		message_label.text = "鑽石不足" if reason == "not_enough_gems" else "無法解鎖角色"
		return
	pending_character_purchase_id = ""
	purchase_confirm_layer.visible = false
	_refresh_all("角色已解鎖並選用")
	_refresh_character_selector()

func _make_profile_summary() -> Panel:
	var summary: Panel = UITheme.make_panel(Color(1, 0.97, 0.92, 0.96), Color("#dd9ba7"), 34, 5)
	summary.name = "ProfileSummaryPanel"
	summary.custom_minimum_size = Vector2(0, 580)
	UITheme.apply_texture_panel_skin(summary, PANEL_SKIN_PATH, 34)
	var margin: MarginContainer = _panel_margin(summary, 32)
	margin.add_theme_constant_override("margin_top", 70)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	level_label = UITheme.make_label("", 34, UITheme.INK, UITheme.FontRole.BOLD)
	level_label.name = "ProfileLevelLabel"
	exp_label = UITheme.make_label("", 19, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	exp_label.name = "ProfileExpLabel"
	stack.add_child(level_label)
	stack.add_child(exp_label)
	exp_progress = ProgressBar.new()
	exp_progress.name = "ProfileExpProgress"
	exp_progress.custom_minimum_size = Vector2(0, 18)
	exp_progress.show_percentage = false
	exp_progress.add_theme_stylebox_override("background", UITheme.rounded_style(Color("#f5ded7"), Color("#d9a59d"), 9, 2))
	exp_progress.add_theme_stylebox_override("fill", UITheme.rounded_style(Color("#f29eaa"), Color.TRANSPARENT, 9, 0))
	stack.add_child(exp_progress)
	stack.add_child(UITheme.make_zh_en_label("能力總覽", "STATS", 24, 12, UITheme.INK))
	var grid: GridContainer = GridContainer.new()
	grid.name = "ProfileStatGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(grid)
	for spec: Array in [["attack", "攻擊", "ATK"], ["max_hp", "生命", "HP"], ["defense", "防禦", "DEF"], ["luck", "幸運", "LUCK"]]:
		grid.add_child(_make_stat_summary_tile(str(spec[0]), str(spec[1]), str(spec[2])))
	stats_label = UITheme.make_label("", 1, Color.TRANSPARENT)
	stats_label.name = "ProfileStatsLabel"
	stats_label.visible = false
	stack.add_child(stats_label)
	return summary

func _make_stat_summary_tile(stat: String, chinese: String, english: String) -> Panel:
	var tile: Panel = UITheme.make_panel(Color(1.0, 0.99, 0.95, 0.72), Color("#ead2b4"), 18, 2)
	tile.name = "ProfileStat_%s" % stat
	tile.custom_minimum_size = Vector2(0, 126)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon: TextureRect = _make_sprite(str(ICON_PATHS.get(stat, "")), Vector2(54, 54))
	icon.position = Vector2(16, 36)
	tile.add_child(icon)
	var value: Label = UITheme.make_label("", 20, UITheme.INK, UITheme.FontRole.BOLD)
	value.name = "ProfileStatValue_%s" % stat
	value.position = Vector2(78, 10)
	value.size = Vector2(350, 106)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_child(value)
	stat_summary_labels[stat] = value
	value.set_meta("zh", chinese)
	value.set_meta("en", english)
	return tile

func _make_profile_actions() -> Control:
	var layer: Control = Control.new()
	layer.name = "CharacterActionLayer"
	layer.custom_minimum_size = Vector2(0, 540)
	var growth: Panel = UITheme.make_panel(Color("#fff8e8"), Color("#efc979"), 30, 4)
	growth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UITheme.apply_texture_panel_skin(growth, PANEL_SKIN_PATH, 30)
	layer.add_child(growth)
	var margin: MarginContainer = _panel_margin(growth, 30)
	margin.add_theme_constant_override("margin_top", 88)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	stack.add_child(UITheme.make_zh_en_label("能力配點", "STAT POINTS", 28, 13, UITheme.INK))
	points_label = UITheme.make_label("", 21, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	points_label.name = "StatPointsLabel"
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.custom_minimum_size = Vector2(0, 48)
	stack.add_child(points_label)
	var grid: GridContainer = GridContainer.new()
	grid.name = "StatButtonGrid"
	grid.columns = 2
	grid.custom_minimum_size = Vector2(800, 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	stack.add_child(grid)
	_add_stat_button(grid, "攻擊 +1\nATK", "attack")
	_add_stat_button(grid, "生命 +3\nMAX HP", "max_hp")
	_add_stat_button(grid, "防禦 +1\nDEF", "defense")
	_add_stat_button(grid, "幸運 +1\nLUCK", "luck")
	return layer

func _make_equipment_summary_panel() -> Panel:
	var panel: Panel = UITheme.make_panel(Color("#f4fbf6"), Color("#82c8ad"), 30, 4)
	panel.name = "EquipmentSummaryPanel"
	panel.custom_minimum_size = Vector2(0, 250)
	UITheme.apply_texture_panel_skin(panel, PANEL_SKIN_PATH, 30)
	var margin: MarginContainer = _panel_margin(panel, 28)
	margin.add_theme_constant_override("margin_top", 68)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(UITheme.make_zh_en_label("裝備加成", "EQUIPMENT BONUS", 25, 12, UITheme.INK))
	var grid: GridContainer = GridContainer.new()
	grid.name = "EquipmentBonusGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(grid)
	for spec: Array in [["attack", "攻擊", "ATK"], ["max_hp", "生命", "HP"], ["defense", "防禦", "DEF"], ["luck", "幸運", "LUCK"]]:
		var value: Label = UITheme.make_label("", 20, UITheme.MUTED_INK, UITheme.FontRole.BOLD)
		value.name = "EquipmentBonus_%s" % str(spec[0])
		value.custom_minimum_size = Vector2(0, 66)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.set_meta("zh", str(spec[1]))
		value.set_meta("en", str(spec[2]))
		grid.add_child(value)
		equipment_bonus_values[str(spec[0])] = value
	equipment_bonus_label = UITheme.make_label("", 1, Color.TRANSPARENT)
	equipment_bonus_label.name = "EquipmentBonusValueLabel"
	equipment_bonus_label.visible = false
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
	stack.custom_minimum_size = Vector2(992, 0)
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
	if bag_header_panel != null:
		bag_header_panel.visible = active_tab == TAB_BAG
	character_goblin_layer.visible = active_tab != TAB_BAG
	profile_portrait.visible = active_tab == TAB_PROFILE
	equipment_portrait.visible = active_tab == TAB_EQUIPMENT
	character_action_layer.visible = active_tab == TAB_PROFILE
	character_equipment_layer.visible = active_tab == TAB_EQUIPMENT
	for tab_id: String in TAB_IDS:
		var button: Button = tab_buttons.get(tab_id) as Button
		if button != null:
			button.button_pressed = tab_id == active_tab
			button.modulate = Color.WHITE if tab_id == active_tab else Color(0.88, 0.84, 0.80, 0.82)
			button.position.y = -4.0 if tab_id == active_tab else 0.0
	if active_tab == TAB_PROFILE:
		profile_scroll.scroll_vertical = 0
	elif active_tab == TAB_EQUIPMENT:
		equipment_scroll.scroll_vertical = 0
	else:
		bag_scroll.scroll_vertical = 0
	_clear_scroll_drag()
	_play_tab_transition(_get_active_scroll())

func _play_page_entrance() -> void:
	for portrait: TextureRect in [profile_portrait, equipment_portrait]:
		if portrait == null:
			continue
		portrait.pivot_offset = portrait.size * 0.5
		portrait.modulate.a = 0.0
		portrait.scale = Vector2(0.96, 0.96)
		var tween: Tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait, "modulate:a", 1.0, 0.18)
		tween.tween_property(portrait, "scale", Vector2.ONE, 0.18)
	var panels: Array[Control] = []
	for node_name: String in ["ProfileSummaryPanel", "CharacterActionLayer", "CharacterEquipmentLayer", "EquipmentSummaryPanel", "BagHeader"]:
		var panel: Control = find_child(node_name, true, false) as Control
		if panel != null:
			panels.append(panel)
	for index: int in range(panels.size()):
		var panel: Control = panels[index]
		panel.modulate.a = 0.0
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "modulate:a", 1.0, 0.20).set_delay(float(index) * 0.06)

func _play_tab_transition(scroll: ScrollContainer) -> void:
	if scroll == null or not scroll.visible or not is_inside_tree():
		return
	var target_x: float = scroll.position.x
	scroll.position.x = target_x + 12.0
	scroll.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll, "position:x", target_x, 0.16)
	tween.tween_property(scroll, "modulate:a", 1.0, 0.16)

func _refresh_character_portraits() -> void:
	var sprite_path: String = GameManager.get_character_sprite_path()
	if not ResourceLoader.exists(sprite_path):
		return
	var texture: Texture2D = load(sprite_path) as Texture2D
	if texture == null:
		return
	for portrait: TextureRect in [profile_portrait, equipment_portrait]:
		if portrait == null or portrait.texture == texture:
			continue
		portrait.texture = texture
		if not is_inside_tree():
			continue
		portrait.modulate.a = 0.0
		portrait.scale = Vector2(0.97, 0.97)
		var tween: Tween = create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(portrait, "modulate:a", 1.0, 0.16)
		tween.tween_property(portrait, "scale", Vector2.ONE, 0.16)

func _refresh_all(message: String = "") -> void:
	if level_label == null:
		return
	_refresh_character_portraits()
	level_label.text = "等級 %d  ·  第 %d 章" % [GameManager.get_level(), GameBalance.chapter_for_stage(int(GameManager.player_state.get("unlocked_stage", 1)))]
	exp_label.text = "經驗值 %d / %d  ·  EXP" % [GameManager.get_exp(), GameManager.get_required_exp()]
	exp_progress.max_value = maxf(1.0, float(GameManager.get_required_exp()))
	exp_progress.value = minf(float(GameManager.get_exp()), exp_progress.max_value)
	var stat_breakdown: Dictionary = GameManager.get_stat_breakdown()
	stats_label.text = _format_stat_breakdown(stat_breakdown)
	_refresh_stat_summary(stat_breakdown)
	_refresh_stat_buttons(stat_breakdown)
	if equipment_bonus_label != null:
		equipment_bonus_label.text = "目前套用：%s" % _format_stats(GameManager.get_equipped_stats())
		_refresh_equipment_bonus_grid(GameManager.get_equipped_stats())
	var total_stat_points: int = GameManager.get_total_stat_points()
	var available_stat_points: int = GameManager.get_stat_points()
	points_label.text = "可用 %d 點  ·  累計獲得 %d 點" % [available_stat_points, total_stat_points]
	inventory_count_label.text = "背包 %d / ∞\nBAG CAPACITY" % GameManager.get_inventory().size()
	coin_label.text = "%d  鑽石\n%d  金幣" % [GameManager.get_gems(), GameManager.get_coins()]
	if choose_character_button != null:
		var selected_character: Dictionary = GameManager.get_selected_character()
		UITheme.set_dual_button_text(choose_character_button, "選擇主角 · %s" % str(selected_character.get("name_zh", "主角")), "CHOOSE HERO")
	message_label.text = message
	_refresh_equipment_slots()
	_refresh_inventory()
	_refresh_active_tab()

func _refresh_stat_summary(stat_breakdown: Dictionary) -> void:
	for stat: String in stat_summary_labels:
		var label: Label = stat_summary_labels[stat] as Label
		var data: Dictionary = stat_breakdown.get(stat, {})
		if label != null:
			label.text = "%s %d  ·  %s\n等級 %d  +  加點 %d\n裝備 %d  +  角色 %d" % [
				str(label.get_meta("zh", "")),
				int(data.get("total", 0)),
				str(label.get_meta("en", "")),
				int(data.get("level", 0)),
				int(data.get("allocated_value", 0)),
				int(data.get("equipment", 0)),
				int(data.get("character", 0))
			]

func _refresh_equipment_bonus_grid(stats: Dictionary) -> void:
	for stat: String in equipment_bonus_values:
		var label: Label = equipment_bonus_values[stat] as Label
		if label == null:
			continue
		var value: int = int(stats.get(stat, 0))
		label.text = "%s +%d\n%s" % [str(label.get_meta("zh", "")), value, str(label.get_meta("en", ""))]

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
		lines.append("%s %d（等級 %d + 加點 %d + 裝備 %d + 角色 %d）" % [
			str(spec[1]),
			int(data.get("total", 0)),
			int(data.get("level", 0)),
			int(data.get("allocated_value", 0)),
			int(data.get("equipment", 0)),
			int(data.get("character", 0))
		])
	return "\n".join(lines)

func _refresh_stat_buttons(stat_breakdown: Dictionary) -> void:
	var specs: Array = [
		["attack", "攻擊 %d", "ATK · +1"],
		["max_hp", "生命 %d", "MAX HP · +3"],
		["defense", "防禦 %d", "DEF · +1"],
		["luck", "幸運 %d", "LUCK · +1"]
	]
	for spec: Array in specs:
		var stat: String = str(spec[0])
		var button: Button = stat_buttons.get(stat) as Button
		var data: Dictionary = stat_breakdown.get(stat, {})
		if button != null:
			UITheme.set_dual_button_text(button, str(spec[1]) % int(data.get("total", 0)), str(spec[2]))

func _refresh_equipment_slots() -> void:
	if equipment_row == null:
		return
	_clear_children(equipment_row)
	for slot: String in SLOT_ORDER:
		equipment_row.add_child(_make_equipment_slot_card(slot))

func _make_equipment_slot_card(slot: String) -> Panel:
	var color: Color = Color("#f8f3e7")
	var card: Panel = UITheme.make_panel(color, Color("#82c8ad"), 25, 4)
	card.name = "EquipmentSlot_%s" % slot.capitalize()
	card.custom_minimum_size = Vector2(0, 470)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_texture_panel_skin(card, SLOT_FRAME_PATH, 34)
	var margin: MarginContainer = _panel_margin(card, 20)
	margin.add_theme_constant_override("margin_top", 120)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var slot_name: Dictionary = SLOT_NAMES[slot]
	stack.add_child(UITheme.make_zh_en_label(str(slot_name["secondary"]), str(slot_name["primary"]), 23, 12, UITheme.INK))
	var uid: String = GameManager.get_equipped_uid(slot)
	var item: Dictionary = EquipmentSystem.find_item(GameManager.get_inventory(), uid)
	stack.add_child(_make_item_icon(slot, not item.is_empty(), Vector2(136, 136), item))
	var item_text: String = EquipmentSystem.describe_item(item) if not item.is_empty() else "未裝備\nEMPTY"
	var item_label: Label = UITheme.make_label(item_text, 18, EquipmentSystem.rarity_color(str(EquipmentSystem.get_item_template(item).get("rarity", "common"))) if not item.is_empty() else UITheme.MUTED_INK, UITheme.FontRole.BOLD)
	item_label.custom_minimum_size = Vector2(0, 48)
	stack.add_child(item_label)
	if item.is_empty():
		var empty_action: Control = Control.new()
		empty_action.custom_minimum_size = Vector2(0, 104)
		stack.add_child(empty_action)
	else:
		var unequip: Button = _make_small_button("卸下\nUNEQUIP", Color("#e7f1e8"), Vector2(0, 104))
		unequip.name = "UnequipButton_%s" % slot
		unequip.custom_minimum_size = Vector2(180, 104)
		unequip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		unequip.pressed.connect(_on_unequip_pressed.bind(slot))
		stack.add_child(unequip)
	return card

func _refresh_inventory() -> void:
	if inventory_list == null:
		return
	_clear_children(inventory_list)
	var inventory: Array = GameManager.get_inventory()
	if inventory_sort_button != null:
		UITheme.set_dual_button_text(inventory_sort_button, "整理", _inventory_sort_label())
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
	card.custom_minimum_size = Vector2(992, BAG_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_texture_panel_skin(card, PANEL_SKIN_PATH, 26)
	var row: Control = Control.new()
	row.name = "ItemRow_%s" % str(item.get("uid", "unknown"))
	row.position = Vector2(BAG_CARD_MARGIN, BAG_CARD_MARGIN)
	row.size = Vector2(992 - BAG_CARD_MARGIN * 2, BAG_CARD_HEIGHT - BAG_CARD_MARGIN * 2)
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
	var action_start_x: float = row.size.x - BAG_ACTION_COLUMN_WIDTH + 8.0
	var info_start_x: float = BAG_ICON_COLUMN_WIDTH + 16.0
	info.position = Vector2(info_start_x, 0)
	info.size = Vector2(action_start_x - 16.0 - info_start_x, row.size.y)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 6)
	row.add_child(info)
	var is_equipped: bool = EquipmentSystem.is_equipped(GameManager.player_state, str(item.get("uid", "")))
	if is_equipped:
		var status: Label = UITheme.make_label("已裝備  ·  EQUIPPED", 17, Color("#3e9a79"), UITheme.FontRole.BOLD)
		status.name = "EquippedBadge_%s" % str(item.get("uid", ""))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(status)
	var name_label: Label = UITheme.make_label(EquipmentSystem.describe_item(item), 25, EquipmentSystem.rarity_color(rarity), UITheme.FontRole.BOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(name_label)
	var slot_name: Dictionary = SLOT_NAMES.get(slot, {"primary": "ITEM", "secondary": "裝備"})
	var detail: Label = UITheme.make_label("%s · %s\n%s" % [str(slot_name["secondary"]), _rarity_name(rarity), _format_stats(EquipmentSystem.get_item_stats(item))], 19, UITheme.MUTED_INK)
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
	var equip_button: Button = _make_small_button("已穿戴\nEQUIPPED" if is_equipped else "穿戴\nEQUIP", Color("#a8d8c4") if is_equipped else Color("#d9ead8"), BAG_ACTION_BUTTON_SIZE, ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["equip"]))
	equip_button.name = "EquipButton_%s" % uid
	equip_button.disabled = is_equipped
	equip_button.pressed.connect(_on_equip_pressed.bind(uid))
	actions.add_child(equip_button)
	var cost: int = EquipmentSystem.upgrade_cost(item)
	var upgrade_button: Button = _make_small_button("強化 · %d 金幣\nUPGRADE" % cost, Color("#f5d88d"), BAG_ACTION_BUTTON_SIZE, ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["upgrade"]))
	upgrade_button.name = "UpgradeButton_%s" % uid
	upgrade_button.disabled = GameManager.get_coins() < cost
	upgrade_button.pressed.connect(_on_upgrade_pressed.bind(uid))
	actions.add_child(upgrade_button)
	var sell_text: String = "確認出售 +%d\nCONFIRM" % EquipmentSystem.sell_value(item) if pending_sell_uid == uid else "出售 +%d\nSELL" % EquipmentSystem.sell_value(item)
	var sell_color: Color = Color("#efa7b5") if pending_sell_uid == uid else Color("#f5ccd3")
	var sell_button: Button = _make_small_button(sell_text, sell_color, BAG_ACTION_BUTTON_SIZE, ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS["sell"]))
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
	var button: Button = _make_small_button(title, Color("#f5d88d"), Vector2(0, 124), ACTION_BUTTON_SKIN_PATH, str(ICON_PATHS.get(stat, "")))
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
	GameManager.go_to_gacha("summon", "character")

func _on_merge_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_gacha("merge", "character")

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

func _make_small_button(text_value: String, color: Color, min_size: Vector2, _logo_path: String = ACTION_BUTTON_SKIN_PATH, icon_path: String = "") -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(maxf(min_size.x, 96.0), maxf(min_size.y, 96.0))
	button.clip_contents = false
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_color_override("font_hover_color", UITheme.INK)
	button.add_theme_color_override("font_pressed_color", UITheme.INK)
	button.add_theme_color_override("font_disabled_color", UITheme.MUTED_INK)
	var radius: int = 28 if min_size.x > 140.0 else 22
	var border: Color = Color("#d7a45d")
	var normal_style: StyleBoxFlat = UITheme.rounded_style(color.lightened(0.12), border, radius, 3)
	var hover_style: StyleBoxFlat = UITheme.rounded_style(color.lightened(0.20), border.lightened(0.08), radius, 3)
	var pressed_style: StyleBoxFlat = UITheme.rounded_style(color.darkened(0.06), border.darkened(0.08), radius, 3)
	var disabled_style: StyleBoxFlat = UITheme.rounded_style(color.darkened(0.12), Color("#c9ae8b"), radius, 2)
	disabled_style.shadow_size = 2
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	UITheme.apply_font(button, UITheme.FontRole.BOLD)
	var separator_index: int = text_value.find("\n")
	var primary: String = text_value if separator_index < 0 else text_value.substr(0, separator_index)
	var secondary: String = "" if separator_index < 0 else text_value.substr(separator_index + 1)
	var content: HBoxContainer = HBoxContainer.new()
	content.name = "ButtonContent"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12.0
	content.offset_top = 8.0
	content.offset_right = -12.0
	content.offset_bottom = -8.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4 if min_size.x <= 140.0 else 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.z_index = 2
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon_size: float = 34.0 if min_size.x <= 140.0 else 42.0
		var icon: TextureRect = _make_sprite(icon_path, Vector2(icon_size, icon_size))
		icon.name = "ButtonIcon"
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		content.add_child(icon)
	var labels: VBoxContainer = UITheme.make_zh_en_label(primary, secondary, 20 if min_size.x <= 140.0 else 22, 10 if min_size.x <= 140.0 else 12, UITheme.INK)
	labels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(labels)
	button.add_child(content)
	button.button_down.connect(_animate_button_down.bind(button))
	button.button_up.connect(_animate_button_up.bind(button))
	return button

func _animate_button_down(button: Button) -> void:
	if button == null or button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.08)

func _animate_button_up(button: Button) -> void:
	if button == null or button.disabled:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.10)

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
	return GameManager.get_character_sprite_path()

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
