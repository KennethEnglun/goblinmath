extends Control

## Layered start screen for the Goblin Leveling adventure.
const BACKGROUND_PATH: String = "res://assets/ui/start/start_background_v2.png"
const EFFECTS_PATH: String = "res://assets/ui/start/start_effects_v2.png"
const LOGO_PATH: String = "res://assets/ui/start/start_logo_v2.png"
const GOBLIN_PATH: String = "res://assets/ui/start/goblin_start_v2.png"
const BUTTON_PATH: String = "res://assets/ui/start/start_adventure_button_v2.png"

var start_button: BaseButton
var logo_layer: TextureRect
var goblin_layer: TextureRect
var effects_layer: TextureRect
var _transitioning: bool = false

func _ready() -> void:
	if _generated_assets_available():
		_build_layered_screen()
	else:
		push_warning("Start-screen image layers are incomplete. Using the built-in fallback UI.")
		_build_fallback_screen()
	call_deferred("_start_idle_animations")

func _generated_assets_available() -> bool:
	for path: String in [BACKGROUND_PATH, EFFECTS_PATH, LOGO_PATH, GOBLIN_PATH, BUTTON_PATH]:
		if not ResourceLoader.exists(path):
			return false
	return true

func _build_layered_screen() -> void:
	var background: TextureRect = _make_texture_rect(BACKGROUND_PATH, TextureRect.STRETCH_SCALE)
	background.name = "BackgroundLayer"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_area: MarginContainer = UITheme.make_safe_margin(self, 42)
	safe_area.name = "SafeArea"
	var layer_stage: Control = Control.new()
	layer_stage.name = "LayerStage"
	layer_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_area.add_child(layer_stage)

	effects_layer = _make_texture_rect(EFFECTS_PATH, TextureRect.STRETCH_SCALE)
	effects_layer.name = "EffectsLayer"
	_place_layer(effects_layer, 0.0, 0.0, 1.0, 1.0)
	layer_stage.add_child(effects_layer)

	logo_layer = _make_texture_rect(LOGO_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	logo_layer.name = "LogoLayer"
	_place_layer(logo_layer, 0.03, 0.02, 0.97, 0.25)
	layer_stage.add_child(logo_layer)

	goblin_layer = _make_texture_rect(GOBLIN_PATH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	goblin_layer.name = "GoblinLayer"
	_place_layer(goblin_layer, 0.17, 0.27, 0.83, 0.72)
	layer_stage.add_child(goblin_layer)

	var texture_button: TextureButton = TextureButton.new()
	texture_button.name = "StartAdventureButton"
	texture_button.texture_normal = load(BUTTON_PATH)
	texture_button.ignore_texture_size = true
	texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	texture_button.focus_mode = Control.FOCUS_NONE
	texture_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_button.tooltip_text = "開始冒險"
	_place_layer(texture_button, 0.05, 0.76, 0.95, 0.95)
	layer_stage.add_child(texture_button)
	start_button = texture_button
	_connect_start_button()

func _build_fallback_screen() -> void:
	UITheme.add_gradient_background(self, Color("#f7c9d7"), Color("#fff2df"))
	var safe: MarginContainer = UITheme.make_safe_margin(self, 58)
	safe.name = "FallbackSafeArea"
	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(content)

	content.add_child(UITheme.make_spacer(100))
	var title_panel: Panel = UITheme.make_panel(Color(1, 0.95, 0.92, 0.95), Color("#dd8e9f"), 42, 5)
	title_panel.custom_minimum_size = Vector2(0, 220)
	content.add_child(title_panel)
	var title: Label = UITheme.make_label("哥布林升級中", 62, UITheme.INK)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_panel.add_child(title)

	goblin_layer = TextureRect.new()
	goblin_layer.name = "FallbackGoblinLayer"
	goblin_layer.texture = load("res://assets/characters/goblin_placeholder.svg")
	goblin_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	goblin_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	goblin_layer.custom_minimum_size = Vector2(0, 760)
	goblin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(goblin_layer)

	var fallback_button: Button = UITheme.make_button("開始冒險", "", UITheme.YELLOW, Vector2(0, 150))
	fallback_button.name = "FallbackStartAdventureButton"
	content.add_child(fallback_button)
	start_button = fallback_button
	_connect_start_button()
	content.add_child(UITheme.make_spacer(80))

func _make_texture_rect(path: String, stretch: TextureRect.StretchMode) -> TextureRect:
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.texture = load(path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = stretch
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_rect

func _place_layer(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _connect_start_button() -> void:
	start_button.pressed.connect(_on_start_pressed)
	start_button.button_down.connect(_on_start_button_down)
	start_button.button_up.connect(_on_start_button_up)

func _start_idle_animations() -> void:
	if goblin_layer != null:
		goblin_layer.pivot_offset = goblin_layer.size * 0.5
		var breathing: Tween = create_tween().set_loops()
		breathing.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breathing.tween_property(goblin_layer, "scale", Vector2(1.025, 1.025), 1.45)
		breathing.tween_property(goblin_layer, "scale", Vector2.ONE, 1.45)

	if logo_layer != null:
		var logo_origin_y: float = logo_layer.position.y
		var floating_logo: Tween = create_tween().set_loops()
		floating_logo.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		floating_logo.tween_property(logo_layer, "position:y", logo_origin_y - 9.0, 1.8)
		floating_logo.tween_property(logo_layer, "position:y", logo_origin_y, 1.8)

	if effects_layer != null:
		effects_layer.modulate.a = 0.62
		var effects_origin_y: float = effects_layer.position.y
		var twinkle: Tween = create_tween().set_loops()
		twinkle.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		twinkle.set_parallel(true)
		twinkle.tween_property(effects_layer, "modulate:a", 0.94, 1.25)
		twinkle.tween_property(effects_layer, "position:y", effects_origin_y - 7.0, 1.25)
		twinkle.chain().set_parallel(true)
		twinkle.tween_property(effects_layer, "modulate:a", 0.62, 1.25)
		twinkle.tween_property(effects_layer, "position:y", effects_origin_y, 1.25)

	if start_button != null:
		start_button.pivot_offset = start_button.size * 0.5

func _on_start_button_down() -> void:
	if start_button == null or _transitioning:
		return
	var press_tween: Tween = create_tween()
	press_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(start_button, "scale", Vector2(0.965, 0.965), 0.08)

func _on_start_button_up() -> void:
	if start_button == null or _transitioning:
		return
	var release_tween: Tween = create_tween()
	release_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	release_tween.tween_property(start_button, "scale", Vector2.ONE, 0.12)

func _on_start_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	AudioManager.play_sfx("button_click")
	if start_button != null:
		var bounce: Tween = create_tween()
		bounce.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bounce.tween_property(start_button, "scale", Vector2(1.035, 1.035), 0.08)
		bounce.tween_property(start_button, "scale", Vector2.ONE, 0.1)
		await bounce.finished
	_go_to_world_map()

func _go_to_world_map() -> void:
	GameManager.go_to_world_map()
