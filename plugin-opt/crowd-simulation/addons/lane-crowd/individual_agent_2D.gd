extends CharacterBody2D
class_name IndividualAgent2D

enum SimMode { KINETIC, RVO, ORCA }

@export var speed: float = 60.0
@export var radius: float = 15.0
@export var group_id: int = 0
@export var chiral_mode: bool = false
@export_range(0.0, 1.0) var chiral_bias_factor: float = 0.3

var nav_agent: NavigationAgent2D
var target_position: Vector2
var mode: SimMode = SimMode.KINETIC

# ToDo ORCA nefunguje

func _ready() -> void:
	add_to_group("sim_agents")

	for child in get_children():
		if child is NavigationAgent2D:
			child.avoidance_enabled = false
			remove_child(child)
			child.queue_free()

	# Inicializace RVO/ORCA NavigationAgent2D
	nav_agent = NavigationAgent2D.new()
	nav_agent.avoidance_enabled = true
	nav_agent.radius = radius
	nav_agent.max_speed = speed * 1.5
	nav_agent.time_horizon_agents = 1.0
	nav_agent.neighbor_distance = radius * 5.0
	nav_agent.max_neighbors = 10
	nav_agent.path_desired_distance = 60.0
	nav_agent.velocity_computed.connect(_on_safe_velocity_computed)
	add_child(nav_agent)
	
	if is_inside_tree() and get_world_2d():
		nav_agent.set_navigation_map(get_world_2d().get_navigation_map())
	
	var parent = get_parent()
	if parent != null and parent.has_method("get_group_target"):
		group_id = parent.group_id
		mode = parent.mode
		set_target(parent.get_group_target(global_position))

func set_target(new_target: Vector2) -> void:
	target_position = new_target
	if nav_agent:
		nav_agent.target_position = new_target

# debug
#var debug_pref_vel: Vector2 = Vector2.ZERO
#var debug_safe_vel: Vector2 = Vector2.ZERO
#
#func _draw() -> void:
#	draw_line(Vector2.ZERO, to_local(target_position), Color.CYAN, 1.0)
#	draw_line(Vector2.ZERO, debug_pref_vel, Color.GREEN, 6.0)
#	draw_line(Vector2.ZERO, debug_safe_vel, Color.RED, 2.0)

func _physics_process(delta: float) -> void:
	if global_position.distance_to(target_position) < 10.0:
		nav_agent.set_velocity(Vector2.ZERO)
		return

	var direction: Vector2
	var map_rid = nav_agent.get_navigation_map()
	var closest_point = NavigationServer2D.map_get_closest_point(map_rid, global_position)

	if global_position.distance_to(closest_point) > 10.0 or nav_agent.is_navigation_finished():
		direction = global_position.direction_to(target_position)
	else:
		var next_path_pos = nav_agent.get_next_path_position()
		direction = global_position.direction_to(next_path_pos)

	var preferred_velocity = direction * speed
	
	# debug
	#debug_pref_vel = preferred_velocity
	#queue_redraw()

	if mode == SimMode.KINETIC:
		var final_velocity = calculate_kinetic_velocity(preferred_velocity, direction)
		velocity = final_velocity
		move_and_slide()
	elif mode == SimMode.ORCA:
		nav_agent.set_velocity(preferred_velocity)
	elif mode == SimMode.RVO:
		nav_agent.set_velocity(preferred_velocity)

# Mikroskopický operátor G_x(x) podle Bacik et al.
func G_x(x: float, sigma: float) -> float:
	var norm_x = x / sigma
	var base = -norm_x * exp(-pow(norm_x, 2.0) / 2.0)
	if chiral_mode:
		base += chiral_bias_factor * exp(-pow(norm_x, 2.0) / 2.0)
	return base

func calculate_kinetic_velocity(preferred_velocity: Vector2, forward_direction: Vector2) -> Vector2:
	# Laterální jednotkový vektor (kolmice na směr chůze)
	var lateral_unit = Vector2(-forward_direction.y, forward_direction.x).normalized()
	var sigma = radius * 0.9
	
	var repulsion_force = Vector2.ZERO
	var lateral_drift_force = Vector2.ZERO
	
	var all_agents = get_tree().get_nodes_in_group("sim_agents")
	
	for other_agent in all_agents:
		if other_agent == self or not (other_agent is IndividualAgent2D):
			continue
			
		var to_other = other_agent.global_position - global_position
		var distance = to_other.length()
		var min_dist = radius + other_agent.radius
		
		# 1. STEJNÁ SKUPINA: pouze jemná separace, když se dotýkají
		if other_agent.group_id == self.group_id:
			if distance > 0.001 and distance < min_dist:
				var overlap = (min_dist - distance) / min_dist
				var push_away = -to_other / distance
				repulsion_force += push_away * overlap * (speed * 0.6)
			continue
		
		# 2. PROTIJDOUNCÍ AGENTI (Protisměr)
		# Detekční zóna: sledujeme protijdoucí agenty v dosahu 2x součtu poloměrů
		if distance > 0.001 and distance < (min_dist * 2.0):
			# Zkontrolujeme, zda jde skutečně proti nám (skalární součin směrů < 0) nebo je před námi
			var is_ahead = to_other.dot(forward_direction) > -radius * 0.5
			
			if is_ahead:
				# Excluded volume (hard-sphere repulze při fyzickém překryvu)
				if distance < min_dist:
					var overlap = (min_dist - distance) / min_dist
					var push_away = -to_other / distance
					repulsion_force += push_away * overlap * (speed * 1.8)
				
				# Kinetický laterální posun G_x(x)
				var lateral_offset = to_other.dot(lateral_unit)
				var gx = G_x(lateral_offset, sigma)
				
				# Síla laterálního driftu musí být výrazná, aby pruhy spolehlivě vznikly
				lateral_drift_force += lateral_unit * gx * (speed * 2.2)

	# Výsledná rychlost kombinuje dopředný tah, separaci a boční drift
	var desired_velocity = preferred_velocity + repulsion_force + lateral_drift_force
	
	# Mírné zastropování, aby nevznikaly extrémní skoky
	var max_allowed_speed = speed * 1.8
	if desired_velocity.length() > max_allowed_speed:
		desired_velocity = desired_velocity.normalized() * max_allowed_speed
		
	return desired_velocity

func _on_safe_velocity_computed(safe_velocity: Vector2) -> void:
	# debug
	#debug_safe_vel = safe_velocity
	if mode == SimMode.ORCA or mode == SimMode.RVO:
		velocity = safe_velocity
		move_and_slide()
