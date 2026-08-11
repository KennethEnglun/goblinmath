extends Control

## Offline gacha screen with independent visual layers and a merge mode.
const BACKGROUND_PATH: String = "res://assets/ui/gacha/gacha_background_v1.png"
const AMBIENT_PATH: String = "res://assets/ui/gacha/gacha_ambient_effects_v1.png"
const SHARED_AMBIENT_PATH: String = "res://assets/ui/start/start_effects_v2.png"
const PLAYER_PATH: String = "res://assets/ui/start/goblin_start_v2.png"
const PLAYER_FALLBACK_PATH: String = "res://assets/characters/goblin_placeholder.svg"
const SUMMON_PEDESTAL_PATH: String = "res://assets/ui/gacha/gacha_summon_pedestal_v1.png"
const SUMMON_CIRCLE_PATH: String = "res://assets/ui/gacha/gacha_summon_circle_v1.png"
const PANEL_SKIN_PATH: String = "res://assets/ui/gacha/gacha_panel_skin_v1.png"
const RESULT_CARD_PATH: String = "res://assets/ui/gacha/gacha_result_card_frame_v1.png"
const BUTTON_SKIN_PATH: String = "res://assets/ui/gacha/gacha_button_skin_v1.png"
const MERGE_EFFECT_PATH: String = "res://assets/ui/gacha/gacha_merge_effect_v1.png"
const DIAMOND_ICON_PATH: String = "res://assets/ui/gacha/gacha_diamond_icon_v1.png"
const AD_LOCK_BADGE_PATH: String = "res://assets/ui/gacha/gacha_ad_lock_badge_v1.png"
const CORNER_ORNAMENT_PATH: String = "res://assets/ui/gacha/gacha_corner_ornament_v2.png"
const TITLE_DIVIDER_PATH: String = "res://assets/ui/gacha/gacha_title_divider_v2_cropped.png"
const CENTER_MEDALLION_PATH: String = "res://assets/ui/gacha/gacha_center_medallion_v2.png"
const SHARED_PANEL_SKIN_PATH: String = "res://assets/ui/character/character_panel_skin_v1.png"
const SHARED_BUTTON_SKIN_PATH: String = "res://assets/ui/character/character_action_button_skin_v1.png"
const SHARED_SLOT_FRAME_PATH: String = "res://assets/ui/character/character_slot_frame_v1.png"
const SHARED_ICON_PATHS: Dictionary = {
	"weapon": "res://assets/equipment/icons/equipment_weapon_v1.png",
	"head": "res://assets/equipment/icons/equipment_head_v1.png",
	"body": "res://assets/equipment/icons/equipment_body_v1.png"
}
const SLOT_NAMES: Dictionary = {"weapon": "武器", "head": "頭部", "body": "身體"}

var top_offset: float = 0.0
var active_mode: String = "summon"
var selected_merge_uids: Array[String] = []
var selected_merge_template: String = ""
var toast_tween: Tween

var gacha_background_layer: Control
var gacha_ambient_layer: Control
var gacha_summon_layer: Control
var gacha_panel_layer: Control
var gacha_result_layer: Control
var gacha_merge_layer: Control
var gacha_hud_layer: Control
var gacha_action_layer: Control
var gacha_toast_layer: Control

var gem_label: Label
var summon_panel: Panel
var merge_panel: Panel
var action_panel: Panel
var summary_label: Label
var pool_label: Label
var merge_selection_label: Label
var merge_scroll: ScrollContainer
var merge_content: VBoxContainer
var merge_button: Button
var single_pull_button: Button
var ten_pull_button: Button
var watch_ad_button: Button
var summon_action_row: HBoxContainer
var summon_tab_button: Button
var merge_tab_button: Button
var result_list: VBoxContainer
var result_info_label: Label
var goblin_sprite: TextureRect

func _ready() -> void:
	_build_visual_layers()
	_build_hud()
	_build_summon_stage()
	_build_main_panels()
	_build_actions()
	_build_result_layer()
	_build_toast_layer()
	var ad_service: Node = _get_rewarded_ad_service()
	var ad_callback: Callable = Callable(self, "_on_rewarded_ad_completed")
	if ad_service != null and not ad_service.is_connected("reward_completed", ad_callback):
		ad_service.connect("reward_completed", ad_callback)
	_set_mode("summon")
	_refresh()

