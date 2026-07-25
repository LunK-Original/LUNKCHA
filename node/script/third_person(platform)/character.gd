## A first-person / third-person character controller with camera controls,
## movement, sprinting, walking, and jumping.
##
## REQUIRED SCENE STRUCTURE (all as unique names, e.g. right-click node > "Access as Unique Name"):
##   %CameraPivot (Node3D)
##     └── %SpringArm3D (SpringArm3D)
##           └── %Camera3D (Camera3D)
##   %Character (Node3D) — the visible mesh/model, hidden in first-person mode
##
## If any required node is missing, this script will print a clear error
## instead of crashing at runtime.
class_name FirstPersonCharacterController
extends CharacterBody3D

enum CameraMode {
	FIRST_PERSON,
	THIRD_PERSON
}

## Node References
## -----------------------------------------------------------------------------
## These nodes must exist in the scene tree for the controller to work properly.
## Fetched safely in _ready() with validation instead of directly in @onready,
## so missing nodes produce a clear error rather than a silent crash.

var camera_pivot: Node3D
var camera_3d: Camera3D
var spring_arm: SpringArm3D
var character: Node3D

## Movement Settings
## -----------------------------------------------------------------------------
## Configure the character's movement speed and jump behavior.

@export_group("Movement")
@export_range(0.1, 20.0, 0.1, "or_greater") var speed: float = 5.0
## Speed when walking. Should be lower than normal speed.
@export_range(0.1, 10.0, 0.1, "or_greater") var walk_speed: float = 2.5
## Speed multiplier when sprinting. Should be higher than normal speed.
@export_range(0.1, 30.0, 0.1, "or_greater") var sprint_speed: float = 8.0
## Vertical velocity applied when jumping.
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 4.5
@export var can_walk: bool = true

## Camera Settings
## -----------------------------------------------------------------------------
## Adjust camera sensitivity and rotation limits.

@export_group("Camera")
## Mouse sensitivity for camera rotation. Higher values = faster rotation.
@export_range(0.0, 1.0, 0.001) var mouse_sensitivity: float = 0.005
## Enable controller support for camera look.
@export var controller_support: bool = true
## Controller stick sensitivity for camera rotation.
@export_range(0.1, 10.0, 0.1) var controller_sensitivity: float = 2.0
## Maximum vertical camera tilt angle in radians (prevents over-rotation).
@export_range(0.0, 1.57, 0.01) var tilt_limit: float = deg_to_rad(75)
## Speed at which the character mesh rotates to face movement direction.
@export_range(0.1, 50.0, 0.1) var rotation_speed: float = 10.0
## Camera mode: FIRST_PERSON or THIRD_PERSON.
@export var camera_mode: CameraMode = CameraMode.THIRD_PERSON:
	set(value):
		camera_mode = value
		if is_node_ready():
			_update_camera_mode()
## Camera distance (SpringArm length) for third-person mode.
@export_range(0.0, 10.0, 0.1) var camera_distance: float = 3.5
## Speed at which the camera transitions between modes.
@export_range(1.0, 20.0, 0.1) var camera_transition_speed: float = 8.0
## Allow switching between camera modes with V key.
@export var allow_camera_mode_switch: bool = false
## Capture the mouse cursor automatically when the scene starts.
@export var capture_mouse_on_ready: bool = true

@export_group("Gamepad (raw input)")
## Which gamepad/joypad device index to read raw input from.
@export var joypad_device: int = 0
## Values below this are treated as 0 to ignore stick drift ("deadzone").
@export_range(0.0, 1.0, 0.01) var joy_deadzone: float = 0.2
## Right-stick axis used for horizontal look. Change if your controller maps differently.
@export var look_axis_x: JoyAxis = JOY_AXIS_RIGHT_X
## Right-stick axis used for vertical look. Change if your controller maps differently.
@export var look_axis_y: JoyAxis = JOY_AXIS_RIGHT_Y
## Gamepad button (R3 / right stick click) that switches camera mode.
@export var camera_switch_gamepad_button: JoyButton = JOY_BUTTON_RIGHT_STICK
## Gamepad button that triggers sprint (e.g. L3 / left stick click).
@export var sprint_gamepad_button: JoyButton = JOY_BUTTON_LEFT_STICK
## Gamepad button that triggers walk (e.g. L1 / left shoulder).
@export var walk_gamepad_button: JoyButton = JOY_BUTTON_LEFT_SHOULDER
## Gamepad button that triggers a jump (in addition to the "jump" input action).
@export var jump_gamepad_button: JoyButton = JOY_BUTTON_A

