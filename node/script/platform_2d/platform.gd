extends CharacterBody2D

#------------------variable-------------------------
@export var SPEED = 300.0
@export var JUMP_VELOCITY = 400.0
@export var DASH_SPEED  = 600
@export var DOUBLE_JUMP = true
@export var DASH = true
@export var CROUCH = true


#-----------------variable(hide)--------------------
var direction : float 
var double_jump = false
var is_jump = 2
var can_jump = false
var can_dash_with_gamepad = false
var is_dash = false
var can_dash = true
var dash_direct = Vector2.ZERO
var is_crouching = false
var last_shoot = 1

var animation_idle = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_front.png")
var animation_fall = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_hit.png")
var animation_jump = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_jump.png")
var animation_dash = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_idle.png")
var animation_turn_1 = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_walk_a.png")
var animation_turn_2 = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_walk_b.png")
var animation_turn_3 = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_idle.png")
var animation_crouch = load("res://addons/Lunk_Character_Controller/node/asset/2d/platform_2d/character_beige_duck.png")

#-----------------variable(objct)--------------------
@onready var collision = $CollisionShape2D
@onready var collision_shape = collision.shape as CapsuleShape2D
@onready var collision_base = collision.position.y
@onready var collision_area = $Area2D/CollisionShape2D
@onready var animation = $AnimatedSprite2D

#------------------variable(obect)----------------------

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	movement(delta)

func movement(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif is_on_floor() and DOUBLE_JUMP:
		is_jump = 2
	elif not DOUBLE_JUMP:
		is_jump = 1
	
	# Handle jump.
	var button_gamepad_jump = Input.is_joy_button_pressed(0 , JOY_BUTTON_A)
	if button_gamepad_jump and not can_jump and is_jump > 0:
		velocity.y = - JUMP_VELOCITY
		is_jump -= 1
	can_jump = button_gamepad_jump
	if Input.is_action_just_pressed("ui_select") and DOUBLE_JUMP:
		if is_on_floor():
			velocity.y  = - JUMP_VELOCITY
			double_jump = true
		elif double_jump:
			velocity.y = - JUMP_VELOCITY
			double_jump = false
	
	#movement
	direction = Input.get_axis("ui_left","ui_right")
	if direction > 0:
		velocity.x = direction * SPEED
		animation.flip_h = false
		last_shoot = 1
	elif direction < 0:
		velocity.x = direction * SPEED
		animation.flip_h = true
		last_shoot = -1 
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	
	#crouch
	is_crouching = Input.is_action_pressed("ui_down") and CROUCH #and is_on_floor()
	var scale_y = 0.5 if is_crouching else 1.0
	collision.scale.y = scale_y
	collision_area.scale.y = scale_y
	
	var offset_collision = collision_shape.height * (1.0 - scale_y) / 2.0
	collision.position.y = collision_base + offset_collision
	
	#dash
	if direction != 0 and can_dash and Input.is_key_pressed(KEY_SHIFT) and DASH:
		_start_dash(direction) 
	var dash_with_gamepad = Input.is_joy_button_pressed(0 , JOY_BUTTON_B) and DASH
	if direction != 0 and can_dash and dash_with_gamepad and not can_dash_with_gamepad:
		_start_dash(direction) 
	can_dash_with_gamepad = dash_with_gamepad
	if is_dash:
		velocity.x = DASH_SPEED * dash_direct
	else:
		velocity.x = SPEED * direction
	
	print(can_jump)
	
	move_and_slide()
	update_animation(direction)

func update_animation(direction: float) -> void:
	var new_anim := "idle"

	# Urutan prioritas: dash > airborne > crouch > run > idle
	if is_dash:
		new_anim = "dash" if animation.sprite_frames.has_animation("dash") else "turn"
	elif not is_on_floor():
		new_anim = "jump" if velocity.y < 0 else "fall"
	elif is_crouching:
		new_anim = "crouch" if animation.sprite_frames.has_animation("crouch") else "idle"
	elif direction != 0:
		new_anim = "turn"
	else:
		new_anim = "idle"

	# Cuma play() kalau animasinya beda -> gak restart tiap frame
	if animation.animation != new_anim:
		animation.play(new_anim)
		
		#print("crouching=", is_crouching, " on_floor=", is_on_floor(), " new_anim=", new_anim, " has_crouch_anim=", animation.sprite_frames.has_animation("crouch"))

func _start_dash(direct: float):
	can_dash = false
	is_dash = true
	dash_direct = direct
	
	await get_tree().create_timer(0.35).timeout
	is_dash = false
	
	await get_tree().create_timer(0.5).timeout
	can_dash = true
