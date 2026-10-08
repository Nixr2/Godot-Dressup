class_name WalkableStage
extends Node3D
## A stage the customized character can walk around in.
##
## Expects a [Player] named "Player" and a [StageHud] named
## "StageHud" as children; the world itself is anything else. An optional
## [DayNightCycle] named "DayNightCycle" gets time controls in the HUD.

## Emitted when the player asks to return to character creation.
signal exit_requested

@onready var player: Player = $Player
@onready var _hud: StageHud = $StageHud
@onready var _day_night: DayNightCycle = get_node_or_null(^"DayNightCycle")


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


## Dresses the player's character. Call before adding the stage to the tree,
## so the character is dressed once, as it enters, instead of being redressed.
func setup(appearance: CharacterAppearance) -> void:
	var mannequin: Mannequin = get_node(^"Player/Mannequin")
	mannequin.initial_appearance = appearance


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
