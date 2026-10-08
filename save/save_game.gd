class_name SaveGame
extends RefCounted
## Everything saved in one save slot: a set of [SaveSection]s.
##
## Create one with SaveManager.new_game() so it has every section type, then
## reach sections by key with [method get_section], or the player's data
## through [member player]. Sections in a file that this build doesn't know
## (from a newer build, or a removed feature) are kept and written back
## unchanged.

## When this game was last saved, as a Unix timestamp (0 = never).
var saved_at := 0
## The sections, by [method SaveSection.get_key].
var sections: Dictionary[StringName, SaveSection] = {}
## The player's data.
var player: PlayerSection:
	get:
		return sections.get(PlayerSection.KEY)

var _unknown_sections: Dictionary = {}


## Returns the section named [param key], or null.
func get_section(key: StringName) -> SaveSection:
	return sections.get(key)


func add_section(section: SaveSection) -> void:
	sections[section.get_key()] = section


## Returns the whole save as JSON-safe data, stamped with [param version].
func to_dict(version: int) -> Dictionary:
	var section_data := _unknown_sections.duplicate(true)
	for key in sections:
		section_data[String(key)] = sections[key].to_dict()
	return { "version": version, "saved_at": saved_at, "sections": section_data }


## Fills the sections from [method to_dict] data.
func load_dict(data: Dictionary) -> void:
	# JSON numbers are floats.
	var version: int = int(data.version) if data.get("version") is float else 1
	saved_at = int(data.saved_at) if data.get("saved_at") is float else 0
	_unknown_sections.clear()
	var section_data: Variant = data.get("sections")
	if not section_data is Dictionary:
		return
	for key: Variant in section_data:
		var section := get_section(StringName(str(key)))
		if section == null:
			_unknown_sections[key] = section_data[key]
		elif section_data[key] is Dictionary:
			section.from_dict(section_data[key], version)
