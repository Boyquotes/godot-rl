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

const LEVEL_ROOM_COUNT = [4, 5, 9, 11, 13]
const LEVEL_ENEMY_COUNT = [3, 5, 7, 9, 11]
const LEVEL_ITEM_COUNT = [1, 3, 5, 5, 5]
const LEVEL_POWERUP_COUNT = [0, 1, 1, 1, 1]
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 9
const PLAYER_START_HP = 15

# item values
var coin_value = 1
var coin_score = 10
var heart_health = 5
var blood_health = 1
var heart_score = 10
var potion_score = 20

const STATUS_EFFECTS = ["heal_once", "heal_over_time", "poison"]

const EnemyScene = preload("res://Enemy.tscn")
const ItemScene = preload("res://Item.tscn")
const FloatLabelScene = preload("res://FloatLabel.tscn")
const BloodScene = preload("res://Blood.tscn")

var name_parts = "..bobabukekogixaxoxurirero"
var name_titles = ["of The Valley", "of The Woodlands", "The Unknowable", "The Warrior", "The Knight", "The Brave", "The Foolish", "The Forsaken", "The Idiot", "The Smelly", "The Sticky", "Smith", "The Thief", "The Rogue", "The Unseen", "The Drifter", "The Dweller", "The Lurker", "The Small", "The Unforgiven", "The Crestfallen", "The Hungry", "The Second Oldest", "The Younger", "The Original"]

var save_path = "user://save.dat"

# enum to get tiles by index ---------------------------------------------------
enum Tile {Player, Stone, Floor, Ladder, Wall, Door, Bloody, Bones, ShopGrate}
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
const snd_item_coin = preload("res://sound/item-coin.wav")
const snd_item_potion = preload("res://sound/item-potion.wav")
const snd_item_heart = preload("res://sound/item-heart.wav")

var snd_walk = [snd_walk1, snd_walk2, snd_walk3]

var lowpass = AudioServer.get_bus_effect(1, 0)

var music_status = "ON"
var sfx_status = "ON"
var log_status = "ON"

# item class -------------------------------------------------------------------

class Item extends Reference:
	var sprite_node
	var tile
	var this_drop

	func _init(game, x, y, this_drop):
		tile = Vector2(x, y)
		sprite_node = ItemScene.instance()
		sprite_node.position = tile * TILE_SIZE
		sprite_node.frame = this_drop
		game.add_child(sprite_node)

	func remove():
		sprite_node.queue_free()

# enemy class ------------------------------------------------------------------

class Enemy extends Reference:
	var possible_types = ["Boblin", "Gogonim", "Gogant", "Sepekter", "Ancient Sepekter", "Old One"]
	var enemy_name
	var sprite_node
	var tile
	var full_hp
	var hp
	var dead = false

	func _init(game, enemy_level, x, y):
		full_hp = 1 + enemy_level * 2
		hp = full_hp
		tile = Vector2(x, y)
		sprite_node = EnemyScene.instance()
		sprite_node.frame = sprite_node.frame + enemy_level * 16
		# assign enemy names and levels
		enemy_name = possible_types[enemy_level]
		sprite_node.position = tile * TILE_SIZE
		game.add_child(sprite_node)

	func remove():
		sprite_node.queue_free()
		
	func take_damage(game, dmg):
		
		if dead:
			return
			
		hp = max(0, hp - dmg)
		sprite_node.get_node("HP").rect_size.x = TILE_SIZE * hp / full_hp
		
		var pos = sprite_node.position
		game.spawn_label("-" + str(dmg), 0, pos)
		
		if hp == 0:
			dead = true
			game.score += 10 * full_hp
			
			# drop item
			
			var r = randi() % 100
			
			# coins: 40% 
			# full hp: 5%
			# 5 hp: 10%
			# nothing: rest
			
			if r >= 95:
				# drop a potion
				game.items.append(Item.new(game, tile.x, tile.y, 17))
			elif r >= 85:
				# drop a heart
				game.items.append(Item.new(game, tile.x, tile.y, 16))
			elif r >= 45:
				# drop a coin
				game.items.append(Item.new(game, tile.x, tile.y, 18))
	
			
	func act(game):
		if !sprite_node.visible:
			return
	
		var my_point = game.enemy_pathfinding.get_closest_point(Vector3(tile.x, tile.y, 0))
		var player_point = game.enemy_pathfinding.get_closest_point(Vector3(game.player_tile.x, game.player_tile.y, 0))
		var path = game.enemy_pathfinding.get_point_path(my_point, player_point)
		if path:
			assert(path.size() > 1)
			var move_tile = Vector2(path[1].x, path[1].y)
			
			if move_tile == game.player_tile:
				game.damage_player(1, self)
				var pos = sprite_node.position
				game.spawn_label("-1", 3, pos + Vector2(12, 12))
			else:
				var blocked = false
				for enemy in game.enemies:
					if enemy.tile == move_tile:
						blocked = true
						break
				
				if !blocked:
					tile = move_tile

