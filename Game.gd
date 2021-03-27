extends Node2D

# constants for level generation -----------------------------------------------

const TILE_SIZE = 10

const LEVEL_SIZES = [
	Vector2(30, 20),
	Vector2(35, 25),
	Vector2(40, 30),
	Vector2(45, 35),
	Vector2(50, 40)
]

const LEVEL_ROOM_COUNT = [4, 5, 7, 9, 11]
const LEVEL_ENEMY_COUNT = [1, 4, 8, 11, 15]
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 9

const EnemyScene = preload("res://Enemy.tscn")

var name_parts = "..bobabukekogixaxoxurirero"
var name_titles = ["The Warrior", "The Knight", "The Brave", "The Foolish", "The Forsaken", "The Idiot", "The Smelly", "The Sticky", "Smith", "The Thief", "The Rogue", "The Unseen", "The Drifter", "The Dweller", "The Lurker", "The Small", "The Unforgiven", "The Crestfallen", "The Hungry", "The Second Oldest", "The Younger", "The Original"]

# enum to get tiles by index ---------------------------------------------------
enum Tile {Player, Stone, Floor, Ladder, Wall, Door, Bloody, Bones}
enum VisTile { Dark, Shaded }
enum ExplTile { Unexplored, Explored }

# sound resources

const snd_menu_amb = preload("res://sound/menu-ambience.wav")
const snd_walk1 = preload("res://sound/footstep1.wav")
const snd_walk2 = preload("res://sound/footstep2.wav")
const snd_walk3 = preload("res://sound/footstep3.wav")
const snd_walk_blood = preload("res://sound/footstep-blood1.wav")
const snd_door_open = preload("res://sound/door1.wav")
const snd_ladder = preload("res://sound/ladder1.wav")
const snd_enemy_hurt = preload("res://sound/enemy-hurt.wav")
const snd_enemy_death = preload("res://sound/enemy-death.wav")

# enemy class ------------------------------------------------------------------

class Enemy extends Reference:
	var sprite_node
	var tile
	var full_hp
	var hp
	var dead = false

	func _init(game, enemy_level, x, y):
		full_hp = 5 + enemy_level * 2
		hp = full_hp
		tile = Vector2(x, y)
		sprite_node = EnemyScene.instance()
		# sprite_node.frame = enemy_level
		sprite_node.position = tile * TILE_SIZE
		game.add_child(sprite_node)

	func remove():
		sprite_node.queue_free()
		
	func take_damage(game, dmg):
		if dead:
			return
			
		hp = max(0, hp - dmg)
		sprite_node.get_node("HP").rect_size.x = TILE_SIZE * hp / full_hp
		
		if hp == 0:
			dead = true
			game.score += 10 * full_hp

# current level data -----------------------------------------------------------

var level_num = 0
var map = []
var rooms = []
var enemies = []
var level_size

# references to commonly used nodes --------------------------------------------
# ref via scene node name, onready to reference only after setup

onready var tile_map = $TileMap
onready var visibility_map = $VisibilityMap
onready var exploration_map = $ExplorationMap
onready var player = $Player
onready var player_anims = $Player/PlayerAnims
onready var player_sound = $Player/SoundPlayer
onready var level_sound = $Player/SoundLevel
onready var music_sound = $Player/SoundMusic

# game states ------------------------------------------------------------------

var game_state
var player_name
var player_tile
var score = 0
var window_scale = 1
var screen_size = OS.get_screen_size()
var window_size = OS.get_window_size()

# Called when the node enters the scene tree for the first time ----------------
func _ready():
	OS.set_window_size(Vector2(400 * window_scale,300 * window_scale))
	game_state = "title"
	player_name = "nobody"
	$CanvasLayer/Title.visible = true
	
	# play menu ambience
	play_music(music_sound, snd_menu_amb)
	
