class_name CustomizationMenu
extends Control
## Character creation UI: appearance cards on the left, the wardrobe on the
## right.
##
## Each section card has a "focus" metadata entry naming a camera framing;
## hovering a card emits [signal focus_requested] with it, so the camera can
## frame what's being edited. Focus sticks after the mouse leaves the card, and
## hovering is ignored while a color picker is open or a mouse button is held
## (dragging a slider, orbiting the camera).
##
## Emits signals only; the owner decides what to do with each change and
## reports state back through the public setters.

## Emitted when either skin slider changes.
signal skin_tone_changed(tone: float, undertone: float)
## Emitted when a hair swatch or the custom hair color is picked.
signal hair_color_changed(color: Color)
## Emitted when an item button is pressed.
signal item_selected(item: OutfitItem)
## Emitted when a slot's "None" button is pressed.
signal slot_cleared(slot: OutfitItem.Slot)
## Emitted when a slot's color picker changes.
signal item_tint_changed(slot: OutfitItem.Slot, color: Color)
## Emitted when a body shape slider changes.
signal body_shape_changed(key: StringName, value: float)
## Emitted when an expression button is pressed. An empty key means neutral.
signal expression_selected(key: StringName)
## Emitted when the auto blink checkbox is toggled.
signal auto_blink_toggled(enabled: bool)
## Emitted when an arm pose button is pressed. Null means the idle's own arms.
signal arm_pose_selected(pose: ArmPose)
## Emitted when a body pose button is pressed. Null means the idle.
signal body_pose_selected(pose: BodyPose)
## Emitted when the Play button is pressed.
signal play_requested
## Emitted with the camera framing of a newly hovered section.
signal focus_requested(focus: StringName)
## Emitted when the head follow chip is toggled.
signal head_follow_toggled(enabled: bool)
## Emitted when the eyes follow chip is toggled.
signal eyes_follow_toggled(enabled: bool)

const HAIR_PRESETS: Array[Color] = [
	Color("2a2420"), # Black
	Color("4a3426"), # Dark brown
	Color("6f4a2f"), # Brown
	Color("8d3f25"), # Auburn
	Color("b5582a"), # Ginger
	Color("d8b574"), # Blonde
	Color("e6dcc3"), # Platinum
	Color("a9a9a9"), # Gray
]
const SLOT_FOCUS: Dictionary[OutfitItem.Slot, StringName] = {
	OutfitItem.Slot.HEAD: &"head",
	OutfitItem.Slot.TORSO: &"torso",
	OutfitItem.Slot.LEGS: &"legs",
	OutfitItem.Slot.FEET: &"feet",
	OutfitItem.Slot.ACCESSORY: &"full_body",
}
const SWATCH_SIZE := Vector2(22.0, 22.0)
const FOCUS_META := &"focus"
const CARD := &"Card"
const CARD_ACTIVE := &"CardActive"

@export var catalog: OutfitCatalog
@export var skin_tone_palette: SkinTonePalette
@export var shape_key_set: ShapeKeySet
## Framing for cards without their own, and the initial focus.
@export var default_focus: StringName = &"full_body"

var _tint_pickers: Dictionary[OutfitItem.Slot, ColorPickerButton] = {}
var _item_buttons: Dictionary[OutfitItem, Button] = {}
var _clear_buttons: Dictionary[OutfitItem.Slot, Button] = {}
var _body_shape_sliders: Dictionary[StringName, HSlider] = {}
var _body_shape_labels: Dictionary[StringName, Label] = {}
var _expression_group := ButtonGroup.new()
var _arm_pose_group := ButtonGroup.new()
var _body_pose_group := ButtonGroup.new()
var _cards: Array[PanelContainer] = []
var _color_pickers: Array[ColorPickerButton] = []
## Card under the mouse last frame; focus changes only when this changes.
var _hovered_card: PanelContainer
## Card whose framing the camera shows; stays highlighted.
var _focused_card: PanelContainer
var _current_focus: StringName

@onready var _skin_tone_preview: TextureRect = %SkinTonePreview
@onready var _skin_tone_slider: HSlider = %SkinToneSlider
@onready var _undertone_slider: HSlider = %UndertoneSlider
@onready var _hair_swatches: HFlowContainer = %HairSwatches
@onready var _hair_color_picker: ColorPickerButton = %HairColorPicker
@onready var _body_shape_list: VBoxContainer = %BodyShapeList
@onready var _expression_buttons: HFlowContainer = %ExpressionButtons
@onready var _auto_blink_check: CheckBox = %AutoBlinkCheck
@onready var _body_pose_buttons: HFlowContainer = %BodyPoseButtons
@onready var _arm_pose_buttons: HFlowContainer = %ArmPoseButtons
@onready var _head_follow_toggle: Button = %HeadFollowToggle
@onready var _eyes_follow_toggle: Button = %EyesFollowToggle
@onready var _slot_list: VBoxContainer = %SlotList
@onready var _play_button: Button = %PlayButton
@onready var _left_scroll: ScrollContainer = %LeftScroll
@onready var _right_scroll: ScrollContainer = %RightScroll


