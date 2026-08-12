class_name UITheme
extends RefCounted

## Shared visual helpers for the soft, rounded portrait UI.
const BODY_FONT_PATH: String = "res://assets/fonts/ChironGoRoundTC-500M.woff2"
const BOLD_FONT_PATH: String = "res://assets/fonts/ChironGoRoundTC-700B.woff2"
# Backwards-compatible alias used by existing checks and callers.
const CJK_FONT_PATH: String = BODY_FONT_PATH
const INK: Color = Color("#5c2d2d")
const MUTED_INK: Color = Color("#8c5f58")
const CREAM: Color = Color("#fff9ec")
const MINT: Color = Color("#a9e4cf")
const MINT_DARK: Color = Color("#69bda4")
const SKY: Color = Color("#bfeaf5")
const PINK: Color = Color("#ffb9c6")
const YELLOW: Color = Color("#ffe28a")
const GREEN: Color = Color("#a8df9a")
const ORANGE: Color = Color("#ff9b52")
const RED: Color = Color("#ef6e7f")
enum FontRole {
	BODY,
	BOLD
}

static var _shared_fonts: Dictionary = {}
static var _font_checked: Dictionary = {}

static func shared_font(role: int = FontRole.BODY) -> Font:
	var normalized_role: int = FontRole.BOLD if role == FontRole.BOLD else FontRole.BODY
	if not bool(_font_checked.get(normalized_role, false)):
		_font_checked[normalized_role] = true
		var path: String = BOLD_FONT_PATH if normalized_role == FontRole.BOLD else BODY_FONT_PATH
		if ResourceLoader.exists(path):
			_shared_fonts[normalized_role] = load(path) as Font
	return _shared_fonts.get(normalized_role) as Font

static func apply_font(control: Control, role: int = FontRole.BODY) -> void:
	var font: Font = shared_font(role)
	if font != null:
		control.add_theme_font_override("font", font)

static func rounded_style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 28, border_width: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.25, 0.12, 0.12, 0.18)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	return style

static func add_gradient_background(parent: Control, top_color: Color, bottom_color: Color) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([top_color, bottom_color])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 1080
	texture.height = 1920
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var background: TextureRect = TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	parent.move_child(background, 0)
	return background

static func make_label(text_value: String, font_size: int, color: Color = INK, font_role: int = FontRole.BODY) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.25, 0.12, 0.12, 0.16))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 4)
	apply_font(label, font_role)
	return label

static func make_dual_label(primary: String, secondary: String, primary_size: int = 40, secondary_size: int = 20, color: Color = INK) -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main_label: Label = make_label(primary, primary_size, color, FontRole.BOLD)
	var small_label: Label = make_label(secondary, secondary_size, color.lightened(0.12))
	main_label.name = "PrimaryLabel"
	small_label.name = "SecondaryLabel"
	main_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	small_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(main_label)
	stack.add_child(small_label)
	return stack

static func make_zh_en_label(chinese: String, english: String, chinese_size: int = 36, english_size: int = 15, color: Color = INK) -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var zh_label: Label = make_label(chinese, chinese_size, color, FontRole.BOLD)
	var en_label: Label = make_label(english, english_size, color.lightened(0.16), FontRole.BODY)
	zh_label.name = "PrimaryLabel"
	en_label.name = "SecondaryLabel"
	zh_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	en_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(zh_label)
	stack.add_child(en_label)
	return stack

static func make_panel(background: Color = CREAM, border: Color = Color("#f3d88a"), radius: int = 34, border_width: int = 5) -> Panel:
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", rounded_style(background, border, radius, border_width))
	return panel

static func make_texture_style(texture: Texture2D, tint: Color = Color.WHITE, texture_margin: int = 32) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.content_margin_left = texture_margin
	style.content_margin_top = texture_margin
	style.content_margin_right = texture_margin
	style.content_margin_bottom = texture_margin
	return style

static func make_button_texture_style(texture: Texture2D, tint: Color = Color.WHITE, texture_margin: int = 72) -> StyleBoxTexture:
	var style: StyleBoxTexture = make_texture_style(texture, tint, texture_margin)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 8.0
	return style

static func apply_texture_panel_skin(panel: Panel, texture_path: String, texture_margin: int = 32) -> bool:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return false
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return false
	panel.add_theme_stylebox_override("panel", make_texture_style(texture, Color.WHITE, texture_margin))
	return true

