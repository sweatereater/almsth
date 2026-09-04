class_name CampSilhouetteOverlay
extends Control

## Cached alpha-derived outlines for camp props. Source art is never tinted or
## modified: every texture below is generated once from a layer alpha mask.

const BaseLayout := preload("res://scripts/ui/base_layout.gd")
const Renderer := preload("res://scripts/ui/game_renderer.gd")
const IDS := ["mural", "bunk", "textile_area", "workbench", "writing_set", "ritual_table", "crusher", "whetstone", "campfire", "kettle", "rocking_chair", "record_player", "storage_chest"]
const OUTER := Color("f2e8d4")
const SELECTED := Color("67cdc5")
const FOCUS := Color("e1b965")
static var cached_outlines: Dictionary = {}
var states: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in IDS:
		states[id] = "normal"
		_ensure_cached(id)

func set_state(id: String, state: String) -> void:
	if not states.has(id) or states[id] == state:
		return
	states[id] = state
	queue_redraw()

func set_states(next: Dictionary) -> void:
	var changed := false
	for id in IDS:
		var value := String(next.get(id, "normal"))
		if states.get(id, "normal") != value:
			states[id] = value
			changed = true
	if changed:
		queue_redraw()

static func cache_cardinality() -> int:
	return cached_outlines.size()

static func _ensure_cached(id: String) -> void:
	var texture: Texture2D = Renderer.CAMP_LAYER_ART.get(id)
	if texture == null:
		return
	var source_path := texture.resource_path
	var source_hash := FileAccess.get_sha256(source_path) if not source_path.is_empty() and FileAccess.file_exists(source_path) else str(texture.get_instance_id())
	if cached_outlines.has(id) and String(cached_outlines[id].get("source_hash", "")) == source_hash:
		return
	var source := texture.get_image()
	var size := source.get_size()
	var masks := {}
	# Build each morphology in separate passes.  Clearing while dilating a later
	# source pixel would refill an earlier interior and tint the world prop.
	# Hover is a native +2 image/rect.  Keep a separate +4-coordinate
	# dilate2 only for subtracting the focus ring; never scale either mask.
	var dilate2 := Image.create(size.x + 4, size.y + 4, false, Image.FORMAT_RGBA8)
	var dilate2_for_focus := Image.create(size.x + 8, size.y + 8, false, Image.FORMAT_RGBA8)
	var dilate4 := Image.create(size.x + 8, size.y + 8, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			if source.get_pixel(x, y).a < (32.0 / 255.0):
				continue
			for radius in [2, 4]:
				var destination := dilate2 if radius == 2 else dilate4
				for oy in range(-radius, radius + 1):
					for ox in range(-radius, radius + 1):
						if ox * ox + oy * oy <= radius * radius:
							var offset := 2 if radius == 2 else 4
							destination.set_pixel(x + ox + offset, y + oy + offset, Color.WHITE)
							if radius == 2:
								dilate2_for_focus.set_pixel(x + ox + 4, y + oy + 4, Color.WHITE)
	for y in dilate4.get_height():
		for x in dilate4.get_width():
			if dilate2_for_focus.get_pixel(x, y).a > 0.0:
				dilate4.set_pixel(x, y, Color.TRANSPARENT)
	for y in size.y:
		for x in size.x:
			if source.get_pixel(x, y).a >= (32.0 / 255.0):
				dilate2.set_pixel(x + 2, y + 2, Color.TRANSPARENT)
	masks[2] = ImageTexture.create_from_image(dilate2)
	masks[4] = ImageTexture.create_from_image(dilate4)
	var inner := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			if source.get_pixel(x, y).a < (32.0 / 255.0):
				continue
			var edge := false
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var sx := x + ox
					var sy := y + oy
					if sx < 0 or sy < 0 or sx >= size.x or sy >= size.y or source.get_pixel(sx, sy).a < (32.0 / 255.0):
						edge = true
						break
				if edge:
					break
			if edge:
				inner.set_pixel(x, y, Color.WHITE)
	masks["inner"] = ImageTexture.create_from_image(inner)
	cached_outlines[id] = {"source_hash": source_hash, "masks": masks}

func _draw() -> void:
	for id in IDS:
		var state := String(states.get(id, "normal"))
		if state == "normal" or state == "disabled_unbuilt" or not cached_outlines.has(id):
			continue
		var masks: Dictionary = cached_outlines[id].masks
		if state == "hover":
			draw_texture_rect(masks[2], BaseLayout.camp_layer_rect(id).grow(2), false, OUTER)
		elif state == "selected":
			draw_texture_rect(masks["inner"], BaseLayout.camp_layer_rect(id), false, SELECTED)
		elif state == "focus":
			var focus_rect := BaseLayout.camp_layer_rect(id).grow(4)
			draw_texture_rect(masks[4], focus_rect, false, FOCUS)
			_draw_chevron(focus_rect, FOCUS)
		elif state == "selected_focus":
			draw_texture_rect(masks["inner"], BaseLayout.camp_layer_rect(id), false, SELECTED)
			var selected_focus_rect := BaseLayout.camp_layer_rect(id).grow(4)
			draw_texture_rect(masks[4], selected_focus_rect, false, FOCUS)
			_draw_chevron(selected_focus_rect, FOCUS)

func _draw_chevron(rect: Rect2, color: Color) -> void:
	var center := Vector2(rect.get_center().x, rect.position.y + 3.0)
	# Two lines avoid allocating a PackedVector2Array every redraw.
	draw_line(center + Vector2(-5, 4), center, color, 2.0)
	draw_line(center, center + Vector2(5, 4), color, 2.0)