func _build_visual_layers() -> void:
	top_offset = maxf(0.0, UITheme.safe_area_insets(self).y - 86.0)
	gacha_background_layer = _make_layer("GachaBackgroundLayer", Control.MOUSE_FILTER_IGNORE)
	var background: TextureRect = TextureRect.new()
	background.name = "GachaBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKGROUND_PATH):
		background.texture = load(BACKGROUND_PATH)
	gacha_background_layer.add_child(background)
	if background.texture == null:
		var fallback: TextureRect = UITheme.add_gradient_background(gacha_background_layer, Color("#f7c8da"), Color("#fff0cf"))
		fallback.name = "GachaBackgroundFallback"

	gacha_ambient_layer = _make_layer("GachaAmbientLayer", Control.MOUSE_FILTER_IGNORE)
	var ambient: TextureRect = TextureRect.new()
	ambient.name = "GachaAmbientEffects"
	ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ambient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ambient.stretch_mode = TextureRect.STRETCH_SCALE
	ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ambient_path: String = AMBIENT_PATH if ResourceLoader.exists(AMBIENT_PATH) else SHARED_AMBIENT_PATH
	if ResourceLoader.exists(ambient_path):
		ambient.texture = load(ambient_path)
	ambient.modulate = Color(1.0, 1.0, 1.0, 0.34)
	gacha_ambient_layer.add_child(ambient)

	gacha_summon_layer = _make_layer("GachaSummonLayer", Control.MOUSE_FILTER_IGNORE)
	# Full-screen layer roots are layout-only; only their child controls should
	# participate in hit testing so action buttons never block each other.
	gacha_panel_layer = _make_layer("GachaPanelLayer", Control.MOUSE_FILTER_IGNORE)
	gacha_result_layer = _make_layer("GachaResultLayer", Control.MOUSE_FILTER_IGNORE)
	gacha_merge_layer = _make_layer("GachaMergeLayer", Control.MOUSE_FILTER_IGNORE)
	gacha_hud_layer = _make_layer("GachaHudLayer", Control.MOUSE_FILTER_IGNORE)
	gacha_action_layer = _make_layer("GachaActionLayer", Control.MOUSE_FILTER_IGNORE)
	gacha_toast_layer = _make_layer("GachaToastLayer", Control.MOUSE_FILTER_IGNORE)
	UITheme.set_layer_order(gacha_background_layer, 0)
	UITheme.set_layer_order(gacha_ambient_layer, 1)
	UITheme.set_layer_order(gacha_summon_layer, 5)
	UITheme.set_layer_order(gacha_panel_layer, 10)
	UITheme.set_layer_order(gacha_merge_layer, 12)
	UITheme.set_layer_order(gacha_action_layer, 20)
	UITheme.set_layer_order(gacha_hud_layer, 30)
	UITheme.set_layer_order(gacha_result_layer, 100)
	UITheme.set_layer_order(gacha_toast_layer, 120)

func _build_hud() -> void:
	var header: Control = Control.new()
	header.name = "GachaHeader"
	header.position = Vector2(60, 86 + top_offset)
	header.size = Vector2(960, 108)
	gacha_hud_layer.add_child(header)
	var back_button: Button = _make_button("MAP", "地圖", Color("#d9edf0"), Vector2(202, 100))
	back_button.name = "BackToMapButton"
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	var title: VBoxContainer = UITheme.make_dual_label("GACHA", "轉蛋", 39, 20, UITheme.INK)
	title.name = "GachaTitle"
	title.position = Vector2(329, 0)
	title.size = Vector2(300, 104)
	header.add_child(title)
	var gem_badge: Panel = UITheme.make_panel(Color("#e8ddff"), Color("#b79bdf"), 28, 4)
	gem_badge.name = "GemBadge"
	gem_badge.position = Vector2(700, 8)
	gem_badge.size = Vector2(258, 90)
	var diamond_icon: TextureRect = _make_sprite(DIAMOND_ICON_PATH, Vector2(58, 58))
	diamond_icon.name = "DiamondIcon"
	diamond_icon.position = Vector2(10, 16)
	gem_badge.add_child(diamond_icon)
	gem_label = UITheme.make_label("", 25, Color("#80599e"))
	gem_label.position = Vector2(72, 4)
	gem_label.size = Vector2(176, 82)
	gem_badge.add_child(gem_label)
	header.add_child(gem_badge)

	var mode_bar: HBoxContainer = HBoxContainer.new()
	mode_bar.name = "GachaModeTabs"
	mode_bar.position = Vector2(140, 242 + top_offset)
	mode_bar.size = Vector2(800, 110)
	mode_bar.add_theme_constant_override("separation", 80)
	gacha_hud_layer.add_child(mode_bar)
	summon_tab_button = _make_button("SUMMON", "抽裝備", Color("#f6b6c8"), Vector2(0, 108))
	summon_tab_button.name = "SummonTabButton"
	summon_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summon_tab_button.pressed.connect(_on_summon_tab_pressed)
	_style_tab_button(summon_tab_button, Color("#f6c2c7"))
	_decorate_tab_button(summon_tab_button)
	mode_bar.add_child(summon_tab_button)
	merge_tab_button = _make_button("MERGE", "三件合成", Color("#bfe7d3"), Vector2(0, 108))
	merge_tab_button.name = "MergeTabButton"
	merge_tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	merge_tab_button.pressed.connect(_on_merge_tab_pressed)
	_style_tab_button(merge_tab_button, Color("#c9e4b1"))
	_decorate_tab_button(merge_tab_button)
	mode_bar.add_child(merge_tab_button)

