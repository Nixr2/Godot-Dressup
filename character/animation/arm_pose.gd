class_name ArmPose
extends Resource
## An arm layer played on top of the full-body idle, e.g. "hand on hip".
##
## Each side names the animation that drives that arm; only the arm's bones
## are taken from it, the rest of the body keeps playing the idle. Leave a
## side empty to keep the idle's own arm motion. One animation can drive both
## sides (e.g. "covering self"). A pose that doesn't [member loop] plays once
## and holds its last frame, e.g. taking out a phone, and can put a
## [member prop] in the character's hand.

@export var id: StringName
@export var display_name: String
@export var left_arm_animation: StringName
@export var right_arm_animation: StringName
## Off: play once and hold the last frame.
@export var loop := true
## Optional prop held while the pose plays, timed to it.
@export var prop: HeldProp
