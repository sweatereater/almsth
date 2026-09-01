class_name WikiReference
extends RefCounted

const Rules := preload("res://scripts/game/game_rules.gd")
const Abilities := preload("res://scripts/game/skill_system.gd")
const Statuses := preload("res://scripts/game/status_system.gd")
const Localization := preload("res://scripts/localization/localization.gd")
const Floors := preload("res://scripts/world/floor_generator.gd")
const FixedFloor := preload("res://scripts/world/fixed_floor_90.gd")

const SCHEMA_VERSION := 2
const MARKDOWN_PATH := "res://docs/wiki/generated/game-reference.md"
const JSON_PATH := "res://docs/wiki/generated/game-reference.json"
const RESOURCE_IDS := ["wood", "stone", "cloth"]
const STATUS_IDS := ["implemented", "partial", "placeholder", "planned", "absent"]
const WIKI_PAGE_PATHS := [
	"res://docs/wiki/README.md",
	"res://docs/wiki/current-snapshot.md",
	"res://docs/wiki/progression.md",
	"res://docs/wiki/skills-and-abilities.md",
	"res://docs/wiki/economy.md",
	"res://docs/wiki/items.md",
	"res://docs/wiki/enemies.md",
	"res://docs/wiki/special-mechanics.md",
	"res://docs/wiki/roadmap.md",
	"res://docs/wiki/prompt-template.md",
	MARKDOWN_PATH,
]