func _build_summon_stage() -> void:
	var glow: Panel = UITheme.make_panel(Color(1.0, 0.92, 0.76, 0.45), Color(1.0, 0.84, 0.55, 0.0), 180, 0)
	glow.name = "SummonGlow"
	glow.position = Vector2(250, 350 + top_offset)
	glow.size = Vector2(580, 340)
	gacha_summon_layer.add_child(glow)
	var circle: TextureRect = _make_texture_or_fallback("SummonCircle", SUMMON_CIRCLE_PATH, Vector2(540, 190), Color(1.0, 0.9, 0.72, 0.6))
	circle.position = Vector2(270, 545 + top_offset)
	gacha_summon_layer.add_child(circle)
	var pedestal: TextureRect = _make_texture_or_fallback("SummonPedestal", SUMMON_PEDESTAL_PATH, Vector2(560, 190), Color(1.0, 0.9, 0.82, 1.0))
	pedestal.position = Vector2(260, 555 + top_offset)
	gacha_summon_layer.add_child(pedestal)
	goblin_sprite = _make_sprite(_get_player_sprite_path(), Vector2(300, 300))
	goblin_sprite.name = "GachaGoblinShowcase"
	goblin_sprite.position = Vector2(390, 330 + top_offset)
	gacha_summon_layer.add_child(goblin_sprite)
	goblin_sprite.pivot_offset = goblin_sprite.size * 0.5
	var breathe: Tween = create_tween().set_loops()
	breathe.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(goblin_sprite, "scale", Vector2(1.025, 1.025), 1.3)
	breathe.tween_property(goblin_sprite, "scale", Vector2.ONE, 1.3)

func _build_main_panels() -> void:
	summon_panel = _make_panel("SummonPanel", Color("#fff8ed"), Color("#e3a4b5"), Vector2(46, 735 + top_offset), Vector2(988, 525), PANEL_SKIN_PATH, SHARED_PANEL_SKIN_PATH)
	gacha_panel_layer.add_child(summon_panel)
	var summon_stack: VBoxContainer = _panel_stack(summon_panel, 24)
	summon_stack.add_child(UITheme.make_dual_label("EQUIPMENT SUMMON", "抽取可用裝備", 30, 18, UITheme.INK))
	summary_label = UITheme.make_label("", 24, UITheme.MUTED_INK)
	summary_label.name = "GachaSummaryLabel"
	summary_label.custom_minimum_size = Vector2(0, 78)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summon_stack.add_child(summary_label)
	pool_label = UITheme.make_label("", 23, UITheme.MUTED_INK)
	pool_label.name = "GachaPoolLabel"
	pool_label.custom_minimum_size = Vector2(0, 100)
	pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summon_stack.add_child(pool_label)

	merge_panel = _make_panel("MergePanel", Color("#f4fbf6"), Color("#82c8ad"), Vector2(46, 315 + top_offset), Vector2(988, 1155), PANEL_SKIN_PATH, SHARED_PANEL_SKIN_PATH)
	gacha_merge_layer.add_child(merge_panel)
	var merge_divider: TextureRect = _make_sprite(TITLE_DIVIDER_PATH, Vector2(600, 58))
	merge_divider.name = "MergeTitleDivider"
	merge_divider.position = Vector2(244, 133)
	merge_divider.size = Vector2(500, 30)
	merge_divider.stretch_mode = TextureRect.STRETCH_SCALE
	merge_divider.modulate = Color(1.0, 1.0, 1.0, 0.86)
	merge_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merge_panel.add_child(merge_divider)
	var merge_stack: VBoxContainer = _panel_stack(merge_panel, 34)
	merge_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	merge_stack.z_index = 2
	var merge_top_spacer: Control = Control.new()
	merge_top_spacer.custom_minimum_size = Vector2(0, 105)
	merge_stack.add_child(merge_top_spacer)
	var merge_title: VBoxContainer = UITheme.make_dual_label("EQUIPMENT MERGE", "裝備合成", 34, 18, UITheme.INK)
	merge_title.custom_minimum_size = Vector2(0, 76)
	merge_stack.add_child(merge_title)
	merge_selection_label = UITheme.make_label("", 24, UITheme.MUTED_INK)
	merge_selection_label.name = "MergeSelectionLabel"
	merge_selection_label.custom_minimum_size = Vector2(0, 98)
	merge_stack.add_child(merge_selection_label)
	merge_scroll = ScrollContainer.new()
	merge_scroll.name = "MergeScroll"
	merge_scroll.custom_minimum_size = Vector2(0, 760)
	merge_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	merge_stack.add_child(merge_scroll)
	merge_content = VBoxContainer.new()
	merge_content.name = "MergeContent"
	merge_content.custom_minimum_size = Vector2(920, 0)
	merge_content.add_theme_constant_override("separation", 10)
	merge_scroll.add_child(merge_content)

