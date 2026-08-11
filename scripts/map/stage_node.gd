class_name StageMapNode
extends Control

signal stage_selected(stage_id: int)

const NODE_SIZE: Vector2 = Vector2(240, 286)
const BUTTON_RECT: Rect2 = Rect2(25, 25, 190, 190)
const BASE_TEXTURE: String = "res://assets/ui/map/stage_node_base.png"
const BOSS_TEXTURE: String = "res://assets/ui/map/stage_node_boss.png"
const LOCK_TEXTURE: String = "res://assets/ui/map/stage_lock.png"
const STAR_TEXTURE: String = "res://assets/ui/map/stage_complete_star.png"
const GLOW_TEXTURE: String = "res://assets/ui/map/stage_current_glow.png"
const DRAG_CANCEL_DISTANCE: float = 24.0

var stage_id: int = 0
var stage_status: StringName = &"locked"
var stage_button: BaseButton
var glow: Control
var pointer_down: bool = false
var pointer_dragged: bool = false
var pointer_press_position: Vector2 = Vector2.ZERO

func configure(stage_data: Dictionary, status: StringName) -> void:
	stage_id = int(stage_data.get("id", 0))
	stage_status = status
	name = "StageNode%d" % stage_id
	custom_minimum_size = NODE_SIZE
	size = NODE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build(stage_data)

func _build(stage_data: Dictionary) -> void:
	var is_boss: bool = bool(stage_data.get("is_boss", false))
	if stage_status == &"current":
		glow = _make_image_or_glow()
		add_child(glow)

	stage_button = _make_stage_button(is_boss)
	stage_button.position = BUTTON_RECT.position
	stage_button.size = BUTTON_RECT.size
	stage_button.focus_mode = Control.FOCUS_NONE
	# Let the parent ScrollContainer receive drag motion while this node still
	# handles a stationary release as a stage tap.
	stage_button.mouse_filter = Control.MOUSE_FILTER_PASS
	stage_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stage_button.disabled = stage_status == &"locked"
	stage_button.button_down.connect(_on_stage_button_down)
	stage_button.button_up.connect(_on_stage_button_up)
	stage_button.gui_input.connect(_on_stage_button_gui_input)
	stage_button.pressed.connect(_on_pressed)
	add_child(stage_button)

	if stage_button is TextureButton:
		var number_label: Label = UITheme.make_label(str(stage_id), _stage_font_size(is_boss), UITheme.INK)
		number_label.name = "StageNumber"
		number_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage_button.add_child(number_label)

	if is_boss:
		var crown: Label = UITheme.make_label("♛", 44, Color("#c76b54"))
		crown.name = "BossCrown"
		crown.position = Vector2(150, 0)
		crown.size = Vector2(82, 58)
		crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(crown)

	if stage_status == &"locked":
		_add_badge(LOCK_TEXTURE, "鎖", Color("#8b7778"), Vector2(150, 4))
	elif stage_status == &"completed":
		_add_badge(STAR_TEXTURE, "★", Color("#f0aa45"), Vector2(150, 4))

	var caption_panel: Panel = UITheme.make_panel(Color(1, 0.97, 0.92, 0.94), Color("#e5a5a7"), 23, 3)
	caption_panel.name = "CaptionPanel"
	caption_panel.position = Vector2(0, 222)
	caption_panel.size = Vector2(240, 58)
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption_panel)
	var caption_text: String = str(stage_data.get("name_zh", "第 %d 關" % stage_id))
	if stage_status == &"completed":
		var best_stars: int = GameManager.get_stage_stars(stage_id)
		if best_stars > 0:
			caption_text += "\n" + "★".repeat(best_stars) + "☆".repeat(GameBalance.MAX_STAGE_STARS - best_stars)
	var caption: Label = UITheme.make_label(caption_text, 20 if stage_status == &"completed" else 25, UITheme.INK)
	caption.name = "StageName"
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_panel.add_child(caption)

	if stage_status == &"current":
		call_deferred("_start_current_animation")