static func validate_contract() -> Array[String]:
	var failures: Array[String] = []
	for locale in Localization.SUPPORTED_LOCALES:
		if not Localization.STRINGS.has(locale):
			failures.append("Missing localization dictionary: %s" % locale)
	for key in Localization.STRINGS.get("ru", {}):
		if not Localization.STRINGS.get("en", {}).has(key):
			failures.append("English localization is missing key: %s" % key)
	for key in Localization.STRINGS.get("en", {}):
		if not Localization.STRINGS.get("ru", {}).has(key):
			failures.append("Russian localization is missing key: %s" % key)

	for form_id in Rules.FORM_ORDER:
		if not Rules.FORMS.has(form_id):
			failures.append("FORM_ORDER references unknown form: %s" % form_id)
			continue
		var form: Dictionary = Rules.FORMS[form_id]
		_validate_localization_key(String(form.get("name", "")), "form %s" % form_id, failures)
		for slot_id in form.get("slots", []):
			if not Rules.SLOT_NAMES.has(slot_id):
				failures.append("Form %s references unknown slot: %s" % [form_id, slot_id])
	for form_id in Rules.FORMS:
		if not Rules.FORM_ORDER.has(form_id):
			failures.append("Form registry entry is absent from FORM_ORDER: %s" % form_id)
	for slot_id in Rules.SLOT_NAMES:
		_validate_localization_key(String(Rules.SLOT_NAMES[slot_id]), "slot %s" % slot_id, failures)

	for skill_id in Rules.SKILLS:
		var skill: Dictionary = Rules.SKILLS[skill_id]
		_validate_localization_key(String(skill.get("name", "")), "skill %s" % skill_id, failures)
		_validate_localization_key(String(skill.get("description", "")), "skill %s description" % skill_id, failures)
		var stage_id := String(skill.get("stage", ""))
		if not Rules.FORMS.has(stage_id):
			failures.append("Skill %s references unknown stage: %s" % [skill_id, stage_id])
		for required_id in skill.get("requires", {}):
			if not Rules.SKILLS.has(required_id):
				failures.append("Skill %s requires unknown skill: %s" % [skill_id, required_id])
		var ability_id := String(skill.get("ability_id", ""))
		if not ability_id.is_empty() and not Abilities.ABILITIES.has(ability_id):
			failures.append("Skill %s references unknown ability: %s" % [skill_id, ability_id])

	for ability_id in Abilities.ABILITIES:
		var ability: Dictionary = Abilities.ABILITIES[ability_id]
		_validate_localization_key(String(ability.get("name", "")), "ability %s" % ability_id, failures)
		var required_stage := String(ability.get("required_stage", ""))
		if not Rules.FORMS.has(required_stage):
			failures.append("Ability %s references unknown stage: %s" % [ability_id, required_stage])
		if String(ability.get("slot_kind", "")) not in ["attack", "active"]:
			failures.append("Ability %s has an unknown slot kind" % ability_id)

	for status_id in Statuses.STATUS_ORDER:
		if not Statuses.STATUSES.has(status_id):
			failures.append("STATUS_ORDER references unknown status: %s" % status_id)
			continue
		var status: Dictionary = Statuses.STATUSES[status_id]
		_validate_localization_key(String(status.get("name", "")), "status %s" % status_id, failures)
		_validate_localization_key(String(status.get("description", "")), "status %s description" % status_id, failures)
	for status_id in Statuses.STATUSES:
		if not Statuses.STATUS_ORDER.has(status_id):
			failures.append("Status registry entry is absent from STATUS_ORDER: %s" % status_id)

	for feature_id in Rules.INTRINSIC_FEATURES:
		var feature: Dictionary = Rules.INTRINSIC_FEATURES[feature_id]
		_validate_localization_key(String(feature.get("name", "")), "feature %s" % feature_id, failures)
		_validate_localization_key(String(feature.get("description", "")), "feature %s description" % feature_id, failures)
		if not Rules.FORMS.has(String(feature.get("stage", ""))):
			failures.append("Intrinsic feature %s references an unknown stage" % feature_id)

	for item_id in Rules.EQUIPMENT:
		var item: Dictionary = Rules.EQUIPMENT[item_id]
		_validate_localization_key(String(item.get("name", "")), "item %s" % item_id, failures)
		var compatible_slots: Array[String] = Rules.compatible_slots(item_id)
		if compatible_slots.is_empty():
			failures.append("Item %s has no compatible physical slots" % item_id)
		for slot_id in compatible_slots:
			if not Rules.SLOT_NAMES.has(slot_id):
				failures.append("Item %s references unknown slot: %s" % [item_id, slot_id])
		for resource_id in item.get("salvage", {}):
			if resource_id not in RESOURCE_IDS:
				failures.append("Item %s salvages unknown resource: %s" % [item_id, resource_id])
		if Rules.item_category(item_id) == "weapon":
			if Rules.weapon_attack_type(item_id) not in ["melee", "ranged"]:
				failures.append("Weapon %s has an invalid attack_type" % item_id)
			if Rules.weapon_grip(item_id) not in ["one_handed", "two_handed"]:
				failures.append("Weapon %s has an invalid grip" % item_id)

	for enemy_id in Rules.ENEMIES:
		var enemy: Dictionary = Rules.ENEMIES[enemy_id]
		_validate_localization_key(String(enemy.get("name", "")), "enemy %s" % enemy_id, failures)
		_validate_localization_key(String(enemy.get("glyph", "")), "enemy %s glyph" % enemy_id, failures)
		for ability_id in enemy.get("abilities", []):
			if not Abilities.ABILITIES.has(ability_id):
				failures.append("Enemy %s references unknown ability: %s" % [enemy_id, ability_id])

	for upgrade_id in Rules.CAMP_UPGRADES:
		var upgrade: Dictionary = Rules.CAMP_UPGRADES[upgrade_id]
		_validate_localization_key(String(upgrade.get("name", "")), "camp upgrade %s" % upgrade_id, failures)
		for resource_id in upgrade.get("cost", {}):
			if resource_id not in RESOURCE_IDS:
				failures.append("Camp upgrade %s costs unknown resource: %s" % [upgrade_id, resource_id])
		for requirement in upgrade.get("requires", []):
			if not Rules.CAMP_UPGRADES.has(requirement):
				failures.append("Camp upgrade %s requires unknown upgrade: %s" % [upgrade_id, requirement])

	return failures