func _ready() -> void:
	var preview_texture := GradientTexture1D.new()
	preview_texture.gradient = skin_tone_palette.gradient
	_skin_tone_preview.texture = preview_texture

	_skin_tone_slider.value_changed.connect(_on_skin_slider_changed.unbind(1))
	_undertone_slider.value_changed.connect(_on_skin_slider_changed.unbind(1))
	_hair_color_picker.color_changed.connect(hair_color_changed.emit)
	_auto_blink_check.toggled.connect(auto_blink_toggled.emit)
	_head_follow_toggle.toggled.connect(head_follow_toggled.emit)
	_eyes_follow_toggle.toggled.connect(eyes_follow_toggled.emit)
	_play_button.pressed.connect(play_requested.emit)
	_build_hair_swatches()
	_build_body_shape_sliders()
	_build_expression_buttons()
	_build_slot_list()
	for card in find_children("*", "PanelContainer", true, false):
		if card.has_meta(FOCUS_META):
			_cards.append(card)
	_color_pickers.assign(find_children("*", "ColorPickerButton", true, false))
	_current_focus = default_focus


func _process(_delta: float) -> void:
	_update_hover(get_global_mouse_position(), _is_hover_blocked())


## Shows the current skin tone, undertone and hair color.
func set_body_values(tone: float, undertone: float, hair_color: Color) -> void:
	_skin_tone_slider.set_value_no_signal(tone)
	_undertone_slider.set_value_no_signal(undertone)
	_hair_color_picker.color = hair_color


## Shows whether the head and eyes follow the camera.
func set_follow_state(head: bool, eyes: bool) -> void:
	_head_follow_toggle.set_pressed_no_signal(head)
	_eyes_follow_toggle.set_pressed_no_signal(eyes)


## Lists [param poses] as arm pose buttons, after "Default".
func set_arm_poses(poses: Array[ArmPose]) -> void:
	_clear(_arm_pose_buttons)
	_add_toggle_button(_arm_pose_buttons, _arm_pose_group, "Default", arm_pose_selected, null)
	for pose in poses:
		_add_toggle_button(
				_arm_pose_buttons, _arm_pose_group, pose.display_name, arm_pose_selected, pose
		)


## Lists [param poses] as body pose buttons, after "Idle".
func set_body_poses(poses: Array[BodyPose]) -> void:
	_clear(_body_pose_buttons)
	_add_toggle_button(_body_pose_buttons, _body_pose_group, "Idle", body_pose_selected, null)
	for pose in poses:
		_add_toggle_button(
				_body_pose_buttons, _body_pose_group, pose.display_name, body_pose_selected, pose
		)


## Shows the current body shape sliders and auto blink state.
func set_body_shape_values(values: Dictionary[StringName, float], auto_blink: bool) -> void:
	for key: StringName in _body_shape_sliders:
		_body_shape_sliders[key].set_value_no_signal(values.get(key, 0.0))
	_auto_blink_check.set_pressed_no_signal(auto_blink)


## Disables a body shape slider whose clothing condition isn't met.
func set_body_shape_available(key: StringName, available: bool) -> void:
	if not _body_shape_sliders.has(key):
		return
	_body_shape_sliders[key].editable = available
	var definition := shape_key_set.get_definition(key)
	var reason := "" if available else "Needs clothing tagged '%s'" % definition.required_tag
	_body_shape_sliders[key].tooltip_text = reason
	_body_shape_labels[key].tooltip_text = reason
	_body_shape_labels[key].modulate.a = 1.0 if available else 0.5


## Shows which item is worn in [param slot] and its tint.
func set_slot_state(slot: OutfitItem.Slot, item: OutfitItem, tint: Color) -> void:
	if not _tint_pickers.has(slot):
		return
	var picker := _tint_pickers[slot]
	picker.disabled = item == null or not item.tintable
	picker.color = tint
	var selected: Button = _item_buttons.get(item, _clear_buttons[slot])
	selected.set_pressed_no_signal(true)


## Focuses the card under [param mouse] when it differs from last frame's.
## While [param blocked], the card under the mouse still counts as hovered, so
## closing a picker over another card doesn't refocus until a new card.
func _update_hover(mouse: Vector2, blocked: bool) -> void:
	var hovered := _find_hovered_card(mouse)
	if hovered == _hovered_card:
		return
	_hovered_card = hovered
	if hovered and not blocked:
		_focus_card(hovered)