# input event handler
func _input(event):
	if !event.is_pressed():
		return
	
	# gameplay-only inputs
	if game_state == "gameplay":
		if event.is_action("Up"):
			try_move(0, -1)
		if event.is_action("Down"):
			try_move(0, 1)
		if event.is_action("Left"):
			try_move(-1, 0)
		if event.is_action("Right"):
			try_move(1, 0)
	
	# inputs outside of gameplay only
	## TODO: if game_state == "title" or game_state == "end":
	if true:
		if event.is_action("Start"):
			# stop menu music
			stop_sound(music_sound)
			initialize_game()
	
	# global inputs
	if event.is_action("Quit"):
		get_tree().quit()
		
	if event.is_action("Debug"):
		$CanvasLayer/Debug.visible = !$CanvasLayer/Debug.visible
	
	if event.is_action("Zoom"):
		if window_scale == 1:
			window_scale = 2
		else:
			window_scale = 1
		OS.set_window_size(Vector2(400 * window_scale,300 * window_scale))

# function to initialize / restart the entire game -----------------------------

func initialize_game():
	game_state = "gameplay"
	
	player_name = get_name() + " " + get_title()
	$CanvasLayer/Name.text = player_name

	randomize()
	level_num = 0
	score = 0
	$CanvasLayer/Win.visible = false
	$CanvasLayer/Lose.visible = false
	$CanvasLayer/Title.visible = false
	build_level()
		
func try_move(dx, dy):
	var x = player_tile.x + dx
	var y = player_tile.y + dy
	
	# assume first that everything is stone so we can't go
	var tile_type = Tile.Stone
	if x >= 0 && x < level_size.x && y >= 0 && y < level_size.y:
		tile_type = map[x][y]
	
	# actions based on this type of tile
	match tile_type:
		# if floor
		Tile.Floor:
			
			# maybe an enemy interaction
			var blocked = false
			for enemy in enemies:
				if enemy.tile.x == x && enemy.tile.y == y:
					enemy.take_damage(self, 1)
					# sfx
					play_sfx(player_sound, snd_enemy_hurt, 0.8, 1)
					# anim
					if dx < 0:
						player.set_flip_h(true)
					else:
						player.set_flip_h(false)
					player_anims.stop(true)
					player_anims.play("Attack")
					if enemy.dead:
						play_sfx(player_sound, snd_enemy_death, 0.8, 1)
						enemy.remove()
						enemies.erase(enemy)
						# bleed on the floor
						for bx in range(x-1, x+2):
							for by in range(y-1, y+2):
								if tile_map.get_cell(bx, by) == Tile.Floor:
									set_tile(bx, by, Tile.Bloody)
						set_tile(x, y, Tile.Bones)
					blocked = true
					break
					
			if !blocked:
				player_tile = Vector2(x, y)
				# play walk sound
				play_sfx(player_sound, snd_walk1, 0.8, 1)
				# anim
				if dx < 0:
					player.set_flip_h(true)
				else:
					player.set_flip_h(false)
				player_anims.stop(true)
				player_anims.play("PlayerWalk")


		Tile.Bloody:
			player_tile = Vector2(x, y)
			player_anims.play("PlayerWalk")
			# play squishy sound
			play_sfx(player_sound, snd_walk_blood, 0.8, 1)
		Tile.Bones:
			player_tile = Vector2(x, y)
			player_anims.play("PlayerWalk")
			# play squishy sound
			play_sfx(player_sound, snd_walk_blood, 0.8, 1)
			# BUG: blood can unblock enemy?
		
		# if door, turn it into floor to "open"
		Tile.Door:
			set_tile(x, y, Tile.Floor)
			yield(get_tree(), "idle_frame")
			# play door open sound
			play_sfx(level_sound, snd_door_open, 0.9, 1)
			# anim
			if dx < 0:
				player.set_flip_h(true)
			else:
				player.set_flip_h(false)
			player_anims.play("OpenDoor")
			
		# if ladder, increase level count, add score, etc.
		Tile.Ladder:
			# play ladder sound
			
			play_sfx(level_sound, snd_ladder, 0.9, 1)
			level_num += 1
			score += 20
			$CanvasLayer/Score.text = "Score: " + str(score)
			if level_num < LEVEL_SIZES.size():
				build_level()
			else:
				# no more levels left, you win
				score += 1000
				$CanvasLayer/Win.visible = true
				game_state = "end"
	
	call_deferred("update_visuals")

