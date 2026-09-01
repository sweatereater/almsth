class_name SkillTreeIcon
extends Button

## Focusable, code-drawn skill node. The button intentionally contains no
## gameplay action of its own: its owner decides whether activation selects or
## purchases the represented entry.

const GameRules := preload("res://scripts/game/game_rules.gd")

const COLOR_TEXT := Color("e6e2d8")
const COLOR_MUTED := Color("8d98aa")
const COLOR_SOUL := Color("72d7cf")
const COLOR_AVAILABLE := Color("9eb0c6")
const COLOR_LEARNED := Color("5fc5b5")
const COLOR_MAX := Color("e1bf71")
const COLOR_LOCKED := Color("596274")
const COLOR_PLACEHOLDER := Color("758093")
const COLOR_SELECTION := Color("f2e6b6")
const COST_BADGE_RADIUS := 8.0
const COST_BADGE_OFFSET := Vector2(-46.0, -20.0)
const COMPACT_COST_BADGE_OFFSET := Vector2(-20.0, -20.0)

static var _texture_cache: Dictionary = {}

var node_id := ""
var display_name := ""
var node_kind := "passive"
var visual_state := "available"
var selected := false
var purchasable := false
var compact := false
var skill_texture: Texture2D = null


func _ready() -> void:
	flat = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	skill_texture = load_skill_texture(node_id)
	tooltip_text = display_name
	accessibility_name = display_name
	queue_redraw()


static func load_skill_texture(skill_id: String) -> Texture2D:
	if _texture_cache.has(skill_id):
		return _texture_cache[skill_id]
	var result: Texture2D = null
	if GameRules.SKILLS.has(skill_id):
		var icon_path := String(GameRules.SKILLS[skill_id].get("icon", ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path, "Texture2D"):
			var resource := ResourceLoader.load(icon_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
			if resource is Texture2D:
				result = resource
	_texture_cache[skill_id] = result
	return result


func uses_raster_texture() -> bool:
	return skill_texture != null


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

	if button_pressed:
		fill = fill.lightened(0.10)

	var diamond := PackedVector2Array()
	if node_kind == "passive" or node_kind == "intrinsic":
		draw_circle(center, 27.0, fill)
	else:
		var half := 24.0
		diamond = PackedVector2Array([
			center + Vector2(0, -half),
			center + Vector2(half, 0),
			center + Vector2(0, half),
			center + Vector2(-half, 0),
		])
		draw_colored_polygon(diamond, fill)

	if skill_texture != null:
		_draw_raster(center)
	else:
		_draw_glyph(center, outline)

	# Frames, focus, state and cost remain code-drawn above every raster.
	if node_kind == "passive" or node_kind == "intrinsic":
		draw_arc(center, 27.0, 0.0, TAU, 48, outline, 2.5, true)
	else:
		draw_polyline(PackedVector2Array([
			diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
		]), outline, 2.5, true)

	if selected or has_focus() or is_hovered():
		_draw_selection_outline(center, COLOR_SELECTION if selected else COLOR_SOUL)
	_draw_state_badge(center, outline)
	if purchasable:
		_draw_cost_badge(center)
	if not compact:
		_draw_name()


func _draw_raster(center: Vector2) -> void:
	var texture_size := 64.0 if compact else 54.0
	var modulation := Color.WHITE
	if visual_state == "locked" or visual_state == "intrinsic_locked":
		modulation.a = 0.46
	draw_texture_rect(
		skill_texture,
		Rect2(center - Vector2.ONE * texture_size * 0.5, Vector2.ONE * texture_size),
		false,
		modulation,
	)


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
	var badge_center := center + (
		COMPACT_COST_BADGE_OFFSET if compact else COST_BADGE_OFFSET
	)
	var gold := COLOR_MAX
	draw_circle(badge_center, COST_BADGE_RADIUS, Color("111720"))
	draw_arc(badge_center, COST_BADGE_RADIUS, 0.0, TAU, 20, gold, 2.0, true)
	draw_line(badge_center + Vector2(-3, -3), badge_center + Vector2(3, -3), gold, 1.5, true)
	draw_line(badge_center + Vector2(-4, 0), badge_center + Vector2(4, 0), gold, 1.5, true)
	draw_line(badge_center + Vector2(-3, 3), badge_center + Vector2(3, 3), gold, 1.5, true)


func cost_badge_bounds() -> Rect2:
	var center := Vector2(size.x * 0.5, 20.0 if not compact else size.y * 0.5)
	var offset := COMPACT_COST_BADGE_OFFSET if compact else COST_BADGE_OFFSET
	return Rect2(
		center + offset - Vector2.ONE * COST_BADGE_RADIUS,
		Vector2.ONE * COST_BADGE_RADIUS * 2.0,
	)


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
		"stomach":
			draw_arc(center + Vector2(-2, 1), 11.0, -1.35, 1.75, 24, color, 3.0, true)
			draw_arc(center + Vector2(5, 5), 6.0, 1.1, 3.5, 16, color, thin, true)
			draw_line(center + Vector2(-1, -10), center + Vector2(4, -4), color, thin, true)
		"ears":
			for offset in [-7.0, 7.0]:
				draw_arc(center + Vector2(offset, 0), 7.0, -1.25, 1.25, 18, color, 2.5, true)
				draw_arc(center + Vector2(offset, 1), 3.5, -1.1, 1.1, 12, color, thin, true)
			draw_line(center + Vector2(-1, -8), center + Vector2(1, 8), color, thin, true)
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


func name_line_bounds() -> Array[Rect2]:
	var result: Array[Rect2] = []
	if compact:
		return result
	var font := get_theme_font("font")
	var font_size := 11
	var lines := _wrap_name(font, font_size)
	var start_y := 68.0 if lines.size() == 1 else 64.0
	for index in range(lines.size()):
		var line_width := font.get_string_size(
			lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		).x
		var baseline := start_y + index * 10.0
		result.append(Rect2(
			Vector2((size.x - line_width) * 0.5, baseline - font_size),
			Vector2(line_width, font_size + 2.0),
		))
	return result


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
