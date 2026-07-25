extends CharacterBody3D

#-----------------variable----------------------
@export var SPEED = 5.0
@export var RUN_SPEED = 7.0
@export var JUMP_VELOCITY = 4.5
@export var MOUSE_SENSIVITY = 0.1
@export var GAMEPAD_SENSIVITY_Y = 2.0
@export var GAMEPAD_SENSIVITY_X = 4.0
@export var CAN_DOUBEL_JUMP = true

#-----------------variable(hide)----------------------
var mouse_x = 0
var mouse_y = 0
var can_jump = true
var double_jump = 2

#-----------------variable(hide)----------------------
@onready var head = $Camera3D
@onready var body = self


func _ready() -> void:
	_mouse_masuk_game()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_mouse_keluar_game()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_movement(delta)
		_camera_input()
		_gamepad_input()


func _mouse_masuk_game():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _mouse_keluar_game():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _camera_input():
	head.rotation_degrees.x = mouse_y
	body.rotation_degrees.y = mouse_x

func _gamepad_input():
	var gamepad_y = Input.get_joy_axis(0 , JOY_AXIS_RIGHT_Y) 
	var gamepad_x = Input.get_joy_axis(0 , JOY_AXIS_RIGHT_X)
	mouse_x += - gamepad_x * GAMEPAD_SENSIVITY_X
	mouse_y += - gamepad_y * GAMEPAD_SENSIVITY_Y

func _movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif is_on_floor() and CAN_DOUBEL_JUMP:
		double_jump = 2
	elif not CAN_DOUBEL_JUMP:
		double_jump = 1

	# Handle jump.
	var gamepad_jump = Input.is_joy_button_pressed(0 , JOY_BUTTON_A) 
	
	if Input.is_action_just_pressed("ui_accept") and double_jump > 0:
		velocity.y = JUMP_VELOCITY
		double_jump -= 1
	if gamepad_jump and not can_jump  and double_jump > 0 :
		velocity.y = JUMP_VELOCITY
		double_jump -= 1
		
	can_jump = gamepad_jump

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0 , JOY_BUTTON_LEFT_STICK):
		SPEED = RUN_SPEED
	else:
		SPEED = 5.0
		
		
	move_and_slide()

func _input(event: InputEvent) -> void:
#-----------------variable(hide)----------------------
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			mouse_x += - event.relative.x * MOUSE_SENSIVITY
			mouse_y += - event.relative.y * MOUSE_SENSIVITY
			mouse_y = clamp(mouse_y , -90 , 90)
