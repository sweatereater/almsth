class_name SkillTreeIcon
extends Button

## Focusable, code-drawn skill node. The button intentionally contains no
## gameplay action of its own: its owner decides whether activation selects or
## purchases the represented entry.

const COLOR_TEXT := Color("e6e2d8")
const COLOR_MUTED := Color("8d98aa")
const COLOR_SOUL := Color("72d7cf")
const COLOR_AVAILABLE := Color("9eb0c6")
const COLOR_LEARNED := Color("5fc5b5")
const COLOR_MAX := Color("e1bf71")
const COLOR_LOCKED := Color("596274")
const COLOR_PLACEHOLDER := Color("758093")
const COLOR_SELECTION := Color("f2e6b6")

var node_id := ""
var display_name := ""
var node_kind := "passive"
var visual_state := "available"
var selected := false
var purchasable := false
var compact := false


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func set_presentation(
	id_value: String,
	name_value: String,
	kind_value: String,
	state_value: String,
	selected_value: bool,
	purchasable_value := false,
	compact_value := false,
) -> void:
	node_id = id_value
	display_name = name_value
	node_kind = kind_value
	visual_state = state_value
	selected = selected_value
	purchasable = purchasable_value
	compact = compact_value
	tooltip_text = display_name
	accessibility_name = display_name
	queue_redraw()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, 20.0 if not compact else size.y * 0.5)
	var outline := _state_color()
	var fill := Color("111720")
	if visual_state == "learned" or visual_state == "intrinsic_owned":
		fill = Color("17302f")
	elif visual_state == "max":
		fill = Color("302b1d")
	elif visual_state == "locked" or visual_state == "intrinsic_locked":
		fill = Color("141923")
	elif visual_state == "placeholder":
		fill = Color("181d27")

	if selected or has_focus() or is_hovered():
		_draw_selection_outline(center, COLOR_SELECTION if selected else COLOR_SOUL)
	if button_pressed:
		fill = fill.lightened(0.10)

	if node_kind == "passive" or node_kind == "intrinsic":
		draw_circle(center, 27.0, fill)
		draw_arc(center, 27.0, 0.0, TAU, 48, outline, 2.5, true)
	else:
		var half := 24.0
		var diamond := PackedVector2Array([
			center + Vector2(0, -half),
			center + Vector2(half, 0),
			center + Vector2(0, half),
			center + Vector2(-half, 0),
		])
		draw_colored_polygon(diamond, fill)
		draw_polyline(PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
		]), outline, 2.5, true)

	_draw_glyph(center, outline)
	_draw_state_badge(center, outline)
	if purchasable:
		_draw_cost_badge(center)
	if not compact:
		_draw_name()


func _state_color() -> Color:
	match visual_state:
		"learned", "intrinsic_owned": return COLOR_LEARNED
		"max": return COLOR_MAX
		"locked", "intrinsic_locked": return COLOR_LOCKED
		"placeholder": return COLOR_PLACEHOLDER
	return COLOR_AVAILABLE


func _draw_selection_outline(center: Vector2, color: Color) -> void:
	if node_kind == "passive" or node_kind == "intrinsic":
		draw_arc(center, 31.0, 0.0, TAU, 48, color, 2.0, true)
		return
	var half := 28.0
	var points := PackedVector2Array([
		center + Vector2(0, -half), center + Vector2(half, 0),
		center + Vector2(0, half), center + Vector2(-half, 0),
		center + Vector2(0, -half),
	])
	draw_polyline(points, color, 2.0, true)


func _draw_state_badge(center: Vector2, color: Color) -> void:
	var badge_center := center + Vector2(20, -20)
	if visual_state == "locked" or visual_state == "intrinsic_locked":
		draw_rect(Rect2(badge_center + Vector2(-6, -1), Vector2(12, 10)), Color("121720"))
		draw_rect(Rect2(badge_center + Vector2(-6, -1), Vector2(12, 10)), color, false, 2.0)
		draw_arc(badge_center + Vector2(0, -1), 5.0, PI, TAU, 16, color, 2.0, true)
	elif visual_state == "learned" or visual_state == "intrinsic_owned":
		draw_circle(badge_center, 8.0, Color("111720"))
		draw_arc(badge_center, 8.0, 0.0, TAU, 20, color, 2.0, true)
		draw_polyline(PackedVector2Array([
			badge_center + Vector2(-4, 0), badge_center + Vector2(-1, 4),
			badge_center + Vector2(5, -4),
		]), color, 2.0, true)
	elif visual_state == "max":
		draw_circle(badge_center, 8.0, Color("111720"))
		draw_arc(badge_center, 8.0, 0.0, TAU, 20, color, 2.0, true)
		draw_arc(badge_center, 4.5, 0.0, TAU, 16, color, 1.5, true)
	elif visual_state == "placeholder":
		draw_circle(badge_center, 8.0, Color("111720"))
		draw_arc(badge_center, 8.0, 0.0, TAU, 20, color, 2.0, true)
		for offset in [-3.0, 0.0, 3.0]:
			draw_circle(badge_center + Vector2(offset, 0), 0.9, color)


