class_name UiThemeController
extends RefCounted

## Central, allocation-free-after-warmup Theme/StyleBox/font factory.
## Screen code selects a semantic context; controls select semantic variations.

const Palette := preload("res://scripts/ui/ui_palette.gd")
const NOTO_REGULAR: Font = preload("res://assets/fonts/noto-sans/NotoSans-Regular.ttf")
const NOTO_MEDIUM: Font = preload("res://assets/fonts/noto-sans/NotoSans-Medium.ttf")
const NOTO_SEMIBOLD: Font = preload("res://assets/fonts/noto-sans/NotoSans-SemiBold.ttf")
const CORMORANT_SEMIBOLD: Font = preload("res://assets/fonts/cormorant-garamond/CormorantGaramond-SemiBold.ttf")
const UI_SYMBOLS: Font = preload("res://assets/fonts/ui-symbols/stage1c-ui-symbols.fnt")

const WARM_ARCHIVE := Palette.WARM_ARCHIVE
const COLD_DUNGEON := Palette.COLD_DUNGEON
const FONT_SIZES := [12, 14, 16, 20, 28, 32]

static var _theme_cache: Dictionary = {}
static var _style_cache: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _font_sources_configured := false


static func theme_for(context: String) -> Theme:
	context = Palette.normalized_context(context)
	if not _theme_cache.has(context):
		_theme_cache[context] = _build_theme(context)
	return _theme_cache[context]


static func style_for(context: String, variation: String, state: String) -> StyleBoxFlat:
	context = Palette.normalized_context(context)
	var key := "%s|%s|%s" % [context, variation, state]
	if not _style_cache.has(key):
		_style_cache[key] = _build_style(context, variation, state)
	return _style_cache[key]


static func texture_for(context: String, variation: String, state: String) -> Texture2D:
	context = Palette.normalized_context(context)
	var key := "%s|%s|%s" % [context, variation, state]
	if not _texture_cache.has(key):
		_texture_cache[key] = _build_texture(context, variation, state)
	return _texture_cache[key]


static func is_approved_font_size(font_size: int) -> bool:
	return FONT_SIZES.has(font_size)


static func approved_font_size(font_size: int) -> int:
	## Deterministic nearest member of the Stage 1C virtual type scale. Ties
	## resolve upward so essential text does not become less readable.
	var best: int = FONT_SIZES[0]
	var best_distance := absi(font_size - best)
	for candidate: int in FONT_SIZES:
		var distance := absi(font_size - candidate)
		if distance < best_distance or (distance == best_distance and candidate > best):
			best = candidate
			best_distance = distance
	return best


static func approved_sizes_between(preferred_size: int, minimum_size: int) -> Array[int]:
	var result: Array[int] = []
	var maximum := approved_font_size(preferred_size)
	var minimum := approved_font_size(minimum_size)
	for index in range(FONT_SIZES.size() - 1, -1, -1):
		var candidate: int = FONT_SIZES[index]
		if candidate <= maximum and candidate >= minimum:
			result.append(candidate)
	if result.is_empty():
		result.append(minimum)
	return result


static func legacy_button_style(
	background: Color,
	border: Color,
	border_width := 1,
	corner_radius := 4
) -> StyleBoxFlat:
	var key := "legacy_button|%s|%s|%d|%d" % [background.to_html(true), border.to_html(true), border_width, corner_radius]
	if not _style_cache.has(key):
		var style := _flat_style(background, border, border_width, corner_radius)
		_style_cache[key] = style
	return _style_cache[key]


static func legacy_panel_style(context: String, border: Color) -> StyleBoxFlat:
	context = Palette.normalized_context(context)
	var key := "legacy_panel|%s|%s" % [context, border.to_html(true)]
	if not _style_cache.has(key):
		var style := _flat_style(Palette.color(context, "panel"), border, 2, 8)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 5)
		style.content_margin_left = 18.0
		style.content_margin_right = 18.0
		style.content_margin_top = 14.0
		style.content_margin_bottom = 14.0
		_style_cache[key] = style
	return _style_cache[key]


static func functional_font(weight := "regular", tabular := false) -> Font:
	_configure_font_sources()
	var key := "%s|%s" % [weight, "tnum" if tabular else "proportional"]
	if _font_cache.has(key):
		return _font_cache[key]
	var base: Font = NOTO_REGULAR
	if weight == "medium":
		base = NOTO_MEDIUM
	elif weight == "semibold":
		base = NOTO_SEMIBOLD
	var variation := FontVariation.new()
	variation.base_font = base
	variation.fallbacks = [UI_SYMBOLS]
	if tabular:
		variation.variation_opentype = {
			TextServerManager.get_primary_interface().name_to_tag("tnum"): 1,
		}
	_font_cache[key] = variation
	return variation


static func heading_font() -> Font:
	_configure_font_sources()
	return CORMORANT_SEMIBOLD


