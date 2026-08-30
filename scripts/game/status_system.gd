class_name StatusSystem
extends RefCounted

## Immutable status definitions live here; saves contain only the mutable fields
## explicitly sanitized below. Gameplay modifiers are never trusted from save data.

const STATUS_ORDER: Array[String] = ["rested"]
const STATUSES := {
	"rested": {
		"name": "STATUS_RESTED",
		"description": "STATUS_RESTED_DESC",
		"icon": "rested_ember",
		"priority": 100,
		"default_duration": 500,
		"max_duration": 500,
		"temporary_hp_grant": 5,
		"per_turn_effect": {},
		"modifiers": {
			"damage": 1,
			"ranged_damage": 1,
		},
		"cooldown_reduction": {
			"dash": 10,
			"double_attack": 5,
		},
	},
}


static func rules(status_id: String) -> Dictionary:
	return STATUSES.get(status_id, {})


static func sanitize(saved_value: Variant) -> Dictionary:
	var result := {}
	if not saved_value is Dictionary:
		return result
	var saved: Dictionary = saved_value
	for status_id in STATUS_ORDER:
		if not saved.has(status_id) or not saved[status_id] is Dictionary:
			continue
		var entry: Dictionary = saved[status_id]
		var remaining := _positive_integer(entry.get("remaining_turns", 0))
		if remaining <= 0:
			continue
		var status_rules: Dictionary = STATUSES[status_id]
		remaining = mini(remaining, int(status_rules["max_duration"]))
		var temporary_hp := _positive_integer(entry.get("temporary_hp", 0))
		temporary_hp = mini(temporary_hp, int(status_rules.get("temporary_hp_grant", 0)))
		result[status_id] = {
			"remaining_turns": remaining,
			"temporary_hp": temporary_hp,
		}
	return result


static func add_or_refresh(
	active_statuses: Dictionary,
	status_id: String,
	duration := -1,
	temporary_hp := -1,
) -> bool:
	if not STATUSES.has(status_id):
		return false
	var status_rules: Dictionary = STATUSES[status_id]
	var resolved_duration := (
		int(status_rules["default_duration"]) if duration < 0 else duration
	)
	var resolved_temporary_hp := (
		int(status_rules.get("temporary_hp_grant", 0))
		if temporary_hp < 0 else temporary_hp
	)
	active_statuses[status_id] = {
		"remaining_turns": clampi(
			resolved_duration, 1, int(status_rules["max_duration"]),
		),
		"temporary_hp": clampi(
			resolved_temporary_hp, 0, int(status_rules.get("temporary_hp_grant", 0)),
		),
	}
	return true


static func remove(active_statuses: Dictionary, status_id: String) -> bool:
	if not active_statuses.has(status_id):
		return false
	active_statuses.erase(status_id)
	return true


static func tick(active_statuses: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for status_id in ordered_active_ids(active_statuses):
		var entry: Dictionary = active_statuses[status_id]
		var per_turn_effect: Dictionary = STATUSES[status_id].get("per_turn_effect", {})
		if not per_turn_effect.is_empty():
			# Pure event hook: RunState/Main may interpret centrally registered
			# effects without persisting executable/modifier data in the save.
			events.append({
				"type": "per_turn",
				"status_id": status_id,
				"effect": per_turn_effect.duplicate(true),
			})
		entry["remaining_turns"] = int(entry.get("remaining_turns", 0)) - 1
		if int(entry["remaining_turns"]) <= 0:
			active_statuses.erase(status_id)
			events.append({"type": "expired", "status_id": status_id})
		else:
			active_statuses[status_id] = entry
			events.append({"type": "ticked", "status_id": status_id})
	return events


static func ordered_active_ids(active_statuses: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for status_id in STATUS_ORDER:
		if active_statuses.has(status_id):
			result.append(status_id)
	result.sort_custom(func(a: String, b: String) -> bool:
		return int(STATUSES[a].get("priority", 0)) > int(STATUSES[b].get("priority", 0))
	)
	return result


static func modifier(active_statuses: Dictionary, modifier_id: String) -> int:
	var result := 0
	for status_id in ordered_active_ids(active_statuses):
		result += int(STATUSES[status_id].get("modifiers", {}).get(modifier_id, 0))
	return result


static func cooldown_reduction(active_statuses: Dictionary, ability_id: String) -> int:
	var result := 0
	for status_id in ordered_active_ids(active_statuses):
		result += int(STATUSES[status_id].get("cooldown_reduction", {}).get(ability_id, 0))
	return result


static func _positive_integer(value: Variant) -> int:
	if value is bool or (not value is int and not value is float):
		return 0
	return maxi(0, floori(float(value)))
