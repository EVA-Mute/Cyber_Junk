extends Node3D

@onready var body: Node3D = $"../player/body"

const position_smoothing: float = 30.0
const rotation_smoothing: float = 30.0

var target: Transform3D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	target = body.global_transform
	global_transform.origin = global_transform.origin.lerp(target.origin, delta * position_smoothing)
	
	var current_basis = global_transform.basis
	var target_basis = target.basis.orthonormalized()
	global_transform.basis = current_basis.slerp(target_basis, delta * rotation_smoothing)
