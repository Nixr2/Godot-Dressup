extends Node
## Entry point. Wires the GUI to the 3D world (signals up, calls down) and
## swaps between character creation and a walkable stage.

## Stage the Play button opens.
@export var play_stage: PackedScene

var _stage: WalkableStage

@onready var _dressing_room: DressingRoom = $DressingRoom
@onready var _customization_menu: CustomizationMenu = $CustomizationMenu


func _ready() -> void:
	var mannequin := _dressing_room.mannequin
	var wardrobe := mannequin.wardrobe
	var body_customizer := mannequin.body_customizer
	var shape_keys := mannequin.shape_key_controller

	_customization_menu.skin_tone_changed.connect(body_customizer.set_skin_tone)
	_customization_menu.hair_color_changed.connect(body_customizer.set_hair_color)
	_customization_menu.eye_color_changed.connect(body_customizer.set_eye_color)
	_customization_menu.item_selected.connect(wardrobe.equip)
	_customization_menu.slot_cleared.connect(wardrobe.unequip)
	_customization_menu.item_tint_changed.connect(wardrobe.set_item_tint)
	_customization_menu.body_shape_changed.connect(shape_keys.set_body_value)
	_customization_menu.expression_selected.connect(shape_keys.set_expression)
	_customization_menu.auto_blink_toggled.connect(shape_keys.set_auto_blink)
	shape_keys.availability_changed.connect(_update_shape_key_availability)
	_customization_menu.arm_pose_selected.connect(mannequin.animator.set_arm_pose)
	_customization_menu.set_arm_poses(mannequin.animator.arm_poses)
	_customization_menu.body_pose_selected.connect(mannequin.animator.set_body_pose)
	_customization_menu.set_body_poses(mannequin.animator.body_poses)
	_customization_menu.play_requested.connect(_on_play_requested)
	_customization_menu.focus_requested.connect(_dressing_room.camera_rig.focus)
	_customization_menu.head_follow_toggled.connect(mannequin.look_at.set_head_follow)
	_customization_menu.eyes_follow_toggled.connect(mannequin.look_at.set_eyes_follow)
	_customization_menu.set_follow_state(
			mannequin.look_at.head_follow, mannequin.look_at.eyes_follow
	)

	wardrobe.item_equipped.connect(_on_item_equipped)
	wardrobe.item_unequipped.connect(_on_item_unequipped)

	_customization_menu.set_body_values(
			body_customizer.skin_tone,
			body_customizer.skin_undertone,
			body_customizer.hair_color,
			body_customizer.eye_color
	)
	for slot: OutfitItem.Slot in OutfitItem.Slot.values():
		_customization_menu.set_slot_state(
				slot, wardrobe.get_equipped(slot), wardrobe.get_item_tint(slot)
		)
	_customization_menu.set_body_shape_values(
			mannequin.get_appearance().body_shapes, shape_keys.auto_blink
	)
	_update_shape_key_availability()


func _notification(what: int) -> void:
	# Character creation is kept out of the tree while on a stage.
	if what == NOTIFICATION_PREDELETE and not _dressing_room.is_inside_tree():
		_dressing_room.free()
		_customization_menu.free()


func _update_shape_key_availability() -> void:
	var shape_keys := _dressing_room.mannequin.shape_key_controller
	for definition in shape_keys.shape_key_set.definitions:
		_customization_menu.set_body_shape_available(
				definition.key, shape_keys.is_available(definition.key)
		)


func _on_item_equipped(item: OutfitItem) -> void:
	var wardrobe := _dressing_room.mannequin.wardrobe
	_customization_menu.set_slot_state(item.slot, item, wardrobe.get_item_tint(item.slot))


func _on_item_unequipped(item: OutfitItem) -> void:
	_customization_menu.set_slot_state(item.slot, null, Color.WHITE)


## Keeps character creation alive (but out of the tree) so it's unchanged on return.
func _on_play_requested() -> void:
	var appearance := _dressing_room.mannequin.get_appearance()
	remove_child(_dressing_room)
	remove_child(_customization_menu)
	_stage = play_stage.instantiate()
	_stage.setup(appearance)
	add_child(_stage)
	_stage.exit_requested.connect(_on_stage_exit_requested)


func _on_stage_exit_requested() -> void:
	_stage.queue_free()
	_stage = null
	add_child(_dressing_room)
	add_child(_customization_menu)
