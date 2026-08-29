class_name CombatSystem
extends RefCounted

const GridNavigation := preload("res://scripts/world/grid_navigation.gd")

## Deterministic combat primitives shared by player and enemy attacks. Actor
## selection, rewards, messages and turn completion deliberately remain in Main.


static func resolve_attack(d20: int, accuracy: int, dodge: int) -> Dictionary:
	var die_result := clampi(d20, 1, 20)
	var attack_total := die_result + accuracy
	var defense_target := 10 + dodge
	return {
		"d20": die_result,
		"attack_total": attack_total,
		"defense_target": defense_target,
		"hit": attack_total >= defense_target,
	}


static func is_ranged_target_valid(
	tiles: Dictionary,
	from: Vector2i,
	to: Vector2i,
	maximum_range: int,
) -> bool:
	var distance := GridNavigation.manhattan(from, to)
	return (
		distance >= 1
		and distance <= maximum_range
		and GridNavigation.has_clear_line(tiles, from, to)
	)