func _focus_card(card: PanelContainer) -> void:
	if _focused_card:
		_focused_card.theme_type_variation = CARD
	_focused_card = card
	card.theme_type_variation = CARD_ACTIVE
	var focus: StringName = card.get_meta(FOCUS_META)
	if focus != _current_focus:
		_current_focus = focus
		focus_requested.emit(focus)


## True while a color picker is open or a mouse button is held.
func _is_hover_blocked() -> bool:
	for picker in _color_pickers:
		if picker.get_popup().visible:
			return true
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button):
			return true
	return false


## Returns the focus card under [param mouse], if its scroll area shows it.
func _find_hovered_card(mouse: Vector2) -> PanelContainer:
	for card in _cards:
		if not card.is_visible_in_tree() or not card.get_global_rect().has_point(mouse):
			continue
		var scroll := _left_scroll if _left_scroll.is_ancestor_of(card) else _right_scroll
		if scroll.get_global_rect().has_point(mouse):
			return card
	return null


func _build_hair_swatches() -> void:
	for color in HAIR_PRESETS:
		var swatch := Button.new()
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.tooltip_text = "#" + color.to_html(false)
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(11)
		style.set_border_width_all(2)
		style.border_color = Color.WHITE
		var hover := style.duplicate() as StyleBoxFlat
		hover.border_color = Color("ee8fc4")
		for state in [&"normal", &"pressed", &"focus"]:
			swatch.add_theme_stylebox_override(state, style)
		swatch.add_theme_stylebox_override(&"hover", hover)
		swatch.pressed.connect(_on_hair_swatch_pressed.bind(color))
		_hair_swatches.add_child(swatch)


func _build_body_shape_sliders() -> void:
	for definition in shape_key_set.get_by_category(ShapeKeyDefinition.Category.BODY):
		var label := Label.new()
		label.text = definition.display_name
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		_body_shape_list.add_child(label)
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value_changed.connect(_on_body_shape_slider_changed.bind(definition.key))
		_body_shape_list.add_child(slider)
		_body_shape_sliders[definition.key] = slider
		_body_shape_labels[definition.key] = label


func _build_expression_buttons() -> void:
	_add_toggle_button(_expression_buttons, _expression_group, "Neutral", expression_selected, &"")
	for definition in shape_key_set.get_by_category(ShapeKeyDefinition.Category.EXPRESSION):
		_add_toggle_button(
				_expression_buttons, _expression_group, definition.display_name,
				expression_selected, definition.key
		)


## Adds a toggle button that emits [param selected] with [param value]. The
## first button added to a container starts pressed.
func _add_toggle_button(
		container: Container, group: ButtonGroup, text: String, selected: Signal, value: Variant
) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = container.get_child_count() == 0
	button.pressed.connect(selected.emit.bind(value))
	container.add_child(button)
	return button


func _build_slot_list() -> void:
	for slot: OutfitItem.Slot in OutfitItem.Slot.values():
		var items := catalog.get_items_for_slot(slot)
		if items.is_empty():
			continue

		var card := PanelContainer.new()
		card.theme_type_variation = CARD
		card.set_meta(FOCUS_META, SLOT_FOCUS.get(slot, default_focus))
		var content := VBoxContainer.new()
		card.add_child(content)

		var header := HBoxContainer.new()
		var label := Label.new()
		label.text = OutfitItem.Slot.find_key(slot).capitalize()
		label.theme_type_variation = &"SectionHeader"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(label)
		var tint_picker := ColorPickerButton.new()
		tint_picker.custom_minimum_size = SWATCH_SIZE
		tint_picker.edit_alpha = false
		tint_picker.disabled = true
		tint_picker.tooltip_text = "Item color"
		tint_picker.color_changed.connect(_on_tint_picker_changed.bind(slot))
		header.add_child(tint_picker)
		_tint_pickers[slot] = tint_picker
		content.add_child(header)

		var buttons := HFlowContainer.new()
		var group := ButtonGroup.new()
		_clear_buttons[slot] = _add_toggle_button(buttons, group, "None", slot_cleared, slot)
		for item in items:
			_item_buttons[item] = _add_toggle_button(
					buttons, group, item.display_name, item_selected, item
			)
		content.add_child(buttons)
		_slot_list.add_child(card)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_skin_slider_changed() -> void:
	skin_tone_changed.emit(_skin_tone_slider.value, _undertone_slider.value)


func _on_body_shape_slider_changed(value: float, key: StringName) -> void:
	body_shape_changed.emit(key, value)


func _on_hair_swatch_pressed(color: Color) -> void:
	_hair_color_picker.color = color
	hair_color_changed.emit(color)


func _on_tint_picker_changed(color: Color, slot: OutfitItem.Slot) -> void:
	item_tint_changed.emit(slot, color)
