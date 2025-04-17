extends CharacterBody3D

enum player_state {PAUSED, GROUNDED, WALKING, SPRINTING, AIR, CROUCHED, SLIDE, SLIDE_JUMP}
var current_state: player_state = player_state.AIR
var last_state: player_state
var sprint_button: bool = false
var jump_button: bool = false
var crouch_button: bool = false
var can_slide: bool = true
var can_dash: bool = false
var slide_jump: bool = false
var is_sliding: bool = false
var is_jumping: bool = false
var is_grounded: bool = false
var is_paused: bool = false
var dash: bool = false
var speed: float = 0.0

@export var aim_sens: = Vector2(0.2, 0.2)
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var crouch_speed: float = 3.75
@export var air_control: float = 0.3
@export var jump_velocity: float = 10.0
@export var ground_acceleration: float = 10.0
@export var sprint_acceleration: float = 6.0
@export var max_air_speed: float = 20.0
@export var max_slide_speed: float = 20.0
@export var slide_accel: float = 2.0
@export var fall_acceleration: float = 2.0

@onready var head: Node3D =$head # super dope way to track camera, automatically smoothes animations that affect camera position
@onready var animator: AnimationPlayer = $AnimationPlayer
@onready var cam = get_node("/root/main/scene_camera")
@onready var debug_cam = get_node("/root/main/debug_camera")
@onready var stamina: ProgressBar = $"../scene_camera/UI_root/stamina_bar"
@onready var stamina_time: Timer = $stamina_timer
@onready var slide_cast: RayCast3D = $RayCast3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var air_velocity: Vector2 = Vector2.ZERO
var input_vector: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cam.current = true
	debug_cam.current = false
	var spawn: Node3D = $"../spawn_point"
	position = Vector3(spawn.position.x, spawn.position.y + 3, spawn.position.z)

func check_common_transitions():
	if is_paused:
		change_state(player_state.PAUSED)
		print("pause trigger")
		return
	elif !is_on_floor():
		change_state(player_state.AIR)
		return
	# jump from slide
	elif jump_button && current_state == player_state.SLIDE:
		slide_jump = true
		change_state(player_state.AIR)
	# jump from idle, walking, or sprinting
	elif jump_button && current_state in [player_state.GROUNDED, player_state.WALKING, player_state.SPRINTING]:
		is_jumping = true
		change_state(player_state.AIR)
	# SLIDING — crouch + sprint condition (can_slide flag set by sprint)
	elif crouch_button && speed > crouch_speed + 1.0:
		change_state(player_state.SLIDE)
	elif crouch_button:
		change_state(player_state.CROUCHED)
	elif input_vector != Vector2.ZERO:
		if sprint_button && !crouch_button:
			change_state(player_state.SPRINTING)
		elif !crouch_button:
			change_state(player_state.WALKING)
	# FALLBACK IDLE
	elif input_vector == Vector2.ZERO and current_state != player_state.GROUNDED:
		change_state(player_state.GROUNDED)

func _physics_process(delta: float) -> void:
	if is_paused:
		return
	else: # open gate to continue _physics_process aka ALL of the func
		var hori_speed = Vector3(velocity.x, 0.0,velocity.z).length()
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
		
		handle_dash()
		move_and_slide()

func physics_input() -> void:
	input_vector = Input.get_vector("left", "right", "up", "down")
	direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	sprint_button = Input.is_action_pressed("sprint")
	jump_button = Input.is_action_just_pressed("jump")
	crouch_button = Input.is_action_pressed("crouch")
	dash = Input.is_action_just_pressed("dash")
	is_paused = Input.is_action_just_pressed("pause")
	if Input.is_action_just_pressed("debug"):
		if cam.current == true:
			cam.current = false
			debug_cam.current = true
		elif cam.current == false:
			cam.current = true
			debug_cam.current = false
		
	if Input.is_action_just_pressed("left click"):
		shoot_hitscan()

func _unhandled_input(event: InputEvent) -> void: # mouse input, handled here to allow for UI when mouse isn't captured
	if event is InputEventMouseMotion && current_state != player_state.PAUSED:
		rotate_y(-event.relative.x * aim_sens.x * 0.01)
		head.rotate_x(-event.relative.y * aim_sens.y * 0.01)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	elif event is InputEventMouseButton:
		if is_paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Unpause for now
			is_paused = false
		else: pass

