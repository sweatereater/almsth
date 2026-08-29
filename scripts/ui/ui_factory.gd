class_name UiFactory
extends RefCounted

## Creates the prototype's basic controls and owns their shared visual theme.
## Screen layout and signal wiring remain in Main, while style details stay here.

const COLOR_TEXT := Color("e6e2d8")
const COLOR_SOUL := Color("72d7cf")
const COLOR_PANEL := Color("1c2330")


static func make_label(
	parent: Control,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int
) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", COLOR_TEXT)
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
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color("fff8e8"))
	button.add_theme_color_override("font_pressed_color", Color("e9fffc"))
	button.add_theme_color_override("font_disabled_color", Color("687180"))
	button.add_theme_stylebox_override(
		"normal", make_button_style(Color("171c25"), Color("293445"))
	)
	button.add_theme_stylebox_override(
		"hover", make_button_style(Color("222b39"), Color("52647b"))
	)
	button.add_theme_stylebox_override(
		"pressed", make_button_style(Color("20363b"), COLOR_SOUL, 2)
	)
	button.add_theme_stylebox_override(
		"hover_pressed", make_button_style(Color("284349"), COLOR_SOUL, 2)
	)
	button.add_theme_stylebox_override(
		"disabled", make_button_style(Color("151a22"), Color("252d39"))
	)
	parent.add_child(button)
	return button


static func make_button_style(
	background: Color,
	border: Color,
	border_width := 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func make_panel_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style


static func fit_button_text(button: Button, preferred_size: int, minimum_size := 10) -> void:
	if button == null or button.text.is_empty():
		return
	var font := button.get_theme_font("font")
	var usable_width := maxf(16.0, button.size.x - 20.0)
	var fitted_size := preferred_size
	while (
		fitted_size > minimum_size
		and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size).x
		> usable_width
	):
		fitted_size -= 1
	button.add_theme_font_size_override("font_size", fitted_size)


static func enable_keyboard_focus(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override(
		"focus",
		make_button_style(Color("203238"), COLOR_SOUL, 2),
	)


static func apply_skill_node_style(button: Button, kind: String) -> void:
	var passive := kind == "passive"
	var radius := 36 if passive else 3
	var colors := {
		"normal": [Color("171c25"), Color("596274")],
		"hover": [Color("222b39"), Color("7c8da5")],
		"pressed": [Color("20363b"), COLOR_SOUL],
		"hover_pressed": [Color("284349"), COLOR_SOUL],
		"disabled": [Color("151a22"), Color("303846")],
	}
	for state_name in colors:
		var pair: Array = colors[state_name]
		var style := make_button_style(pair[0], pair[1], 2 if state_name.contains("pressed") else 1)
		style.set_corner_radius_all(radius)
		button.add_theme_stylebox_override(state_name, style)
