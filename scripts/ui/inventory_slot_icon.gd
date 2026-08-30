class_name InventorySlotIcon
extends Control

## Code-drawn quiet equipment silhouette used only for empty Character slots.

const CONTAINER := Color("171c25")
const BORDER := Color("293445")
const BORDER_ACTIVE := Color("354052")
const GLYPH := Color(0.478, 0.510, 0.565, 0.66)
const FOCUS := Color("72d7cf")
const PERMANENT_BORDER := Color("a97845")
const PERMANENT_GLYPH := Color(0.70, 0.57, 0.40, 0.86)

var slot_id := ""
var locked := false
var permanent := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var owner := get_parent() as Control
	if owner != null:
		owner.focus_entered.connect(queue_redraw)
		owner.focus_exited.connect(queue_redraw)


func set_slot(value: String, is_locked := false, is_permanent := false) -> void:
	slot_id = value
	locked = is_locked
	permanent = is_permanent
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var alpha := 0.30 if locked else 1.0
	var owner := get_parent() as Button
	var icon_overlay_only := permanent and owner != null and owner.icon != null
	if not icon_overlay_only:
		draw_rect(rect, Color(CONTAINER, alpha))
	var border_color := PERMANENT_BORDER if permanent else (BORDER_ACTIVE if locked else BORDER)
	draw_rect(rect.grow(-1.0), Color(border_color, alpha), false, 2.0)
	var base_glyph := PERMANENT_GLYPH if permanent else GLYPH
	var glyph := Color(base_glyph, base_glyph.a * alpha)
	if not icon_overlay_only:
		_draw_glyph(rect.get_center(), glyph)
	if locked or permanent:
		_draw_lock(Vector2(size.x - 10.0, 10.0), Color(0.62, 0.66, 0.72, 0.62))
	owner = get_parent() as Button
	if owner != null and owner.has_focus():
		draw_rect(rect.grow(-1.0), FOCUS, false, 2.0)
		_draw_focus_notches(rect)