static func validate_wiki_pages() -> Array[String]:
	var failures: Array[String] = []
	var link_regex := RegEx.new()
	link_regex.compile("\\[[^\\]]+\\]\\(([^)]+)\\)")
	var status_regex := RegEx.new()
	status_regex.compile("`([^`]+)`")

	for path_variant in WIKI_PAGE_PATHS:
		var path := String(path_variant)
		if not FileAccess.file_exists(path):
			failures.append("Wiki page is missing: %s" % path)
			continue
		var content := FileAccess.get_file_as_string(path).replace("\r\n", "\n")
		var status_line := ""
		for line_variant in content.split("\n"):
			var line := String(line_variant)
			if line.begins_with("## "):
				break
			if line.begins_with("Статус:") or line.begins_with("Статусы:"):
				status_line = line
				break
		if status_line.is_empty():
			failures.append("Wiki page has no top-level status line: %s" % path)
		else:
			var declared_count := 0
			for status_match in status_regex.search_all(status_line):
				var status_id := status_match.get_string(1)
				declared_count += 1
				if status_id not in STATUS_IDS:
					failures.append("Wiki page %s declares unknown status: %s" % [path, status_id])
			if declared_count == 0:
				failures.append("Wiki page has an empty status line: %s" % path)

		for link_match in link_regex.search_all(content):
			var href := link_match.get_string(1)
			if href.begins_with("http:") or href.begins_with("https:") or href.begins_with("mailto:"):
				continue
			var parts := href.split("#", true, 1)
			var relative_path := String(parts[0]).uri_decode()
			var target_path: String = path
			if not relative_path.is_empty():
				target_path = path.get_base_dir().path_join(relative_path).simplify_path()
			if not target_path.begins_with("res://docs/wiki/") or not FileAccess.file_exists(target_path):
				failures.append("Broken wiki link in %s: %s" % [path, href])
				continue
			if parts.size() < 2 or String(parts[1]).is_empty():
				continue
			var target_headings := _wiki_heading_ids(FileAccess.get_file_as_string(target_path))
			var anchor_id := _wiki_heading_id(String(parts[1]).uri_decode())
			if not target_headings.has(anchor_id):
				failures.append("Broken wiki anchor in %s: %s" % [path, href])

	# These checks keep essential prompt vocabulary discoverable. Gameplay tests,
	# not this text contract, remain the authority for behavior semantics.
	var required_references := {
		"res://docs/wiki/current-snapshot.md": [
			"`carried_souls`", "`banked_souls`", "`absorbed_souls`", "`rope_floor`",
		],
		"res://docs/wiki/special-mechanics.md": [
			"истинную видимость", "засчитывается как пропуск",
		],
	}
	for path_variant in required_references:
		var required_path := String(path_variant)
		var required_content := FileAccess.get_file_as_string(required_path)
		for required_text in required_references[path_variant]:
			if not required_content.contains(required_text):
				failures.append("Wiki page %s is missing required reference: %s" % [required_path, required_text])
	return failures


static func _wiki_heading_ids(content: String) -> Dictionary:
	var result := {}
	for line_variant in content.replace("\r\n", "\n").split("\n"):
		var line := String(line_variant)
		var level := 0
		while level < line.length() and line.substr(level, 1) == "#":
			level += 1
		if level < 1 or level > 6 or level >= line.length() or line.substr(level, 1) != " ":
			continue
		result[_wiki_heading_id(line.substr(level + 1))] = true
	return result


static func _wiki_heading_id(text: String) -> String:
	var lower := text.to_lower().replace("`", "")
	var cleaned := ""
	for index in range(lower.length()):
		var character := lower.substr(index, 1)
		var code := lower.unicode_at(index)
		var is_ascii_letter := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		var is_cyrillic := code >= 0x0400 and code <= 0x04ff
		if is_ascii_letter or is_digit or is_cyrillic or character == " " or character == "-":
			cleaned += character
	return "-".join(cleaned.strip_edges().split(" ", false))


