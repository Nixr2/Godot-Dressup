class_name WalkableStage
extends Node3D
## A stage the customized character can walk around in.
##
## Expects a [Player] named "Player" and a [StageHud] named
## "StageHud" as children; the world itself is anything else.

## Emitted when the player asks to return to character creation.
signal exit_requested

@onready var player: Player = $Player
@onready var _hud: StageHud = $StageHud


func _ready() -> void:
	var animator := player.mannequin.animator
	_hud.back_pressed.connect(exit_requested.emit)
	_hud.move_speed_changed.connect(_on_move_speed_changed)
	_hud.walk_playback_multiplier_changed.connect(_on_walk_playback_multiplier_changed)
	_hud.set_values(
			player.get_effective_move_speed(),
			animator.walk_playback_multiplier,
			animator.stride_speed
	)


## Dresses the player's character. Call after adding the stage to the tree.
func setup(appearance: CharacterAppearance) -> void:
	player.mannequin.apply_appearance(appearance)


func _on_move_speed_changed(speed: float) -> void:
	player.move_speed = speed


func _on_walk_playback_multiplier_changed(multiplier: float) -> void:
	player.mannequin.animator.walk_playback_multiplier = multiplier