# current level data -----------------------------------------------------------

var level_num = 0
var map = []
var rooms = []
var enemies = []
var items = []
var bloodstains = []
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
onready var lose_screen = $CanvasLayer/Lose
onready var win_screen = $CanvasLayer/Win
onready var shop_screen = $CanvasLayer/Shop

onready var shop_slots = [$CanvasLayer/Shop/Slot1, $CanvasLayer/Shop/Slot2, $CanvasLayer/Shop/Slot3]
onready var shop_names = [$CanvasLayer/Shop/Slot1/Name, $CanvasLayer/Shop/Slot2/Name, $CanvasLayer/Shop/Slot3/Name]

# game states ------------------------------------------------------------------
var game_state
var player_name
var player_tile
var player_dmg = 1
var score = 0
var coins = 0
var player_hp = PLAYER_START_HP
var max_hp = PLAYER_START_HP
var enemy_pathfinding
var window_scale = 1
var screen_size = OS.get_screen_size()
var window_size = OS.get_window_size()

# shop -------------------------------------------------------------------------

var shop_items = {
	"vampirism" : {
		"name" : "Vampirism",
		"cost" : 1,
		"purchased" : true,
		"description" : "Drink blood to gain health",
		"frame" : 56
	},
	"pedicure" : {
		"name" : "Pedicure",
		"cost" : 1,
		"purchased" : false,
		"description" : "Improves kick strength by 2",
		"frame" : 57
	},
	"scaryface" : {
		"name" : "Scary Face",
		"cost" : 1,
		"purchased" : false,
		"description" : "Enemies lose 1 health when they spot you",
		"frame" : 58
	},
	"forgery" : {
		"name" : "Forgery",
		"cost" : 1,
		"purchased" : false,
		"description" : "Coins have 5x their normal value",
		"frame" : 59
	},
	"goodeyes" : {
		"name" : "Good Eyes",
		"cost" : 1,
		"purchased" : false,
		"description" : "Find better items",
		"frame" : 60
	},
	"extralife" : {
		"name" : "Extra Life",
		"cost" : 1,
		"purchased" : false,
		"description" : "Upon dying, restart level at full health",
		"frame" : 61
	},
	"bait" : {
		"name" : "Bait",
		"cost" : 1,
		"purchased" : false,
		"description" : "Spawn more enemies",
		"frame" : 62
	},
	"slime" : {
		"name" : "Slime",
		"cost" : 1,
		"purchased" : false,
		"description" : "Leave a toxic trail that hurts enemies",
		"frame" : 63
	}
}



var selected_item_name
var selected_slot
var shop_items_values

# status effects ---------------------------------------------------------------

var player_status = {
	"vampirism" : {
		"active" : false
	},
	"pedicure" : {
		"active" : false
	},
	"scaryface" : {
		"active" : false,
		"damage" : 1
	},
	"forgery" : {
		"active" : false
	},
	"goodeyes" : {
		"active" : false
	},
	"extralife" : {
		"active" : false
	},
	"bait" : {
		"active" : false
	},
	"slime" : {
		"active" : false
	}
}