static func build_reference() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"generated_from": [
			"scripts/game/game_rules.gd",
			"scripts/game/skill_system.gd",
			"scripts/game/status_system.gd",
			"scripts/localization/localization.gd",
			"scripts/world/floor_generator.gd",
			"scripts/world/fixed_floor_90.gd",
		],
		"counts": {
			"forms": Rules.FORMS.size(),
			"skills": Rules.SKILLS.size(),
			"abilities": Abilities.ABILITIES.size(),
			"statuses": Statuses.STATUSES.size(),
			"equipment": Rules.EQUIPMENT.size(),
			"enemies": Rules.ENEMIES.size(),
			"camp_upgrades": Rules.CAMP_UPGRADES.size(),
		},
		"forms": _forms(),
		"skills": _skills(),
		"abilities": _abilities(),
		"statuses": _statuses(),
		"equipment": _equipment(),
		"enemies": _enemies(),
		"enemy_depth_scaling": _enemy_depth_scaling(),
		"camp_upgrades": _camp_upgrades(),
		"rule_constants": {
			"soul_level_start": Rules.SOUL_LEVEL_START,
			"campfire_soul_level_bonus": Rules.CAMPFIRE_SOUL_LEVEL_BONUS,
			"cradle_base_chance": Rules.CRADLE_BASE_CHANCE,
			"cradle_miss_bonus": Rules.CRADLE_MISS_BONUS,
			"player_vision_base_radius": Rules.PLAYER_VISION_BASE_RADIUS,
			"player_hearing_radius_offset": Rules.PLAYER_HEARING_RADIUS_OFFSET,
			"sharp_vision_bonus_per_level": Rules.SHARP_VISION_BONUS_PER_LEVEL,
			"mana_regeneration_base_percent": Rules.MANA_REGENERATION_BASE_PERCENT,
			"mana_regeneration_wisdom_step": Rules.MANA_REGENERATION_WISDOM_STEP,
			"magic_missile_mana_cost": Rules.MAGIC_MISSILE_MANA_COST,
			"magic_missile_base_damage": Rules.MAGIC_MISSILE_BASE_DAMAGE,
			"magic_missile_base_range": Rules.MAGIC_MISSILE_BASE_RANGE,
			"magic_missile_range_bonus": Rules.MAGIC_MISSILE_RANGE_BONUS,
			"magic_ricochet_base_chance": Rules.MAGIC_RICOCHET_BASE_CHANCE,
			"magic_ricochet_level_bonus": Rules.MAGIC_RICOCHET_LEVEL_BONUS,
			"magic_ricochet_range": Rules.MAGIC_RICOCHET_RANGE,
			"weapon_upgrade_chances": _string_key_dictionary(Rules.WEAPON_UPGRADE_CHANCES),
			"weapon_upgrade_cost": _sorted_dictionary(Rules.WEAPON_UPGRADE_COST),
			"item_binding_soul_cost": Rules.ITEM_BINDING_SOUL_COST,
		},
	}


static func build_json() -> String:
	return JSON.stringify(build_reference(), "  ", true, false) + "\n"


