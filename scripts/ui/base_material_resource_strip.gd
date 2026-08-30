class_name BaseMaterialResourceStrip
extends Control

const Loc := preload("res://scripts/localization/localization.gd")

const RESOURCE_ORDER := ["wood", "stone", "cloth"]
const COUNTER_RECTS := {
	"wood": Rect2(0, 0, 56, 44),
	"stone": Rect2(56, 0, 57, 44),
	"cloth": Rect2(113, 0, 57, 44),
}
const TOOLTIP_KEYS := {
	"wood": "BASE_RESOURCE_WOOD_TOOLTIP",
	"stone": "BASE_RESOURCE_STONE_TOOLTIP",
	"cloth": "BASE_RESOURCE_CLOTH_TOOLTIP",
}

var counters: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	for resource_id in RESOURCE_ORDER:
		var counter := MaterialCounter.new()
		counter.name = "%sCounter" % resource_id.capitalize()
		counter.position = COUNTER_RECTS[resource_id].position
		counter.size = COUNTER_RECTS[resource_id].size
		counter.configure(resource_id, TOOLTIP_KEYS[resource_id])
		add_child(counter)
		counters[resource_id] = counter


func refresh(resources: Dictionary) -> void:
	for resource_id in RESOURCE_ORDER:
		var counter: MaterialCounter = counters.get(resource_id)
		if counter != null:
			counter.set_value(maxi(0, int(resources.get(resource_id, 0))))


func refresh_locale() -> void:
	for resource_id in RESOURCE_ORDER:
		var counter: MaterialCounter = counters.get(resource_id)
		if counter != null:
			counter.refresh_locale()


func get_counter(resource_id: String) -> Control:
	return counters.get(resource_id)


class MaterialCounter extends Control:
	const ICON_RECT := Rect2(1, 11, 22, 22)
	const VALUE_RECT := Rect2(25, 0, 31, 44)
	const ICON_STROKE_WIDTH := 2.7
	const VALUE_FONT_SIZE := 10
	const VALUE_MIN_FONT_SIZE := 7

	var resource_id := ""
	var tooltip_key := ""
	var resource_value := 0
	var value_label: Label

	func configure(id_value: String, tooltip_key_value: String) -> void:
		resource_id = id_value
		tooltip_key = tooltip_key_value
		_ensure_value_label()
		refresh_locale()
		queue_redraw()

	func set_value(value: int) -> void:
		resource_value = maxi(0, value)
		_ensure_value_label()
		value_label.text = str(resource_value)
		_fit_value_text()
		refresh_locale()

	func refresh_locale() -> void:
		if tooltip_key.is_empty():
			return
		tooltip_text = Loc.text(tooltip_key, [resource_value])
		accessibility_name = tooltip_text

	func icon_rect() -> Rect2:
		return ICON_RECT

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_HELP
		clip_contents = true
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		_ensure_value_label()

	func _ensure_value_label() -> void:
		if value_label != null:
			return
		value_label = Label.new()
		value_label.name = "Value"
		value_label.position = VALUE_RECT.position
		value_label.size = VALUE_RECT.size
		value_label.clip_text = true
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
		value_label.add_theme_color_override("font_color", Color("f0e8d7"))
		add_child(value_label)

	func _fit_value_text() -> void:
		var font := value_label.get_theme_font("font")
		var fitted_size := VALUE_FONT_SIZE
		while (
			fitted_size > VALUE_MIN_FONT_SIZE
			and font.get_string_size(
				value_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size
			).x > value_label.size.x
		):
			fitted_size -= 1
		value_label.add_theme_font_size_override("font_size", fitted_size)

	func _draw() -> void:
		if has_focus() or Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
			draw_rect(
				Rect2(Vector2(0.5, 4.5), size - Vector2(1, 9)),
				Color(0.45, 0.84, 0.81, 0.5),
				false,
				2.0,
			)
		match resource_id:
			"wood": _draw_wood()
			"stone": _draw_stone()
			"cloth": _draw_cloth()

	func _draw_wood() -> void:
		var origin := ICON_RECT.position
		var body := PackedVector2Array([
			origin + Vector2(3, 6), origin + Vector2(15, 3),
			origin + Vector2(20, 16), origin + Vector2(7, 20),
		])
		draw_colored_polygon(body, Color("865233"))
		draw_polyline(
			PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]),
			Color("4c2c1d"), ICON_STROKE_WIDTH, true,
		)
		draw_line(
			origin + Vector2(6, 8), origin + Vector2(9, 17),
			Color("bc7845"), ICON_STROKE_WIDTH, true,
		)
		var end_grain_center := origin + Vector2(16, 9)
		draw_circle(end_grain_center, 6.5, Color("d3a268"))
		draw_arc(
			end_grain_center, 6.5, 0, TAU, 24,
			Color("5c3824"), ICON_STROKE_WIDTH, true,
		)
		draw_arc(
			end_grain_center, 2.8, 0, TAU, 16,
			Color("99623c"), ICON_STROKE_WIDTH, true,
		)

	func _draw_stone() -> void:
		var origin := ICON_RECT.position
		var mass := PackedVector2Array([
			origin + Vector2(2, 17), origin + Vector2(5, 7),
			origin + Vector2(11, 2), origin + Vector2(19, 6),
			origin + Vector2(21, 15), origin + Vector2(15, 20),
			origin + Vector2(7, 20),
		])
		draw_colored_polygon(mass, Color("718496"))
		draw_colored_polygon(PackedVector2Array([
			origin + Vector2(5, 7), origin + Vector2(11, 2),
			origin + Vector2(13, 10), origin + Vector2(7, 14),
		]), Color("a7b3bc"))
		draw_polyline(
			PackedVector2Array([
				mass[0], mass[1], mass[2], mass[3], mass[4], mass[5], mass[6], mass[0],
			]),
			Color("3d4b5a"), ICON_STROKE_WIDTH, true,
		)
		draw_line(
			origin + Vector2(7, 14), origin + Vector2(15, 20),
			Color("4d5f70"), ICON_STROKE_WIDTH, true,
		)

	func _draw_cloth() -> void:
		var origin := ICON_RECT.position
		var swatch := PackedVector2Array([
			origin + Vector2(3, 5), origin + Vector2(17, 2),
			origin + Vector2(21, 16), origin + Vector2(7, 20),
		])
		draw_colored_polygon(swatch, Color("d7c09a"))
		draw_polyline(
			PackedVector2Array([swatch[0], swatch[1], swatch[2], swatch[3], swatch[0]]),
			Color("77654e"), ICON_STROKE_WIDTH, true,
		)
		draw_colored_polygon(PackedVector2Array([
			origin + Vector2(4, 11), origin + Vector2(18, 8),
			origin + Vector2(14, 17), origin + Vector2(7, 19),
		]), Color("b9a27d"))
		draw_polyline(PackedVector2Array([
			origin + Vector2(4, 11), origin + Vector2(18, 8),
			origin + Vector2(14, 17),
		]), Color("79654d"), ICON_STROKE_WIDTH, true)
