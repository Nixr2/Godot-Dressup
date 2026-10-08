class_name PhoneMenu
extends Control
## The in-game phone, with two tabs: Wardrobe lists the clothing in the
## player's [Inventory] by slot to put on or take off, and Camera shows the
## phone's front camera live on its screen and takes photos with it (see
## SelfieCamera).
##
## Shown with [method open] once the phone is out (slides up from the bottom)
## and hidden with [method close]. The viewfinder renders the world from a
## camera that copies [method set_preview_camera]'s every frame, into its own
## portrait [SubViewport]; [method capture_photo] renders that view at
## [constant PHOTO_SIZE]. Otherwise UI only: it reports choices with signals.

## Emitted when the player picks an item to wear.
signal item_selected(item: OutfitItem)
## Emitted when the player takes off what's worn in [param slot].
signal slot_cleared(slot: OutfitItem.Slot)
## Emitted when the player asks to put the phone away.
signal close_requested
## Emitted when the Camera tab is opened (true) or left (false).
signal camera_toggled(enabled: bool)
## Emitted when the player presses Take Photo.
signal photo_requested
## Emitted when the wide (0.5x) lens is switched on or off.
signal wide_lens_toggled(wide: bool)

## Slots in the order they're listed. Hair isn't clothing, so it's left out.
const SLOT_ORDER: Array[OutfitItem.Slot] = [
	OutfitItem.Slot.HEAD,
	OutfitItem.Slot.FACE_OVERLAY,
	OutfitItem.Slot.TORSO,
	OutfitItem.Slot.UNDERWEAR,
	OutfitItem.Slot.LEGS,
	OutfitItem.Slot.SOCKS,
	OutfitItem.Slot.FEET,
	OutfitItem.Slot.ACCESSORY,
]
## Seconds for the phone to slide in or out.
const SLIDE_TIME := 0.25
## Seconds the photo flash takes to fade.
const FLASH_TIME := 0.35
## Resolution of the live viewfinder and of saved photos (portrait).
const PREVIEW_SIZE := Vector2i(540, 720)
const PHOTO_SIZE := Vector2i(1080, 1440)

var _item_buttons: Dictionary[OutfitItem, Button] = {}
var _clear_buttons: Dictionary[OutfitItem.Slot, Button] = {}
var _slide: Tween
# The phone's top offset in its layout; sliding moves the phone (and so its
# offsets), so the resting spot is remembered.
var _rest_offset_top := 0.0
var _preview_source: Camera3D

@onready var _phone: Control = %Phone
@onready var _wardrobe_tab: Button = %WardrobeTab
@onready var _camera_tab: Button = %CameraTab
@onready var _wardrobe_page: Control = %WardrobePage
@onready var _camera_page: Control = %CameraPage
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _empty_label: Label = %EmptyLabel
@onready var _photo_button: Button = %PhotoButton
@onready var _wide_lens_toggle: Button = %WideLensToggle
@onready var _photo_status: Label = %PhotoStatus
@onready var _close_button: Button = %CloseButton
@onready var _flash: ColorRect = %Flash
@onready var _viewfinder: TextureRect = %Viewfinder
@onready var _preview_viewport: SubViewport = %PreviewViewport
@onready var _preview_camera: Camera3D = %PreviewCamera


func _ready() -> void:
	_close_button.pressed.connect(close_requested.emit)
	_photo_button.pressed.connect(photo_requested.emit)
	_wide_lens_toggle.toggled.connect(wide_lens_toggled.emit)
	_wardrobe_tab.pressed.connect(_show_tab.bind(false))
	_camera_tab.pressed.connect(_show_tab.bind(true))
	_rest_offset_top = _phone.offset_top
	_preview_viewport.size = PREVIEW_SIZE
	_viewfinder.texture = _preview_viewport.get_texture()
	_preview_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	visible = false


func _process(_delta: float) -> void:
	if _camera_page.visible and is_instance_valid(_preview_source):
		_preview_camera.global_transform = _preview_source.global_transform
		_preview_camera.fov = _preview_source.fov
		_preview_camera.near = _preview_source.near