static func build_markdown() -> String:
	var reference := build_reference()
	var lines := PackedStringArray([
		"# Сгенерированный справочник",
		"",
		"Статус: `implemented`",
		"",
		"> Этот файл создаётся из игровых реестров и runtime-констант. Не редактируйте его вручную.",
		"> Ручные страницы объясняют поведение; их ссылки, anchors и статусы проверяет wiki-контракт.",
		"",
		"## Формы",
		"",
		"| ID | RU / EN | Уровень души | Порог `absorbed_souls` | Цена следующей формы | HP | Урон | Регенерация | Слоты |",
		"| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
	])
	for form in reference["forms"]:
		lines.append("| `%s` | %s / %s | %d | %d | %s | %d | %d | %d | %s |" % [
			form["id"], _md(form["name"]["ru"]), _md(form["name"]["en"]), form["required_soul_level"], form["threshold"],
			"—" if form["evolution_cost_to_next"] == null else str(form["evolution_cost_to_next"]),
			form["max_hp"], form["damage"], form["regeneration"],
			", ".join(form["slot_ids"]),
		])
	lines.append_array(PackedStringArray([
		"", "## Навыки", "",
		"| ID | RU / EN | Форма | Вид | Уровни | Цены | Требования | Ability |",
		"| --- | --- | --- | --- | ---: | --- | --- | --- |",
	]))
	for skill in reference["skills"]:
		lines.append("| `%s` | %s / %s | `%s` | `%s` | %d | %s | %s | %s |" % [
			skill["id"], _md(skill["name"]["ru"]), _md(skill["name"]["en"]), skill["stage"],
			skill["kind"], skill["max_level"], _join_values(skill["costs"]),
			_format_requirements(skill["requires"]),
			"—" if String(skill["ability_id"]).is_empty() else "`%s`" % skill["ability_id"],
		])
	lines.append_array(PackedStringArray([
		"", "## Способности", "",
		"| ID | RU / EN | Слот | Цель | Требуемая форма | Перезарядка |",
		"| --- | --- | --- | --- | --- | ---: |",
	]))
	for ability in reference["abilities"]:
		lines.append("| `%s` | %s / %s | `%s` | `%s` | `%s` | %d |" % [
			ability["id"], _md(ability["name"]["ru"]), _md(ability["name"]["en"]),
			ability["slot_kind"], ability["target_kind"], ability["required_stage"], ability["cooldown"],
		])
	lines.append_array(PackedStringArray([
		"", "## Статусы", "",
		"| ID | RU / EN | Длительность | Временные HP | Модификаторы | Сокращение перезарядки |",
		"| --- | --- | ---: | ---: | --- | --- |",
	]))
	for status in reference["statuses"]:
		lines.append("| `%s` | %s / %s | %d | %d | %s | %s |" % [
			status["id"], _md(status["name"]["ru"]), _md(status["name"]["en"]),
			status["default_duration"], status["temporary_hp_grant"],
			_format_dictionary(status["modifiers"]), _format_dictionary(status["cooldown_reduction"]),
		])
	lines.append_array(PackedStringArray([
		"", "## Предметы", "",
		"| ID | RU / EN | Слоты | attack_type | grip | Min depth | Параметры | Разбор |",
		"| --- | --- | --- | --- | --- | ---: | --- | --- |",
	]))
	for item in reference["equipment"]:
		lines.append("| `%s` | %s / %s | `%s` | `%s` | `%s` | %d | %s | %s |" % [
			item["id"], _md(item["name"]["ru"]), _md(item["name"]["en"]), ", ".join(item["slots"]),
			item["attack_type"], item["grip"],
			item["min_depth"], _format_dictionary(item["stats"]), _format_dictionary(item["salvage"]),
		])
	lines.append_array(PackedStringArray([
		"", "## Противники", "",
		"| ID | RU / EN | HP | Урон | Души | Точность | Уклонение | Обзор | Атака | Min depth |",
		"| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |",
	]))
	for enemy in reference["enemies"]:
		lines.append("| `%s` | %s / %s | %d | %d | %d | %d | %d | %d | `%s` | %s |" % [
			enemy["id"], _md(enemy["name"]["ru"]), _md(enemy["name"]["en"]), enemy["max_hp"],
			enemy["damage"], enemy["souls"], enemy["accuracy"], enemy["dodge"], enemy["vision"],
			enemy["attack_type"], "—" if enemy["min_depth"] == null else str(enemy["min_depth"]),
		])
	lines.append_array(PackedStringArray([
		"", "### Масштабирование обычных этажей", "",
		"`%s`" % reference["enemy_depth_scaling"]["depth"], "",
		"- Число врагов: `%s`." % reference["enemy_depth_scaling"]["enemy_count"],
		"- HP: `%s`." % reference["enemy_depth_scaling"]["max_hp"],
		"- Урон: `%s`." % reference["enemy_depth_scaling"]["damage"],
		"- Точность: `%s`." % reference["enemy_depth_scaling"]["accuracy"],
		"- Уклонение: `%s`." % reference["enemy_depth_scaling"]["dodge"],
		"- Награда душами: `%s`." % reference["enemy_depth_scaling"]["souls"],
		"- Обзор не масштабируется.",
		"- Фиксированный этаж %d использует базовые параметры Минотавра без этих бонусов." % FixedFloor.FLOOR_NUMBER,
		"", "## Постройки лагеря", "",
		"| ID | RU / EN | Стоимость | Требует |", "| --- | --- | --- | --- |",
	]))
	for upgrade in reference["camp_upgrades"]:
		lines.append("| `%s` | %s / %s | %s | %s |" % [
			upgrade["id"], _md(upgrade["name"]["ru"]), _md(upgrade["name"]["en"]),
			_format_dictionary(upgrade["cost"]), ", ".join(upgrade["requires"]) if not upgrade["requires"].is_empty() else "—",
		])
	lines.append_array(PackedStringArray([
		"", "## Источник истины", "",
		"- `scripts/game/game_rules.gd` — формы, навыки, предметы, враги, постройки и числовые правила.",
		"- `scripts/game/skill_system.gd` — реестр способностей и совместимость слотов.",
		"- `scripts/game/status_system.gd` — реестр статусов, их модификаторов и длительности.",
		"- `scripts/localization/localization.gd` — RU/EN названия и описания.",
		"- `scripts/world/floor_generator.gd` — runtime-константы глубинного усиления обычных врагов.",
		"- `scripts/world/fixed_floor_90.gd` — номер и контракт фиксированной арены.",
		"",
	]))
	return "\n".join(lines)