func _build_actions() -> void:
	action_panel = _make_panel("ActionPanel", Color(1.0, 0.96, 0.86, 0.96), Color("#e5b95e"), Vector2(46, 1290 + top_offset), Vector2(988, 390), "", SHARED_PANEL_SKIN_PATH)
	gacha_action_layer.add_child(action_panel)
	var action_medallion: TextureRect = _make_sprite(CENTER_MEDALLION_PATH, Vector2(200, 128))
	action_medallion.name = "MergeActionMedallion"
	action_medallion.position = Vector2(394, -60)
	action_panel.add_child(action_medallion)
	var stack: VBoxContainer = _panel_stack(action_panel, 22)
	summon_action_row = HBoxContainer.new()
	summon_action_row.name = "SummonActionRow"
	summon_action_row.add_theme_constant_override("separation", 12)
	stack.add_child(summon_action_row)
	var gacha_config: Dictionary = DataManager.get_gacha_config()
	var single_cost: int = int(gacha_config.get("single_cost", GameBalance.GACHA_SINGLE_COST))
	var ten_cost: int = int(gacha_config.get("ten_cost", GameBalance.GACHA_TEN_COST))
	var ad_reward: int = int(gacha_config.get("ad_reward", GameBalance.AD_GEM_REWARD))
	single_pull_button = _make_button("1 PULL", "%d 鑽石" % single_cost, Color("#ffe19a"), Vector2(0, 112))
	single_pull_button.name = "SinglePullButton"
	single_pull_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	single_pull_button.pressed.connect(_on_single_pull_pressed)
	summon_action_row.add_child(single_pull_button)
	ten_pull_button = _make_button("10 PULLS", "%d 鑽石" % ten_cost, Color("#ffb6c6"), Vector2(0, 112))
	ten_pull_button.name = "TenPullButton"
	ten_pull_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ten_pull_button.pressed.connect(_on_ten_pull_pressed)
	summon_action_row.add_child(ten_pull_button)
	watch_ad_button = _make_button("WATCH AD", "觀看廣告 +%d\n廣告功能尚未開放" % ad_reward, Color("#d8d1d0"), Vector2(0, 112))
	watch_ad_button.name = "WatchAdButton"
	watch_ad_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch_ad_button.disabled = not _is_rewarded_ad_available()
	watch_ad_button.tooltip_text = "廣告功能尚未開放"
	var ad_lock_badge: TextureRect = _make_sprite(AD_LOCK_BADGE_PATH, Vector2(54, 54))
	ad_lock_badge.name = "AdLockBadge"
	ad_lock_badge.position = Vector2(10, 29)
	ad_lock_badge.modulate = Color(1.0, 1.0, 1.0, 0.72)
	watch_ad_button.add_child(ad_lock_badge)
	summon_action_row.add_child(watch_ad_button)
	merge_button = _make_button("MERGE", "合成 0 / 3", Color("#bfe7d3"), Vector2(0, 112))
	merge_button.name = "MergeButton"
	merge_button.custom_minimum_size = Vector2(780, 112)
	merge_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	merge_button.pressed.connect(_on_merge_pressed)
	stack.add_child(merge_button)
	var help: Label = UITheme.make_label("相同模板、Lv.1、未穿戴的三件裝備可以合成下一階。\n廣告獎勵將在未來版本接入。", 21, UITheme.MUTED_INK)
	help.name = "GachaHelpLabel"
	help.custom_minimum_size = Vector2(0, 90)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(help)

func _build_result_layer() -> void:
	gacha_result_layer.visible = false
	var overlay: ColorRect = ColorRect.new()
	overlay.name = "GachaResultOverlay"
	overlay.color = Color(0.18, 0.12, 0.16, 0.62)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The dimmer blocks the background while the explicit panel z-order keeps
	# its result controls above the modal backdrop.
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	gacha_result_layer.add_child(overlay)
	var result_panel: Panel = _make_panel("ResultPanel", Color("#fff8ed"), Color("#e5b95e"), Vector2(70, 300 + top_offset), Vector2(940, 1300), RESULT_CARD_PATH, SHARED_PANEL_SKIN_PATH)
	result_panel.z_index = 1
	gacha_result_layer.add_child(result_panel)
	var stack: VBoxContainer = _panel_stack(result_panel, 22)
	stack.add_child(UITheme.make_dual_label("SUMMON RESULT", "轉蛋結果", 38, 22, UITheme.INK))
	result_info_label = UITheme.make_label("", 22, UITheme.MUTED_INK)
	result_info_label.name = "GachaResultInfoLabel"
	result_info_label.custom_minimum_size = Vector2(0, 48)
	stack.add_child(result_info_label)
	var result_scroll: ScrollContainer = ScrollContainer.new()
	result_scroll.name = "ResultScroll"
	result_scroll.custom_minimum_size = Vector2(0, 880)
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(result_scroll)
	result_list = VBoxContainer.new()
	result_list.name = "ResultList"
	result_list.custom_minimum_size = Vector2(850, 0)
	result_list.add_theme_constant_override("separation", 10)
	result_scroll.add_child(result_list)
	var close_button: Button = _make_button("CLOSE", "關閉結果", Color("#d9edf0"), Vector2(0, 104))
	close_button.name = "CloseResultButton"
	close_button.pressed.connect(_on_close_result_pressed)
	stack.add_child(close_button)

func _build_toast_layer() -> void:
	var toast: Panel = UITheme.make_panel(Color(0.36, 0.18, 0.2, 0.94), Color("#f2b4bb"), 28, 3)
	toast.name = "GachaToast"
	toast.position = Vector2(120, 1770 + top_offset)
	toast.size = Vector2(840, 92)
	toast.visible = false
	gacha_toast_layer.add_child(toast)
	var label: Label = UITheme.make_label("", 22, Color.WHITE)
	label.name = "GachaToastLabel"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast.add_child(label)