func _draw_cost_badge(center: Vector2) -> void:
	var badge_center := center + Vector2(-20, -20)
	var gold := COLOR_MAX
	draw_circle(badge_center, 8.0, Color("111720"))
	draw_arc(badge_center, 8.0, 0.0, TAU, 20, gold, 2.0, true)
	draw_line(badge_center + Vector2(-3, -3), badge_center + Vector2(3, -3), gold, 1.5, true)
	draw_line(badge_center + Vector2(-4, 0), badge_center + Vector2(4, 0), gold, 1.5, true)
	draw_line(badge_center + Vector2(-3, 3), badge_center + Vector2(3, 3), gold, 1.5, true)


func _draw_glyph(center: Vector2, color: Color) -> void:
	var thin := 2.0
	match node_id:
		"strong_bones":
			draw_line(center + Vector2(-10, 8), center + Vector2(10, -8), color, 4.0, true)
			for point in [center + Vector2(-11, 9), center + Vector2(11, -9)]:
				draw_circle(point, 3.5, color)
		"fundamentals":
			draw_line(center + Vector2(-9, 7), center + Vector2(9, -7), color, 3.0, true)
			draw_line(center + Vector2(-9, -7), center + Vector2(9, 7), color, 3.0, true)
		"magic_awakening":
			for angle in range(0, 360, 45):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(angle))
				draw_line(center + direction * 5.0, center + direction * 13.0, color, thin, true)
			draw_circle(center, 4.0, color)
		"magic_missile", "magic_missile_range":
			draw_line(center + Vector2(-11, 7), center + Vector2(9, -7), color, 3.0, true)
			draw_polyline(PackedVector2Array([
				center + Vector2(3, -10), center + Vector2(11, -8), center + Vector2(8, 0),
			]), color, thin, true)
			if node_id == "magic_missile_range":
				draw_arc(center, 14.0, -0.8, 0.8, 12, color, thin, true)
		"magic_ricochet":
			draw_polyline(PackedVector2Array([
				center + Vector2(-12, 8), center + Vector2(-3, -5),
				center + Vector2(4, 5), center + Vector2(12, -8),
			]), color, 3.0, true)
		"flesh_regeneration":
			draw_arc(center + Vector2(-5, -2), 7.0, PI, TAU, 12, color, thin, true)
			draw_arc(center + Vector2(5, -2), 7.0, PI, TAU, 12, color, thin, true)
			draw_polyline(PackedVector2Array([
				center + Vector2(-12, -2), center + Vector2(0, 13), center + Vector2(12, -2),
			]), color, thin, true)
			draw_line(center + Vector2(-5, 1), center + Vector2(5, 1), color, thin, true)
			draw_line(center + Vector2(0, -4), center + Vector2(0, 6), color, thin, true)
		"dash":
			for offset in [-5.0, 5.0]:
				draw_polyline(PackedVector2Array([
					center + Vector2(offset - 6, -9), center + Vector2(offset + 3, 0),
					center + Vector2(offset - 6, 9),
				]), color, 3.0, true)
		"double_attack", "almost_double_strike":
			for offset in [-5.0, 5.0]:
				draw_line(center + Vector2(offset - 5, 9), center + Vector2(offset + 5, -9), color, 3.0, true)
		"nervous_system":
			for offset in [Vector2(-9, -7), Vector2(9, -7), Vector2(0, 10)]:
				draw_line(center, center + offset, color, thin, true)
				draw_circle(center + offset, 3.0, color)
			draw_circle(center, 4.0, color)
		"sharp_vision":
			draw_arc(center, 14.0, PI + 0.35, TAU - 0.35, 16, color, thin, true)
			draw_arc(center, 14.0, 0.35, PI - 0.35, 16, color, thin, true)
			draw_circle(center, 5.0, color)
		"circular_attack":
			draw_arc(center, 12.0, 0.0, TAU, 24, color, thin, true)
			for angle in range(0, 360, 90):
				var direction := Vector2.RIGHT.rotated(deg_to_rad(angle))
				draw_line(center + direction * 8.0, center + direction * 15.0, color, thin, true)
		"choose_appearance":
			draw_circle(center + Vector2(0, -6), 5.0, Color.TRANSPARENT)
			draw_arc(center + Vector2(0, -6), 5.0, 0.0, TAU, 16, color, thin, true)
			draw_arc(center + Vector2(0, 11), 11.0, PI, TAU, 16, color, thin, true)
		_:
			draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), color, thin, true)
			draw_line(center + Vector2(0, -8), center + Vector2(0, 8), color, thin, true)


func _draw_name() -> void:
	var font := get_theme_font("font")
	var font_size := 11
	var lines := _wrap_name(font, font_size)
	var start_y := 68.0 if lines.size() == 1 else 64.0
	for index in range(lines.size()):
		draw_string(
			font,
			Vector2(0, start_y + index * 10.0),
			lines[index],
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			font_size,
			COLOR_TEXT if visual_state != "locked" else COLOR_MUTED,
		)


func _wrap_name(font: Font, font_size: int) -> PackedStringArray:
	var result := PackedStringArray()
	var words := display_name.split(" ", false)
	var current := ""
	for word in words:
		var candidate := String(word) if current.is_empty() else "%s %s" % [current, word]
		if current.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= size.x - 4.0:
			current = candidate
		else:
			result.append(current)
			current = String(word)
	if not current.is_empty():
		result.append(current)
	if result.is_empty():
		result.append(display_name)
	if result.size() > 2:
		result[1] = result[1] + "…"
		result.resize(2)
	return result
