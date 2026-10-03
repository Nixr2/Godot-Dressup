class_name ArmPose
extends Resource
## An arm layer played on top of the full-body idle, e.g. "hand on hip".
##
## Each side names the animation that drives that arm; only the arm's bones
## are taken from it, the rest of the body keeps playing the idle. Leave a
## side empty to keep the idle's own arm motion. One animation can drive both
## sides (e.g. "covering self").

@export var id: StringName
@export var display_name: String
@export var left_arm_animation: StringName
@export var right_arm_animation: StringName