static func write_generated_files() -> Array[String]:
	var failures := validate_contract()
	if not failures.is_empty():
		return failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/wiki/generated"))
	_write_text(MARKDOWN_PATH, build_markdown())
	_write_text(JSON_PATH, build_json())
	failures.append_array(validate_wiki_pages())
	return failures


static func check_generated_files() -> Array[String]:
	var failures := validate_contract()
	_check_file(MARKDOWN_PATH, build_markdown(), failures)
	_check_file(JSON_PATH, build_json(), failures)
	failures.append_array(validate_wiki_pages())
	return failures


static func _enemy_depth_scaling() -> Dictionary:
	return {
		"source": "scripts/world/floor_generator.gd:_spawn_enemies",
		"scope": "regular_generated_floor_main_hall",
		"depth": "depth = 100 - floor_number",
		"enemy_count": "min(%d, %d + floor(depth / %d))" % [
			Floors.ENEMY_COUNT_MAX,
			Floors.ENEMY_COUNT_BASE,
			Floors.ENEMY_COUNT_DEPTH_INTERVAL,
		],
		"max_hp": "base.max_hp + floor(depth / %d)" % Floors.ENEMY_HP_DEPTH_INTERVAL,
		"damage": "base.damage + floor(depth / %d)" % Floors.ENEMY_DAMAGE_DEPTH_INTERVAL,
		"accuracy": "base.accuracy + floor(depth / %d)" % Floors.ENEMY_ACCURACY_DEPTH_INTERVAL,
		"dodge": "base.dodge + floor(depth / %d)" % Floors.ENEMY_DODGE_DEPTH_INTERVAL,
		"souls": "base.souls + floor(depth / %d)" % Floors.ENEMY_SOULS_DEPTH_INTERVAL,
		"vision": "base.vision",
		"note": "Each of 2–3 sealed rooms adds 2–3 enemies with the same stat bonuses. Floor %d is hand-authored and uses the Minotaur base values without these bonuses." % FixedFloor.FLOOR_NUMBER,
	}