func _set_mode(mode: String) -> void:
	if mode != "summon" and mode != "merge":
		return
	active_mode = mode
	if summon_panel != null:
		summon_panel.visible = active_mode == "summon"
	if merge_panel != null:
		merge_panel.visible = active_mode == "merge"
	if gacha_summon_layer != null:
		gacha_summon_layer.visible = active_mode == "summon"
	if single_pull_button != null:
		single_pull_button.visible = active_mode == "summon"
	if ten_pull_button != null:
		ten_pull_button.visible = active_mode == "summon"
	if watch_ad_button != null:
		watch_ad_button.visible = active_mode == "summon"
	if summon_action_row != null:
		summon_action_row.visible = active_mode == "summon"
	if merge_button != null:
		merge_button.visible = active_mode == "merge"
	if summon_tab_button != null:
		summon_tab_button.button_pressed = active_mode == "summon"
	if merge_tab_button != null:
		merge_tab_button.button_pressed = active_mode == "merge"
	if action_panel != null:
		# The merge list is taller than the summon copy. Keep the action tray
		# below it so selectable materials never sit underneath a button panel.
		action_panel.position.y = (1490.0 if active_mode == "merge" else 1290.0) + top_offset
	if active_mode == "merge":
		_refresh_merge_panel()

func _refresh() -> void:
	if gem_label == null:
		return
	gem_label.text = "%d\n鑽石" % GameManager.get_gems()
	var available: Array[String] = GachaSystem.get_available_rarities(int(GameManager.player_state.get("highest_completed_stage", 0)))
	var rarity_text: Array[String] = []
	for rarity: String in available:
		rarity_text.append(_rarity_name(rarity))
	var stage_text: String = "最高完成 Stage %d" % int(GameManager.player_state.get("highest_completed_stage", 0))
	summary_label.text = "目前可抽取：%s\n%s" % [", ".join(rarity_text), stage_text]
	pool_label.text = "機率會依已解鎖稀有度重新計算。\n十連抽在有更高階池時保證至少一件 Uncommon 以上。"
	var gacha_config: Dictionary = DataManager.get_gacha_config()
	var current_gems: int = GameManager.get_gems()
	var single_cost: int = int(gacha_config.get("single_cost", GameBalance.GACHA_SINGLE_COST))
	var ten_cost: int = int(gacha_config.get("ten_cost", GameBalance.GACHA_TEN_COST))
	if single_pull_button != null:
		single_pull_button.disabled = current_gems < single_cost
	if ten_pull_button != null:
		ten_pull_button.disabled = current_gems < ten_cost
	_refresh_merge_panel()
	_set_mode(active_mode)

func _refresh_merge_panel() -> void:
	if merge_content == null:
		return
	var valid_uids: Array[String] = []
	for uid: String in selected_merge_uids:
		var selected_item: Dictionary = EquipmentSystem.find_item(GameManager.get_inventory(), uid)
		if not selected_item.is_empty() and int(selected_item.get("level", 1)) == 1 and not EquipmentSystem.is_equipped(GameManager.player_state, uid):
			valid_uids.append(uid)
	selected_merge_uids = valid_uids
	if selected_merge_uids.is_empty():
		selected_merge_template = ""
	merge_selection_label.text = "MATERIALS %d / 3\n選擇三件完全相同、Lv.1、未穿戴的裝備" % selected_merge_uids.size()
	UITheme.set_dual_button_text(merge_button, "MERGE", "合成 %d / 3" % selected_merge_uids.size())
	merge_button.disabled = selected_merge_uids.size() != 3
	_clear_children(merge_content)
	var inventory: Array = GameManager.get_inventory()
	var templates: Array = DataManager.get_all_equipment()
	var available_rarities: Array[String] = GachaSystem.get_available_rarities(int(GameManager.player_state.get("highest_completed_stage", 0)))
	templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _template_item_count(str(a.get("id", "")), inventory) > _template_item_count(str(b.get("id", "")), inventory)
	)
	var added_group: bool = false
	for template: Dictionary in templates:
		if not available_rarities.has(str(template.get("rarity", "common"))) or str(template.get("merge_to", "")).is_empty():
			continue
		var template_id: String = str(template.get("id", ""))
		var items: Array = []
		for raw_item: Variant in inventory:
			if raw_item is Dictionary and str(raw_item.get("template_id", "")) == template_id:
				items.append(raw_item)
		added_group = true
		merge_content.add_child(_make_merge_group(template, items))
	if not added_group:
		merge_content.add_child(UITheme.make_label("EMPTY MATERIALS\n尚未有可合成的裝備。", 24, UITheme.MUTED_INK))

