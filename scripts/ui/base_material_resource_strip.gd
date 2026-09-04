class_name BaseMaterialResourceStrip
extends Control

const Loc := preload("res://scripts/localization/localization.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")

const RESOURCE_ORDER := ["wood", "stone", "cloth"]
const TOOLTIP_KEYS := {
	"wood": "BASE_RESOURCE_WOOD_TOOLTIP",
	"stone": "BASE_RESOURCE_STONE_TOOLTIP",
	"cloth": "BASE_RESOURCE_CLOTH_TOOLTIP",
}

var counters: Dictionary = {}
var ui_context := Palette.WARM_ARCHIVE
var interactive := true
var compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	theme = ThemeController.theme_for(ui_context)
	for resource_id in RESOURCE_ORDER:
		var counter := MaterialCounter.new()
		counter.name = "%sCounter" % resource_id.capitalize()
		counter.configure(resource_id, TOOLTIP_KEYS[resource_id], ui_context, interactive, compact)
		add_child(counter)
		counters[resource_id] = counter
	_layout_counters()
	_configure_counter_focus()


func set_presentation(context_value: String, interactive_value := true, compact_value := false) -> void:
	ui_context = Palette.normalized_context(context_value)
	interactive = interactive_value
	compact = compact_value
	mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	theme = ThemeController.theme_for(ui_context)
	for resource_id in RESOURCE_ORDER:
		var counter: MaterialCounter = counters.get(resource_id)
		if counter != null:
			counter.set_presentation(ui_context, interactive, compact)
	_layout_counters()
	_configure_counter_focus()


func _layout_counters() -> void:
	if counters.is_empty():
		return
	if compact:
		var gap := 2.0
		var counter_width := (size.x - gap * 2.0) / 3.0
		for index in range(RESOURCE_ORDER.size()):
			var counter: MaterialCounter = counters[RESOURCE_ORDER[index]]
			counter.position = Vector2(index * (counter_width + gap), 0)
			counter.size = Vector2(counter_width, size.y)
			counter._apply_layout()
			counter.queue_redraw()
	else:
		# Base owns a fixed top-strip boundary, but the souls counter may need
		# more room for its complete carried/total value. Partition whatever
		# width remains equally and on integer boundaries; 198px becomes three
		# exact 66px counters whose 12px tabular `9999` labels still fit.
		for index in range(RESOURCE_ORDER.size()):
			var resource_id: String = RESOURCE_ORDER[index]
			var counter: MaterialCounter = counters[resource_id]
			var left := floorf(size.x * index / float(RESOURCE_ORDER.size()))
			var right := floorf(size.x * (index + 1) / float(RESOURCE_ORDER.size()))
			counter.position = Vector2(left, 0)
			counter.size = Vector2(right - left, size.y)
			counter._apply_layout()
			counter.queue_redraw()


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


func focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for resource_id in RESOURCE_ORDER:
		var counter: Control = counters.get(resource_id)
		if interactive and counter != null and counter.visible:
			result.append(counter)
	return result


func _configure_counter_focus() -> void:
	var controls := focusable_controls()
	for index in range(controls.size()):
		var previous := controls[(index - 1 + controls.size()) % controls.size()]
		var next := controls[(index + 1) % controls.size()]
		controls[index].focus_neighbor_left = previous.get_path()
		controls[index].focus_neighbor_top = previous.get_path()
		controls[index].focus_neighbor_right = next.get_path()
		controls[index].focus_neighbor_bottom = next.get_path()


