class_name StageHud
extends Control
## Back button plus live tuning for walk speed and stride matching.

## Emitted when the back button is pressed.
signal back_pressed
## Emitted when the move speed slider changes, in m/s.
signal move_speed_changed(speed: float)
## Emitted when the walk playback slider changes.
signal walk_playback_multiplier_changed(multiplier: float)

@onready var _back_button: Button = %BackButton
@onready var _move_speed_slider: HSlider = %MoveSpeedSlider
@onready var _move_speed_value: Label = %MoveSpeedValue
@onready var _playback_slider: HSlider = %PlaybackSlider
@onready var _playback_value: Label = %PlaybackValue
@onready var _stride_label: Label = %StrideLabel


func _ready() -> void:
	_back_button.pressed.connect(back_pressed.emit)
	_move_speed_slider.value_changed.connect(_on_move_speed_changed)
	_playback_slider.value_changed.connect(_on_playback_changed)


## Shows the current tuning values without emitting change signals.
func set_values(move_speed: float, playback_multiplier: float, stride_speed: float) -> void:
	_move_speed_slider.set_value_no_signal(move_speed)
	_move_speed_value.text = "%.2f m/s" % move_speed
	_playback_slider.set_value_no_signal(playback_multiplier)
	_playback_value.text = "%.2fx" % playback_multiplier
	_stride_label.text = "Walk's natural stride speed: %.2f m/s" % stride_speed


func _on_move_speed_changed(value: float) -> void:
	_move_speed_value.text = "%.2f m/s" % value
	move_speed_changed.emit(value)


func _on_playback_changed(value: float) -> void:
	_playback_value.text = "%.2fx" % value
	walk_playback_multiplier_changed.emit(value)