static func _forms() -> Array:
	var result: Array = []
	for form_id in Rules.FORM_ORDER:
		var form: Dictionary = Rules.FORMS[form_id]
		var slots: Array = []
		for slot_id in form["slots"]:
			slots.append({"id": slot_id, "name": _localized(String(Rules.SLOT_NAMES[slot_id]))})
		var next := Rules.next_form(form_id)
		result.append({
			"id": form_id,
			"name": _localized(String(form["name"])),
			"threshold": int(form["threshold"]),
			"required_soul_level": Rules.required_soul_level(form_id),
			"evolution_cost_to_next": null if next.is_empty() else Rules.evolution_cost(form_id),
			"max_hp": int(form["max_hp"]),
			"damage": int(form["damage"]),
			"regeneration": int(form["regeneration"]),
			"slot_ids": Array(form["slots"], TYPE_STRING, "", null),
			"slots": slots,
		})
	return result


static func _skills() -> Array:
	var result: Array = []
	var ids := Rules.SKILLS.keys()
	ids.sort()
	for skill_id in ids:
		var skill: Dictionary = Rules.SKILLS[skill_id]
		var costs: Array = []
		for current_level in range(int(skill["max_level"])):
			costs.append(Rules.skill_cost(skill_id, current_level))
		result.append({
			"id": skill_id,
			"name": _localized(String(skill["name"])),
			"description": _localized(String(skill["description"])),
			"stage": String(skill["stage"]),
			"kind": String(skill.get("kind", "passive")),
			"max_level": int(skill["max_level"]),
			"base_cost": int(skill["base_cost"]),
			"cost_step": int(skill["cost_step"]),
			"costs": costs,
			"requires": _sorted_dictionary(skill.get("requires", {})),
			"ability_id": String(skill.get("ability_id", "")),
		})
	return result


static func _abilities() -> Array:
	var result: Array = []
	var ids := Abilities.ABILITIES.keys()
	ids.sort()
	for ability_id in ids:
		var ability: Dictionary = Abilities.ABILITIES[ability_id]
		result.append({
			"id": ability_id,
			"name": _localized(String(ability["name"])),
			"slot_kind": String(ability["slot_kind"]),
			"target_kind": String(ability["target_kind"]),
			"required_stage": String(ability["required_stage"]),
			"cooldown": Abilities.base_cooldown(ability_id),
		})
	return result


static func _statuses() -> Array:
	var result: Array = []
	for status_id in Statuses.STATUS_ORDER:
		var status: Dictionary = Statuses.STATUSES[status_id]
		result.append({
			"id": status_id,
			"name": _localized(String(status["name"])),
			"description": _localized(String(status["description"])),
			"icon": String(status.get("icon", "")),
			"priority": int(status.get("priority", 0)),
			"default_duration": int(status.get("default_duration", 0)),
			"max_duration": int(status.get("max_duration", 0)),
			"temporary_hp_grant": int(status.get("temporary_hp_grant", 0)),
			"modifiers": _sorted_dictionary(status.get("modifiers", {})),
			"cooldown_reduction": _sorted_dictionary(status.get("cooldown_reduction", {})),
		})
	return result


static func _equipment() -> Array:
	var result: Array = []
	var ids := Rules.EQUIPMENT.keys()
	ids.sort()
	var stat_keys := [
		"range", "damage", "ranged_damage", "max_hp", "soul_bonus", "soul_level_bonus",
		"accuracy", "dodge", "mana", "spell_power", "regeneration", "vision", "preparation",
	]
	for item_id in ids:
		var item: Dictionary = Rules.EQUIPMENT[item_id]
		var stats := {}
		for key in stat_keys:
			if not item.has(key):
				continue
			var value: Variant = item[key]
			if (value is int or value is float) and float(value) == 0.0:
				continue
			if value is String and String(value).is_empty():
				continue
			stats[key] = value
		result.append({
			"id": item_id,
			"name": _localized(String(item["name"])),
			"category": Rules.item_category(item_id),
			"slots": Rules.compatible_slots(item_id),
			"attack_type": Rules.weapon_attack_type(item_id) if Rules.item_category(item_id) == "weapon" else "",
			"grip": Rules.weapon_grip(item_id) if Rules.item_category(item_id) == "weapon" else "",
			"min_depth": int(item["min_depth"]),
			"stats": _sorted_dictionary(stats),
			"salvage": _sorted_dictionary(item.get("salvage", {})),
		})
	return result


