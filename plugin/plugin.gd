@tool
extends EditorPlugin

#-------------------variable-------------------
var ui = load("res://addons/Lunk_Character_Controller/node/control.tscn")
var control : Control

func _enable_plugin() -> void:
	make_ui()

func _disable_plugin() -> void:
	remove_ui()

func make_ui():
#-------------------Membuat-------------------
	control = Control.new()
	
#-------------------Setting-------------------
	control.name = "Playert Controler"
	control.custom_minimum_size = Vector2( 400 , 100)
	control.add_child(ui.instantiate())
	
#-------------------Memunculkan-------------------
	add_control_to_bottom_panel(control , "Playert Controller")
	

func remove_ui():
	remove_control_from_bottom_panel(control)
	control.queue_free()
