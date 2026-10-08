extends Node
## Saves and loads the game and character creation presets (autoload
## "SaveManager").
##
## Saves are JSON files in user://saves/<slot>.json holding a [SaveGame]: the
## current game is [member current]. Presets are looks saved from character
## creation, in user://presets/<name>.json, plus [member builtin_presets]
## that ship with the game.
##
## Files are written to a temporary file first and then swapped in, with the
## previous version kept as a .bak that is read if the main file is damaged.
## Every file records [constant VERSION], so later builds can convert old
## saves (see [method SaveSection.from_dict]). On Windows, user:// is
## %APPDATA%/Godot/app_userdata/Dressup.

signal game_saved(slot: String)
signal game_loaded(slot: String)
## Emitted when a user preset is saved or deleted.
signal presets_changed

## Save format version. Bump it when a section's layout changes, and convert
## older data in that section's from_dict().
const VERSION := 1
const SAVE_DIR := "user://saves"
const PRESET_DIR := "user://presets"
const DEFAULT_SLOT := "autosave"
## Every section a save holds. Add new [SaveSection] scripts here.
const SECTION_TYPES: Array[Script] = [
	preload("res://save/sections/player_section.gd"),
]

## Catalogs used to turn saved item ids back into items.
@export var item_catalogs: Array[OutfitCatalog] = []
## Presets that ship with the game, by name. They can't be overwritten or
## deleted.
@export var builtin_presets: Dictionary[String, CharacterAppearance] = {}

## The game being played; saved by [method save_game].
var current: SaveGame

var _items: Dictionary[StringName, OutfitItem] = {}


func _ready() -> void:
	for catalog in item_catalogs:
		for item in catalog.items:
			_items[item.id] = item
	current = new_game()


## Returns a new, empty game with every section.
func new_game() -> SaveGame:
	var game := SaveGame.new()
	for section_type in SECTION_TYPES:
		game.add_section(section_type.new())
	return game


## Writes [member current] to [param slot].
func save_game(slot := DEFAULT_SLOT) -> Error:
	current.saved_at = int(Time.get_unix_time_from_system())
	var error := _write_json(_slot_path(slot), current.to_dict(VERSION))
	if error == OK:
		game_saved.emit(slot)
	else:
		push_error("SaveManager: couldn't save slot '%s' (%s)." % [slot, error_string(error)])
	return error


## Replaces [member current] with the game in [param slot]. On failure
## [member current] is left unchanged.
func load_game(slot := DEFAULT_SLOT) -> Error:
	var data := _read_json(_slot_path(slot))
	if data.is_empty():
		return ERR_FILE_NOT_FOUND if not has_save(slot) else ERR_FILE_CORRUPT
	var game := new_game()
	game.load_dict(data)
	current = game
	game_loaded.emit(slot)
	return OK


func has_save(slot := DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot := DEFAULT_SLOT) -> Error:
	return _delete_file(_slot_path(slot))


## Returns the names of every saved slot.
func get_save_slots() -> PackedStringArray:
	return _list_json_files(SAVE_DIR)


## Returns the item with [param id] from [member item_catalogs], or null.
func find_item(id: StringName) -> OutfitItem:
	return _items.get(id)


## Returns the names of the user's presets, sorted.
func get_preset_names() -> PackedStringArray:
	var names := PackedStringArray()
	for file in _list_json_files(PRESET_DIR):
		var data := _read_json(_preset_path(file))
		var preset_name: Variant = data.get("name")
		names.append(preset_name if preset_name is String else file)
	names.sort()
	return names


## Returns the names of [member builtin_presets], sorted.
func get_builtin_preset_names() -> PackedStringArray:
	var names := PackedStringArray(builtin_presets.keys())
	names.sort()
	return names


func is_builtin_preset(preset_name: String) -> bool:
	return builtin_presets.has(preset_name)


## Saves [param appearance] as a user preset, replacing one with the same
## name. Built-in preset names are refused.
func save_preset(preset_name: String, appearance: CharacterAppearance) -> Error:
	preset_name = preset_name.strip_edges()
	if preset_name.is_empty() or is_builtin_preset(preset_name):
		return ERR_INVALID_PARAMETER
	var data := { "version": VERSION, "name": preset_name, "appearance": appearance.to_dict() }
	var error := _write_json(_preset_path(preset_name), data)
	if error == OK:
		presets_changed.emit()
	return error


## Returns the preset named [param preset_name] (built-in or user), or null.
## The result is a new copy, so changing it doesn't change the preset.
func load_preset(preset_name: String) -> CharacterAppearance:
	if is_builtin_preset(preset_name):
		# Round-trips through plain data: a copy that shares the same items.
		return CharacterAppearance.from_dict(builtin_presets[preset_name].to_dict(), find_item)
	var appearance_data: Variant = _read_json(_preset_path(preset_name)).get("appearance")
	if appearance_data is Dictionary:
		return CharacterAppearance.from_dict(appearance_data, find_item)
	return null


## Deletes a user preset. Built-in presets can't be deleted.
func delete_preset(preset_name: String) -> Error:
	if is_builtin_preset(preset_name):
		return ERR_INVALID_PARAMETER
	var error := _delete_file(_preset_path(preset_name))
	if error == OK:
		presets_changed.emit()
	return error


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot.validate_filename()]


func _preset_path(preset_name: String) -> String:
	return "%s/%s.json" % [PRESET_DIR, preset_name.validate_filename()]


# Writes to a temporary file, keeps the old file as .bak, then swaps the new
# one in, so a crash mid-write never leaves a half-written save.
func _write_json(path: String, data: Dictionary) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(temp_path, path)


# Returns the file's data, falling back to its .bak if the file is missing or
# damaged; an empty dictionary if neither can be read.
func _read_json(path: String) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if data is Dictionary:
			return data
		push_warning("SaveManager: '%s' is damaged." % candidate)
	return {}


func _delete_file(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	if FileAccess.file_exists(path + ".bak"):
		DirAccess.remove_absolute(path + ".bak")
	return DirAccess.remove_absolute(path)


# Names (without extension) of the .json files in [param directory].
func _list_json_files(directory: String) -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(directory):
		if file.get_extension() == "json":
			names.append(file.get_basename())
	return names