@export_group("Keyboard (raw input)")
## Physical key that switches camera mode.
@export var camera_switch_key: Key = KEY_C
## Physical key that triggers sprint.
@export var sprint_key: Key = KEY_SHIFT
## Physical key that triggers walk.
@export var walk_key: Key = KEY_CTRL

@export_group("Jumping")
## How many times the character can jump before touching the ground again.
## 1 = normal single jump, 2 = double jump, etc.
@export_range(1, 5, 1) var max_jumps: int = 2


var input_dir: Vector2 = Vector2.ZERO
var input_strength: float = 0.0
var direction: Vector3 = Vector3.ZERO
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

# Freeze the character. It may be useful when you want to pause the character.
var frozen: bool = false

var target_camera_distance: float = 3.5

## How many jumps have been used since the character last left the ground.
var jump_count: int = 0

## Tracks the previous frame's gamepad jump-button state so we can detect
## the moment it's *pressed* rather than triggering every frame it's held.
var _was_jump_button_pressed: bool = false

## Tracks the previous frame's gamepad camera-switch-button state so it
## toggles once per press instead of every frame it's held.
var _was_camera_switch_button_pressed: bool = false

## Set to false in _ready() if required nodes are missing, to prevent
## the controller from running with broken references.
var _is_properly_configured: bool = true



func _ready() -> void:
	if not _resolve_required_nodes():
		_is_properly_configured = false
		push_error("%s: disabled because required scene nodes were not found. See warnings above." % [name])
		set_physics_process(false)
		set_process_unhandled_input(false)
		return

	if capture_mouse_on_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	target_camera_distance = 0.0 if camera_mode == CameraMode.FIRST_PERSON else camera_distance
	spring_arm.spring_length = target_camera_distance
	character.visible = camera_mode == CameraMode.THIRD_PERSON


## Looks up all required child nodes and reports exactly which ones are
## missing, instead of letting the game crash with a vague null-reference error.
func _resolve_required_nodes() -> bool:
	var ok := true

	if has_node("%CameraPivot"):
		camera_pivot = get_node("%CameraPivot")
	else:
		push_error("%s: missing required unique-name node '%%CameraPivot' (Node3D)." % [name])
		ok = false

	if has_node("%Camera3D"):
		camera_3d = get_node("%Camera3D")
	else:
		push_error("%s: missing required unique-name node '%%Camera3D' (Camera3D)." % [name])
		ok = false

	if has_node("%SpringArm3D"):
		spring_arm = get_node("%SpringArm3D")
	else:
		push_error("%s: missing required unique-name node '%%SpringArm3D' (SpringArm3D). Give it a unique name instead of relying on the exact path 'CameraPivot/SpringArm3D'." % [name])
		ok = false

	if has_node("%Character"):
		character = get_node("%Character")
	elif has_node("character"):
		# Backwards-compatible fallback for older scenes using the plain path.
		character = get_node("character")
		push_warning("%s: using fallback path 'character' — consider giving this node the unique name '%%Character' for robustness." % [name])
	else:
		push_error("%s: missing required node 'character' (Node3D, the visible mesh)." % [name])
		ok = false

	return ok


func _physics_process(delta: float) -> void:
	if not _is_properly_configured:
		return

	_handle_gravity_and_jump(delta)
	_handle_camera_transition(delta)
	_handle_controller_camera(delta)
	_handle_gamepad_camera_switch()

	if frozen:
		_handle_frozen_movement()
		move_and_slide()
		return

	_handle_movement_input()
	if camera_mode == CameraMode.THIRD_PERSON:
		_handle_character_rotation(delta)
	_apply_movement()
	move_and_slide()


func _handle_frozen_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	input_dir = Vector2.ZERO
	is_sprinting = false
	is_walking = false


## Handles gravity application and jump mechanics, including double jump
## triggered by the "jump" input action or the gamepad's jump button.
func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		is_jumping = velocity.y > 0.0
	else:
		is_jumping = false
		# Refill jumps only once the character is actually back on the ground.
		jump_count = 0

	# Raw gamepad button read (not through InputMap), edge-detected manually
	# so it fires once per press instead of every physics frame it's held.
	var jump_button_down := Input.is_joy_button_pressed(joypad_device, jump_gamepad_button)
	var jump_button_just_pressed := jump_button_down and not _was_jump_button_pressed
	_was_jump_button_pressed = jump_button_down

	var jump_requested := Input.is_action_just_pressed("ui_accept") or jump_button_just_pressed

	if not frozen and jump_requested and jump_count < max_jumps:
		velocity.y = jump_velocity
		jump_count += 1
		is_jumping = true



