extends CharacterBody3D # 🍝

enum player_state {PAUSED, GROUNDED, WALKING, SPRINTING, AIR, CROUCHED, SLIDE}
var current_state: player_state = player_state.AIR
var last_state: player_state
var sprint_button: bool = false
var jump_button: bool = false
var crouch_button: bool = false
var can_slide: bool = true
var slide_jump: bool = false
var is_jumping: bool = false
var is_grounded: bool = false
var is_paused: bool = false
var speed: float = 0.0
var min_speed_for_slide: float = 7.0

@export var aim_sens: = Vector2(0.2, 0.2)
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 3.75
@export var air_control: float = 0.3
@export var jump_velocity: float = 10.0
@export var ground_acceleration: float = 10.0
@export var sprint_acceleration: float = 6.0
@export var max_air_speed: float = 20.0
@export var air_drag: float = 10.0

@onready var head: Node3D =$head # super dope way to track camera, automatically smoothes animations that affect camera position
@onready var animator: AnimationPlayer = $AnimationPlayer

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var air_velocity: Vector2 = Vector2.ZERO

var input_vector: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

#func check_common_transitions():
	#if is_paused:
		#change_state(player_state.PAUSED)
	#elif !is_on_floor():
		#change_state(player_state.AIR)
	#elif jump_button && is_grounded && current_state != player_state.SLIDE:
		#is_jumping = true
		#animator.play("RESET")
		#change_state(player_state.AIR)
	#elif jump_button && is_grounded && current_state == player_state.SLIDE:
		#slide_jump = true
		#change_state(player_state.AIR)
	#elif crouch_button && current_state != player_state.SLIDE && current_state != player_state.AIR:
		#if can_slide:
			#change_state(player_state.SLIDE)
		#elif !can_slide:
			#change_state(player_state.CROUCHED)
	#elif input_vector == Vector2.ZERO && current_state != player_state.GROUNDED:
		#change_state(player_state.GROUNDED)
	#elif input_vector != Vector2.ZERO:
		#current_state = player_state.SPRINTING if sprint_button else player_state.WALKING
func check_common_transitions():
	if is_paused:
		current_state = player_state.PAUSED
	elif !is_on_floor():
		current_state = player_state.AIR
	elif jump_button && current_state == player_state.SLIDE:
		slide_jump = true
		animator.play("RESET")
		current_state = player_state.AIR
	elif jump_button && is_grounded && current_state != player_state.SLIDE:
		is_jumping = true
		animator.play("RESET")
		current_state = player_state.AIR
	elif crouch_button && current_state == player_state.SPRINTING:
		current_state = player_state.SLIDE
	elif crouch_button && current_state != player_state.SLIDE:
		current_state = player_state.CROUCHED
	elif input_vector == Vector2.ZERO && current_state != player_state.GROUNDED:
		current_state = player_state.GROUNDED
	elif input_vector != Vector2.ZERO && !crouch_button:
		current_state = player_state.SPRINTING if sprint_button else player_state.WALKING



func _physics_process(delta: float) -> void:
	if is_paused:
		return
	else: # open gate to continue _physics_process aka ALL of the func
		speed = velocity.length()
		
		physics_input() # movement input, seperate function for legibility only
		check_common_transitions()
		
		match current_state: # state machine
			player_state.PAUSED:handle_pause_state()
			player_state.GROUNDED:handle_ground_state(delta)
			player_state.WALKING:handle_walking_state(delta)
			player_state.SPRINTING:handle_sprint_state(delta)
			player_state.AIR:handle_air_state(delta)
			player_state.CROUCHED:handle_crouch_state(delta)
			player_state.SLIDE:handle_slide_state(delta)
		#print(current_state)

func physics_input() -> void:
	# ONLY FOR LEGIBILITY, can be placed where phisics_input is called and get rid of this overhead
	input_vector = Input.get_vector("left", "right", "up", "down")
	direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	sprint_button = Input.is_action_pressed("sprint")
	jump_button = Input.is_action_just_pressed("jump")
	crouch_button = Input.is_action_pressed("crouch")
	is_paused = Input.is_action_just_pressed("pause")