static func _configure_font_sources() -> void:
	if _font_sources_configured:
		return
	for font in [NOTO_REGULAR, NOTO_MEDIUM, NOTO_SEMIBOLD, CORMORANT_SEMIBOLD, UI_SYMBOLS]:
		if font is FontFile:
			(font as FontFile).allow_system_fallback = false
	_font_sources_configured = true


static func apply_context(root: Control, context: String) -> void:
	if root != null:
		root.theme = theme_for(context)


static func apply_warm_overlay(root: Control) -> void:
	apply_context(root, WARM_ARCHIVE)


static func _build_theme(context: String) -> Theme:
	var theme := Theme.new()
	theme.default_font = functional_font()
	theme.default_font_size = 16
	for variation in ["FunctionalButton", "ToggleButton", "DangerButton", "CompactButton"]:
		theme.set_type_variation(variation, "Button")
	theme.set_type_variation("SemanticSlider", "HSlider")
	for variation in ["BodyLabel", "SecondaryLabel", "SectionTitle", "DisplayTitle", "TabularLabel", "DangerLabel"]:
		theme.set_type_variation(variation, "Label")
	theme.set_type_variation("WarmPanel", "Panel")
	theme.set_type_variation("InsetPanel", "Panel")

	var primary := Palette.color(context, "primary")
	var secondary := Palette.color(context, "secondary")
	var disabled_text := Palette.color(context, "disabled_text_contrast")
	for type_name in ["Label", "Button", "CheckButton", "LineEdit", "RichTextLabel"]:
		theme.set_color("font_color", type_name, primary)
		theme.set_font("font", type_name, functional_font())
		theme.set_font_size("font_size", type_name, 16)
	for type_name in ["Button", "CheckButton"]:
		theme.set_color("font_hover_color", type_name, primary)
		theme.set_color("font_pressed_color", type_name, primary)
		theme.set_color("font_focus_color", type_name, primary)
		theme.set_color("font_disabled_color", type_name, disabled_text)
		theme.set_stylebox("normal", type_name, style_for(context, "button", "normal"))
		theme.set_stylebox("hover", type_name, style_for(context, "button", "hover"))
		theme.set_stylebox("pressed", type_name, style_for(context, "button", "selected"))
		theme.set_stylebox("hover_pressed", type_name, style_for(context, "button", "selected_hover"))
		theme.set_stylebox("disabled", type_name, style_for(context, "button", "disabled"))
		theme.set_stylebox("focus", type_name, style_for(context, "button", "focus"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var semantic_state: String = state
		if state == "pressed":
			semantic_state = "selected"
		elif state == "hover_pressed":
			semantic_state = "selected_hover"
		theme.set_stylebox(
			state, "CompactButton", style_for(context, "compact_button", semantic_state),
		)
	theme.set_font("font", "Button", functional_font("medium"))
	theme.set_font("font", "CheckButton", functional_font("medium"))
	theme.set_font_size("font_size", "CompactButton", 14)

	theme.set_color("font_color", "SecondaryLabel", secondary)
	theme.set_font_size("font_size", "SecondaryLabel", 14)
	theme.set_font("font", "SectionTitle", functional_font("semibold"))
	theme.set_font_size("font_size", "SectionTitle", 20)
	theme.set_font("font", "DisplayTitle", heading_font())
	theme.set_font_size("font_size", "DisplayTitle", 32)
	theme.set_font("font", "TabularLabel", functional_font("regular", true))
	theme.set_color("font_color", "DangerLabel", Palette.color(context, "danger"))

	theme.set_color("font_color", "DangerButton", primary)
	theme.set_color("font_hover_color", "DangerButton", primary)
	theme.set_color("font_pressed_color", "DangerButton", primary)
	theme.set_color("font_disabled_color", "DangerButton", disabled_text)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "DangerButton", style_for(context, "danger", state))

	# HSlider exposes semantic rail/fill styles and grabber icons through Theme.
	# The accompanying SemanticSlider control draws the cached separated focus
	# outline because Godot's stock HSlider has no focus StyleBox slot.
	theme.set_stylebox("slider", "SemanticSlider", style_for(context, "slider_rail", "normal"))
	theme.set_stylebox("grabber_area", "SemanticSlider", style_for(context, "slider_fill", "normal"))
	theme.set_stylebox("grabber_area_highlight", "SemanticSlider", style_for(context, "slider_fill", "hover"))
	theme.set_icon("grabber", "SemanticSlider", texture_for(context, "slider_grabber", "normal"))
	theme.set_icon("grabber_highlight", "SemanticSlider", texture_for(context, "slider_grabber", "hover"))
	theme.set_icon("grabber_disabled", "SemanticSlider", texture_for(context, "slider_grabber", "disabled"))

	theme.set_color("font_color", "LineEdit", primary)
	theme.set_color("font_placeholder_color", "LineEdit", secondary)
	theme.set_color("caret_color", "LineEdit", Palette.color(context, "focus"))
	theme.set_color("selection_color", "LineEdit", Color(Palette.color(context, "soul"), 0.34))
	theme.set_stylebox("normal", "LineEdit", style_for(context, "line_edit", "normal"))
	theme.set_stylebox("focus", "LineEdit", style_for(context, "line_edit", "focus"))
	theme.set_stylebox("read_only", "LineEdit", style_for(context, "line_edit", "disabled"))
	theme.set_stylebox("panel", "Panel", style_for(context, "panel", "normal"))
	theme.set_stylebox("panel", "WarmPanel", style_for(context, "panel", "normal"))
	theme.set_stylebox("panel", "InsetPanel", style_for(context, "inset_panel", "normal"))
	return theme


static func _build_style(context: String, variation: String, state: String) -> StyleBoxFlat:
	var compact := variation == "compact_button"
	var neutral := Palette.color(context, "neutral_border")
	var background := Palette.color(context, "inset")
	var border := neutral
	var width := 1
	var radius := 4
	if variation == "panel":
		var panel := _flat_style(Palette.color(context, "panel"), neutral, 2, 8)
		panel.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
		panel.shadow_size = 12
		panel.shadow_offset = Vector2(0, 5)
		panel.content_margin_left = 18.0
		panel.content_margin_right = 18.0
		panel.content_margin_top = 14.0
		panel.content_margin_bottom = 14.0
		return panel
	if variation == "inset_panel":
		return _flat_style(Palette.color(context, "inset"), neutral, 1, 4)
	if variation == "skill_tab_active":
		var active_tab := _flat_style(
			Palette.color(context, "panel"), Palette.color(context, "soul"), 2, 6,
		)
		active_tab.border_width_bottom = 0
		active_tab.corner_radius_bottom_left = 0
		active_tab.corner_radius_bottom_right = 0
		active_tab.content_margin_top = 5.0
		active_tab.content_margin_left = 8.0
		active_tab.content_margin_right = 8.0
		return active_tab
	if variation == "slider_rail":
		var rail_border := Palette.color(context, "disabled") if state == "disabled" else neutral
		var rail_background := (
			Palette.color(context, "raised") if state == "hover"
			else Palette.color(context, "inset")
		)
		var rail := _flat_style(rail_background, rail_border, 2 if state == "hover" else 1, 4)
		rail.content_margin_top = 4.0
		rail.content_margin_bottom = 4.0
		return rail
	if variation == "slider_fill":
		var fill := _flat_style(
			Palette.color(context, "inset") if state == "disabled" else Palette.color(context, "selected_fill"),
			Palette.color(context, "disabled") if state == "disabled" else Palette.color(context, "soul"),
			2 if state == "hover" else 1,
			4,
		)
		fill.content_margin_top = 4.0
		fill.content_margin_bottom = 4.0
		return fill
	if variation == "danger":
		background = Palette.color(context, "danger_surface")
		border = Palette.color(context, "danger")
		width = 2
		if state == "hover":
			width = 3
		elif state == "pressed":
			width = 3
			radius = 1
		elif state == "hover_pressed":
			width = 4
			radius = 1
	if state == "hover":
		if variation != "danger":
			background = Palette.color(context, "raised")
			width = 2
	elif state in ["selected", "selected_hover"] and variation != "danger":
		background = Palette.color(context, "selected_fill")
		border = Palette.color(context, "soul")
		width = 2
	elif state == "disabled":
		background = Palette.color(context, "inset")
		border = Palette.color(context, "disabled")
		width = 1
		radius = 0
	elif state == "focus":
		var focus := _flat_style(Color.TRANSPARENT, Palette.color(context, "focus"), 3, 7)
		focus.expand_margin_left = 4.0
		focus.expand_margin_top = 4.0
		focus.expand_margin_right = 4.0
		focus.expand_margin_bottom = 4.0
		if compact:
			_set_compact_margins(focus)
		return focus
	var result := _flat_style(background, border, width, radius)
	if state in ["selected", "selected_hover"] or variation == "danger":
		result.border_width_left = (
			7 if variation == "danger" and state in ["pressed", "hover_pressed"] else 5
		)
	if compact:
		_set_compact_margins(result)
	return result


static func _flat_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style


static func _set_compact_margins(style: StyleBoxFlat) -> void:
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0


static func _build_texture(context: String, variation: String, state: String) -> Texture2D:
	assert(variation == "slider_grabber", "Unsupported semantic texture variation")
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var fill := Palette.color(context, "disabled") if state == "disabled" else (
		Palette.color(context, "primary") if state == "hover" else Palette.color(context, "secondary")
	)
	var border := Palette.color(context, "disabled") if state == "disabled" else Palette.color(context, "neutral_border")
	for y in range(18):
		for x in range(18):
			var distance_squared := Vector2(x - 8.5, y - 8.5).length_squared()
			if distance_squared <= 64.0:
				image.set_pixel(x, y, border if distance_squared >= 42.25 else fill)
	return ImageTexture.create_from_image(image)
