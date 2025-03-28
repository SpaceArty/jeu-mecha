extends CharacterBody3D

@export var speed: float = 5.0
@export var jump_force: float = 5 
@export var gravity: float = 9.8
@export var sensitivity: float = 0.002

@export var stamina: float = 100.0  # Max stamina
@export var stamina_regen_rate: float = 5.0  # Stamina regenerates per second
@export var jump_stamina_cost: float = 20.0  # Stamina cost per jump

@onready var stamina_bar = $"../Control/StaminaBar"  # Move up to World, then access Control
@onready var head: Node3D = $Head
@onready var first_person_camera: Camera3D = %CameraFPS
@onready var third_person_camera: Camera3D = %CameraTPS
@onready var spring_arm: SpringArm3D = %SpringArmTPS
@onready var camera_pivot: Node3D = %CameraPivotTPS
@onready var visual = %Gundam

var is_third_person = false
var velocity_y: float = 0.0  # Gravity
var camera_rotation_x = 0.0  # Vertical rotation
var camera_rotation_y = 0.0  # Horizontal rotation

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_camera_mode()
	visual.position = Vector3(0, -1, 0)  # Adjust model position
	print("Stamina Bar:", stamina_bar)  # Debugging

func _unhandled_input(event):
	# Mouse look
	if event is InputEventMouseMotion:
		if is_third_person:
			# Rotate horizontally (left/right) - affects only camera_pivot
			camera_rotation_y -= event.relative.x * sensitivity
			camera_pivot.rotation.y = camera_rotation_y  # Only rotate around Y-axis

			# Rotate vertically (up/down) - affects only spring_arm
			camera_rotation_x -= event.relative.y * sensitivity
			camera_rotation_x = clamp(camera_rotation_x, deg_to_rad(-45), deg_to_rad(45))  # Limit vertical tilt
			spring_arm.rotation.x = camera_rotation_x
		else:
			# First-person: rotate whole character and head
			rotate_y(-event.relative.x * sensitivity)
			first_person_camera.rotate_x(-event.relative.y * sensitivity)
			first_person_camera.rotation.x = clamp(first_person_camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Toggle between first-person and third-person
	if event.is_action_pressed("toggle_camera"):
		is_third_person = !is_third_person
		update_camera_mode()

func update_camera_mode():
	if is_third_person:
		first_person_camera.current = false
		third_person_camera.current = true
	else:
		first_person_camera.current = true
		third_person_camera.current = false

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity_y -= gravity * delta  # Gravity is applied when not on the floor
	else:
		if velocity_y < 0:  # Only reset velocity_y when falling
			velocity_y = 0.0

	stamina = min(stamina + stamina_regen_rate * delta, 100.0) # Stamina regen
	stamina_bar.value = stamina  # Update UI to match stamina value

	var input_dir = Vector3.ZERO
	var move_forward: Vector3
	var move_right: Vector3

	# Use camera direction in third-person mode
	if is_third_person:
		move_forward = -camera_pivot.global_transform.basis.z
		move_right = camera_pivot.global_transform.basis.x
	else:
		move_forward = -global_transform.basis.z
		move_right = global_transform.basis.x

	if Input.is_action_pressed("move_forward"):
		input_dir += move_forward
	if Input.is_action_pressed("move_backward"):
		input_dir -= move_forward
	if Input.is_action_pressed("move_left"):
		input_dir -= move_right
	if Input.is_action_pressed("move_right"):
		input_dir += move_right

	# Normalize input direction and apply speed
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized() * speed
		# Rotate model towards movement direction
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-input_dir.x, -input_dir.z), delta * 10)

	# Apply movement
	velocity.x = input_dir.x
	velocity.z = input_dir.z
	velocity.y = velocity_y  # Vertical movement including gravity

	# Jump logic with stamina check
	if Input.is_action_just_pressed("jump") and is_on_floor() and stamina >= jump_stamina_cost:
		velocity_y = jump_force  # Apply upward velocity when jumping
		stamina -= jump_stamina_cost  # Reduce stamina

	# Move the character and apply sliding
	move_and_slide()

func _input(event):
	# Release mouse capture on ESC
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
