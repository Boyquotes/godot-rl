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

const LEVEL_ROOM_COUNT = [4, 7, 9, 13, 15]
const LEVEL_ENEMY_COUNT = [2, 5, 9, 11, 15]
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 9

const EnemyScene = preload("res://Enemy.tscn")

var name_parts = "..bobabukekogixaxoxurirero"
var name_titles = ["of The Valley", "of The Woodlands", "The Unknowable", "The Warrior", "The Knight", "The Brave", "The Foolish", "The Forsaken", "The Idiot", "The Smelly", "The Sticky", "Smith", "The Thief", "The Rogue", "The Unseen", "The Drifter", "The Dweller", "The Lurker", "The Small", "The Unforgiven", "The Crestfallen", "The Hungry", "The Second Oldest", "The Younger", "The Original"]

# enum to get tiles by index ---------------------------------------------------
enum Tile {Player, Stone, Floor, Ladder, Wall, Door, Bloody, Bones}
enum VisTile { Dark, Shaded, Debug }
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
const snd_music1 = preload("res://sound/music1.wav")
const snd_ui_select = preload("res://sound/ui-select.wav")
const snd_ui_back = preload("res://sound/ui-back.wav")
const snd_ui_set = preload("res://sound/ui-set.wav")

var snd_walk = [snd_walk1, snd_walk2, snd_walk3]

var lowpass = AudioServer.get_bus_effect(1, 0)

var music_status = "ON"
var sfx_status = "ON"
var log_status = "ON"

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
onready var message_log = $CanvasLayer/MessageLog
onready var settings_screen = $CanvasLayer/Settings
onready var pause_screen = $CanvasLayer/Pause
onready var credits_screen = $CanvasLayer/Credits

# game states ------------------------------------------------------------------

var game_state
var player_name
var player_tile
var score = 0
var window_scale = 1
var screen_size = OS.get_screen_size()
var window_size = OS.get_window_size()

# movement delay ---------------------------------------------------------------

var move_timer
var can_move = true
var move_delay = 0.15

# Called when the node enters the scene tree for the first time ----------------
func _ready():
	OS.set_window_size(Vector2(400 * window_scale,300 * window_scale))
	
	title_setup()

func title_setup():
	game_state = "title"
	player_name = "nobody"
	$CanvasLayer/Title.visible = true
	
	# move create move delay timer
	
	move_timer = Timer.new()
	move_timer.set_one_shot(true)
	move_timer.set_wait_time(move_delay)
	move_timer.connect("timeout", self, "on_walk_timeout_complete")
	add_child(move_timer)
	
	# play menu ambience
	play_music(music_sound, snd_menu_amb)

# fires when walk timer has timed out
func on_walk_timeout_complete():
	can_move = true
	
