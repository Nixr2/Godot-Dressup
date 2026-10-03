class_name DressingRoom
extends Node3D
## 3D stage that displays the character being customized. The character's
## head and eyes can follow the camera.

@onready var mannequin: Mannequin = $Mannequin
@onready var camera_rig: OrbitCamera = $CameraRig


func _ready() -> void:
	mannequin.look_at.set_target(camera_rig.get_camera())