static func apply_texture_button_skin(button: Button, texture_path: String, tint: Color = Color.WHITE, texture_margin: int = 28) -> bool:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return false
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return false
	button.add_theme_stylebox_override("normal", make_texture_style(texture, tint, texture_margin))
	button.add_theme_stylebox_override("hover", make_texture_style(texture, tint.lightened(0.06), texture_margin))
	button.add_theme_stylebox_override("pressed", make_texture_style(texture, tint.darkened(0.08), texture_margin))
	button.add_theme_stylebox_override("disabled", make_texture_style(texture, tint.darkened(0.28), texture_margin))
	return true

static func set_layer_order(layer: Control, order: int) -> void:
	if layer == null:
		return
	# Explicit z ordering keeps dynamically-created HUD buttons above scrollable
	# content on every renderer. Relying only on sibling insertion order is easy
	# to break when a tab or result overlay rebuilds its children.
	layer.z_index = order
	layer.z_as_relative = false

static func make_button(primary: String, secondary: String, background: Color = YELLOW, min_size: Vector2 = Vector2(0, 124)) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(maxf(min_size.x, 96.0), maxf(min_size.y, 96.0))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", rounded_style(background, background.darkened(0.18), 34, 5))
	button.add_theme_stylebox_override("hover", rounded_style(background.lightened(0.08), background.darkened(0.18), 34, 5))
	button.add_theme_stylebox_override("pressed", rounded_style(background.darkened(0.08), background.darkened(0.2), 34, 5))
	button.add_theme_stylebox_override("disabled", rounded_style(background.darkened(0.2), background.darkened(0.28), 34, 5))
	var content: VBoxContainer = make_dual_label(primary, secondary, 36, 18)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(content)
	return button

static func set_dual_button_text(button: Button, primary: String, secondary: String) -> void:
	if button == null:
		return
	var named_primary: Label = button.find_child("PrimaryLabel", true, false) as Label
	var named_secondary: Label = button.find_child("SecondaryLabel", true, false) as Label
	if named_primary != null and named_secondary != null:
		named_primary.text = primary
		named_secondary.text = secondary
		return
	var content: VBoxContainer = button.get_child(0) as VBoxContainer
	if content != null and content.get_child_count() >= 2:
		var main_label: Label = content.get_child(0) as Label
		var small_label: Label = content.get_child(1) as Label
		if main_label != null:
			main_label.text = primary
		if small_label != null:
			small_label.text = secondary
		return
	button.text = "%s\n%s" % [primary, secondary]

static func make_key_button(value: String, background: Color, min_size: Vector2 = Vector2(0, 112)) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 44)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_stylebox_override("normal", rounded_style(background, background.darkened(0.2), 28, 5))
	button.add_theme_stylebox_override("hover", rounded_style(background.lightened(0.08), background.darkened(0.2), 28, 5))
	button.add_theme_stylebox_override("pressed", rounded_style(background.darkened(0.08), background.darkened(0.24), 28, 5))
	button.add_theme_stylebox_override("disabled", rounded_style(background.darkened(0.24), background.darkened(0.3), 28, 5))
	apply_font(button, FontRole.BOLD)
	return button

static func make_safe_margin(parent: Control, margin: int = 52) -> MarginContainer:
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var insets: Vector4 = safe_area_insets(parent)
	safe.add_theme_constant_override("margin_left", int(maxf(float(margin), insets.x)))
	safe.add_theme_constant_override("margin_right", int(maxf(float(margin), insets.z)))
	safe.add_theme_constant_override("margin_top", int(maxf(86.0, insets.y)))
	safe.add_theme_constant_override("margin_bottom", int(maxf(64.0, insets.w)))
	parent.add_child(safe)
	return safe

static func safe_area_insets(parent: Control) -> Vector4:
	# DisplayServer returns screen-space pixels/points. Convert them to the
	# project's logical portrait viewport and keep the authored design margins
	# as the minimum on desktop and headless test runners.
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var viewport_size: Vector2 = parent.get_viewport_rect().size
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0 or screen_size.x <= 0 or screen_size.y <= 0 or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4(0.0, 0.0, 0.0, 0.0)
	var scale_x: float = viewport_size.x / float(screen_size.x)
	var scale_y: float = viewport_size.y / float(screen_size.y)
	var left: float = float(safe_rect.position.x) * scale_x
	var top: float = float(safe_rect.position.y) * scale_y
	var right: float = float(screen_size.x - safe_rect.end.x) * scale_x
	var bottom: float = float(screen_size.y - safe_rect.end.y) * scale_y
	return Vector4(maxf(0.0, left), maxf(0.0, top), maxf(0.0, right), maxf(0.0, bottom))

static func make_spacer(min_height: float) -> Control:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, min_height)
	return spacer