# function to generate and build level -----------------------------------------

func build_level():
	# start with blank map
	rooms.clear()
	map.clear()
	tile_map.clear()
	
	# remove enemies
	for enemy in enemies:
		enemy.remove()
	enemies.clear()
	
	# look up size of this level
	level_size = LEVEL_SIZES[level_num]
	
	# make everything start as stone
	for x in range(level_size.x):
		map.append([])
		for y in range(level_size.y):
			map[x].append(Tile.Stone)
			tile_map.set_cell(x, y, Tile.Stone)
			
			# set everything to dark visibility and unexplored
			visibility_map.set_cell(x, y, VisTile.Dark)
			exploration_map.set_cell(x, y, ExplTile.Unexplored)
			
	# set region but keep one tile edge of stone
	var free_regions = [Rect2(Vector2(2, 2), level_size - Vector2(4, 4))]
	
	var num_rooms = LEVEL_ROOM_COUNT[level_num]
	for i in range(num_rooms):
		add_room(free_regions)
		if free_regions.empty():
			break
			
	connect_rooms()
	
	# place player
	
	var start_room = rooms.front()
	var player_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
	var player_y = start_room.position.y + 1 + randi() % int(start_room.size.y - 2)
	player_tile = Vector2(player_x, player_y)
	
	yield(get_tree(), "idle_frame")
	call_deferred("update_visuals")
	
	# place enemies
	
	var num_enemies = LEVEL_ENEMY_COUNT[level_num]
	for i in range(num_enemies):
		var room = rooms[1 + randi() % (rooms.size() - 1)]
		var x = room.position.x + 1 + randi() % int(room.size.x - 2)
		var y = room.position.y + 1 + randi() % int(room.size.y - 2)
		
		var blocked = false
		for enemy in enemies:
			if enemy.tile.x == x && enemy.tile.y == y:
				blocked = true
				break
			
		if !blocked:
			var enemy = Enemy.new(self, randi() % 2, x, y)
			enemies.append(enemy)
	
	# place end ladder
	
	var end_room = rooms.back()
	var ladder_x = end_room.position.x + 1 + randi() % int(end_room.size.x - 2)
	var ladder_y = end_room.position.y + 1 + randi() % int(end_room.size.y - 2)
	set_tile(ladder_x, ladder_y, Tile.Ladder)
	
	# update ui
	if level_num > 0:
		$CanvasLayer/Level.text = "Basement Level " + str(level_num)
	else:
		$CanvasLayer/Level.text = "Ground Floor"

# visibility -------------------------------------------------------------------

# additional tile map
# states: visible, explored, unexplored

# visible is eiter a radius around the player, or a raycast solution
# explored is everything that was ever visible at any point
# unexplored is the default state, was never visible

# TODO: test with radius around player

func update_visuals():
	# convert tile coords into pixel coords
	player.position = player_tile * TILE_SIZE
	yield(get_tree(), "idle_frame")
	var player_center = tile_to_pixel_center(player_tile.x, player_tile.y)
	var space_state = get_world_2d().direct_space_state
	for x in range(level_size.x):
		for y in range(level_size.y):
			# raycast to check what we're currently seeing
			
			# go dark
			visibility_map.set_cell(x, y, VisTile.Dark)
			
			# explored
			if exploration_map.get_cell(x, y) == ExplTile.Explored:
				visibility_map.set_cell(x, y, VisTile.Shaded)
			
			var x_dir = 1 if x < player_tile.x else -1
			var y_dir = 1 if y < player_tile.y else -1
			var test_point = tile_to_pixel_center(x, y) + Vector2(x_dir, y_dir) * TILE_SIZE / 2
			
			var occlusion = space_state.intersect_ray(player_center, test_point)
			if !occlusion || (occlusion.position - test_point).length() < 1:
				# mark as explored if previous unexplored
				exploration_map.set_cell(x, y, ExplTile.Explored)
				visibility_map.set_cell(x, y, -1)


func tile_to_pixel_center(x, y):
	return Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)


