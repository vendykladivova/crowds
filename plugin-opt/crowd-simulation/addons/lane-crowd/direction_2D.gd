@tool
extends Node2D
class_name Direction2D

enum SimMode { KINETIC, RVO, ORCA }

@export var mode: SimMode = SimMode.KINETIC
@export var target_line: NodePath
@export var group_id: int = 0

@export_group("Spawning")
@export var start: Area2D = null
@export var repeat: bool = true
@export var repeat_times: int = 15

func _ready() -> void:
	_spawn_agents()

func _spawn_agents() -> void:
	var originals: Array = []
	print("--- START SPAWNOVANI PRO: ", name, " ---")
	if repeat and (start != null):
		originals = self.get_children()
		
		var x1: float = 0.0
		var x2: float = 0.0
		var y1: float = 0.0
		var y2: float = 0.0
		var found_shape: bool = false
		
		# Detekce rozměrů Start area
		for child in start.get_children():
			print(child)
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var center = child.global_position
				var extents = (child.shape.size / 2.0) * child.global_scale
				x1 = center.x - extents.x
				x2 = center.x + extents.x
				y1 = center.y - extents.y
				y2 = center.y + extents.y
				found_shape = true
				break
			
		if not found_shape:
			push_warning("Start Area2D without CollisionShape2D with RectangleShape2D.")
			return
		
		print("Klonovani")
		for node in originals:
			print("before", )
			if not (node is IndividualAgent2D):
				continue
			print(node)
			# Vytvoření klonů
			var number=0
			print(repeat_times)
			for i in range(1, repeat_times):
				var clone = node.duplicate()
				add_child(clone)
				
				var rand_pos = Vector2(randf_range(x1, x2), randf_range(y1, y2))
				clone.global_position = rand_pos
				clone.set_target(get_group_target(rand_pos))
				number += 1
			print("Konec spawn, celkem ",number)	

func get_group_target(agent_pos: Vector2) -> Vector2:
	#ToDo predelat na najiti nejkratsi cesty k target_line
	if target_line:
		var line = get_node_or_null(target_line)
		if line is Line2D and line.get_point_count() >= 2:
			var p1 = line.to_global(line.get_point_position(0))
			var p2 = line.to_global(line.get_point_position(line.get_point_count() - 1))
			return Geometry2D.get_closest_point_to_segment(agent_pos, p1, p2)
			
	return global_position