func _make_merge_group(template: Dictionary, items: Array) -> Panel:
	var rarity: String = str(template.get("rarity", "common"))
	var group: Panel = UITheme.make_panel(Color("#fffaf3"), Color("#dfc28f"), 24, 3)
	group.name = "MergeGroup_%s" % str(template.get("id", "unknown"))
	group.custom_minimum_size = Vector2(0, 300)
	var margin: MarginContainer = _panel_margin(group, 18)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var target_id: String = GachaSystem.get_merge_target(str(template.get("id", "")))
	var target: Dictionary = DataManager.get_equipment(target_id)
	var title: String = "%s · %s" % [str(template.get("name_zh", template.get("name", "裝備"))), _rarity_name(rarity)]
	if not target.is_empty():
		title += "  →  %s" % str(target.get("name_zh", target.get("name", "下一階")))
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "MergeGroupHeader"
	header.custom_minimum_size = Vector2(0, 120)
	header.add_theme_constant_override("separation", 14)
	stack.add_child(header)
	header.add_child(_make_item_icon(str(template.get("id", "")), str(template.get("slot", "weapon")), Vector2(100, 100), rarity))
	var title_label: Label = UITheme.make_label("%s\n(%d 件)" % [title, items.size()], 24, UITheme.INK)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "MergeMaterialRow"
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 154)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.add_child(row)
	var leading_space: Control = Control.new()
	leading_space.custom_minimum_size = Vector2(138, 0)
	row.add_child(leading_space)
	var shown: int = 0
	for raw_item: Variant in items:
		if not raw_item is Dictionary:
			continue
		var item: Dictionary = raw_item
		var uid: String = str(item.get("uid", ""))
		var is_valid: bool = int(item.get("level", 1)) == 1 and not EquipmentSystem.is_equipped(GameManager.player_state, uid)
		var item_button: Button = _make_merge_material_button(item, template, rarity, is_valid, selected_merge_uids.has(uid))
		if is_valid:
			item_button.pressed.connect(_on_merge_item_pressed.bind(uid, str(template.get("id", ""))))
		row.add_child(item_button)
		shown += 1
		if shown >= 7:
			break
	return group

func _make_merge_material_button(item: Dictionary, template: Dictionary, rarity: String, is_valid: bool, is_selected: bool) -> Button:
	var item_button: Button = Button.new()
	var base_color: Color = Color("#d9f1d0") if is_selected else Color("#fff0ee")
	if not is_valid:
		base_color = Color("#e5ded9")
	item_button.name = "MergeItem_%s" % str(item.get("uid", ""))
	item_button.custom_minimum_size = Vector2(120, 154)
	item_button.focus_mode = Control.FOCUS_NONE
	item_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item_button.add_theme_stylebox_override("normal", UITheme.rounded_style(base_color, Color("#c99b48"), 18, 3))
	item_button.add_theme_stylebox_override("hover", UITheme.rounded_style(base_color.lightened(0.06), Color("#b98234"), 18, 4))
	item_button.add_theme_stylebox_override("pressed", UITheme.rounded_style(base_color.darkened(0.06), Color("#a8782f"), 18, 4))
	item_button.add_theme_stylebox_override("disabled", UITheme.rounded_style(base_color.darkened(0.12), Color("#b9aaa2"), 18, 3))
	item_button.disabled = not is_valid
	var material_icon: Panel = _make_item_icon(str(template.get("id", "")), str(template.get("slot", "weapon")), Vector2(98, 98), rarity)
	material_icon.position = Vector2(11, 8)
	material_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_button.add_child(material_icon)
	var level_label: Label = UITheme.make_label("Lv.%d" % int(item.get("level", 1)), 20, UITheme.INK if is_valid else UITheme.MUTED_INK)
	level_label.position = Vector2(0, 108)
	level_label.size = Vector2(120, 36)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_button.add_child(level_label)
	if is_valid:
		var badge: Panel = _make_selection_badge(is_selected)
		badge.position = Vector2(86, 2)
		item_button.add_child(badge)
	return item_button

func _make_selection_badge(is_selected: bool = false) -> Panel:
	var badge: Panel = Panel.new()
	badge.name = "SelectedBadge"
	badge.size = Vector2(32, 32)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_color: Color = Color("#72bd7d") if is_selected else Color("#a8d99c")
	var badge_border: Color = Color("#4f965f") if is_selected else Color("#78ad6f")
	badge.add_theme_stylebox_override("panel", UITheme.rounded_style(badge_color, badge_border, 16, 2))
	var check: Label = UITheme.make_label("✓", 20, Color.WHITE)
	check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(check)
	return badge

func _template_item_count(template_id: String, inventory: Array) -> int:
	var count: int = 0
	for raw_item: Variant in inventory:
		if raw_item is Dictionary and str(raw_item.get("template_id", "")) == template_id:
			count += 1
	return count

func _on_merge_item_pressed(uid: String, template_id: String) -> void:
	if selected_merge_uids.has(uid):
		selected_merge_uids.erase(uid)
		if selected_merge_uids.is_empty():
			selected_merge_template = ""
	else:
		if selected_merge_uids.size() >= 3:
			_show_toast("SELECTED 3 / 3\n已經選滿三件。")
			return
		if not selected_merge_template.is_empty() and selected_merge_template != template_id:
			_show_toast("SAME ITEM ONLY\n合成必須選擇相同模板。")
			return
		selected_merge_template = template_id
		selected_merge_uids.append(uid)
	_refresh_merge_panel()

func _on_single_pull_pressed() -> void:
	_perform_pull(1)

func _on_ten_pull_pressed() -> void:
	_perform_pull(10)

func _perform_pull(count: int) -> void:
	var result: Dictionary = GameManager.pull_gacha(count)
	if not bool(result.get("success", false)):
		_show_toast(_reason_text(str(result.get("reason", "pull_failed"))))
		_refresh()
		return
	AudioManager.play_sfx("button_click")
	_refresh()
	_show_results(result)

