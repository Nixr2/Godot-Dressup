class_name PhotoAlbum
extends RefCounted
## Saves photos taken with the in-game phone as PNGs in user://photos
## (on Windows, %APPDATA%/Godot/app_userdata/Dressup/photos).

const DIRECTORY := "user://photos"


## Saves [param image] with a timestamped name and returns its path, or an
## empty string if it couldn't be saved.
static func save(image: Image) -> String:
	var error := DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if error != OK:
		push_error("PhotoAlbum: couldn't create %s (%s)." % [DIRECTORY, error_string(error)])
		return ""
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "%s/photo_%s.png" % [DIRECTORY, stamp]
	var suffix := 2
	while FileAccess.file_exists(path):
		path = "%s/photo_%s_%d.png" % [DIRECTORY, stamp, suffix]
		suffix += 1
	error = image.save_png(path)
	if error != OK:
		push_error("PhotoAlbum: couldn't save %s (%s)." % [path, error_string(error)])
		return ""
	return path
