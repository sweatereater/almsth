class_name UiFactory
extends RefCounted

## Backward-compatible semantic control facade. UiThemeController is the only
## resource factory; this file keeps stable helpers used throughout the prototype.

const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")

const COLOR_TEXT := Color("f2e8d4")
const COLOR_SOUL := Color("67cdc5")
const COLOR_PANEL := Color("2a251e")


static func make_label(
	parent: Control,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int
) -> Label:
	var approved_size := ThemeController.approved_font_size(font_size)
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.clip_text = true
	label.add_theme_font_size_override("font_size", approved_size)
	label.add_theme_font_override(
		"font",
		ThemeController.functional_font("semibold" if approved_size >= 20 else "regular"),
	)
	parent.add_child(label)
	return label


static func make_button(
	parent: Control,
	position_value: Vector2,
	text_value: String,
	size_value: Vector2 = Vector2(400, 54)
) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = size_value
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.theme_type_variation = "FunctionalButton"
	button.add_theme_font_override("font", ThemeController.functional_font("medium"))
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	return button


static func make_button_style(
	background: Color,
	border: Color,
	border_width := 1
) -> StyleBoxFlat:
	return ThemeController.legacy_button_style(background, border, border_width)


static func make_panel_style(border: Color) -> StyleBoxFlat:
	return ThemeController.legacy_panel_style(Palette.WARM_ARCHIVE, border)


static func semantic_style(context: String, variation: String, state: String) -> StyleBoxFlat:
	return ThemeController.style_for(context, variation, state)


static func theme_for(context: String) -> Theme:
	return ThemeController.theme_for(context)


static func fit_button_text(button: Button, preferred_size: int, minimum_size := 12) -> void:
	if button == null or button.text.is_empty():
		return
	var font := button.get_theme_font("font")
	var usable_width := maxf(16.0, button.size.x - 20.0)
	var candidates := ThemeController.approved_sizes_between(preferred_size, minimum_size)
	var fitted_size: int = candidates[-1]
	for candidate in candidates:
		fitted_size = candidate
		if font.get_string_size(
			button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size,
		).x <= usable_width:
			break
	button.add_theme_font_size_override("font_size", fitted_size)


static func enable_keyboard_focus(control: Control) -> void:
	control.focus_mode = Control.FOCUS_ALL


static func apply_danger(button: Button) -> void:
	button.theme_type_variation = "DangerButton"
	button.accessibility_description = "danger"


static func apply_tabular(label: Label) -> void:
	label.theme_type_variation = "TabularLabel"
	label.add_theme_font_override("font", ThemeController.functional_font("regular", true))


static func apply_heading(label: Label, font_size: int) -> void:
	assert(font_size == 28 or font_size == 32, "Cormorant headings are restricted to 28/32")
	label.theme_type_variation = "DisplayTitle"
	label.add_theme_font_override("font", ThemeController.heading_font())
	label.add_theme_font_size_override("font_size", font_size)


static func apply_skill_node_style(button: Button, kind: String) -> void:
	# Stage 1D nodes draw their circle/diamond geometry themselves. Their control
	# shell still uses the shared semantic theme for focus/input behavior and does
	# not construct per-refresh resources.
	button.theme = ThemeController.theme_for(Palette.WARM_ARCHIVE)
	button.theme_type_variation = "FunctionalButton"
	button.set_meta("skill_kind", kind)