func _make_stage_button(is_boss: bool) -> BaseButton:
	var texture_path: String = BOSS_TEXTURE if is_boss else BASE_TEXTURE
	if ResourceLoader.exists(texture_path):
		var texture_button: TextureButton = TextureButton.new()
		texture_button.texture_normal = load(texture_path)
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		texture_button.modulate = Color(0.72, 0.72, 0.72, 1.0) if stage_status == &"locked" else Color.WHITE
		return texture_button

	var button: Button = Button.new()
	button.text = str(stage_id)
	UITheme.apply_font(button)
	button.add_theme_font_size_override("font_size", _stage_font_size(is_boss))
	button.add_theme_color_override("font_color", UITheme.INK)
	var fill: Color = Color("#ffd985") if is_boss else Color("#ffb8c9")
	var border: Color = Color("#b96c66")
	if stage_status == &"current":
		fill = Color("#aee5c8")
	elif stage_status == &"locked":
		fill = Color("#d8d0cf")
		border = Color("#a69594")
	button.add_theme_stylebox_override("normal", UITheme.rounded_style(fill, border, 95, 7))
	button.add_theme_stylebox_override("hover", UITheme.rounded_style(fill.lightened(0.07), border, 95, 7))
	button.add_theme_stylebox_override("pressed", UITheme.rounded_style(fill.darkened(0.06), border, 95, 7))
	button.add_theme_stylebox_override("disabled", UITheme.rounded_style(fill, border, 95, 7))
	return button

func _stage_font_size(is_boss: bool) -> int:
	var digits: int = str(stage_id).length()
	var size_value: int = 62 if is_boss else 68
	if digits == 3:
		size_value = 52
	elif digits == 4:
		size_value = 42
	elif digits >= 5:
		size_value = 32
	return size_value

func _make_image_or_glow() -> Control:
	if ResourceLoader.exists(GLOW_TEXTURE):
		var image_glow: TextureRect = TextureRect.new()
		image_glow.texture = load(GLOW_TEXTURE)
		image_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image_glow.position = Vector2(-5, -5)
		image_glow.size = Vector2(250, 250)
		image_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return image_glow
	var fallback_glow: Panel = UITheme.make_panel(Color(0.76, 1.0, 0.85, 0.24), Color(0.65, 1.0, 0.8, 0.88), 118, 8)
	fallback_glow.position = Vector2(4, 4)
	fallback_glow.size = Vector2(232, 232)
	fallback_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fallback_glow

func _add_badge(texture_path: String, fallback_text: String, color: Color, at: Vector2) -> void:
	if ResourceLoader.exists(texture_path):
		var badge_texture: TextureRect = TextureRect.new()
		badge_texture.texture = load(texture_path)
		badge_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge_texture.position = at
		badge_texture.size = Vector2(82, 82)
		badge_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge_texture)
		return
	var badge: Label = UITheme.make_label(fallback_text, 41, color)
	badge.position = at
	badge.size = Vector2(82, 82)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)

func _start_current_animation() -> void:
	if glow != null:
		glow.pivot_offset = glow.size * 0.5
		var glow_tween: Tween = create_tween().set_loops()
		glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_tween.set_parallel(true)
		glow_tween.tween_property(glow, "scale", Vector2(1.06, 1.06), 1.0)
		glow_tween.tween_property(glow, "modulate:a", 0.55, 1.0)
		glow_tween.chain().set_parallel(true)
		glow_tween.tween_property(glow, "scale", Vector2.ONE, 1.0)
		glow_tween.tween_property(glow, "modulate:a", 1.0, 1.0)
	if stage_button != null:
		stage_button.pivot_offset = stage_button.size * 0.5

func _on_pressed() -> void:
	# Scroll gestures can pass through a child button. Do not turn the release
	# at the end of a drag into a battle launch.
	if pointer_dragged:
		_clear_pointer_state()
		return
	if stage_status == &"locked":
		return
	stage_selected.emit(stage_id)

func _on_stage_button_down() -> void:
	pointer_down = true
	pointer_dragged = false
	pointer_press_position = stage_button.get_local_mouse_position()

func _on_stage_button_up() -> void:
	# Defer clearing so _on_pressed can inspect pointer_dragged for this release.
	call_deferred("_clear_pointer_state")

func _on_stage_button_gui_input(event: InputEvent) -> void:
	if not pointer_down or pointer_dragged:
		return
	var current_position: Vector2 = pointer_press_position
	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		current_position = (event as InputEventMouseMotion).position
	elif event is InputEventScreenDrag:
		current_position = (event as InputEventScreenDrag).position
	else:
		return
	if current_position.distance_to(pointer_press_position) >= DRAG_CANCEL_DISTANCE:
		pointer_dragged = true

func _clear_pointer_state() -> void:
	pointer_down = false
	pointer_dragged = false
	pointer_press_position = Vector2.ZERO
