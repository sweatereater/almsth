class_name WikiContractTestSuite
extends RefCounted

const Reference := preload("res://tools/wiki_reference.gd")
const Floors := preload("res://scripts/world/floor_generator.gd")
const FixedFloor := preload("res://scripts/world/fixed_floor_90.gd")
const SaveSystem := preload("res://scripts/system/persistence.gd")


func run(_tree: SceneTree) -> Array[String]:
	var failures := Reference.check_generated_files()
	var data := Reference.build_reference()
	if int(data["counts"]["forms"]) != GameRules.FORMS.size():
		failures.append("Wiki form count must follow GameRules")
	if int(data["counts"]["skills"]) != GameRules.SKILLS.size():
		failures.append("Wiki skill count must follow GameRules")
	if int(data["counts"]["equipment"]) != GameRules.EQUIPMENT.size():
		failures.append("Wiki equipment count must follow GameRules")
	if int(data["counts"]["enemies"]) != GameRules.ENEMIES.size():
		failures.append("Wiki enemy count must follow GameRules")
	var roadmap := FileAccess.get_file_as_string("res://docs/wiki/roadmap.md")
	if not roadmap.contains("atomic-сохранения v%d" % SaveSystem.SAVE_VERSION):
		failures.append("Wiki roadmap save version must follow Persistence.SAVE_VERSION")
	_test_floor_scaling_constants(data, failures)
	return failures


func _test_floor_scaling_constants(data: Dictionary, failures: Array[String]) -> void:
	if (
		Floors.ENEMY_COUNT_BASE != 5
		or Floors.ENEMY_COUNT_MAX != 12
		or Floors.ENEMY_COUNT_DEPTH_INTERVAL != 12
		or Floors.ENEMY_HP_DEPTH_INTERVAL != 20
		or Floors.ENEMY_DAMAGE_DEPTH_INTERVAL != 35
		or Floors.ENEMY_ACCURACY_DEPTH_INTERVAL != 25
		or Floors.ENEMY_DODGE_DEPTH_INTERVAL != 30
		or Floors.ENEMY_SOULS_DEPTH_INTERVAL != 30
	):
		failures.append("Extracted enemy scaling constants must preserve the prototype balance")
	if (
		Floors.enemy_count_for_depth(0) != 5
		or Floors.enemy_count_for_depth(11) != 5
		or Floors.enemy_count_for_depth(12) != 6
		or Floors.enemy_count_for_depth(60) != 10
		or Floors.enemy_count_for_depth(99) != 12
	):
		failures.append("Enemy count helper must grow with depth within the approved 5–12 hall range")
	if (
		Floors.enemy_stat_bonus_for_depth(19, Floors.ENEMY_HP_DEPTH_INTERVAL) != 0
		or Floors.enemy_stat_bonus_for_depth(20, Floors.ENEMY_HP_DEPTH_INTERVAL) != 1
		or Floors.enemy_stat_bonus_for_depth(69, Floors.ENEMY_DAMAGE_DEPTH_INTERVAL) != 1
		or Floors.enemy_stat_bonus_for_depth(70, Floors.ENEMY_DAMAGE_DEPTH_INTERVAL) != 2
	):
		failures.append("Enemy stat helper must preserve floor-based bonus thresholds")
	var scaling: Dictionary = data["enemy_depth_scaling"]
	if (
		not String(scaling["enemy_count"]).contains("/ %d" % Floors.ENEMY_COUNT_DEPTH_INTERVAL)
		or not String(scaling["max_hp"]).contains("/ %d" % Floors.ENEMY_HP_DEPTH_INTERVAL)
		or not data["generated_from"].has("scripts/world/floor_generator.gd")
		or not data["generated_from"].has("scripts/world/fixed_floor_90.gd")
	):
		failures.append("Wiki formulas must be generated from floor runtime constants")
	for enemy in data["enemies"]:
		if enemy["id"] == "minotaur" and enemy["fixed_floor"] != FixedFloor.FLOOR_NUMBER:
			failures.append("Wiki fixed floor must follow FixedFloor90.FLOOR_NUMBER")