# movement delay ---------------------------------------------------------------
var move_timer
var can_move = true
var move_delay = 0.15

# Called when the node enters the scene tree for the first time ----------------
func _ready():
	OS.set_window_size(Vector2(400 * window_scale,300 * window_scale))
	OS.set_window_position(screen_size*0.5 - window_size*0.5)
	get_tree().set_auto_accept_quit(false)
	
	# load settings
	load_data()
	
	# apply loaded settings from save or defaults
	if music_status == "ON":
		AudioServer.set_bus_mute(3, false)
	else:
		AudioServer.set_bus_mute(3, true)
		
	if sfx_status == "ON":
		AudioServer.set_bus_mute(4, false)
	else:
		AudioServer.set_bus_mute(4, true)
		
	if log_status == "ON":
		message_log.visible = true
	else:
		message_log.visible = false
	
	# launch into title screen
	title_setup()

func title_setup():
	AudioServer.set_bus_bypass_effects(1, true)
	
	game_state = "title"
	player_name = "nobody"
	$CanvasLayer/Title.visible = true
	
	# create move delay timer
	move_timer = Timer.new()
	move_timer.set_one_shot(true)
	move_timer.set_wait_time(move_delay)
	move_timer.connect("timeout", self, "on_walk_timeout_complete")
	add_child(move_timer)
	
	# play menu ambience
	play_music(music_sound, snd_menu_amb)

func shop_setup():
	# 0 is first item, 2 is last item
	selected_slot = 0
	$CanvasLayer/Shop/SelectedMarker.position.x = 120 + selected_slot * 80
	
	# TODO:
	# stop gameplay etc., set up controls
	# disable pause etc.
	
	# play shop music
	play_music(music_sound, snd_menu_amb)
	game_state = "shop"
	
	shop_items_values = shop_items.values()
	# choose random items to display in shop
	shop_items_values.shuffle()
		
	# fill slots with items from dictionary, set up titles
	
	$CanvasLayer/Shop/SelectedMarker/AnimationPlayer.play("Bounce")
	$CanvasLayer/Shop/ItemDescription.text = shop_items_values[selected_slot].description
	
	# make shop visible
	shop_update()
	shop_screen.visible = true
	
	# check currently selected
	# for the selected item, allow purchase if enough coins
	# for the selected item, update item description
	
func shop_update():
	# update purchased text
	# update visuals on purchase
	
	$CanvasLayer/Shop/CurrentCoins.text = "Your coins: " + str(coins)

	for i in range (0, 3):
		# reset opacity
		shop_slots[i].modulate = Color(1, 1, 1, 1)
	
		# fill in image, name, description, value
		shop_names[i].text = shop_items_values[i].name + "\n"
		if shop_items_values[i].purchased:
			shop_slots[i].modulate = Color(1, 1, 1, 0.3)
			shop_names[i].text += "Purchased"
		else:
			shop_names[i].text += str(shop_items_values[i].cost)
		shop_slots[i].frame = shop_items_values[i].frame
	return

func select_item(dir):
	# try to select an item left or right from us
	selected_slot += dir
	if selected_slot >= 0 && selected_slot <= 2:
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
	selected_slot = clamp(selected_slot, 0, 2)
	$CanvasLayer/Shop/SelectedMarker.position.x = 120 + selected_slot * 80
	$CanvasLayer/Shop/ItemDescription.text = shop_items_values[selected_slot].description
	return
	
