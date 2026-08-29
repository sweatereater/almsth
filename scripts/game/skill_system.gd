class_name SkillSystem
extends RefCounted

## Actor-neutral ability metadata and deterministic geometry. Scene state,
## animation and turn completion deliberately stay in Main.

const SLOT_ORDER: Array[String] = ["attack", "active_1", "active_2", "active_3"]
const FORM_ORDER: Array[String] = ["skeleton", "zombie", "ghoul", "revenant", "almost_human"]
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const DASH_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

const ABILITIES := {
	"basic_attack": {
		"name": "ABILITY_BASIC_ATTACK",
		"slot_kind": "attack",
		"target_kind": "adjacent_enemy",
		"required_stage": "skeleton",
	},
	"magic_missile": {
		"name": "ABILITY_MAGIC_MISSILE",
		"slot_kind": "active",
		"target_kind": "visible_enemy",
		"required_stage": "skeleton",
	},
	"dash": {
		"name": "ABILITY_DASH",
		"slot_kind": "active",
		"target_kind": "dash_cell",
		"required_stage": "ghoul",
	},
	"double_attack": {
		"name": "ABILITY_DOUBLE_ATTACK",
		"slot_kind": "attack",
		"target_kind": "adjacent_enemy",
		"required_stage": "ghoul",
	},
	"circular_attack": {
		"name": "ABILITY_CIRCULAR_ATTACK",
		"slot_kind": "attack",
		"target_kind": "adjacent_area",
		"required_stage": "almost_human",
	},
}


static func default_loadout() -> Dictionary:
	return {
		"attack": "basic_attack",
		"active_1": "",
		"active_2": "",
		"active_3": "",
	}


static func ability(ability_id: String) -> Dictionary:
	return ABILITIES.get(ability_id, {})


static func slot_accepts(slot_id: String, ability_id: String) -> bool:
	if not SLOT_ORDER.has(slot_id) or not ABILITIES.has(ability_id):
		return false
	var expected_kind := "attack" if slot_id == "attack" else "active"
	return String(ABILITIES[ability_id]["slot_kind"]) == expected_kind


static func learned_ability_ids(skill_levels: Dictionary) -> Array[String]:
	var result: Array[String] = ["basic_attack"]
	for skill_id in GameRules.SKILLS:
		var skill: Dictionary = GameRules.SKILLS[skill_id]
		var ability_id := String(skill.get("ability_id", ""))
		if ability_id.is_empty() or int(skill_levels.get(skill_id, 0)) <= 0:
			continue
		if ABILITIES.has(ability_id) and not result.has(ability_id):
			result.append(ability_id)
	return result


static func is_learned(ability_id: String, skill_levels: Dictionary) -> bool:
	return learned_ability_ids(skill_levels).has(ability_id)


static func can_use_in_form(ability_id: String, form_id: String, skill_levels: Dictionary) -> bool:
	if not is_learned(ability_id, skill_levels):
		return false
	var required_stage := String(ABILITIES[ability_id].get("required_stage", "skeleton"))
	return FORM_ORDER.find(form_id) >= FORM_ORDER.find(required_stage)


static func sanitize_loadout(saved_value: Variant, skill_levels: Dictionary) -> Dictionary:
	var result := default_loadout()
	if not saved_value is Dictionary:
		return _migrated_default(skill_levels)
	var saved: Dictionary = saved_value
	var used := {"basic_attack": true}
	for slot_id in SLOT_ORDER:
		if slot_id == "attack":
			var attack_id := String(saved.get(slot_id, "basic_attack"))
			if (
				slot_accepts(slot_id, attack_id)
				and is_learned(attack_id, skill_levels)
			):
				result[slot_id] = attack_id
				used[attack_id] = true
			continue
		var ability_id := String(saved.get(slot_id, ""))
		if (
			ability_id.is_empty()
			or used.has(ability_id)
			or not slot_accepts(slot_id, ability_id)
			or not is_learned(ability_id, skill_levels)
		):
			continue
		result[slot_id] = ability_id
		used[ability_id] = true
	return result


static func _migrated_default(skill_levels: Dictionary) -> Dictionary:
	var result := default_loadout()
	if is_learned("magic_missile", skill_levels):
		result["active_1"] = "magic_missile"
	return result


static func options_for_slot(slot_id: String, skill_levels: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if slot_id != "attack":
		result.append("")
	for ability_id in learned_ability_ids(skill_levels):
		if slot_accepts(slot_id, ability_id):
			result.append(ability_id)
	if slot_id == "attack" and not result.has("basic_attack"):
		result.push_front("basic_attack")
	return result


static func dash_targets(
	tiles: Dictionary,
	origin: Vector2i,
	explored_cells: Dictionary,
	occupied_cells: Dictionary,
	maximum_distance := 3,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DASH_DIRECTIONS:
		result.append_array(dash_targets_in_direction(
			tiles, origin, direction, explored_cells, occupied_cells, maximum_distance,
		))
	return result


static func dash_targets_in_direction(
	tiles: Dictionary,
	origin: Vector2i,
	direction: Vector2i,
	explored_cells: Dictionary,
	occupied_cells: Dictionary,
	maximum_distance := 3,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not DASH_DIRECTIONS.has(direction):
		return result
	var previous := origin
	for distance in range(1, maximum_distance + 1):
		var cell := origin + direction * distance
		if direction.x != 0 and direction.y != 0:
			var horizontal_flank := previous + Vector2i(direction.x, 0)
			var vertical_flank := previous + Vector2i(0, direction.y)
			if (
				tiles.get(horizontal_flank, "void") != "floor"
				or tiles.get(vertical_flank, "void") != "floor"
				or not bool(explored_cells.get(horizontal_flank, false))
				or not bool(explored_cells.get(vertical_flank, false))
			):
				break
		if tiles.get(cell, "void") != "floor":
			break
		if not bool(explored_cells.get(cell, false)):
			break
		if bool(occupied_cells.get(cell, false)):
			break
		result.append(cell)
		previous = cell
	return result


static func direction_to_straight_endpoint(origin: Vector2i, endpoint: Vector2i) -> Vector2i:
	var delta := endpoint - origin
	if delta.x == 0 and delta.y != 0:
		return Vector2i(0, signi(delta.y))
	if delta.y == 0 and delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	if absi(delta.x) == absi(delta.y) and delta.x != 0:
		return Vector2i(signi(delta.x), signi(delta.y))
	return Vector2i.ZERO


static func direction_to_cardinal_endpoint(origin: Vector2i, endpoint: Vector2i) -> Vector2i:
	## Kept as a compatibility helper for older tests/callers. New Dash logic
	## should use direction_to_straight_endpoint(), which also accepts diagonals.
	var direction := direction_to_straight_endpoint(origin, endpoint)
	return direction if CARDINAL_DIRECTIONS.has(direction) else Vector2i.ZERO


static func dash_distance(origin: Vector2i, endpoint: Vector2i) -> int:
	var delta := endpoint - origin
	return maxi(absi(delta.x), absi(delta.y))


static func circular_target_cells(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y_offset in range(-1, 2):
		for x_offset in range(-1, 2):
			if x_offset == 0 and y_offset == 0:
				continue
			result.append(origin + Vector2i(x_offset, y_offset))
	return result


static func almost_double_strike_chance(level: int) -> float:
	if level <= 0:
		return 0.0
	var percent := 10 + (clampi(level, 1, 11) - 1) * 2
	return percent / 100.0


static func chance_succeeds(roll: float, chance: float) -> bool:
	return clampf(roll, 0.0, 1.0) < clampf(chance, 0.0, 1.0)
