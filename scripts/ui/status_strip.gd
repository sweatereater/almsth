class_name StatusStrip
extends Control

const StatusSystem := preload("res://scripts/game/status_system.gd")
const Loc := preload("res://scripts/localization/localization.gd")

const CHIP_SIZE := Vector2(32, 28)
const CHIP_GAP := 4.0
const MAX_VISIBLE_STATUSES := 4

var status_snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


func refresh(active_statuses: Dictionary) -> void:
	var sanitized := StatusSystem.sanitize(active_statuses)
	if sanitized == status_snapshot:
		return
	status_snapshot = sanitized
	_rebuild_chips()


func refresh_locale() -> void:
	_rebuild_chips()


func _rebuild_chips() -> void:
	for child in get_children():
		child.queue_free()
	var active_ids := StatusSystem.ordered_active_ids(status_snapshot)
	var shown_count := mini(active_ids.size(), MAX_VISIBLE_STATUSES)
	for index in range(shown_count):
		var status_id: String = active_ids[index]
		var chip := StatusChip.new()
		chip.position = Vector2(index * (CHIP_SIZE.x + CHIP_GAP), 1)
		chip.size = CHIP_SIZE
		chip.configure(status_id, status_snapshot[status_id])
		add_child(chip)
	if active_ids.size() > MAX_VISIBLE_STATUSES:
		var summary := StatusChip.new()
		summary.position = Vector2(shown_count * (CHIP_SIZE.x + CHIP_GAP), 1)
		summary.size = CHIP_SIZE
		summary.configure_summary(active_ids.size() - shown_count)
		add_child(summary)


class StatusChip extends Control:
	const ChipStatusSystem := preload("res://scripts/game/status_system.gd")
	const ChipLoc := preload("res://scripts/localization/localization.gd")

	var status_id := ""
	var entry: Dictionary = {}
	var summary_count := 0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_HELP

	func configure(value: String, status_entry: Dictionary) -> void:
		status_id = value
		entry = status_entry.duplicate(true)
		var status_rules := ChipStatusSystem.rules(status_id)
		tooltip_text = "%s — %s\n%s" % [
			ChipLoc.text(String(status_rules.get("name", status_id))),
			ChipLoc.text("STATUS_TURNS", [int(entry.get("remaining_turns", 0))]),
			ChipLoc.text(String(status_rules.get("description", ""))),
		]
		accessibility_name = tooltip_text
		queue_redraw()

	func configure_summary(value: int) -> void:
		summary_count = value
		tooltip_text = ChipLoc.text("STATUS_MORE", [summary_count])
		accessibility_name = tooltip_text
		queue_redraw()

	func _draw() -> void:
		draw_style_box(_chip_style(), Rect2(Vector2.ZERO, size))
		if summary_count > 0:
			_draw_text("+%d" % summary_count, Vector2(0, 18), 11, Color("d8dce4"))
			return
		if status_id == "rested":
			_draw_rested_ember()
		var duration := int(entry.get("remaining_turns", 0))
		_draw_text(str(duration), Vector2(12, 25), 8 if duration >= 100 else 9, Color("fff0ca"))

	func _chip_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("24252c")
		style.border_color = Color("a97043")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		return style

	func _draw_rested_ember() -> void:
		draw_circle(Vector2(11, 16), 6.0, Color(0.45, 0.16, 0.08, 0.95))
		draw_colored_polygon(PackedVector2Array([
			Vector2(7, 18), Vector2(9, 9), Vector2(12, 13),
			Vector2(15, 7), Vector2(16, 18),
		]), Color("e7883f"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(10, 18), Vector2(12, 12), Vector2(14, 18),
		]), Color("ffd37a"))

	func _draw_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
		draw_string(
			ThemeDB.fallback_font,
			position,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			20.0,
			font_size,
			color,
		)
