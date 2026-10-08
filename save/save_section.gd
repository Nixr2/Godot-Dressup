class_name SaveSection
extends RefCounted
## One independent part of a [SaveGame], such as the player's data.
##
## To save something new, extend this class, give it a unique [method get_key]
## and convert its data to and from JSON-safe values (numbers, strings, bools,
## arrays and dictionaries), then add the script to
## SaveManager.SECTION_TYPES. Sections load independently, so adding or
## removing one never breaks existing save files.


## Unique name of this section in the save file. Never change it once saves
## exist; rename the class instead.
func get_key() -> StringName:
	return &""


## Returns this section's data as JSON-safe values.
func to_dict() -> Dictionary:
	return {}


## Restores this section from [method to_dict] data written by save format
## [param version]; convert older layouts here when the format changes.
## Missing or malformed values should fall back to defaults.
func from_dict(_data: Dictionary, _version: int) -> void:
	pass