## Lists the items in [param inventory], marking what [param wardrobe] has on.
func show_inventory(inventory: Inventory, wardrobe: Wardrobe) -> void:
	for card in _slot_list.get_children():
		card.queue_free()
	_item_buttons.clear()
	_clear_buttons.clear()
	for slot in SLOT_ORDER:
		var items := inventory.get_items_for_slot(slot)
		if not items.is_empty():
			_add_slot_card(slot, items)
	_empty_label.visible = _clear_buttons.is_empty()
	for slot in _clear_buttons:
		set_equipped(slot, wardrobe.get_equipped(slot))


## Marks [param item] as worn in [param slot] (null = nothing worn).
func set_equipped(slot: OutfitItem.Slot, item: OutfitItem) -> void:
	if not _clear_buttons.has(slot):
		return
	var selected: Button = _item_buttons.get(item, _clear_buttons[slot])
	# set_pressed_no_signal() doesn't release the rest of the group.
	for button in selected.button_group.get_buttons():
		button.set_pressed_no_signal(button == selected)


## Slides the phone up into view, on the Wardrobe tab.
func open() -> void:
	visible = true
	_set_tab_state(false)
	_photo_status.text = ""
	_slide_to(0.0)


## Slides the phone down out of view, then hides it. Leaves the Camera tab
## first, so the game camera comes back.
func close() -> void:
	if not visible:
		return
	if _camera_page.visible:
		_set_tab_state(false)
		camera_toggled.emit(false)
	_slide_to(_phone.size.y + 64.0).finished.connect(hide)


## Sets the camera the viewfinder shows (e.g. the SelfieCamera).
func set_preview_camera(camera: Camera3D) -> void:
	_preview_source = camera


## Renders the viewfinder's view at [constant PHOTO_SIZE] and returns it,
## flashing the viewfinder.
func capture_photo() -> Image:
	_preview_viewport.size = PHOTO_SIZE
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := _preview_viewport.get_texture().get_image()
	_preview_viewport.size = PREVIEW_SIZE
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	flash()
	return image


## Shows a white flash over the viewfinder, like a camera flash.
func flash() -> void:
	_flash.modulate.a = 0.8
	_flash.visible = true
	var tween := create_tween()
	tween.tween_property(_flash, ^"modulate:a", 0.0, FLASH_TIME)
	tween.tween_callback(_flash.hide)


## Shows where the last photo was saved (or why it wasn't).
func show_photo_status(message: String) -> void:
	_photo_status.text = message


func _show_tab(camera: bool) -> void:
	if camera == _camera_page.visible:
		return
	_set_tab_state(camera)
	camera_toggled.emit(camera)


func _set_tab_state(camera: bool) -> void:
	_wardrobe_tab.set_pressed_no_signal(not camera)
	_camera_tab.set_pressed_no_signal(camera)
	_wardrobe_page.visible = not camera
	_camera_page.visible = camera
	_wide_lens_toggle.set_pressed_no_signal(false)


func _slide_to(offset: float) -> Tween:
	if _slide:
		_slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if offset > 0.0:
		_slide.set_ease(Tween.EASE_IN)
	else:
		_phone.position.y = _get_rest_y() + _phone.size.y + 64.0
	_slide.tween_property(_phone, ^"position:y", _get_rest_y() + offset, SLIDE_TIME)
	return _slide


# Where the phone sits when fully shown: its anchored layout position.
func _get_rest_y() -> float:
	return size.y + _rest_offset_top


func _add_slot_card(slot: OutfitItem.Slot, items: Array[OutfitItem]) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	var content := VBoxContainer.new()
	card.add_child(content)
	var header := Label.new()
	header.text = OutfitItem.Slot.find_key(slot).capitalize()
	header.theme_type_variation = &"SectionHeader"
	content.add_child(header)
	var buttons := HFlowContainer.new()
	content.add_child(buttons)
	var group := ButtonGroup.new()
	_clear_buttons[slot] = _add_button(buttons, group, "None", slot_cleared.emit.bind(slot))
	for item in items:
		var select := item_selected.emit.bind(item)
		_item_buttons[item] = _add_button(buttons, group, item.display_name, select)
	_slot_list.add_child(card)


func _add_button(
		container: Container, group: ButtonGroup, text: String, pressed: Callable
) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	container.add_child(button)
	return button
