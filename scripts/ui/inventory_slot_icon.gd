class_name InventorySlotIcon
extends Control

var slot_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_slot(value: String) -> void:
	slot_id = value
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color := _slot_color(slot_id)
	draw_rect(rect, Color("202a38"))
	draw_rect(rect, color, false, 2.0)
	var center := rect.get_center()
	match slot_id:
		"weapon":
			draw_line(center + Vector2(-9, 10), center + Vector2(9, -10), color, 3.0)
			draw_line(center + Vector2(-9, 6), center + Vector2(-5, 10), color, 3.0)
		"armor":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-10, -9), center + Vector2(10, -9),
				center + Vector2(8, 11), center + Vector2(-8, 11),
			]), Color(color, 0.55))
		"hands":
			draw_circle(center, 9.0, Color(color, 0.55))
			draw_line(center + Vector2(-8, 7), center + Vector2(8, 7), color, 2.0)
		"charm":
			draw_arc(center, 9.0, 0.0, TAU, 24, color, 2.5, true)
			draw_line(center + Vector2(0, -11), center + Vector2(0, -17), color, 2.0)
		"relic":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -12), center + Vector2(10, 0),
				center + Vector2(0, 12), center + Vector2(-10, 0),
			]), Color(color, 0.55))
		"offhand":
			draw_arc(center, 11.0, 0.3, PI - 0.3, 16, color, 3.0)
		_:
			draw_circle(center, 8.0, color)


func _slot_color(slot: String) -> Color:
	match slot:
		"weapon": return Color("c89562")
		"armor": return Color("8497aa")
		"hands": return Color("b28a72")
		"charm": return Color("72d7cf")
		"relic": return Color("a48bd0")
		"offhand": return Color("9ab07a")
	return Color("596274")