## Processes movement input and calculates movement direction relative to camera.
func _handle_movement_input() -> void:
	input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_strength = minf(input_dir.length(), 1.0)

	var camera_basis := Transform3D(Basis(Vector3.UP, camera_pivot.rotation.y), Vector3.ZERO).basis
	direction = (camera_basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()


## Rotates the character mesh to face the movement direction smoothly.
func _handle_character_rotation(delta: float) -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		return
	character.rotation.y = lerp_angle(character.rotation.y, camera_pivot.rotation.y + PI, rotation_speed * delta)


## Handles controller stick input for camera rotation, reading the raw
## joystick axes directly via Input.get_joy_axis() instead of an InputMap
## action. A manual deadzone is applied since raw axes don't have one built in.
func _handle_controller_camera(delta: float) -> void:
	if not controller_support or frozen:
		return

	var look_x := Input.get_joy_axis(joypad_device, look_axis_x)
	var look_y := Input.get_joy_axis(joypad_device, look_axis_y)

	if absf(look_x) < joy_deadzone:
		look_x = 0.0
	if absf(look_y) < joy_deadzone:
		look_y = 0.0

	if look_x != 0.0 or look_y != 0.0:
		camera_pivot.rotation.y -= look_x * controller_sensitivity * delta
		camera_pivot.rotation.x += look_y * controller_sensitivity * delta
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)



## Handles smooth camera transition between modes.
func _handle_camera_transition(delta: float) -> void:
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_camera_distance, camera_transition_speed * delta)

	if character:
		if not is_zero_approx(camera_distance):
			var transition_progress := spring_arm.spring_length / camera_distance
			var visibility_threshold := 0.3
			character.visible = transition_progress > visibility_threshold
		else:
			character.visible = camera_mode == CameraMode.THIRD_PERSON


## Updates camera mode (sets target for smooth transition).
func _update_camera_mode() -> void:
	target_camera_distance = 0.0 if camera_mode == CameraMode.FIRST_PERSON else camera_distance


## Applies horizontal movement velocity based on input and sprint/walk state.
## Sprint and walk are read directly from a raw keyboard key OR a raw gamepad
## button (not through InputMap), so they work without configuring actions.
func _apply_movement() -> void:
	var is_moving := input_dir != Vector2.ZERO and is_on_floor()

	var sprint_input := Input.is_key_pressed(sprint_key) or Input.is_joy_button_pressed(joypad_device, sprint_gamepad_button)
	var walk_input := Input.is_key_pressed(walk_key) or Input.is_joy_button_pressed(joypad_device, walk_gamepad_button)

	is_sprinting = sprint_input and is_moving and not walk_input
	is_walking = walk_input and is_moving and not sprint_input and can_walk

	var current_speed: float
	if is_sprinting:
		current_speed = sprint_speed
	elif is_walking and can_walk:
		current_speed = walk_speed
	else:
		current_speed = speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * current_speed * input_strength
		velocity.z = direction.z * current_speed * input_strength
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)


## Handles mouse input for camera rotation with tilt limits, plus the raw
## keyboard camera-switch key (C).
func _unhandled_input(event: InputEvent) -> void:
	if frozen or not _is_properly_configured:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.physical_keycode == camera_switch_key and allow_camera_mode_switch:
			_toggle_camera_mode()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)
		camera_pivot.rotation.y += -event.relative.x * mouse_sensitivity


## Flips between FIRST_PERSON and THIRD_PERSON and applies the new target
## camera distance immediately.
func _toggle_camera_mode() -> void:
	camera_mode = CameraMode.THIRD_PERSON if camera_mode == CameraMode.FIRST_PERSON else CameraMode.FIRST_PERSON
	_update_camera_mode()


## Polls the raw gamepad camera-switch button (R3 / right stick click) every
## physics frame, edge-detected so it toggles once per press.
func _handle_gamepad_camera_switch() -> void:
	if not allow_camera_mode_switch:
		return
	var button_down := Input.is_joy_button_pressed(joypad_device, camera_switch_gamepad_button)
	if button_down and not _was_camera_switch_button_pressed:
		_toggle_camera_mode()
	_was_camera_switch_button_pressed = button_down
