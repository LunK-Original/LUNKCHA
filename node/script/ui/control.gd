@tool
extends Control

#--------------------variable------------------
var platform_2d = load("res://addons/Lunk_Character_Controller/node/platform_2d.tscn")
var first_person_platform_3d = load("res://addons/Lunk_Character_Controller/node/first_person(platform).tscn")
var third_person_platform_3d = load("res://addons/Lunk_Character_Controller/node/character.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _menekan_create_platform_2d() -> void:
	var scene = get_tree().edited_scene_root
	var platform_2d_inst = platform_2d.instantiate()
	
	scene.add_child(platform_2d_inst)
	
	if Engine.is_editor_hint():
		platform_2d_inst.owner = scene

func _menekan_create_first_person_platform_3d() -> void:
	var scene = get_tree().edited_scene_root
	var platform_first_person_3d_inst = first_person_platform_3d.instantiate()
	
	scene.add_child(platform_first_person_3d_inst)
	
	if Engine.is_editor_hint():
		platform_first_person_3d_inst.owner = scene

func _menekan_create_third_person_platform_3d() -> void:
	var scene = get_tree().edited_scene_root
	var third_person_platform_3d_inst = third_person_platform_3d.instantiate()
	
	scene.add_child(third_person_platform_3d_inst)
	
	if Engine.is_editor_hint():
		third_person_platform_3d_inst.owner = scene
