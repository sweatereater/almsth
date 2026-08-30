class_name CharacterAttributeRowTestSuite
extends RefCounted

const Loc := preload("res://scripts/localization/localization.gd")
const Layout := preload("res://scripts/ui/character_sheet_layout.gd")

var failures: Array[String] = []


func run(tree: SceneTree) -> Array[String]:
	failures.clear()
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.persistence_enabled = false
	main.audio_playback_enabled = false
	tree.root.add_child(main)
	await tree.process_frame
	main.state.configure_character(
		"Путник с чрезвычайно длинным именем",
		GameRules.default_attributes(),
	)
	main.state.current_form_id = "almost_human"
	main.state.highest_unlocked_form_index = GameRules.FORM_ORDER.find("almost_human")
	main.state.skill_levels["stomach"] = 1
	for index in range(GameRules.ATTRIBUTE_ORDER.size()):
		main.state.attributes[GameRules.ATTRIBUTE_ORDER[index]] = 100000 + index
	main.state.unspent_attribute_points = GameRules.ATTRIBUTE_ORDER.size()
	main.state.add_or_refresh_status("rested", 321, 5)
	main.state.add_or_refresh_status("satiated", 200, 3)
	main._show_base("")
	main._show_character()
	main._select_character_panel("inventory")
	await tree.process_frame

	for locale in Loc.SUPPORTED_LOCALES:
		Loc.set_locale(locale)
		main._apply_locale()
		_assert_geometry_and_text(main, locale)
	_test_exact_purchases(main)

	main.queue_free()
	await tree.process_frame
	Loc.set_locale("ru")
	return failures


func _assert_geometry_and_text(main, locale: String) -> void:
	_expect(
		Rect2(main.character_primary_label.position, main.character_primary_label.size)
			== Layout.PRIMARY_ATTRIBUTES_HEADER_RECT
		and Layout.PRIMARY_ATTRIBUTES_RECT.encloses(Layout.PRIMARY_ATTRIBUTES_HEADER_RECT),
		"Primary-attribute header must use its explicit shared rect (actual %s, expected %s)" % [
			Rect2(main.character_primary_label.position, main.character_primary_label.size),
			Layout.PRIMARY_ATTRIBUTES_HEADER_RECT,
		],
	)
	var previous_row := Rect2()
	var expected_button_x := Layout.ATTRIBUTE_BUTTON_X
	for index in range(GameRules.ATTRIBUTE_ORDER.size()):
		var attribute_id: String = GameRules.ATTRIBUTE_ORDER[index]
		var row_rect := Layout.attribute_row_rect(index)
		var label_rect := Layout.attribute_label_rect(index)
		var button_rect := Layout.attribute_button_rect(index)
		var label: Label = main.character_attribute_row_labels[attribute_id]
		var button: Button = main.character_attribute_spend_buttons[attribute_id]
		var actual_label_rect := Rect2(label.position, label.size)
		var actual_button_rect := Rect2(button.position, button.size)
		_expect(
			actual_label_rect == label_rect
			and actual_button_rect == button_rect
			and is_equal_approx(label_rect.get_center().y, row_rect.get_center().y)
			and is_equal_approx(button_rect.get_center().y, row_rect.get_center().y)
			and is_equal_approx(button.position.x, expected_button_x)
			and button.size == Layout.ATTRIBUTE_BUTTON_SIZE,
			"Attribute %s label and + button must share one exact row center (label %s, button %s, row %s)" % [
				attribute_id, actual_label_rect, actual_button_rect, row_rect,
			],
		)
		_expect(
			Layout.PRIMARY_ATTRIBUTES_RECT.encloses(row_rect)
			and Layout.PRIMARY_ATTRIBUTES_RECT.encloses(actual_label_rect)
			and Layout.PRIMARY_ATTRIBUTES_RECT.encloses(actual_button_rect)
			and not actual_label_rect.intersects(actual_button_rect)
			and not actual_button_rect.intersects(Layout.PRIMARY_ATTRIBUTES_HEADER_RECT)
			and not actual_button_rect.intersects(Layout.FREE_STATS_RECT)
			and not actual_button_rect.intersects(Layout.STATUS_STRIP_RECT),
			"Attribute %s row must stay inside Primary Attributes without adjacent overlap" % attribute_id,
		)
		if previous_row.has_area():
			_expect(
				is_equal_approx(row_rect.position.y - previous_row.position.y, Layout.ATTRIBUTE_ROW_STRIDE)
				and not row_rect.intersects(previous_row),
				"All five attribute rows must share one non-overlapping stride",
			)
		previous_row = row_rect
		var label_width: float = label.get_theme_font("font").get_string_size(
			label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			label.get_theme_font_size("font_size"),
		).x
		_expect(
			label_width <= label.size.x
			and label.text.contains(Loc.text(String(GameRules.ATTRIBUTE_NAMES[attribute_id])))
			and label.text.contains(str(main.state.attributes[attribute_id])),
			"Localized long attribute values must fit their explicit row in %s" % locale,
		)
		_expect(
			button.visible
			and not button.disabled
			and button.focus_mode == Control.FOCUS_ALL
			and not button.focus_neighbor_top.is_empty()
			and not button.focus_neighbor_bottom.is_empty()
			and button.accessibility_name.contains(
				Loc.text(String(GameRules.ATTRIBUTE_NAMES[attribute_id]))
			)
			and button.size.x * 0.75 >= 21
			and button.size.y * 0.75 >= 15,
			"Every attribute + must remain accessible, navigable and touch-usable at 960x540",
		)
	_expect(
		Layout.PRIMARY_ATTRIBUTES_RECT.end.y <= Layout.FREE_STATS_RECT.position.y
		and Layout.FREE_STATS_RECT.end.y <= Layout.STATUS_STRIP_RECT.position.y
		and main.character_status_strip.status_snapshot.size() == 2,
		"Primary rows, free points and both active statuses must remain vertically separated",
	)


func _test_exact_purchases(main) -> void:
	var expected_attributes: Dictionary = main.state.attributes.duplicate(true)
	var expected_points: int = GameRules.ATTRIBUTE_ORDER.size()
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		var button: Button = main.character_attribute_spend_buttons[attribute_id]
		_expect(button.visible, "Each attribute + must be clickable while points remain")
		button.pressed.emit()
		expected_attributes[attribute_id] = int(expected_attributes[attribute_id]) + 1
		expected_points -= 1
		_expect(
			main.state.attributes == expected_attributes
			and main.state.unspent_attribute_points == expected_points,
			"Clicking %s + must spend exactly one point on that attribute" % attribute_id,
		)
	for attribute_id in GameRules.ATTRIBUTE_ORDER:
		_expect(
			not main.character_attribute_spend_buttons[attribute_id].visible,
			"All attribute + buttons must hide when no points remain",
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