class MaterialCounter extends Control:
	const CounterPalette := preload("res://scripts/ui/ui_palette.gd")
	const CounterThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
	const BASE_ICON_RECT := Rect2(5, 11, 22, 22)
	const ICON_STROKE_WIDTH := 2.7
	const VALUE_FONT_SIZE := 12
	static var WOOD_BODY := PackedVector2Array([
		Vector2(3, 6), Vector2(15, 3), Vector2(20, 16), Vector2(7, 20),
	])
	static var WOOD_OUTLINE := PackedVector2Array([
		Vector2(3, 6), Vector2(15, 3), Vector2(20, 16), Vector2(7, 20), Vector2(3, 6),
	])
	static var STONE_MASS := PackedVector2Array([
		Vector2(2, 17), Vector2(5, 7), Vector2(11, 2), Vector2(19, 6),
		Vector2(21, 15), Vector2(15, 20), Vector2(7, 20),
	])
	static var STONE_OUTLINE := PackedVector2Array([
		Vector2(2, 17), Vector2(5, 7), Vector2(11, 2), Vector2(19, 6),
		Vector2(21, 15), Vector2(15, 20), Vector2(7, 20), Vector2(2, 17),
	])
	static var STONE_HIGHLIGHT := PackedVector2Array([
		Vector2(5, 7), Vector2(11, 2), Vector2(13, 10), Vector2(7, 14),
	])
	static var CLOTH_SWATCH := PackedVector2Array([
		Vector2(3, 5), Vector2(17, 2), Vector2(21, 16), Vector2(7, 20),
	])
	static var CLOTH_OUTLINE := PackedVector2Array([
		Vector2(3, 5), Vector2(17, 2), Vector2(21, 16), Vector2(7, 20), Vector2(3, 5),
	])
	static var CLOTH_FOLD := PackedVector2Array([
		Vector2(4, 11), Vector2(18, 8), Vector2(14, 17), Vector2(7, 19),
	])
	static var CLOTH_SEAM := PackedVector2Array([
		Vector2(4, 11), Vector2(18, 8), Vector2(14, 17),
	])

	var resource_id := ""
	var tooltip_key := ""
	var resource_value := 0
	var value_label: Label
	var normal_style: StyleBoxFlat
	var hover_style: StyleBoxFlat
	var focus_style: StyleBoxFlat
	var value_font: Font
	var hovered := false
	var ui_context := CounterPalette.WARM_ARCHIVE
	var interactive := true
	var compact := false
	var icon_rect_value := BASE_ICON_RECT
	var value_x := 29.0

	func configure(
		id_value: String,
		tooltip_key_value: String,
		context_value := CounterPalette.WARM_ARCHIVE,
		interactive_value := true,
		compact_value := false,
	) -> void:
		resource_id = id_value
		tooltip_key = tooltip_key_value
		ui_context = CounterPalette.normalized_context(context_value)
		interactive = interactive_value
		compact = compact_value
		_cache_resources()
		_ensure_value_label()
		_apply_layout()
		refresh_locale()
		queue_redraw()

	func set_presentation(context_value: String, interactive_value: bool, compact_value: bool) -> void:
		ui_context = CounterPalette.normalized_context(context_value)
		interactive = interactive_value
		compact = compact_value
		theme = CounterThemeController.theme_for(ui_context)
		focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_HELP if interactive else Control.CURSOR_ARROW
		hovered = false
		_cache_resources()
		_apply_layout()
		refresh_locale()
		queue_redraw()

	func set_value(value: int) -> void:
		resource_value = maxi(0, value)
		_ensure_value_label()
		value_label.text = str(resource_value)
		refresh_locale()

	func refresh_locale() -> void:
		if tooltip_key.is_empty():
			return
		tooltip_text = Loc.text(tooltip_key, [resource_value])
		accessibility_name = tooltip_text
		accessibility_description = tooltip_text

	func icon_rect() -> Rect2:
		return icon_rect_value

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_HELP if interactive else Control.CURSOR_ARROW
		clip_contents = true
		theme = CounterThemeController.theme_for(ui_context)
		mouse_entered.connect(_set_hovered.bind(true))
		mouse_exited.connect(_set_hovered.bind(false))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		_cache_resources()
		_ensure_value_label()

	func _set_hovered(value: bool) -> void:
		hovered = value
		queue_redraw()

	func _cache_resources() -> void:
		normal_style = CounterThemeController.style_for(
			ui_context, "material_counter", "normal"
		)
		hover_style = CounterThemeController.style_for(
			ui_context, "material_counter", "hover"
		)
		focus_style = CounterThemeController.style_for(
			ui_context, "material_counter", "focus"
		)
		value_font = CounterThemeController.functional_font("regular", true)

	func _ensure_value_label() -> void:
		if value_label != null:
			return
		value_label = Label.new()
		value_label.name = "Value"
		value_label.position = Vector2(value_x, 0)
		value_label.size = Vector2(maxf(1.0, size.x - value_x - 3.0), size.y)
		value_label.clip_text = true
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.add_theme_font_override("font", value_font)
		value_label.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
		value_label.add_theme_color_override(
			"font_color", CounterPalette.color(ui_context, "primary")
		)
		add_child(value_label)

	func _apply_layout() -> void:
		icon_rect_value = Rect2(3, (size.y - 18.0) * 0.5, 18, 18) if compact else BASE_ICON_RECT
		value_x = 22.0 if compact else 29.0
		if value_label != null:
			value_label.position = Vector2(value_x, 0)
			value_label.size = Vector2(maxf(1.0, size.x - value_x - 2.0), size.y)
			value_label.add_theme_color_override(
				"font_color", CounterPalette.color(ui_context, "primary")
			)

	func _draw() -> void:
		var state_rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_style_box(hover_style if interactive and hovered else normal_style, state_rect)
		match resource_id:
			"wood": _draw_wood()
			"stone": _draw_stone()
			"cloth": _draw_cloth()
		if interactive and has_focus():
			draw_style_box(focus_style, state_rect)

	func _draw_wood() -> void:
		var origin := icon_rect_value.position
		draw_set_transform(origin, 0.0, Vector2.ONE * (icon_rect_value.size.x / 22.0))
		draw_colored_polygon(WOOD_BODY, Color("865233"))
		draw_polyline(WOOD_OUTLINE, Color("4c2c1d"), ICON_STROKE_WIDTH, true)
		draw_line(
			Vector2(6, 8), Vector2(9, 17),
			Color("bc7845"), ICON_STROKE_WIDTH, true,
		)
		var end_grain_center := Vector2(16, 9)
		draw_circle(end_grain_center, 6.5, Color("d3a268"))
		draw_arc(
			end_grain_center, 6.5, 0, TAU, 24,
			Color("5c3824"), ICON_STROKE_WIDTH, true,
		)
		draw_arc(
			end_grain_center, 2.8, 0, TAU, 16,
			Color("99623c"), ICON_STROKE_WIDTH, true,
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_stone() -> void:
		var origin := icon_rect_value.position
		draw_set_transform(origin, 0.0, Vector2.ONE * (icon_rect_value.size.x / 22.0))
		draw_colored_polygon(STONE_MASS, Color("718496"))
		draw_colored_polygon(STONE_HIGHLIGHT, Color("a7b3bc"))
		draw_polyline(STONE_OUTLINE, Color("3d4b5a"), ICON_STROKE_WIDTH, true)
		draw_line(
			Vector2(7, 14), Vector2(15, 20),
			Color("4d5f70"), ICON_STROKE_WIDTH, true,
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_cloth() -> void:
		var origin := icon_rect_value.position
		draw_set_transform(origin, 0.0, Vector2.ONE * (icon_rect_value.size.x / 22.0))
		draw_colored_polygon(CLOTH_SWATCH, Color("d7c09a"))
		draw_polyline(CLOTH_OUTLINE, Color("77654e"), ICON_STROKE_WIDTH, true)
		draw_colored_polygon(CLOTH_FOLD, Color("b9a27d"))
		draw_polyline(CLOTH_SEAM, Color("79654d"), ICON_STROKE_WIDTH, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
