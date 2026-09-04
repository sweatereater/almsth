extends RefCounted

## Character-only archive materials. All raster/style resources are constructed
## once before drawing; no world, item or portrait pixels are tinted.
const ThemeController := preload("res://scripts/ui/ui_theme_controller.gd")
const Palette := preload("res://scripts/ui/ui_palette.gd")
const BRONZE := Color("766346")
const EDGE_LIGHT := Color("a78b5c")
const GROOVE := Color("080a09")
static var materials: Dictionary = {}
static var styles: Dictionary = {}


static func prepare() -> void:
	if not materials.is_empty():
		return
	for kind in ["panel", "niche", "normal", "hover", "selected", "disabled"]:
		var dimensions := Vector2i(256, 256) if kind == "panel" else Vector2i(128, 64)
		if kind == "niche":
			dimensions = Vector2i(245, 530)
		var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		for y in dimensions.y:
			for x in dimensions.x:
				var p := Vector2(float(x) / dimensions.x, float(y) / dimensions.y)
				# Fixed integer grain + broad mineral mottling: independent of game RNG.
				var grain := float((x * 374761393 + y * 668265263 + x * y * 127) % 101) / 100.0
				var mottle := _noise(p, 8) * 0.65 + _noise(p, 16) * 0.35
				var value := 0.044 + grain * 0.020 + mottle * 0.035
				var color := Color(value * 1.08, value * 1.04, value * 0.94)
				if kind == "niche":
					var light := exp(-pow((p.x - 0.53) * 3.0, 2) - pow((p.y - 0.86) * 2.7, 2))
					color = color.darkened(0.36).lerp(Color("493720"), light * 0.52)
					var corner := Vector2(clampf(x, 32, dimensions.x - 33), clampf(y, 32, dimensions.y - 33))
					if Vector2(x, y).distance_to(corner) > 32:
						color.a = 0.0
				elif kind == "selected":
					color = color.lerp(Palette.color(Palette.WARM_ARCHIVE, "selected_fill"), 0.80)
				elif kind == "hover":
					color = color.lightened(0.035)
				elif kind == "disabled":
					color = color.darkened(0.25)
				image.set_pixel(x, y, color)
		if kind not in ["panel", "niche"]:
			var border := BRONZE
			if kind == "selected":
				border = Palette.color(Palette.WARM_ARCHIVE, "soul")
			elif kind == "disabled":
				border = Color("484338")
			for inset in [0, 2, 4]:
				var line := border if inset == 0 else (GROOVE if inset == 2 else Color(border, 0.42))
				image.fill_rect(Rect2i(inset, inset, dimensions.x - inset * 2, 1), line)
				image.fill_rect(Rect2i(inset, dimensions.y - inset - 1, dimensions.x - inset * 2, 1), line)
				image.fill_rect(Rect2i(inset, inset, 1, dimensions.y - inset * 2), line)
				image.fill_rect(Rect2i(dimensions.x - inset - 1, inset, 1, dimensions.y - inset * 2), line)
			if kind == "selected":
				image.fill_rect(Rect2i(0, 4, 4, dimensions.y - 8), border)
		materials[kind] = ImageTexture.create_from_image(image)
		if kind not in ["panel", "niche"]:
			for compact in [false, true]:
				var style := StyleBoxTexture.new()
				style.texture = materials[kind]
				style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
				style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					style.set_texture_margin(side, 6.0)
					style.set_content_margin(side, 3.0 if compact else (10.0 if side in [SIDE_LEFT, SIDE_RIGHT] else 5.0))
				styles[kind + ("_compact" if compact else "")] = style
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Palette.color(Palette.WARM_ARCHIVE, "focus")
	focus.set_border_width_all(1)
	focus.set_expand_margin_all(3.0)
	styles.focus = focus


static func _lattice(x: int, y: int, period: int) -> float:
	x = posmod(x, period)
	y = posmod(y, period)
	var value := (x * 374761393 + y * 668265263 + 982451653) & 0x7fffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0x7fffffff
	return float(value % 65536) / 65535.0


static func _noise(p: Vector2, period: int) -> float:
	var point := p * period
	var cell := Vector2i(point.floor())
	var f := point - Vector2(cell)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	return lerpf(lerpf(_lattice(cell.x, cell.y, period), _lattice(cell.x + 1, cell.y, period), f.x), lerpf(_lattice(cell.x, cell.y + 1, period), _lattice(cell.x + 1, cell.y + 1, period), f.x), f.y)


static func apply_button(button: Button, enabled := true, compact := false) -> void:
	prepare()
	if enabled:
		button.add_theme_stylebox_override("focus", styles.focus)
	else:
		button.remove_theme_stylebox_override("focus")
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		if enabled:
			var material: String = "selected" if state in ["pressed", "hover_pressed"] else state
			button.add_theme_stylebox_override(state, styles[material + ("_compact" if compact else "")])
		else:
			button.remove_theme_stylebox_override(state)


static func apply_title(control: Control, font_size: int) -> void:
	assert(font_size in [16, 20, 28], "Sheet ornamental type must use the reviewed scale")
	control.add_theme_font_override("font", ThemeController.heading_font())
	control.add_theme_font_size_override("font_size", font_size)


static func draw_panel(canvas: CanvasItem, rect: Rect2, ornate := true) -> void:
	canvas.draw_texture_rect(materials.panel, rect, true)
	canvas.draw_rect(rect.grow(-0.5), BRONZE, false, 1.0)
	canvas.draw_rect(rect.grow(-2.5), GROOVE, false, 1.0)
	canvas.draw_rect(rect.grow(-4.5), Color(BRONZE, 0.55), false, 1.0)
	if not ornate:
		return
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var direction := Vector2(1 if corner.x < rect.get_center().x else -1, 1 if corner.y < rect.get_center().y else -1)
		var origin: Vector2 = corner + direction * 3
		canvas.draw_line(origin, origin + Vector2(direction.x * 17, 0), EDGE_LIGHT, 1.0, true)
		canvas.draw_line(origin, origin + Vector2(0, direction.y * 17), EDGE_LIGHT, 1.0, true)
		canvas.draw_line(origin + Vector2(direction.x * 13, 0), origin + Vector2(0, direction.y * 13), BRONZE, 1.0, true)


static func draw_niche(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_texture_rect(materials.niche, rect, false)
	# Cached material is rounded; matching thin arcs form an inset architectural niche.
	for inset in [0.5, 2.5]:
		var box := rect.grow(-inset)
		var radius: float = 32.0 - inset
		var color := BRONZE if inset == 0.5 else GROOVE
		canvas.draw_line(box.position + Vector2(radius, 0), Vector2(box.end.x - radius, box.position.y), color, 1.0, true)
		canvas.draw_line(Vector2(box.position.x + radius, box.end.y), box.end - Vector2(radius, 0), color, 1.0, true)
		canvas.draw_line(box.position + Vector2(0, radius), Vector2(box.position.x, box.end.y - radius), color, 1.0, true)
		canvas.draw_line(Vector2(box.end.x, box.position.y + radius), box.end - Vector2(0, radius), color, 1.0, true)
		for corner in [[box.position + Vector2(radius, radius), PI, PI * 1.5], [Vector2(box.end.x - radius, box.position.y + radius), PI * 1.5, TAU], [box.end - Vector2(radius, radius), 0.0, PI * 0.5], [Vector2(box.position.x + radius, box.end.y - radius), PI * 0.5, PI]]:
			canvas.draw_arc(corner[0], radius, corner[1], corner[2], 18, color, 1.0, true)