# input event handler
func _input(event):
	if !event.is_pressed():
		return
	
	# inputs outside of gameplay only
	## TODO: if game_state == "title" or game_state == "end":
	
	# things we can do in title screen
	
	# start the game
	if game_state == "title" && event.is_action("Start"):
		initialize_game()
		
	# quit from main menu
	if game_state == "title" && event.is_action("Quit"):
		get_tree().quit()
		
	# view credits
	if game_state == "title" && event.is_action("Credits"):
		play_sfx(level_sound, snd_ui_select, 0.9, 1)
		game_state = "credits"
		credits_screen.visible = true
		return
		
	# view settings
	if game_state == "title" && event.is_action("Settings"):
		play_sfx(level_sound, snd_ui_select, 0.9, 1)
		game_state = "settings"
		# print current settings
		$CanvasLayer/Settings/Info.text = "Music is " + music_status + "\n"
		$CanvasLayer/Settings/Info.text += "SFX are " + sfx_status + "\n"
		$CanvasLayer/Settings/Info.text += "Message Log is " + log_status + "\n\n"
		$CanvasLayer/Settings/Info.text += "Back"
		settings_screen.visible = true
		return
			
	# things we can do during gameplay
	
	# open pause menu
	if game_state == "gameplay" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_set, 0.9, 1)
		game_state = "pause"
		AudioServer.set_bus_bypass_effects(1, false)
		# print current settings
		$CanvasLayer/Pause/Info.text = "Resume Game\n\n"
		$CanvasLayer/Pause/Info.text += "Music is " + music_status + "\n"
		$CanvasLayer/Pause/Info.text += "SFX are " + sfx_status + "\n"
		$CanvasLayer/Pause/Info.text += "Message Log is " + log_status + "\n\n"
		$CanvasLayer/Pause/Info.text += "Restart\nQuit to Desktop"
		pause_screen.visible = true
		return
		
	# things we can do from the pause screen
	
	if game_state == "pause" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
		# resume the game
		game_state = "gameplay"
		pause_screen.visible = false
		AudioServer.set_bus_bypass_effects(1, true)
		return
	if game_state == "pause" && event.is_action("Restart"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		pause_screen.visible = false
		title_setup()
		return
	if game_state == "pause" && event.is_action("Toggle Music"):
		
		toggle_setting("music")
		return
	if game_state == "pause" && event.is_action("Toggle SFX"):
		toggle_setting("sfx")
		return
	if game_state == "pause" && event.is_action("Toggle Log"):
		toggle_setting("log")
		return
	if game_state == "pause" && event.is_action("Quit"):
		get_tree().quit()

	# things we can do from the settings screen
	
	# go back to title
	if game_state == "settings" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
		# resume the game
		game_state = "title"
		settings_screen.visible = false
		return
	if game_state == "settings" && event.is_action("Toggle Music"):
		toggle_setting("music")
		return
	if game_state == "settings" && event.is_action("Toggle SFX"):
		toggle_setting("sfx")
		return
	if game_state == "settings" && event.is_action("Toggle Log"):
		toggle_setting("log")
		return
		
	# things we can do from the settings screen
	
	if game_state == "credits" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
		# back to title
		game_state = "title"
		credits_screen.visible = false
	
	# global inputs
		
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
	
	# clear message log
	message_log.messages.clear()
	
	stop_sound(music_sound)
	play_music(music_sound, snd_music1)
	
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
	# disable walking until timer complete
	can_move = false
	
	# start timer
	move_timer.start()
	
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
					
					log_random("attack")
					
					if enemy.dead:
						play_sfx(player_sound, snd_enemy_death, 0.8, 1)
						enemy.remove()
						enemies.erase(enemy)
						# bleed on the floor
						# for bx in range(x-1, x+2):
						#	for by in range(y-1, y+2):
						#		if tile_map.get_cell(bx, by) == Tile.Floor:
						#			set_tile(bx, by, Tile.Bloody)
						# BUG
						set_tile(x, y, Tile.Bones)
						
						message_log.add_message("You defeat the monstrosity")
					blocked = true
					break
					
			if !blocked:
				player_tile = Vector2(x, y)
				# play walk sound
				var r = snd_walk[randi() % snd_walk.size()]
				play_sfx(player_sound, r, 0.8, 1)
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
			message_log.add_message("The door opens without a key.")
			
		# if ladder, increase level count, add score, etc.
		Tile.Ladder:
			# play ladder sound
			
			play_sfx(level_sound, snd_ladder, 0.9, 1)
			level_num += 1
			score += 20
			print("level completed")
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
	
	# BUG: make sure enemies can't ever be on top of ladders
	
	var num_enemies = LEVEL_ENEMY_COUNT[level_num]
	for i in range(num_enemies):
		var room = rooms[1 + randi() % (rooms.size() - 1)]
		var enemy_x = room.position.x + 1 + randi() % int(room.size.x - 2)
		var enemy_y = room.position.y + 1 + randi() % int(room.size.y - 2)
		
		var blocked = false
		for enemy in enemies:
			if enemy.tile.x == enemy_x && enemy.tile.y == enemy_y:
				blocked = true
				break
			if tile_map.get_cell(enemy_x, enemy_y) == Tile.Ladder:
				blocked = true
				break
			
		if !blocked:
			var enemy = Enemy.new(self, randi() % 2, enemy_x, enemy_y)
			enemies.append(enemy)
	
	# place end ladder
	
	var end_room = rooms.back()
	var ladder_x = end_room.position.x + 1 + randi() % int(end_room.size.x - 2)
	var ladder_y = end_room.position.y + 1 + randi() % int(end_room.size.y - 2)
	set_tile(ladder_x, ladder_y, Tile.Ladder)
	
	# update ui
	if level_num > 0:
		$CanvasLayer/Level.text = "Basement Level " + str(level_num)
		message_log.add_message("You enter level " + str(level_num) + " of the dungeon.")
	else:
		$CanvasLayer/Level.text = "Ground Floor"
		message_log.add_message("You enter the ground floor.")

# visibility -------------------------------------------------------------------

# additional tile map
# states: visible, explored, unexplored

# visible is eiter a radius around the player, or a raycast solution
# explored is everything that was ever visible at any point
# unexplored is the default state, was never visible

# TODO: test with radius around player

func update_visuals_bak():
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

func update_visuals():
	# convert tile coords into pixel coords
	player.position = player_tile * TILE_SIZE
	yield(get_tree(), "idle_frame")

	# assuming we're not inside a room
	for x in range(level_size.x):
		for y in range(level_size.y):
			# raycast to check what we're currently seeing
			
			# go dark
			visibility_map.set_cell(x, y, VisTile.Dark)

			# explored
			if exploration_map.get_cell(x, y) == ExplTile.Explored:
				visibility_map.set_cell(x, y, VisTile.Shaded)
			
			# if player is there, see and explore
			for vx in range(player_tile.x - 1, player_tile.x + 2):
				for vy in range(player_tile.y - 1, player_tile.y + 2):
					visibility_map.set_cell(vx, vy, -1)
					exploration_map.set_cell(vx, vy, ExplTile.Explored)
						
	# find what room the player is in
	var i = 0
	while i < rooms.size():
		for rx in range(rooms[i].position.x, rooms[i].position.x + rooms[i].size.x):
			for ry in range(rooms[i].position.y, rooms[i].position.y + rooms[i].size.y):
				if rx == player_tile.x && ry == player_tile.y:
					# light up that room
					visit_room(rooms[i])
		i += 1

func visit_room(room):
	for rx in range(room.position.x, room.position.x + room.size.x):
			for ry in range(room.position.y, room.position.y + room.size.y):
				visibility_map.set_cell(rx, ry, -1)
				exploration_map.set_cell(rx, ry, ExplTile.Explored)

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

func log_random(type):
	if type == "attack":
		var r = randi() % 3
		if r == 0:
			message_log.add_message("You attack the beast.")
		if r == 1:
			message_log.add_message("You kick at the monster mercilessly.")
		if r == 2:
			message_log.add_message("You attack this foul creature.")
		return
		
func toggle_setting(setting):
	
	play_sfx(level_sound, snd_ui_set, 0.85, 1.05)
	
	if setting == "music":
		# music to full or no volume
		if music_status == "ON":
			AudioServer.set_bus_mute(3, true)
			music_status = "OFF"
		else:
			AudioServer.set_bus_mute(3, false)
			music_status = "ON"
	if setting == "sfx":
		# sfx to full or no volume
		if sfx_status == "ON":
			AudioServer.set_bus_mute(4, true)
			sfx_status = "OFF"
		else:
			AudioServer.set_bus_mute(4, false)
			sfx_status = "ON"
	if setting == "log":
		message_log.visible = !message_log.visible
		if message_log.visible:
			log_status = "ON"
		else:
			log_status = "OFF"
		
	# print current settings
	$CanvasLayer/Pause/Info.text = "Resume Game\n\n"
	$CanvasLayer/Pause/Info.text += "Music is " + music_status + "\n"
	$CanvasLayer/Pause/Info.text += "SFX are " + sfx_status + "\n"
	$CanvasLayer/Pause/Info.text += "Message Log is " + log_status + "\n\n"
	$CanvasLayer/Pause/Info.text += "Restart\nQuit to Desktop"
	
	# print current settings
	$CanvasLayer/Settings/Info.text = "Music is " + music_status + "\n"
	$CanvasLayer/Settings/Info.text += "SFX are " + sfx_status + "\n"
	$CanvasLayer/Settings/Info.text += "Message Log is " + log_status + "\n\n"
	$CanvasLayer/Settings/Info.text += "Back"

func _process(delta):
	# gameplay-only inputs
	if game_state == "gameplay" && can_move:
		if Input.is_action_pressed("Up"):
			yield(get_tree(), "idle_frame")
			try_move(0, -1)
		if Input.is_action_pressed("Down"):
			yield(get_tree(), "idle_frame")
			try_move(0, 1)
		if Input.is_action_pressed("Left"):
			yield(get_tree(), "idle_frame")
			try_move(-1, 0)
		if Input.is_action_pressed("Right"):
			yield(get_tree(), "idle_frame")
			try_move(1, 0)