func _on_merge_pressed() -> void:
	if selected_merge_uids.size() != 3:
		_show_toast("NEED THREE ITEMS\n請選擇三件有效材料。")
		return
	var result: Dictionary = GameManager.merge_equipment(selected_merge_uids)
	if bool(result.get("success", false)):
		var item: Dictionary = result.get("item", {})
		selected_merge_uids.clear()
		selected_merge_template = ""
		_refresh()
		_play_merge_effect()
		_show_toast("MERGE SUCCESS\n合成了 %s！" % EquipmentSystem.describe_item(item))
	else:
		_show_toast(_reason_text(str(result.get("reason", "merge_failed"))))
	_refresh()

func _show_results(result: Dictionary) -> void:
	_clear_children(result_list)
	var items: Variant = result.get("items", [])
	if not items is Array:
		return
	result_info_label.text = "%s\n剩餘鑽石 %d" % ["十連保底已生效" if bool(result.get("guaranteed", false)) else "抽取完成", GameManager.get_gems()]
	for raw_item: Variant in items:
		if raw_item is Dictionary:
			result_list.add_child(_make_result_card(raw_item))
	# A result is a modal state. Hide the action tray while it is open so the
	# underlying pull/merge controls can never win the hit test over CLOSE.
	gacha_action_layer.visible = false
	gacha_result_layer.visible = true

func _play_merge_effect() -> void:
	if not ResourceLoader.exists(MERGE_EFFECT_PATH) or gacha_merge_layer == null:
		return
	var effect: TextureRect = _make_sprite(MERGE_EFFECT_PATH, Vector2(420, 420))
	effect.name = "MergeSuccessEffect"
	effect.position = Vector2(330, 315 + top_offset)
	effect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	effect.pivot_offset = effect.size * 0.5
	gacha_merge_layer.add_child(effect)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "modulate:a", 0.95, 0.16)
	tween.tween_property(effect, "scale", Vector2(1.08, 1.08), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(effect, "modulate:a", 0.0, 0.42)
	tween.chain().tween_callback(effect.queue_free)

func _make_result_card(item: Dictionary) -> Panel:
	var template: Dictionary = EquipmentSystem.get_item_template(item)
	var rarity: String = str(template.get("rarity", item.get("rarity", "common")))
	var slot: String = str(template.get("slot", "weapon"))
	var card: Panel = UITheme.make_panel(Color(1.0, 0.98, 0.94, 0.98), EquipmentSystem.rarity_color(rarity), 22, 4)
	card.custom_minimum_size = Vector2(0, 132)
	var margin: MarginContainer = _panel_margin(card, 10)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	row.add_child(_make_item_icon(str(template.get("id", "")), slot, Vector2(96, 96), rarity))
	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(UITheme.make_label("%s  Lv.1" % str(template.get("name_zh", template.get("name", "裝備"))), 23, EquipmentSystem.rarity_color(rarity)))
	info.add_child(UITheme.make_label("%s · %s" % [str(SLOT_NAMES.get(slot, "裝備")), _rarity_name(rarity)], 19, UITheme.MUTED_INK))
	return card

func _on_close_result_pressed() -> void:
	AudioManager.play_sfx("button_click")
	gacha_result_layer.visible = false
	gacha_action_layer.visible = true

func _on_rewarded_ad_completed(reward_gems: int) -> void:
	var configured_reward: int = int(DataManager.get_gacha_config().get("ad_reward", GameBalance.AD_GEM_REWARD))
	if reward_gems != configured_reward:
		return
	if GameManager.add_gems(configured_reward, "rewarded_ad"):
		_refresh()
		_show_toast("AD REWARD\n獲得 %d 鑽石！" % configured_reward)

func _get_rewarded_ad_service() -> Node:
	return get_node_or_null("/root/RewardedAdService") as Node

func _is_rewarded_ad_available() -> bool:
	var ad_service: Node = _get_rewarded_ad_service()
	return ad_service != null and bool(ad_service.call("is_available"))

func _on_summon_tab_pressed() -> void:
	_set_mode("summon")

func _on_merge_tab_pressed() -> void:
	_set_mode("merge")

func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_click")
	GameManager.go_to_world_map()

func _show_toast(text_value: String) -> void:
	var toast: Panel = gacha_toast_layer.get_node_or_null("GachaToast") as Panel
	var label: Label = toast.get_node_or_null("GachaToastLabel") as Label if toast != null else null
	if toast == null or label == null:
		return
	label.text = text_value
	toast.visible = true
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	toast_tween.tween_callback(func() -> void: toast.visible = false)

func _reason_text(reason: String) -> String:
	return {
		"not_enough_gems": "NOT ENOUGH GEMS\n鑽石不足。",
		"empty_gacha_pool": "POOL LOCKED\n目前沒有可抽取的裝備。",
		"requires_three_items": "NEED THREE ITEMS\n需要三件材料。",
		"item_must_be_level_one": "LEVEL ONE ONLY\n強化過的裝備不能合成。",
		"equipped_item": "EQUIPPED ITEM\n穿戴中的裝備不能合成。",
		"templates_must_match": "SAME ITEM ONLY\n請選擇相同模板。",
		"max_rarity": "MAX RARITY\n這件裝備已經是最高階。"
	}.get(reason, "TRY AGAIN\n操作未完成。")

func _rarity_name(rarity: String) -> String:
	return {"common": "COMMON 普通", "uncommon": "UNCOMMON 精良", "rare": "RARE 稀有", "epic": "EPIC 史詩", "legendary": "LEGENDARY 傳說"}.get(rarity, "COMMON 普通")

func _make_panel(panel_name: String, background: Color, border: Color, at: Vector2, panel_size: Vector2, primary_skin: String, fallback_skin: String) -> Panel:
	var panel: Panel = UITheme.make_panel(background, border, 32, 5)
	panel.name = panel_name
	panel.position = at
	panel.size = panel_size
	if not UITheme.apply_texture_panel_skin(panel, primary_skin, 28):
		UITheme.apply_texture_panel_skin(panel, fallback_skin, 28)
	return panel

func _make_button(primary: String, secondary: String, color: Color, minimum: Vector2) -> Button:
	var button: Button = UITheme.make_button(primary, secondary, color, minimum)
	UITheme.apply_texture_button_skin(button, BUTTON_SKIN_PATH if ResourceLoader.exists(BUTTON_SKIN_PATH) else SHARED_BUTTON_SKIN_PATH, color, 24)
	return button

func _style_tab_button(button: Button, background: Color) -> void:
	if button == null:
		return
	var border: Color = Color("#b7823e")
	button.clip_contents = false
	button.add_theme_stylebox_override("normal", UITheme.rounded_style(background, border, 28, 3))
	button.add_theme_stylebox_override("hover", UITheme.rounded_style(background.lightened(0.06), border, 28, 3))
	button.add_theme_stylebox_override("pressed", UITheme.rounded_style(background.darkened(0.08), border.darkened(0.08), 28, 4))
	button.add_theme_stylebox_override("disabled", UITheme.rounded_style(background.darkened(0.18), border.darkened(0.12), 28, 3))
	var content: VBoxContainer = button.get_child(0) as VBoxContainer
	if content != null:
		content.z_index = 2
		var main_label: Label = content.get_child(0) as Label
		var small_label: Label = content.get_child(1) as Label
		if main_label != null:
			main_label.add_theme_font_size_override("font_size", 34)
		if small_label != null:
			small_label.add_theme_font_size_override("font_size", 20)

func _decorate_tab_button(button: Button) -> void:
	if button == null or not ResourceLoader.exists(CORNER_ORNAMENT_PATH):
		return
	var left: TextureRect = _make_sprite(CORNER_ORNAMENT_PATH, Vector2(86, 72))
	left.name = "LeftSakuraOrnament"
	left.anchor_left = 0.0
	left.anchor_right = 0.0
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.offset_left = 8.0
	left.offset_top = -76.0
	left.offset_right = 94.0
	left.offset_bottom = -4.0
	left.z_index = 5
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(left)
	var right: TextureRect = _make_sprite(CORNER_ORNAMENT_PATH, Vector2(86, 72))
	right.name = "RightSakuraOrnament"
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -94.0
	right.offset_top = -76.0
	right.offset_right = -8.0
	right.offset_bottom = -4.0
	right.z_index = 5
	right.pivot_offset = Vector2(43, 36)
	right.scale.x = -1.0
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(right)

func _panel_stack(panel: Panel, margin_value: int) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, margin_value)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	return stack