func _draw_glyph(center: Vector2, color: Color) -> void:
	match slot_id:
		"jacket":
			var jacket := PackedVector2Array([
				center + Vector2(-7, -17), center + Vector2(-17, -10),
				center + Vector2(-13, 17), center + Vector2(-2, 17),
				center + Vector2(0, -3), center + Vector2(2, 17),
				center + Vector2(13, 17), center + Vector2(17, -10),
				center + Vector2(7, -17), center + Vector2(0, -10),
				center + Vector2(-7, -17),
			])
			draw_polyline(jacket, color, 2.0)
			draw_circle(center + Vector2(4, 5), 1.5, color)
		"head":
			draw_arc(center + Vector2(0, 2), 15.0, PI, TAU, 22, color, 2.0)
			draw_line(center + Vector2(-15, 2), center + Vector2(-15, 11), color, 2.0)
			draw_line(center + Vector2(15, 2), center + Vector2(15, 11), color, 2.0)
			draw_line(center + Vector2(-15, 11), center + Vector2(-7, 11), color, 2.0)
			draw_line(center + Vector2(7, 11), center + Vector2(15, 11), color, 2.0)
		"body":
			var torso := PackedVector2Array([
				center + Vector2(-8, -17), center + Vector2(-17, -10),
				center + Vector2(-12, 17), center + Vector2(12, 17),
				center + Vector2(17, -10), center + Vector2(8, -17),
				center + Vector2(4, -9), center + Vector2(-4, -9),
			])
			draw_polyline(torso, color, 2.0)
		"hands":
			_draw_glove(center + Vector2(-9, 0), color, -1.0)
			_draw_glove(center + Vector2(9, 0), color, 1.0)
		"legs":
			draw_line(center + Vector2(-8, -17), center + Vector2(-3, -1), color, 2.0)
			draw_line(center + Vector2(-3, -1), center + Vector2(-7, 17), color, 2.0)
			draw_line(center + Vector2(8, -17), center + Vector2(3, -1), color, 2.0)
			draw_line(center + Vector2(3, -1), center + Vector2(7, 17), color, 2.0)
			draw_line(center + Vector2(-8, -17), center + Vector2(8, -17), color, 2.0)
		"feet":
			draw_arc(center + Vector2(-8, 5), 9.0, 0.15, PI - 0.15, 14, color, 2.0)
			draw_arc(center + Vector2(8, 5), 9.0, 0.15, PI - 0.15, 14, color, 2.0)
			draw_line(center + Vector2(-17, 7), center + Vector2(-2, 7), color, 2.0)
			draw_line(center + Vector2(2, 7), center + Vector2(17, 7), color, 2.0)
		"right_hand":
			draw_line(center + Vector2(-13, 15), center + Vector2(11, -14), color, 3.0)
			draw_line(center + Vector2(7, -12), center + Vector2(13, -17), color, 2.0)
			draw_line(center + Vector2(-16, 10), center + Vector2(-7, 17), color, 2.0)
		"left_hand":
			draw_arc(center, 16.0, 0.28, PI - 0.28, 22, color, 2.0)
			draw_line(center + Vector2(-15, 5), center + Vector2(0, 17), color, 2.0)
			draw_line(center + Vector2(15, 5), center + Vector2(0, 17), color, 2.0)
		"back":
			var backpack := PackedVector2Array([
				center + Vector2(-10, -13), center + Vector2(10, -13),
				center + Vector2(15, -6), center + Vector2(15, 15),
				center + Vector2(-15, 15), center + Vector2(-15, -6),
				center + Vector2(-10, -13),
			])
			draw_polyline(backpack, color, 2.0)
			draw_arc(center + Vector2(0, -13), 8.0, PI, TAU, 12, color, 2.0)
			draw_line(center + Vector2(-15, 2), center + Vector2(15, 2), color, 2.0)
		"talisman":
			draw_line(center + Vector2(-12, -14), center, color, 2.0)
			draw_line(center + Vector2(12, -14), center, color, 2.0)
			draw_arc(center + Vector2(0, 6), 9.0, 0.0, TAU, 20, color, 2.0)
		"ring_1", "ring_2":
			draw_arc(center, 14.0, 0.0, TAU, 24, color, 2.0)
			var notches := 1 if slot_id == "ring_1" else 2
			for index in range(notches):
				var x := center.x + (index * 7.0 - (notches - 1) * 3.5)
				draw_line(Vector2(x, center.y - 17), Vector2(x, center.y - 10), color, 2.0)
		_:
			draw_circle(center, 8.0, color)


func _draw_glove(center: Vector2, color: Color, direction: float) -> void:
	draw_arc(center, 8.0, 0.0, TAU, 16, color, 2.0)
	for index in range(3):
		var y := -8.0 + index * 4.0
		draw_line(center + Vector2(direction * 5.0, y), center + Vector2(direction * 11.0, y - 1.0), color, 1.5)


func _draw_lock(center: Vector2, color: Color) -> void:
	draw_arc(center + Vector2(0, -2), 4.0, PI, TAU, 10, color, 1.5)
	draw_rect(Rect2(center + Vector2(-5, -1), Vector2(10, 8)), color, false, 1.5)


func _draw_focus_notches(rect: Rect2) -> void:
	for corner in [rect.position + Vector2(3, 3), Vector2(rect.end.x - 3, rect.position.y + 3), rect.end - Vector2(3, 3), Vector2(rect.position.x + 3, rect.end.y - 3)]:
		var sx := 1.0 if corner.x < rect.get_center().x else -1.0
		var sy := 1.0 if corner.y < rect.get_center().y else -1.0
		draw_line(corner, corner + Vector2(sx * 6.0, 0), FOCUS, 2.0)
		draw_line(corner, corner + Vector2(0, sy * 6.0), FOCUS, 2.0)
