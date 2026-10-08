class_name WalkableStage
extends Node3D
## A stage the customized character can walk around in.
##
## Expects a [Player] named "Player" and a [StageHud] named
## "StageHud" as children; the world itself is anything else. An optional
## [DayNightCycle] named "DayNightCycle" gets time controls in the HUD, and an
## optional [PhoneMenu] named "PhoneMenu" opens when the player takes their
## phone out, to change clothes from their [Inventory] or take selfies with
## its front camera (saved by [PhotoAlbum]).

## Emitted when the player asks to return to character creation.
signal exit_requested

@onready var player: Player = $Player
@onready var _hud: StageHud = $StageHud
@onready var _day_night: DayNightCycle = get_node_or_null(^"DayNightCycle")
@onready var _phone_menu: PhoneMenu = get_node_or_null(^"PhoneMenu")

var _inventory: Inventory


func _ready() -> void:
	var animator := player.mannequin.animator
	_hud.back_pressed.connect(exit_requested.emit)
	_hud.move_speed_changed.connect(_on_move_speed_changed)
	_hud.jog_speed_changed.connect(_on_jog_speed_changed)
	_hud.sprint_speed_changed.connect(_on_sprint_speed_changed)
	_hud.walk_playback_multiplier_changed.connect(_on_walk_playback_multiplier_changed)
	_hud.set_values(
			player.get_effective_move_speed(),
			player.get_effective_jog_speed(),
			player.get_effective_sprint_speed(),
			animator.walk_playback_multiplier,
			animator.stride_speed,
			animator.jog_stride_speed,
			animator.sprint_stride_speed
	)
	if _day_night:
		_hud.show_time_controls(_day_night.time_of_day, _day_night.paused)
		_hud.time_of_day_changed.connect(_on_time_of_day_changed)
		_hud.time_paused_toggled.connect(_on_time_paused_toggled)
		_day_night.time_changed.connect(_hud.show_time)
	if _phone_menu:
		var wardrobe := player.mannequin.wardrobe
		player.phone_opened.connect(_on_phone_opened)
		player.phone_closed.connect(_phone_menu.close)
		_phone_menu.close_requested.connect(player.put_away_phone)
		_phone_menu.item_selected.connect(wardrobe.equip)
		_phone_menu.slot_cleared.connect(wardrobe.unequip)
		_phone_menu.camera_toggled.connect(_on_camera_toggled)
		_phone_menu.photo_requested.connect(_take_photo)
		_phone_menu.wide_lens_toggled.connect(player.set_wide_lens)
		_phone_menu.set_preview_camera(player.get_selfie_camera())
		wardrobe.item_equipped.connect(_on_item_equipped)
		wardrobe.item_unequipped.connect(_on_item_unequipped)


## Dresses the player's character and gives the phone menu the clothes they
## own. Call before adding the stage to the tree, so the character is dressed
## once, as it enters, instead of being redressed.
func setup(appearance: CharacterAppearance, inventory: Inventory) -> void:
	var mannequin: Mannequin = get_node(^"Player/Mannequin")
	mannequin.initial_appearance = appearance
	_inventory = inventory


## Returns the player character's current look.
func get_player_appearance() -> CharacterAppearance:
	return player.mannequin.get_appearance()


func _on_move_speed_changed(speed: float) -> void:
	player.move_speed = speed


func _on_jog_speed_changed(speed: float) -> void:
	player.jog_speed = speed


func _on_sprint_speed_changed(speed: float) -> void:
	player.sprint_speed = speed


func _on_time_of_day_changed(hours: float) -> void:
	_day_night.time_of_day = hours


func _on_time_paused_toggled(paused: bool) -> void:
	_day_night.paused = paused


func _on_walk_playback_multiplier_changed(multiplier: float) -> void:
	player.mannequin.animator.walk_playback_multiplier = multiplier


func _on_phone_opened() -> void:
	var inventory := _inventory if _inventory else Inventory.new()
	_phone_menu.show_inventory(inventory, player.mannequin.wardrobe)
	_phone_menu.open()


func _on_item_equipped(item: OutfitItem) -> void:
	_phone_menu.set_equipped(item.slot, item)


func _on_item_unequipped(item: OutfitItem) -> void:
	_phone_menu.set_equipped(item.slot, null)


func _on_camera_toggled(enabled: bool) -> void:
	player.set_selfie_mode(enabled)


func _take_photo() -> void:
	var image := await _phone_menu.capture_photo()
	var path := PhotoAlbum.save(image)
	if path.is_empty():
		_phone_menu.show_photo_status("Couldn't save the photo.")
	else:
		_phone_menu.show_photo_status("Saved %s" % path.get_file())