func _unhandled_input(event: InputEvent) -> void: # mouse input, handled here to allow for UI when mouse isn't captured
	if event is InputEventMouseMotion && current_state != player_state.PAUSED:
		rotate_y(-event.relative.x * aim_sens.x * 0.01)
		head.rotate_x(-event.relative.y * aim_sens.y * 0.01)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	elif event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Unpause for now
		is_paused = false

func change_state(new_state: player_state) -> void:
	if current_state == new_state:
		return
	last_state = current_state
	current_state = new_state

#func update_animation():
	#match  current_state:
		#player_state.CROUCHED:
			#if !animator.is_playing():
				#animator.play("Crouch")
		#player_state.SLIDE:
			#animator.play("Slide")
			#

func handle_pause_state() -> void:
	is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func handle_ground_state(delta: float) -> void: # for idle, and lerping velocity to zero
	is_grounded = true
	if velocity != Vector3.ZERO: # slow down lerp to simulate inertia after releasing movement on ground
		velocity.x = lerp(velocity.x, 0.0, delta * 15.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 15.0)
	move_and_slide()

func handle_walking_state(delta) -> void:
	var target_velocity = direction * walk_speed
	velocity.x = lerp(velocity.x, target_velocity.x, delta * ground_acceleration)
	velocity.z = lerp(velocity.z, target_velocity.z, delta * ground_acceleration)
	move_and_slide()

func handle_sprint_state(delta: float) -> void:
	var target_velocity = direction * sprint_speed
	velocity.x = lerp(velocity.x, target_velocity.x, delta * sprint_acceleration)
	velocity.z = lerp(velocity.z, target_velocity.z, delta * sprint_acceleration)
	move_and_slide()

func handle_air_state(delta: float) -> void:
	is_grounded = false
	velocity.y -= gravity * delta
	if is_jumping:
		velocity.y = jump_velocity
		is_jumping = false
	elif slide_jump:
		print("slide jump!")
		slide_jump = false
	elif velocity.y != 0.0:
		var max = direction * -max_air_speed
		if abs(velocity.x) >= max_air_speed:
			velocity.x = lerp(velocity.x, max.x, delta * 0.3)
		if abs(velocity.z) >= max_air_speed:
			velocity.z = lerp(velocity.z, max.z, delta * 0.3)
		var target_air_velocity = direction * max_air_speed
		velocity.x = lerp(velocity.x, target_air_velocity.x, delta * air_control)
		velocity.z = lerp(velocity.z, target_air_velocity.z, delta * air_control)
	move_and_slide()

func handle_crouch_state(delta: float) -> void:
		var target_velocity = direction * crouch_speed
		velocity.x = lerp(velocity.x, target_velocity.x, delta * ground_acceleration)
		velocity.z = lerp(velocity.z, target_velocity.z, delta * ground_acceleration)
		move_and_slide()

@export var slow_slide_factor: float = 1.4
#func handle_slide_state(delta) -> void:
	#velocity = velocity.lerp(Vector3.ZERO, delta * slow_slide_factor) # lerp to stop
	#if can_slide:
		#animator.play("Slide")
		#if speed <= 20.0:
			#velocity = velocity * 2.0
		#can_slide = false
	#move_and_slide()
#const MIN_SLIDE_ANGLE = 5.0 # degrees, to ignore small bumps
#const MAX_SLIDE_SPEED = 20.0 # or whatever max you want

func handle_slide_state(delta):
	#if is_on_floor():
		#var floor_normal = get_floor_normal()
		#var slope_angle = rad_to_deg(acos(floor_normal.dot(Vector3.UP)))
		#print(slope_angle)
		#if slope_angle > MIN_SLIDE_ANGLE:
			#var gravity_dir = Vector3.DOWN
			#var slope_dir = (gravity_dir - floor_normal * gravity_dir.dot(floor_normal)).normalized()
			#print(slope_dir)
#
			#var slide_acceleration = gravity * delta * slope_dir
			#velocity += slide_acceleration
			#velocity = velocity.normalized() * min(velocity.length(), MAX_SLIDE_SPEED)
		#else:
			#velocity = velocity.lerp(Vector3.ZERO, delta * slow_slide_factor)
	pass
