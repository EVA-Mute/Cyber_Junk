extends Camera3D

@onready var debug_ui: Label = $UI_root/debug_ui
@onready var head: Node3D = $"../player/head"

@export var rotation_smoothing: float = 30.0
@export var position_smoothing: float = 30.0
var target: Transform3D

func _ready():
	pass
	
func _process(delta):
	target = head.global_transform
	var fps: = Engine.get_frames_per_second()
	debug_ui.text = "FPS: " + str(fps)
	global_transform.origin = global_transform.origin.lerp(target.origin, delta * position_smoothing)
	
	var current_basis = global_transform.basis
	var target_basis = target.basis.orthonormalized()
	global_transform.basis = current_basis.slerp(target_basis, delta * rotation_smoothing)
