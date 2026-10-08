class_name PlayerSection
extends SaveSection
## The player's own data: their character's look and their attributes.

const KEY := &"player"

## The player's character look, or null before one has been saved.
var appearance: CharacterAppearance
## Numeric attributes by name (e.g. level, money, stats), for gameplay to
## fill in. Unknown names are kept, so attributes can be added freely.
var stats: Dictionary[StringName, float] = {}


func get_key() -> StringName:
	return KEY


func to_dict() -> Dictionary:
	var stat_values := {}
	for stat in stats:
		stat_values[String(stat)] = stats[stat]
	return {
		"appearance": appearance.to_dict() if appearance else null,
		"stats": stat_values,
	}


func from_dict(data: Dictionary, _version: int) -> void:
	var appearance_data: Variant = data.get("appearance")
	appearance = null
	if appearance_data is Dictionary:
		appearance = CharacterAppearance.from_dict(appearance_data, SaveManager.find_item)
	stats.clear()
	var stat_values: Variant = data.get("stats")
	if stat_values is Dictionary:
		for stat: Variant in stat_values:
			if stat_values[stat] is float or stat_values[stat] is int:
				stats[StringName(str(stat))] = float(stat_values[stat])
