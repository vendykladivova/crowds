@tool
extends EditorPlugin

func _enter_tree():
	# Registrace nových uzlů do editoru (používáme vaši cestu lane-crowd)
	add_custom_type("IndividualAgent2D", "CharacterBody2D", preload("res://addons/lane-crowd/individual_agent_2D.gd"), null)
	add_custom_type("Direction2D", "Node2D", preload("res://addons/lane-crowd/direction_2D.gd"), null)

func _exit_tree():
	# Úklid při deaktivaci pluginu
	remove_custom_type("IndividualAgent2D")
	remove_custom_type("Direction2D")