func try_purchase(selected_slot):
	# attempt to purchase item
	if !shop_items_values[selected_slot].purchased:
		if coins > shop_items_values[selected_slot].cost:
			var pos = Vector2(100, 100)
			spawn_label("purchased", 2, pos)
			# TODO: make label work
			
			coins -= shop_items_values[selected_slot].cost
			shop_items_values[selected_slot].purchased = true
			shop_update()
			
			# activate abilities
			var status_to_activate = shop_items_values[selected_slot].name
			match status_to_activate:
				"Vampirism":
					player_status.vampirism.active = true
				"Pedicure":
					player_status.pedicure.active = true
				"Scary Face":
					player_status.scaryface.active = true
				"Forgery":
					player_status.forgery.active = true
				"Good Eyes":
					player_status.goodeyes.active = true
				"Extra Life":
					player_status.extralife.active = true
				"Bait":
					player_status.bait.active = true
				"Slime":
					player_status.slime.active = true
			
		else:
			print("cannot afford")
	else:
		print("already purchased")

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
		play_sfx(level_sound, snd_ui_select, 0.2, 0.4)
		initialize_game()
		
	# quit from main menu
	if game_state == "title" && event.is_action("Quit"):
		save_data()
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
		
	# things we can do on game over
	
	# restart immediately
	if game_state == "lose" && event.is_action("Restart"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		lose_screen.visible = false
		initialize_game()
		return
	
	# back to title
	if game_state == "lose" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		lose_screen.visible = false
		title_setup()
		return
	
	# things we can do on win
	
	# restart immediately
	if game_state == "win" && event.is_action("Restart"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		win_screen.visible = false
		initialize_game()
		return
	
	# back to title
	if game_state == "win" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		win_screen.visible = false
		title_setup()
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
		$CanvasLayer/Pause/Info.text += "Restart\nQuit to Title"
		pause_screen.visible = true
		return
		
	if game_state == "gameplay" && event.is_action("DebugShop"):
		shop_setup()
		
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
		initialize_game()
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
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		pause_screen.visible = false
		title_setup()
		return

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
		
	# things we can do from the credits screen
	
	if game_state == "credits" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
		# back to title
		game_state = "title"
		credits_screen.visible = false
		
	# things we can do in the shop
	
	if game_state == "shop" && event.is_action("ui_left"):
		select_item(-1)
		return
	if game_state == "shop" && event.is_action("ui_right"):
		select_item(1)
		return
		
	if game_state == "shop" && event.is_action("Restart"):
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
		# return to game
		game_state = "gameplay"
		shop_screen.visible = false
		return
		
	if game_state == "shop" && event.is_action("Start"):
		try_purchase(selected_slot)
	
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
	AudioServer.set_bus_bypass_effects(1, true)
	player_hp = PLAYER_START_HP
	$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x
	
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
	coins = 99
	player_dmg = 1

	$CanvasLayer/Win.visible = false
	$CanvasLayer/Lose.visible = false
	$CanvasLayer/Title.visible = false
	
	player_status.vampirism.active = true
	print("vampirism enabled")
	
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
		# if shop
		Tile.ShopGrate:
			shop_setup()
		
		# if floor
		Tile.Floor:
			
			# check if walking in blood
			var has_bloody_feet = false
			for bloodstain in bloodstains:
				if bloodstain.position.x == x * TILE_SIZE && bloodstain.position.y == y * TILE_SIZE:
					has_bloody_feet = true
					# drink blood for hp
					if player_status.vampirism.active == true:
						bloodstains.erase(bloodstain)
						bloodstain.queue_free()
						print("drinking blood")
						var heal_amount = 0
						var pos = player_tile * TILE_SIZE
						if player_hp < max_hp:
							# heal by difference
							heal_amount = min(max_hp - player_hp, blood_health)
							player_hp += heal_amount
							message_log.add_message("You drink the blood. " + str(heal_amount) + " health restored.")
							spawn_label("+" + str(heal_amount), 2, pos)
							$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x * player_hp / max_hp
						else:
							message_log.add_message("You drink the blood. Nothing happens.")
							spawn_label("no effect", 1, pos)
				
			
			# maybe an enemy interaction
			var blocked = false
			for enemy in enemies:
				if enemy.tile.x == x && enemy.tile.y == y:
					enemy.take_damage(enemy, player_dmg)
					# sfx
					play_sfx(player_sound, snd_enemy_hurt, 0.8, 1)
					$Player/ShakeCamera2D.add_trauma(0.5)
					# anim
					if dx < 0:
						player.set_flip_h(true)
					else:
						player.set_flip_h(false)
					player_anims.stop(true)
					player_anims.play("Attack")
					
					if enemy.dead:
						play_sfx(player_sound, snd_enemy_death, 0.8, 1)
						message_log.add_message("You defeat the " + enemy.enemy_name + ".")
						enemy.remove()
						enemies.erase(enemy)
						# bleed on the floor
						# check player kick direction
						# bleed within distance of 3 times the direction
					
						var blood_i = 0
						var blood_x = x
						var blood_y = y
						var bleeding = true
						while bleeding:
							# horizontal bleed
							if dy != 0:
								if tile_map.get_cell(x, blood_y) == Tile.Floor:
									var blood = BloodScene.instance()
									blood.position = Vector2(x, blood_y) * TILE_SIZE
									bloodstains.append(blood)
									add_child(blood)
									blood_y += dy
									blood_i += 1
								else:
									bleeding = false
								
							if dx != 0:
								if tile_map.get_cell(blood_x, y) == Tile.Floor:
									var blood = BloodScene.instance()
									blood.position = Vector2(blood_x, y) * TILE_SIZE
									bloodstains.append(blood)
									add_child(blood)
									blood_x += dx
									blood_i += 1
								else:
									bleeding = false
							if blood_i > 2:
								bleeding = false
								# TODO: "spawn" blood instead
								# TODO: stop splattering once a non-floor object is hit
								# BUG: can't pickup coin inside blood
						
						# for bx in range(x-1, x+2):
						#	for by in range(y-1, y+2):
						#		if tile_map.get_cell(bx, by) == Tile.Floor:
						#			set_tile(bx, by, Tile.Bloody)
						# BUG
						# set_tile(x, y, Tile.Bones)
					else:
						message_log.add_message("You attack the " + enemy.enemy_name + ".")
						
						$CanvasLayer/Score.text = "Score: " + str(score)
					blocked = true
					break
					
			if !blocked:
				player_tile = Vector2(x, y)
				# play walk sound
				if has_bloody_feet:
					play_sfx(player_sound, snd_walk_blood, 0.6, 1)
				else:
					var r = snd_walk[randi() % snd_walk.size()]
					play_sfx(player_sound, r, 0.8, 1)
				# anim
				if dx < 0:
					player.set_flip_h(true)
				else:
					player.set_flip_h(false)
				player_anims.stop(true)
				player_anims.play("PlayerWalk")
				pickup_items()				

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
			# yield(get_tree(), "idle_frame")
			# play door open sound
			play_sfx(level_sound, snd_door_open, 0.9, 1)
			# anim
			if dx < 0:
				player.set_flip_h(true)
			else:
				player.set_flip_h(false)
			player_anims.play("OpenDoor")
			# message_log.add_message("The door opens without a key.")
			
		# if ladder, increase level count, add score, etc.
		Tile.Ladder:
			# play ladder sound
			
			play_sfx(level_sound, snd_ladder, 0.9, 1)
			level_num += 1
			score += 20
			$CanvasLayer/Score.text = "Score: " + str(score)
			if level_num < LEVEL_SIZES.size():
				# go to shop
#				build_level()
				var pos = player_tile * TILE_SIZE
				spawn_label("level completed", 0, pos)
				shop_setup()
			else:
				# no more levels left, you win
				score += 1000
				$CanvasLayer/Win/Score.text = "Score: " + str(score)
				$CanvasLayer/Win.visible = true
				game_state = "end"
			return
			
			
				
	# every enemy tries to move
	
	# TODO: add action phase
	# disable player input
	# run enemy animations, effects, etc.
	# after a timer, allow player input again
	
	for enemy in enemies:
		enemy.act(self)

	call_deferred("update_visuals")

# action phase -----------------------------------------------------------------

func action_phase ():
	return

# item pickup ------------------------------------------------------------------

func pickup_items():
	var remove_queue = []
	for item in items:
		if item.tile == player_tile:
			var pos = player_tile * TILE_SIZE
			
			if item.sprite_node.frame == 16:
				# heart pickup
				play_sfx(level_sound, snd_item_heart, 0.8, 1)
				
				# heal until max_hp
				var heal_amount = 0

				if player_hp < max_hp:
					# heal by difference
					heal_amount = min(max_hp - player_hp, heart_health)
					player_hp += heal_amount
					message_log.add_message("You find a heart! " + str(heal_amount) + " health restored.")
					spawn_label("+" + str(heal_amount), 2, pos)
					$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x * player_hp / max_hp
				else:
					message_log.add_message("You find a heart! Nothing happens.")
					spawn_label("no effect", 1, pos)
				
				score += heart_score

			elif item.sprite_node.frame == 17:
				# potion pickup
				play_sfx(level_sound, snd_item_potion, 0.8, 1)
				if player_hp < max_hp:
					player_hp = max_hp
					message_log.add_message("You drink a potion and restore your full health.")
					# spawn info text
					spawn_label("healed", 2, pos)
					$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x * player_hp / max_hp
				else:
					message_log.add_message("You drink a potion. Nothing happens.")
					# spawn info text
					spawn_label("no effect", 1, pos)
				score += potion_score
			elif item.sprite_node.frame == 18:
				# coin pickup
				coins += coin_value
				score += coin_score
				play_sfx(level_sound, snd_item_coin, 0.8, 1)
				$CanvasLayer/Coins.text = "Coins: " + str(coins)
				message_log.add_message("You find a coin!")
				# spawn info text
				spawn_label("+" + str(coin_value), 4, pos)
			elif item.sprite_node.frame == 20:
				# health upgrade
				
				# increase max health
				max_hp += 10
				if player_hp < max_hp:
					player_hp = max_hp
				
				# TODO: sfx
				play_sfx(level_sound, snd_ui_set, 0.8, 1)
				$CanvasLayer/HP.text = "HP: " + str(player_hp) + " / " + str(max_hp)
				message_log.add_message("You drink from the goblet. Max health +10!")
				$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x * player_hp / max_hp
				# spawn info text
				spawn_label("max +10", 2, pos)
			elif item.sprite_node.frame == 21:
				# power upgrade
				player_dmg += 1
				# TODO: sfx
				play_sfx(level_sound, snd_ui_set, 0.8, 1)
				spawn_label("strength +1", 0, pos)
				message_log.add_message("You find a bracelet! Strength +1!")
			else:
				# generic item sound
				play_sfx(level_sound, snd_ui_set, 0.8, 1)
				message_log.add_message("Something unknown collected...")
			
			item.remove()
			remove_queue.append(item)
		
	for item in remove_queue:
		items.erase(item)
	

# function to generate and build level -----------------------------------------

func build_level():
	
	# start with blank map
	rooms.clear()
	map.clear()
	tile_map.clear()
	
	# clean up all that blood
	for bloodstain in bloodstains:
		bloodstain.queue_free()
	bloodstains.clear()
	
	# remove enemies
	for enemy in enemies:
		enemy.remove()
	enemies.clear()
	
	# remove items
	for item in items:
		item.remove()
	items.clear()
	
	# set up enemy pathfinding
	enemy_pathfinding = AStar.new()
	
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
	
	# yield(get_tree(), "idle_frame")
	call_deferred("update_visuals")
	
	# place end ladder
	
	var end_room = rooms.back()
	var ladder_x = end_room.position.x + 1 + randi() % int(end_room.size.x - 2)
	var ladder_y = end_room.position.y + 1 + randi() % int(end_room.size.y - 2)
	set_tile(ladder_x, ladder_y, Tile.Ladder)
	
	# place shop
	
	randomize()
	var shopchance = randi() % 100
	if shopchance > 50:
		var shop_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
		var shop_y = start_room.position.y
		if tile_map.get_cell(shop_x, shop_y) != Tile.Door:
			set_tile(shop_x, shop_y, Tile.ShopGrate)
	
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
				print("enemy tried to spawn on ladder")
				break
			
		if !blocked:
			var enemy = Enemy.new(self, randi() % (level_num + 1), enemy_x, enemy_y)
			enemies.append(enemy)
			
	# place items
	
	var num_items = LEVEL_ITEM_COUNT[level_num]
	for i in range(num_items):
		var room = rooms[randi() % (rooms.size())]
		var x = room.position.x + 1 + randi() % int(room.size.x - 2)
		var y = room.position.y + 1 + randi() % int(room.size.y - 2)
		var r = randi() % 100
		if r >= 70:
			items.append(Item.new(self, x, y, 16))
		else:
			items.append(Item.new(self, x, y, 18))
	
	randomize()
	
	var num_powers = LEVEL_POWERUP_COUNT[level_num]
	if num_powers > 0:
		for i in range(num_powers):
			var room = rooms[1 + randi() % (rooms.size() - 1)]
			var x = room.position.x + 1 + randi() % int(room.size.x - 2)
			var y = room.position.y + 1 + randi() % int(room.size.y - 2)
			var r = randi() % 100
			if r >= 50:
				items.append(Item.new(self, x, y, 20))
			else:
				items.append(Item.new(self, x, y, 21))
	
	call_deferred("update_visuals")

	
	# update ui
	if level_num > 0:
		$CanvasLayer/Level.text = "Basement Level " + str(level_num)
		message_log.add_message("You enter level " + str(level_num) + " of the dungeon.")
	else:
		$CanvasLayer/Level.text = "Ground Floor"
		message_log.add_message("You enter the ground floor.")

# visibility -------------------------------------------------------------------

# states: visible, explored, unexplored
# explored is everything that was ever visible at any point
# unexplored is the default state, was never visible

func update_visuals():
	# convert tile coords into pixel coords
	
	# yield(get_tree(), "idle_frame")
	player.position = player_tile * TILE_SIZE

	# assuming we're not inside a room
	for x in range(level_size.x):
		for y in range(level_size.y):
			# explored
			if exploration_map.get_cell(x, y) == ExplTile.Explored:
				visibility_map.set_cell(x, y, VisTile.Shaded)
			else:
				visibility_map.set_cell(x, y, VisTile.Dark)
			
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
	
	# update enemy sprite positions
	
	# empty list of enemies
	var enemies_spotted = []
	
	for enemy in enemies:
		enemy.sprite_node.position = enemy.tile * TILE_SIZE
		# if enemy isn't already visible
		if !enemy.sprite_node.visible:
			var occlusion = true
			if visibility_map.get_cell(enemy.tile.x, enemy.tile.y) == -1:
				occlusion = false
			if !occlusion:
				# turn node visibility on
				enemy.sprite_node.visible = true
				spawn_label("!", 3, enemy.sprite_node.position)
				# add to count of enemies that spotted you
				enemies_spotted.append(enemy.enemy_name)
				if player_status.scaryface.active == true:
					enemy.take_damage(self, player_status.scaryface.damage)
				
	if enemies_spotted.size() > 0:
		# create dictionary of enemies in room
		var enemy_counts = {}
		
		for enemy in enemies_spotted:
			enemy_counts[enemy] = enemies_spotted.count(enemy)
			
		# assemble this most complex of messages...
		# key is the type of enemy as a string
		# uniques is the number of unique enemy types
		# thismany is the number of instances of that type
			
		var uniques = enemy_counts.size()
		
		var spotted_message = "You were spotted by"
		
		var count_i = 0
		for key in enemy_counts:
			count_i += 1
			var thismany = enemy_counts[key]
			if thismany == 1:
				spotted_message += " a " + key
			else:
				spotted_message += " " + str(thismany) + " " + key
			if thismany > 1:
				spotted_message += "s"
			if count_i < uniques && uniques >= 3:
				spotted_message += ","
			if uniques > 1 && count_i == (uniques - 1):
				spotted_message += " and"
			if count_i == uniques:
				spotted_message += "."

		message_log.add_message(spotted_message)
		if player_status.scaryface.active == true:
			message_log.add_message("Your face scared them a little.")
			# TODO: scary face isn't working properly, hp bar goes missing?
			
	# show and hide items
	
	for item in items:
		item.sprite_node.position = item.tile * TILE_SIZE
		# it item isn't already visible
		var occlusion = true
		if visibility_map.get_cell(item.tile.x, item.tile.y) == -1:
			occlusion = false
		if !occlusion:
			# turn node visibility on
			item.sprite_node.visible = true
		else:
			item.sprite_node.visible = false
				
	$CanvasLayer/HP.text = "HP: " + str(player_hp) + " / " + str(max_hp)
	$CanvasLayer/Score.text = "Score: " + str(score)

func clear_path(tile):
	var new_point = enemy_pathfinding.get_available_point_id()
	enemy_pathfinding.add_point(new_point, Vector3(tile.x, tile.y, 0))
	var points_to_connect = []
	
	if tile.x > 0 && map[tile.x - 1][tile.y] == Tile.Floor:
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector3(tile.x - 1, tile.y, 0)))
	if tile.y > 0 && map[tile.x][tile.y - 1] == Tile.Floor:
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector3(tile.x, tile.y - 1, 0)))
	if tile.x < level_size.x - 1 && map[tile.x + 1][tile.y] == Tile.Floor:
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector3(tile.x + 1, tile.y, 0)))
	if tile.y < level_size.y - 1 && map[tile.x][tile.y + 1] == Tile.Floor:
		points_to_connect.append(enemy_pathfinding.get_closest_point(Vector3(tile.x, tile.y + 1, 0)))
		
	for point in points_to_connect:
		enemy_pathfinding.connect_points(point, new_point)

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
	
	# clear path for pathfinding if we're changing to floor
	if type == Tile.Floor:
		clear_path(Vector2(x, y))

