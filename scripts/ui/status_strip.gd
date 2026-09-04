class_name StatusStrip
extends Control

const StatusSystem := preload("res://scripts/game/status_system.gd")
const Loc := preload("res://scripts/localization/localization.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")

const CHIP_SIZE := Vector2(32, 28)
const CHIP_GAP := 4.0
const MAX_VISIBLE_STATUSES := 4

var status_snapshot: Dictionary = {}
var semantic_context := Palette.WARM_ARCHIVE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	theme = ThemeController.theme_for(semantic_context)


func set_context(context: String) -> void:
	semantic_context = Palette.normalized_context(context)
	theme = ThemeController.theme_for(semantic_context)
	for child in get_children():
		if child is StatusChip:
			child.set_context(semantic_context)


func refresh(active_statuses: Dictionary) -> void:
	var sanitized := StatusSystem.sanitize(active_statuses)
	if sanitized == status_snapshot:
		return
	status_snapshot = sanitized
	_rebuild_chips()


func refresh_locale() -> void:
	_rebuild_chips()


func focusable_controls() -> Array[Control]:
	var result: Array[Control] = []
	for child in get_children():
		if child is StatusChip and child.visible:
			result.append(child)
	return result


func _rebuild_chips() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var active_ids := StatusSystem.ordered_active_ids(status_snapshot)
	var counts := presentation_counts(active_ids.size())
	var shown_count := counts.x
	for index in range(shown_count):
		var status_id: String = active_ids[index]
		var chip := StatusChip.new()
		chip.name = "Status_%s" % status_id
		chip.position = Vector2(index * (CHIP_SIZE.x + CHIP_GAP), 1)
		chip.size = CHIP_SIZE
		chip.configure(status_id, status_snapshot[status_id], semantic_context)
		add_child(chip)
	if counts.y > 0:
		var summary := StatusChip.new()
		summary.name = "StatusMore"
		summary.position = Vector2(shown_count * (CHIP_SIZE.x + CHIP_GAP), 1)
		summary.size = CHIP_SIZE
		summary.configure_summary(counts.y, semantic_context)
		add_child(summary)


static func presentation_counts(active_count: int) -> Vector2i:
	var shown_count := mini(maxi(active_count, 0), MAX_VISIBLE_STATUSES)
	return Vector2i(shown_count, maxi(0, active_count - shown_count))


class StatusChip extends Control:
	const ChipStatusSystem := preload("res://scripts/game/status_system.gd")
	const ChipLoc := preload("res://scripts/localization/localization.gd")
	const ChipPalette := preload("res://scripts/ui/ui_palette.gd")
	const ChipThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
	static var RESTED_FLAME := PackedVector2Array([
		Vector2(7, 18), Vector2(9, 9), Vector2(12, 13),
		Vector2(15, 7), Vector2(16, 18),
	])
	static var RESTED_CORE := PackedVector2Array([
		Vector2(10, 18), Vector2(12, 12), Vector2(14, 18),
	])
	static var SATIATED_BOWL := PackedVector2Array([
		Vector2(6, 14), Vector2(16, 14), Vector2(14, 19), Vector2(8, 19),
	])

	var status_id := ""
	var entry: Dictionary = {}
	var summary_count := 0
	var semantic_context := ChipPalette.WARM_ARCHIVE
	var normal_style: StyleBoxFlat
	var hover_style: StyleBoxFlat
	var focus_style: StyleBoxFlat
	var text_font: Font
	var hovered := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_HELP
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(_set_hovered.bind(true))
		mouse_exited.connect(_set_hovered.bind(false))
		_cache_resources()

	func set_context(context: String) -> void:
		semantic_context = ChipPalette.normalized_context(context)
		_cache_resources()
		queue_redraw()

	func _set_hovered(value: bool) -> void:
		hovered = value
		queue_redraw()

	func configure(
		value: String,
		status_entry: Dictionary,
		context := ChipPalette.WARM_ARCHIVE
	) -> void:
		status_id = value
		entry = status_entry.duplicate(true)
		semantic_context = ChipPalette.normalized_context(context)
		var status_rules := ChipStatusSystem.rules(status_id)
		var status_name := ChipLoc.text(String(status_rules.get("name", status_id)))
		var turns := ChipLoc.text("STATUS_TURNS", [int(entry.get("remaining_turns", 0))])
		tooltip_text = "%s — %s\n%s" % [
			status_name,
			turns,
			ChipLoc.text(String(status_rules.get("description", ""))),
		]
		# Preserve the complete visible help text as the spoken accessible name. This
		# keeps the exact duration and description available without relying on a
		# separate tooltip-only interaction.
		accessibility_name = tooltip_text
		accessibility_description = tooltip_text
		_cache_resources()
		queue_redraw()

	func configure_summary(value: int, context := ChipPalette.WARM_ARCHIVE) -> void:
		summary_count = value
		semantic_context = ChipPalette.normalized_context(context)
		tooltip_text = ChipLoc.text("STATUS_MORE", [summary_count])
		accessibility_name = tooltip_text
		accessibility_description = tooltip_text
		_cache_resources()
		queue_redraw()

	func _cache_resources() -> void:
		normal_style = ChipThemeController.style_for(semantic_context, "status_chip", "normal")
		hover_style = ChipThemeController.style_for(semantic_context, "status_chip", "hover")
		focus_style = ChipThemeController.style_for(semantic_context, "status_chip", "focus")
		text_font = ChipThemeController.functional_font("semibold", true)

	func _draw() -> void:
		draw_style_box(hover_style if hovered else normal_style, Rect2(Vector2.ZERO, size))
		if summary_count > 0:
			_draw_text("+%d" % summary_count, Vector2(0, 21), 12, ChipPalette.color(semantic_context, "primary"), 32.0)
		elif status_id == "rested":
			_draw_rested_ember()
		elif status_id == "satiated":
			_draw_satiated_meal()
		if summary_count == 0:
			var duration := int(entry.get("remaining_turns", 0))
			_draw_text(str(duration), Vector2(12, 25), 12, ChipPalette.color(semantic_context, "primary"), 18.0)
		if has_focus():
			draw_style_box(focus_style, Rect2(Vector2(2, 2), size - Vector2(4, 4)))

	func _draw_rested_ember() -> void:
		draw_circle(Vector2(11, 16), 6.0, ChipPalette.color(semantic_context, "danger_surface"))
		draw_colored_polygon(RESTED_FLAME, ChipPalette.color(semantic_context, "danger"))
		draw_colored_polygon(RESTED_CORE, ChipPalette.color(semantic_context, "focus"))

	func _draw_satiated_meal() -> void:
		draw_circle(Vector2(11, 15), 6.0, ChipPalette.color(semantic_context, "selected_fill"))
		draw_circle(Vector2(11, 15), 4.5, ChipPalette.color(semantic_context, "focus"))
		draw_colored_polygon(SATIATED_BOWL, ChipPalette.color(semantic_context, "neutral_border"))
		draw_line(Vector2(8, 20), Vector2(14, 20), ChipPalette.color(semantic_context, "primary"), 1.5)

	func _draw_text(
		text: String,
		position: Vector2,
		font_size: int,
		color: Color,
		width: float
	) -> void:
		draw_string(
			text_font,
			position,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			font_size,
			color,
		)