# function to connect existing rooms -------------------------------------------

func connect_rooms():
	# build an A* graph of areas where we can add corridors
	
	# add all stone tiles outside the rooms
	var stone_graph = AStar.new()
	var point_id = 0
	for x in range(level_size.x):
		for y in range(level_size.y):
			if map[x][y] == Tile.Stone:
				stone_graph.add_point(point_id, Vector3(x , y, 0))
				
				# connect to left if also stone
				if x > 0 && map[x - 1][y] == Tile.Stone:
					var left_point = stone_graph.get_closest_point(Vector3(x - 1, y, 0))
					stone_graph.connect_points(point_id, left_point)
					
				# connect to above if also stone
				if y > 0 && map[x][y -1] == Tile.Stone:
					var above_point = stone_graph.get_closest_point(Vector3(x, y - 1, 0))
					stone_graph.connect_points(point_id, above_point)
					
				point_id += 1
	
	# build an a* graph of room connections
	# see if there's a path between all of them
	
	var room_graph = AStar.new()
	point_id = 0
	for room in rooms:
		var room_center = room.position + room.size / 2
		room_graph.add_point(point_id, Vector3(room_center.x, room_center.y, 0))
		point_id += 1
	
	# add random connections until everything is connected
	
	while !is_everything_connected(room_graph):
		add_random_connection(stone_graph, room_graph)

# function that returns true if everything has a connection --------------------

func is_everything_connected(graph):
	var points = graph.get_points()
	var start = points.pop_back()
	# try to get a path for every other point
	# if this fails, something is not connected
	for point in points:
		var path = graph.get_point_path(start, point)
		if !path:
			return false
	
	return true
	
func add_random_connection(stone_graph, room_graph):
	# pick rooms to connect

	var start_room_id = get_least_connected_point(room_graph)
	var end_room_id = get_nearest_unconnected_point(room_graph, start_room_id)
	
	# pick door locations
	
	var start_position = pick_random_door_location(rooms[start_room_id])
	var end_position = pick_random_door_location(rooms[end_room_id])
	
	# find a path to connect the doors to each other
	
	var closest_start_point = stone_graph.get_closest_point(start_position)
	var closest_end_point = stone_graph.get_closest_point(end_position)
	
	var path = stone_graph.get_point_path(closest_start_point, closest_end_point)
	assert(path)
	
	# add path to map
	
	set_tile(start_position.x, start_position.y, Tile.Door)
	set_tile(end_position.x, end_position.y, Tile.Door)
	
	for position in path:
		set_tile(position.x, position.y, Tile.Floor)
	
	room_graph.connect_points(start_room_id, end_room_id)	
	
# helper functions for above ---------------------------------------------------

func get_least_connected_point(graph):
	var point_ids = graph.get_points()
	
	# least will hold the point with least connections seen so far
	var least
	# list of all the points with that many connections
	var tied_for_least = []
	
	for point in point_ids:
		var count = graph.get_point_connections(point).size()
		if !least || count < least:
			least = count
			tied_for_least = [point]
		elif count == least:
			tied_for_least.append(point)
			
	return tied_for_least[randi() % tied_for_least.size()]
	
func get_nearest_unconnected_point(graph, target_point):
	var target_position = graph.get_point_position(target_point)
	var point_ids = graph.get_points()
	
	var nearest
	var tied_for_nearest = []
	
	for point in point_ids:
		if point == target_point:
			continue
		
		var path = graph.get_point_path(point, target_point)
		if path:
			continue
			
		var dist = (graph.get_point_position(point) - target_position).length()
		if !nearest || dist < nearest:
			nearest = dist
			tied_for_nearest = [point]
		elif dist == nearest:
			tied_for_nearest.append(point)
			
	return tied_for_nearest[randi() % tied_for_nearest.size()]

func pick_random_door_location(room):
	var options = []
	
	# top and bottom walls
	
	for x in range(room.position.x + 1, room.end.x - 2):
		options.append(Vector3(x, room.position.y, 0))
		options.append(Vector3(x, room.end.y - 1, 0))

	# left and right walls
	
	for y in range(room.position.y + 1, room.end.y - 2):
		options.append(Vector3(room.position.x, y, 0))
		options.append(Vector3(room.end.x - 1, y, 0))

	return options[randi() % options.size()]