# player taking damage= --------------------------------------------------------
func damage_player(dmg, me):
	player_hp = max(0, player_hp - dmg)
	message_log.add_message(me.enemy_name + " attacks you for " + str(dmg) + " damage!")
	$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x * player_hp / max_hp
	if player_hp == 0:
		lose_screen.visible = true
		var death_area = ""
		if (level_num) == 0:
			death_area = "the ground floor"
		else:
			death_area = "level " + str(level_num)
		
		$CanvasLayer/Lose/Score.text = "Score: " + str(score)
		$CanvasLayer/Lose/DeathMsg.text = "You were slain by a " + me.enemy_name + " in\n"
		$CanvasLayer/Lose/DeathMsg.text += death_area + " of the terrible basement."
		game_state = "lose"
		
# floating label spawner -------------------------------------------------------

func spawn_label(text, color, pos):
	var label = FloatLabelScene.instance()
	add_child(label)
	label.set_label_text(text, color)
	label.position = pos + Vector2(randi() % 5, randi() % 5)

# name generators --------------------------------------------------------------

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
	
func save_data():
	# save dictionary of settings
	
	var data = {
		"setting_music": music_status,
		"setting_sfx": sfx_status,
		"setting_log": log_status,
	}
	
	var file = File.new()
	var error = file.open(save_path, File.WRITE)
	if error == OK:
		file.store_var(data)
		file.close()
		print("saved data")
	else:
		print("error occured on save... sorry...")
		
func load_data():
	# load settings from save data
	
	var file = File.new()
	
	if file.file_exists(save_path):
		var error = file.open(save_path, File.READ)
		if error == OK:
			var player_data = file.get_var()
			file.close()
			print("loaded data")
			
			music_status = player_data.setting_music
			sfx_status = player_data.setting_sfx
			log_status = player_data.setting_log
		else:
			print("error occured on load... oopsie...")
	

# on quit request
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_data()
		get_tree().quit()

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