func _make_item_icon(template_id: String, slot: String, icon_size: Vector2, rarity: String) -> Panel:
	var icon_box: Panel = UITheme.make_panel(Color("#fff4cf"), EquipmentSystem.rarity_color(rarity), 20, 4)
	icon_box.name = "EquipmentArt_%s" % template_id
	icon_box.custom_minimum_size = icon_size
	icon_box.size = icon_size
	icon_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.clip_contents = true
	UITheme.apply_texture_panel_skin(icon_box, SHARED_SLOT_FRAME_PATH, 18)
	var generated_path: String = EquipmentSystem.get_equipment_sprite_path(template_id)
	var icon_path: String = generated_path if not generated_path.is_empty() else str(SHARED_ICON_PATHS.get(slot, ""))
	if ResourceLoader.exists(icon_path):
		var icon: TextureRect = _make_sprite(icon_path, icon_size - Vector2(14, 14))
		icon.name = "EquipmentArtSprite"
		icon.position = Vector2(7, 7)
		icon_box.add_child(icon)
	else:
		var fallback: Label = UITheme.make_label(str(SLOT_NAMES.get(slot, "裝備")), 18, UITheme.MUTED_INK)
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_box.add_child(fallback)
	return icon_box

func _make_texture_or_fallback(node_name: String, path: String, texture_size: Vector2, fallback_color: Color) -> TextureRect:
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.name = node_name
	texture_rect.size = texture_size
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path):
		texture_rect.texture = load(path)
	else:
		var gradient: Gradient = Gradient.new()
		gradient.colors = PackedColorArray([fallback_color, fallback_color.darkened(0.14)])
		var gradient_texture: GradientTexture2D = GradientTexture2D.new()
		gradient_texture.gradient = gradient
		gradient_texture.width = int(texture_size.x)
		gradient_texture.height = int(texture_size.y)
		texture_rect.texture = gradient_texture
	return texture_rect

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
