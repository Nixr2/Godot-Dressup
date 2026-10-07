class_name StageHud
extends Control
## Back button plus live tuning for walk and jog speed and stride matching,
## and time-of-day controls on stages with a [DayNightCycle].

## Emitted when the back button is pressed.
signal back_pressed
## Emitted when the move speed slider changes, in m/s.
signal move_speed_changed(speed: float)
## Emitted when the jog speed slider changes, in m/s.
signal jog_speed_changed(speed: float)
## Emitted when the walk playback slider changes.
signal walk_playback_multiplier_changed(multiplier: float)
## Emitted when the time of day slider is dragged, in hours.
signal time_of_day_changed(hours: float)
## Emitted when the pause time toggle changes.
signal time_paused_toggled(paused: bool)

@onready var _back_button: Button = %BackButton
@onready var _move_speed_slider: HSlider = %MoveSpeedSlider
@onready var _move_speed_value: Label = %MoveSpeedValue
@onready var _jog_speed_slider: HSlider = %JogSpeedSlider
@onready var _jog_speed_value: Label = %JogSpeedValue
@onready var _jog_speed_row: HBoxContainer = %JogSpeedRow
@onready var _playback_slider: HSlider = %PlaybackSlider
@onready var _playback_value: Label = %PlaybackValue
@onready var _stride_label: Label = %StrideLabel
@onready var _time_controls: VBoxContainer = %TimeControls
@onready var _time_value: Label = %TimeValue
@onready var _time_slider: HSlider = %TimeSlider
@onready var _pause_toggle: Button = %PauseToggle


func _ready() -> void:
	_back_button.pressed.connect(back_pressed.emit)
	_move_speed_slider.value_changed.connect(_on_move_speed_changed)
	_jog_speed_slider.value_changed.connect(_on_jog_speed_changed)
	_playback_slider.value_changed.connect(_on_playback_changed)
	_time_slider.value_changed.connect(_on_time_slider_changed)
	_pause_toggle.toggled.connect(time_paused_toggled.emit)


## Shows the current tuning values without emitting change signals.
## [param jog_stride_speed] = 0 hides the jog slider.
func set_values(
		move_speed: float,
		jog_speed: float,
		playback_multiplier: float,
		stride_speed: float,
		jog_stride_speed: float,
) -> void:
	_move_speed_slider.set_value_no_signal(move_speed)
	_move_speed_value.text = "%.2f m/s" % move_speed
	_jog_speed_slider.set_value_no_signal(jog_speed)
	_jog_speed_value.text = "%.2f m/s" % jog_speed
	_playback_slider.set_value_no_signal(playback_multiplier)
	_playback_value.text = "%.2fx" % playback_multiplier
	var has_jog := jog_stride_speed > 0.0
	_jog_speed_row.visible = has_jog
	_jog_speed_slider.visible = has_jog
	_stride_label.text = "Natural stride speed: walk %.2f m/s" % stride_speed
	if has_jog:
		_stride_label.text += ", jog %.2f m/s" % jog_stride_speed


## Shows the time-of-day controls with the cycle's current state.
func show_time_controls(hours: float, paused: bool) -> void:
	_time_controls.visible = true
	_pause_toggle.set_pressed_no_signal(paused)
	show_time(hours)


## Shows the current time of day without emitting change signals.
func show_time(hours: float) -> void:
	_time_slider.set_value_no_signal(hours)
	_time_value.text = _format_time(hours)


func _format_time(hours: float) -> String:
	var minutes := floori(hours * 60.0) % (24 * 60)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _on_time_slider_changed(value: float) -> void:
	_time_value.text = _format_time(value)
	time_of_day_changed.emit(value)


func _on_move_speed_changed(value: float) -> void:
	_move_speed_value.text = "%.2f m/s" % value
	move_speed_changed.emit(value)


func _on_jog_speed_changed(value: float) -> void:
	_jog_speed_value.text = "%.2f m/s" % value
	jog_speed_changed.emit(value)


func _on_playback_changed(value: float) -> void:
	_playback_value.text = "%.2fx" % value
	walk_playback_multiplier_changed.emit(value)