func shoot_hitscan() -> void:
	var from = cam.global_position
	var to = from + cam.global_transform.basis.z * -1000.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.exclude = [self]
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		print("hit: ", result.collider.name, " at: ", result.position)
	else:
		print("missed")

func handle_dash() -> void:
	if dash && input_vector && can_dash && current_state != player_state.SLIDE:
		var dash_velocity = direction
		velocity = dash_velocity * 40.0
		stamina.value = 0.0
		stamina_time.start()
	else: pass

func change_state(new_state: player_state) -> void:
	if current_state == new_state:
		return
	last_state = current_state
	current_state = new_state
	
func handle_pause_state() -> void:
	is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func handle_ground_state(delta: float) -> void: # for idle, and lerping velocity to zero
	is_grounded = true
	if velocity != Vector3.ZERO: # slow down lerp to simulate inertia after releasing movement on ground
		velocity.x = lerp(velocity.x, 0.0, delta * 15.0)
		velocity.z = lerp(velocity.z, 0.0, delta * 15.0)

func handle_walking_state(delta) -> void:
	is_grounded = true
	var target_velocity = direction * walk_speed
	velocity.x = lerp(velocity.x, target_velocity.x, delta * ground_acceleration)
	velocity.z = lerp(velocity.z, target_velocity.z, delta * ground_acceleration)

func handle_sprint_state(delta: float) -> void:
	is_grounded = true
	var target_velocity = direction * sprint_speed
	velocity.x = lerp(velocity.x, target_velocity.x, delta * sprint_acceleration)
	velocity.z = lerp(velocity.z, target_velocity.z, delta * sprint_acceleration)

func handle_crouch_state(delta: float) -> void:
		var target_velocity = direction * crouch_speed
		velocity.x = lerp(velocity.x, target_velocity.x, delta * ground_acceleration)
		velocity.z = lerp(velocity.z, target_velocity.z, delta * ground_acceleration)

func handle_air_state(delta: float) -> void:
	is_grounded = false
	if is_jumping:
		velocity.y = jump_velocity
		is_jumping = false
	elif slide_jump:
		velocity.y = jump_velocity
		slide_jump = false
	elif velocity.y != 0.0:
		var target_air_velocity = direction * max_air_speed
		velocity.x = lerp(velocity.x, target_air_velocity.x, delta * air_control)
		velocity.z = lerp(velocity.z, target_air_velocity.z, delta * air_control)
	var pre_velo = velocity.y
	pre_velo -= gravity * fall_acceleration * delta
	velocity.y = clampf(pre_velo, -max_air_speed * 2.0, max_air_speed * 2.0)

func get_slope_direction() -> Vector3:
	if is_on_floor():
		var floor_normal = get_floor_normal()
		var slope = Vector3(floor_normal.x, 0.0, floor_normal.z)
		return slope
	return Vector3.ZERO

@export var friction: float = 10.0
func handle_slide_state(delta):
	var slide_velocity: Vector3 = Vector3.ZERO
	can_slide = false
	slide_velocity = velocity
	var slope_direction = get_slope_direction()
	if slope_direction.length() > 0.01:
		slide_cast.enabled = true
		slope_direction = slope_direction.normalized()
		var target_velocity = slope_direction * max_slide_speed
		slide_velocity = slide_velocity.lerp(target_velocity, slide_accel * delta)
		if slide_cast.is_colliding():
			velocity.y = -max(abs(slide_velocity.x), abs(slide_velocity.z))
		else: velocity.y = 0.0
	else:
		slide_cast.enabled = false
		slide_velocity = slide_velocity.move_toward(Vector3.ZERO, friction * delta)
	print(slope_direction)
	velocity.x = slide_velocity.x
	velocity.z = slide_velocity.z

func _on_stamina_timer_timeout() -> void:
	if stamina.value < stamina.max_value:
		can_dash = false
		stamina.value += 0.1
	else: 
		stamina_time.stop()
		can_dash = true