static func _enemies() -> Array:
	var result: Array = []
	var ids := Rules.ENEMIES.keys()
	ids.sort()
	for enemy_id in ids:
		var enemy: Dictionary = Rules.ENEMIES[enemy_id]
		var minimum_depth: Variant = null
		for floor_number in range(100, 0, -1):
			if Rules.enemy_pool(floor_number).has(enemy_id):
				minimum_depth = 100 - floor_number
				break
		result.append({
			"id": enemy_id,
			"name": _localized(String(enemy["name"])),
			"glyph": _localized(String(enemy["glyph"])),
			"max_hp": int(enemy["max_hp"]),
			"damage": int(enemy["damage"]),
			"souls": int(enemy["souls"]),
			"accuracy": int(enemy["accuracy"]),
			"dodge": int(enemy["dodge"]),
			"vision": int(enemy["vision"]),
			"meat": bool(enemy.get("meat", false)),
			"attack_type": String(enemy.get("attack_type", "melee")),
			"range": int(enemy.get("range", 1)),
			"min_depth": minimum_depth,
			"fixed_floor": FixedFloor.FLOOR_NUMBER if enemy_id == "minotaur" else null,
			"abilities": Array(enemy.get("abilities", []), TYPE_STRING, "", null),
		})
	return result


static func _camp_upgrades() -> Array:
	var result: Array = []
	var ids := Rules.CAMP_UPGRADES.keys()
	ids.sort()
	for upgrade_id in ids:
		var upgrade: Dictionary = Rules.CAMP_UPGRADES[upgrade_id]
		result.append({
			"id": upgrade_id,
			"name": _localized(String(upgrade["name"])),
			"cost": _sorted_dictionary(upgrade["cost"].merged({"banked_souls": upgrade["banked_souls"], "minotaur_tail": upgrade["minotaur_tail"]}) if upgrade_id == "mural" else upgrade["cost"]),
			"requires": Array(upgrade.get("requires", []), TYPE_STRING, "", null),
		})
	return result


static func _localized(key: String) -> Dictionary:
	return {
		"ru": String(Localization.STRINGS["ru"].get(key, key)),
		"en": String(Localization.STRINGS["en"].get(key, key)),
	}


static func _validate_localization_key(key: String, owner: String, failures: Array[String]) -> void:
	if key.is_empty():
		failures.append("Missing localization key reference for %s" % owner)
		return
	for locale in Localization.SUPPORTED_LOCALES:
		if not Localization.STRINGS.get(locale, {}).has(key):
			failures.append("%s localization is missing %s for %s" % [locale, key, owner])


static func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	var keys := source.keys()
	keys.sort_custom(func(a, b): return str(a) < str(b))
	for key in keys:
		result[str(key)] = source[key]
	return result


static func _string_key_dictionary(source: Dictionary) -> Dictionary:
	return _sorted_dictionary(source)


static func _format_requirements(requirements: Dictionary) -> String:
	if requirements.is_empty():
		return "—"
	var parts := PackedStringArray()
	for key in requirements:
		parts.append("`%s` %s" % [key, requirements[key]])
	return ", ".join(parts)


static func _format_dictionary(value: Dictionary) -> String:
	if value.is_empty():
		return "—"
	var parts := PackedStringArray()
	for key in value:
		parts.append("`%s` %s" % [key, value[key]])
	return ", ".join(parts)


static func _join_values(values: Array) -> String:
	var parts := PackedStringArray()
	for value in values:
		parts.append(str(value))
	return ", ".join(parts)


static func _md(value: Variant) -> String:
	return str(value).replace("|", "\\|").replace("\n", " ")


static func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


static func _check_file(path: String, expected: String, failures: Array[String]) -> void:
	if not FileAccess.file_exists(path):
		failures.append("Generated wiki file is missing: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_as_text() != expected:
		failures.append("Generated wiki file is stale: %s" % path)