# function to add a room within free regions -----------------------------------

func add_room(free_regions):
	var region = free_regions[randi() % free_regions.size()]
	
	# go bigger if possible 
	var size_x = MIN_ROOM_DIMENSION 
	if region.size.x > MIN_ROOM_DIMENSION:
		size_x += randi() % int(region.size.x - MIN_ROOM_DIMENSION)
	
	var size_y = MIN_ROOM_DIMENSION
	if region.size.y > MIN_ROOM_DIMENSION:
		size_y += randi() % int(region.size.y - MIN_ROOM_DIMENSION)
		
	# constrain to maximum room size
	size_x = min(size_x, MAX_ROOM_DIMENSION)
	size_y = min(size_y, MAX_ROOM_DIMENSION)
		
	var start_x = region.position.x
	if region.size.x > size_x:
		start_x += randi() % int(region.size.x - size_x)
		
	var start_y = region.position.y
	if region.size.y > size_y:
		start_y += randi() % int(region.size.y - size_y)
	
	var room = Rect2(start_x, start_y, size_x, size_y)
	rooms.append(room)
	
	for x in range(start_x, start_x + size_x):
		set_tile(x, start_y, Tile.Wall)
		set_tile(x, start_y + size_y - 1, Tile.Wall)
		
	for y in range(start_y + 1, start_y + size_y - 1):
		set_tile(start_x, y, Tile.Wall)
		set_tile(start_x + size_x - 1, y, Tile.Wall)
		
		for x in range(start_x + 1, start_x + size_x - 1):
			set_tile(x, y, Tile.Floor)
			
	cut_regions(free_regions, room)

func cut_regions(free_regions, region_to_remove):
	var removal_queue = []
	var addition_queue = []
	
	for region in free_regions:
		if region.intersects(region_to_remove):
			removal_queue.append(region)
			
			var leftover_left = region_to_remove.position.x - region.position.x - 1
			var leftover_right = region.end.x - region_to_remove.end.x - 1
			var leftover_above = region_to_remove.position.y - region.position.y - 1
			var leftover_below = region.end.y - region_to_remove.end.y - 1
			
			if leftover_left >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(region.position, Vector2(leftover_left, region.size.y)))
			if leftover_right >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(Vector2(region_to_remove.end.x + 1, region.position.y), Vector2(leftover_right, region.size.y)))
			if leftover_above >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(region.position, Vector2(region.size.x, leftover_above)))
			if leftover_below >= MIN_ROOM_DIMENSION:
				addition_queue.append(Rect2(Vector2(region.position.x, region_to_remove.end.y + 1), Vector2(region.size.x, leftover_below)))
				
	for region in removal_queue:
		free_regions.erase(region)
		
	for region in addition_queue:
		free_regions.append(region)

# function to set tiles --------------------------------------------------------

func set_tile(x, y, type):
	map[x][y] = type
	tile_map.set_cell(x,y,type)

# name generators ---------------------------------------------------------------

func get_pair():
	var r = randi()%name_parts.length()/2
	var pair = name_parts[r]+name_parts[r+1]
	return pair.replace('.','')

func get_name(pairs=4):
	var name = ''
	for i in range(pairs):
		name += get_pair()
	return name.capitalize()

func get_title():
	return name_titles[randi() % name_titles.size()]

# function to play various sound effects ---------------------------------------

func play_sfx(myplayer, mysound, rangelow, rangehigh):
	myplayer.set_stream(mysound)
	myplayer.set_pitch_scale(rand_range(rangelow, rangehigh))
	myplayer.play()
	
func play_music(myplayer, mysound):
	myplayer.set_stream(mysound)
	myplayer.play()
	
func stop_sound(myplayer):
	myplayer.stop()

# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta):
	# $CanvasLayer/Debug.text = str(game_state) + " * " + str(rooms.size()) + " rooms"
#	pass
