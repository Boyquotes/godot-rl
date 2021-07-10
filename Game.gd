extends Node2D

# constants for level generation -----------------------------------------------

const TILE_SIZE = 10

const LEVEL_SIZES = [
	Vector2(28, 20),
	Vector2(30, 22),
	Vector2(32, 24),
	Vector2(34, 26),
	Vector2(36, 28),
	Vector2(38, 30),
	Vector2(40, 32)
]

const LEVEL_ROOM_COUNT = [4, 5, 7, 8, 9, 9, 9, 9, 9 , 9, 9, 9, 9, 9]
const LEVEL_ENEMY_COUNT = [3, 5, 7, 9, 11, 12, 15, 15, 15, 15, 15, 15, 15, 15]
const LEVEL_ITEM_COUNT = [0, 1, 2, 2, 3, 4, 4, 4, 4, 4, 2, 1, 0, 0]
const LEVEL_POWERUP_COUNT = [0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 0]
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 9
const PLAYER_START_HP = 5

# cheat settings
var can_take_damage = true

# item values
var coin_value = 1
var coin_score = 10
var heart_health = 3
var blood_health = 1
var heart_score = 10
var potion_score = 20

const STATUS_EFFECTS = ["heal_once", "heal_over_time", "poison"]

const EnemyScene = preload("res://Enemy.tscn")
const ItemScene = preload("res://Item.tscn")
const StatusIconScene= preload("res://StatusIcon.tscn")
const FloatLabelScene = preload("res://FloatLabel.tscn")
const BloodScene = preload("res://Blood.tscn")
const SlimeScene = preload("res://Slime.tscn")
const BloodParticles = preload("res://BloodParticles.tscn")

var name_parts = "..bobabukekogixaxoxurirero"
var name_titles = ["of The Valley", "of The Woodlands", "The Unknowable", "The Warrior", "The Knight", "The Brave", "The Foolish", "The Forsaken", "The Idiot", "The Smelly", "The Sticky", "Smith", "The Thief", "The Rogue", "The Unseen", "The Drifter", "The Dweller", "The Lurker", "The Small", "The Unforgiven", "The Crestfallen", "The Hungry", "The Second Oldest", "The Younger", "The Original"]

var interlude_options = ["A cold gust of wind dances around you as you descend.", "Your strong conviction leads you deeper into the basement.", "The pull of the artifact gives you the strength to keep going. You climb further down.", "You smell the damp moss in the crevices around you.", "Climbing down the ladder, you are greeted by a foul stench.", "You climb deeper into what rots below.", "Despite what everyone back in town suspected, you survive another level.", "Careful not to slip on the old broken steps, you journey deeper into the basement.", "You hear faint grunts and breathing. There is something waiting for you, unseen in the dark.", "You feel as though the walls are shifting. Still, you press on.", "You descend deeper into the terrible basement.", "Climbing down the slippery steps, you sense that you may just survive this gruesome adventure.", "For a moment, you feel as though you are hearing voices coming from the walls. Surely you are imagining things."]
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
const snd_music_death = preload("res://sound/music-death.wav")
const snd_music_intro = preload("res://sound/music-intro.wav")
const snd_ui_select = preload("res://sound/ui-select.wav")
const snd_ui_back = preload("res://sound/ui-back.wav")
const snd_ui_set = preload("res://sound/ui-set.wav")
const snd_item_coin = preload("res://sound/item-coin.wav")
const snd_item_potion = preload("res://sound/item-potion.wav")
const snd_item_heart = preload("res://sound/item-heart.wav")
const snd_purchase = preload("res://sound/purchase.wav")

var snd_walk = [snd_walk1, snd_walk2, snd_walk3]

var lowpass = AudioServer.get_bus_effect(1, 0)

var music_status = "ON"
var sfx_status = "ON"
var log_status = "ON"

# item class -------------------------------------------------------------------

class Item extends Reference:
	var sprite_node
	var tile

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
	var possible_types = ["Boblin", "Bibi", "Nana", "Spectral Thing", "Ravaging Thing", "Baddie", "Demon Guy"]
	var enemy_name
	var sprite_node
	var tile
	var full_hp
	var hp
	var dead = false

	func _init(game, enemy_level, x, y):
		full_hp = 1 + enemy_level
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
		
		sprite_node.get_node("AnimationPlayer").play("Hurt")
		
		var pos = sprite_node.position
		game.spawn_label("-" + str(dmg), 0, pos)
		
		if hp == 0:
			dead = true
			game.score += 10 * full_hp
			
			# drop item
			
			var r = randi() % 100
			
			if r >= 95:
				# drop a potion
				game.items.append(Item.new(game, tile.x, tile.y, 17))
			elif r >= 75:
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
				if game.can_take_damage:
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
					
					# check if in slime
					if game.player_status.slime.active == true:
						var slimed = true
						for slimestain in game.slimestains:
							if slimestain.position.x == tile.x * TILE_SIZE && slimestain.position.y == tile.y * TILE_SIZE:
								take_damage(game, 1)
								# TODO: make this work properly
								# sfx
								# game.play_sfx(game.player_sound, snd_enemy_hurt, 0.8, 1)

								if self.dead:
									# play sound
									game.play_sfx(game.player_sound, snd_enemy_death, 0.8, 1)
									game.message_log.add_message("The " + self.enemy_name + " is slimed to death.")
									self.remove()
									game.enemies.erase(self)
									# spawn blood particles
									var particles = BloodParticles.instance()
									particles.position = Vector2(self.tile.x + 0.2, self.tile.y + 0.2) * TILE_SIZE
									game.add_child(particles)
								else:
									# not dying but getting hurt
									game.play_sfx(game.player_sound, snd_enemy_hurt, 0.8, 1)

# current level data -----------------------------------------------------------

var level_num = 0
var level_progress = 0
var map = []
var rooms = []
var enemies = []
var items = []
var bloodstains = []
var slimestains = []
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
onready var intro_screen = $CanvasLayer/IntroScreens
onready var settings_screen = $CanvasLayer/Settings
onready var pause_screen = $CanvasLayer/Pause
onready var credits_screen = $CanvasLayer/Credits
onready var lose_screen = $CanvasLayer/Lose
onready var win_screen = $CanvasLayer/Win
onready var true_win_screen = $CanvasLayer/TrueWin
onready var shop_screen = $CanvasLayer/Shop
onready var interlude_screen = $CanvasLayer/InterludeScreen

onready var shop_slots = [$CanvasLayer/Shop/Slot1, $CanvasLayer/Shop/Slot2, $CanvasLayer/Shop/Slot3]
onready var shop_names = [$CanvasLayer/Shop/Slot1/Name, $CanvasLayer/Shop/Slot2/Name, $CanvasLayer/Shop/Slot3/Name]
onready var intro_screens = [$CanvasLayer/IntroScreens/first, $CanvasLayer/IntroScreens/second, $CanvasLayer/IntroScreens/third]

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
var player_start_pos

# intro ------------------------------------------------------------------------

var intro_state = 0
var intro_timer
var intro_input = true
var intro_delay = 0.15

# shop -------------------------------------------------------------------------

var shop_items = {}

var selected_item_name
var selected_slot
var shop_items_values
var shop_visited
var extralife_used

var shop_icons = []

# status effects ---------------------------------------------------------------

var player_status = {}

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
	
	# create intro timer
	intro_timer = Timer.new()
	intro_timer.set_one_shot(true)
	intro_timer.set_wait_time(intro_delay)
	intro_timer.connect("timeout", self, "on_intro_timeout_complete")
	add_child(intro_timer)
	
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
	# play_music(music_sound, snd_menu_amb)
	game_state = "shop"
	
	# choose random items to display in shop
	if !shop_visited:
		shop_items_values = shop_items.values()
		shop_items_values.shuffle()
		
	# BUG: on second view of shop, items always in default order
		
	# fill slots with items from dictionary, set up titles
	
	$CanvasLayer/Shop/SelectedMarker/AnimationPlayer.play("Bounce")
	$CanvasLayer/Shop/ItemDescription.text = shop_items_values[selected_slot].description
	
	# make shop visible
	shop_update()
	shop_screen.visible = true
	
	# shop only shuffles once per level
	shop_visited = true
	
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
	
func try_purchase(selection):		
	
	# attempt to purchase item
	if !shop_items_values[selection].purchased:
		# check if we have enough coins
		if coins >= shop_items_values[selection].cost:
			var pos = Vector2(100, 100)
			
			if shop_items_values[selection].name == "BAD GOBLET":
				$CanvasLayer/Shop/ItemDescription.text = "You... the goblet??? Impossible!!!"
			else:
				$CanvasLayer/Shop/ItemDescription.text = "Nice choice... good luck...... heh"
			# TODO: make label work
			
			coins -= shop_items_values[selection].cost
			shop_items_values[selection].purchased = true
			play_sfx(level_sound, snd_purchase, 0.9, 1)
			shop_update()
			
			# activate abilities
			var status_to_activate = shop_items_values[selection].name
			match status_to_activate:
				"Vampirism":
					player_status.vampirism.active = true
				"Pedicure":
					player_status.pedicure.active = true
					# increase strength
					player_dmg += 2
				"Scary Face":
					player_status.scaryface.active = true
				"Forgery":
					player_status.forgery.active = true
					# raise coin_value
					coin_value = 5
				"Good Eyes":
					player_status.goodeyes.active = true
				"Extra Life":
					player_status.extralife.active = true
				"Bait":
					player_status.bait.active = true
				"Slime":
					player_status.slime.active = true
				"BAD GOBLET":
					player_status.badgoblet.active = true
			
		else:
			$CanvasLayer/Shop/ItemDescription.text = "You cannot afford that right now."
	else:
		$CanvasLayer/Shop/ItemDescription.text = "You have already purchased that."
		
	update_icons()

func update_icons():
	var icon_x = 0
	for item in shop_items:
		if shop_items[item].purchased == true:
			var iconpos = Vector2(icon_x, 0)
			var icon = StatusIconScene.instance()
			icon.position = iconpos
			icon.frame = shop_items[item].icon
			shop_icons.append(icon)
			$CanvasLayer/StatusIcons.add_child(icon)
			icon_x += 12
			
# fires when walk timer has timed out
func on_walk_timeout_complete():
	can_move = true
	
# fires when intro timer has timed out
func on_intro_timeout_complete():
	intro_input = true
	
# input event handler
func _input(event):
	if !event.is_pressed():
		return
		
	# cheat codes
	
	if event.is_action("Cheat1"):
		# invincible
		can_take_damage = !can_take_damage
		message_log.add_message("CHEAT: taking damage " + str(can_take_damage))
		play_sfx(player_sound, snd_item_coin, 0.4, 0.5)
	if event.is_action("Cheat2"):
		# skip level
		play_sfx(level_sound, snd_ladder, 0.9, 1)
		message_log.add_message("CHEAT: skipping level")
		next_level()
	if event.is_action("Cheat3"):
		coins += 100
		$CanvasLayer/Coins.text = "Coins: " + str(coins)
		message_log.add_message("CHEAT: $$$")
		play_sfx(player_sound, snd_item_coin, 0.4, 0.5)
	# things we can do in title screen
	
	# start the game
	if game_state == "title" && event.is_action("Start"):
		game_state = "intro"
		intro_setup()
		play_sfx(level_sound, snd_ui_select, 0.2, 0.4)
		# TODO: BUG: DOM: here, make this work
		
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
		
	# things we can do in the intro
	
	if game_state == "intro" && event.is_action("Start") && intro_input:
		intro_input = false
		intro_timer.start()
		if intro_state < intro_screens.size() - 1:
			# either go to next slide
			intro_state += 1
			intro_screens[intro_state].visible = true
		else:
			# or start game
			
			# reset intro state
			intro_screens[0].visible = false
			intro_screens[1].visible = false
			intro_screens[2].visible = false
			intro_state = 0
			$CanvasLayer/IntroScreens.visible = false
			initialize_game()
		play_sfx(level_sound, snd_ui_select, 0.2, 0.4)
		
		return
		
	# things we can do in the interlude
	
	if game_state == "interlude" && event.is_action("Start"):
		# go into game
		play_sfx(level_sound, snd_ui_select, 0.2, 0.4)
		game_state = "gameplay"
		interlude_screen.visible = false
		build_level()
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
		
	# things we can do on win
	
	# restart immediately
	if game_state == "truewin" && event.is_action("Restart"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		true_win_screen.visible = false
		initialize_game()
		return
	
	# back to title
	if game_state == "truewin" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_select, 0.3, 0.4)
		true_win_screen.visible = false
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
		
	if game_state == "shop" && event.is_action("Escape"):
		play_sfx(level_sound, snd_ui_back, 0.9, 1)
		# return to game
		if player_status.badgoblet.active == true:
			# TRUE WIN
			score += 1999
			$CanvasLayer/TrueWin/Score.text = "Score: " + str(score)
			$CanvasLayer/TrueWin.visible = true
			game_state = "truewin"
		else:
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

# show the intro cutscene ------------------------------------------------------

func intro_setup():
	play_music(music_sound, snd_music_intro)
	intro_input = false
	intro_timer.start()
	$CanvasLayer/Title.visible = false
	intro_screen.visible = true
	intro_state = 0
	intro_screens[intro_state].visible = true
	
# show intermediate cutscene ---------------------------------------------------

func interlude_setup():
	game_state = "interlude"
	interlude_screen.visible = true
	randomize()
	var r = interlude_options[randi() % interlude_options.size()]
	$CanvasLayer/InterludeScreen/InterludeText.text = r
	# waiting for input

# function to initialize / restart the entire game -----------------------------

func initialize_game():
	AudioServer.set_bus_bypass_effects(1, true)
	player_hp = PLAYER_START_HP
	$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x
	refresh_hp()
	
	game_state = "gameplay"
	
	# clear message log
	message_log.messages.clear()
	
	stop_sound(music_sound)
	play_music(music_sound, snd_music1)
	
	player_name = get_name() + " " + get_title()
	$CanvasLayer/Name.text = player_name

	randomize()
	level_num = 0
	level_progress = 0
	score = 0
	coins = 0
	player_dmg = 1
	coin_value = 1
	
	$CanvasLayer/Coins.text = "Coins: " + str(coins)
	

	$CanvasLayer/Win.visible = false
	$CanvasLayer/Lose.visible = false
	$CanvasLayer/Title.visible = false
	
	# hide all power up icons
	
	for icon in shop_icons:
		icon.queue_free()
	shop_icons.clear()
	
	status_setup()
	
	# make sure all player statuses are turned off
	
#	player_status.vampirism.active = true
#	player_status.scaryface.active = true
#	player_status.forgery.active = true
#	print("debug status effects enabled!")
#	player_status.slime.active = true

	update_icons()
	
	build_level()
	
func status_setup():
	# status effects
	player_status = {
		"vampirism" : {
			"active" : false
		},
		"pedicure" : {
			"active" : false,
			"damage" : 2
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
		},
		"badgoblet" : {
			"active" : false
		}
	}
	
	# shop items
	shop_items = {
		"vampirism" : {
			"name" : "Vampirism",
			"cost" : 13,
			"purchased" : false,
			"description" : "Drink blood to gain health",
			"frame" : 56,
			"icon" : 208
		},
		"pedicure" : {
			"name" : "Pedicure",
			"cost" : 10,
			"purchased" : false,
			"description" : "Improves kick strength by 2",
			"frame" : 57,
			"icon" : 209
		},
		"scaryface" : {
			"name" : "Scary Face",
			"cost" : 7,
			"purchased" : false,
			"description" : "Enemies lose 1 health when they spot you",
			"frame" : 58,
			"icon" : 210
		},
		"forgery" : {
			"name" : "Forgery",
			"cost" : 5,
			"purchased" : false,
			"description" : "Coins have 5x their normal value",
			"frame" : 59,
			"icon" : 211
		},
#		"goodeyes" : {
#			"name" : "Good Eyes",
#			"cost" : 10,
#			"purchased" : false,
#			"description" : "DOES NOT WORK! Find better items",
#			"frame" : 60,
#			"icon" : 212
#		},
		"extralife" : {
			"name" : "Extra Life",
			"cost" : 5,
			"purchased" : false,
			"description" : "Upon dying, restart level at full health",
			"frame" : 61,
			"icon" : 213
		},
		"badgoblet" : {
			"name" : "BAD GOBLET",
			"cost" : 99,
			"purchased" : false,
			"description" : "This is what you came here for",
			"frame" : 63,
			"icon" : 213
		}
#		"bait" : {
#			"name" : "Bait",
#			"cost" : 3,
#			"purchased" : false,
#			"description" : "DOES NOT WORK! Spawn more enemies",
#			"frame" : 62,
#			"icon" : 214
#		},
#		"slime" : {
#			"name" : "Slime",
#			"cost" : 20,
#			"purchased" : false,
#			"description" : "Leave a toxic trail that hurts enemies",
#			"frame" : 63,
#			"icon" : 215
#		}
	}
	
	shop_items_values = shop_items.values()
			
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
			# only allow this when approaching from bottom
			if dy == -1:
				shop_setup()
			return
		
		# if floor
		Tile.Floor:
			
			# check if walking in blood
			var has_bloody_feet = false
			var has_slimy_feet = false
			for bloodstain in bloodstains:
				if bloodstain.position.x == x * TILE_SIZE && bloodstain.position.y == y * TILE_SIZE:
					has_bloody_feet = true
					# drink blood for hp
					if player_status.vampirism.active == true:
						bloodstains.erase(bloodstain)
						bloodstain.queue_free()
						var heal_amount = 0
						var pos = player_tile * TILE_SIZE
						if player_hp < max_hp:
							# heal by difference
							heal_amount = min(max_hp - player_hp, blood_health)
							player_hp += heal_amount
							message_log.add_message("You drink the blood. " + str(heal_amount) + " health restored.")
							spawn_label("+" + str(heal_amount), 2, pos)
							refresh_hp()
						else:
							message_log.add_message("You drink the blood. Nothing happens.")
							spawn_label("no effect", 1, pos)
				
			for slimestain in slimestains:
				if slimestain.position.x == x * TILE_SIZE && slimestain.position.y == y * TILE_SIZE:
					has_slimy_feet = true
			
			# maybe an enemy interaction
			var blocked = false
			for enemy in enemies:
				if enemy.tile.x == x && enemy.tile.y == y:
					enemy.take_damage(self, player_dmg)
					
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
						
						# spawn blood particles
						var particles = BloodParticles.instance()
						particles.position = Vector2(enemy.tile.x + 0.2, enemy.tile.y + 0.2) * TILE_SIZE
						add_child(particles)
					
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
					else:
						message_log.add_message("You attack the " + enemy.enemy_name + ".")
						
						$CanvasLayer/Score.text = "Score: " + str(score)
					blocked = true
					break
					
			if !blocked:

				# leave slime trail where we were
				if player_status.slime.active == true:
					# place one if there isn't one already
					
					var hasslime = false
					for check in slimestains:
						if check.position == player_tile * TILE_SIZE:
							hasslime = true
					if !hasslime:
						var slime = SlimeScene.instance()
						slime.position = player_tile * TILE_SIZE
						slimestains.append(slime)
						add_child(slime)
							
				# move
				player_tile = Vector2(x, y)
					
				# play walk sound
		
				if has_bloody_feet:
					play_sfx(player_sound, snd_walk_blood, 0.6, 1)
				elif has_slimy_feet:
					play_sfx(player_sound, snd_walk_blood, 0.4, 0.6)
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
			
			next_level()
			return
			
			
				
	# every enemy tries to move or attack
	
	for enemy in enemies:
		enemy.act(self)

	call_deferred("update_visuals")

func refresh_hp():
	# update hp bar
	$CanvasLayer/HPBar.rect_size.x = $CanvasLayer/HPBarEmpty.rect_size.x * player_hp / max_hp
	$CanvasLayer/HP.text = "HP: " + str(player_hp) + " / " + str(max_hp)
	
	# color hp bar based on current health
	var hpsplit = ceil(max_hp / 2.0)
	if player_hp < hpsplit:
		$CanvasLayer/HPBar.color = Color("b11616")
	else:
		$CanvasLayer/HPBar.color = Color("3b632a")
		

func next_level():
	score += 20
	$CanvasLayer/Score.text = "Score: " + str(score)
	if level_num < LEVEL_SIZES.size():
		
		## infinite?
		level_num += 1
		
		
#			else:
#				# no more levels left, you win
#				score += 1000
#				$CanvasLayer/Win/Score.text = "Score: " + str(score)
#				$CanvasLayer/Win.visible = true
#				game_state = "win"

	# increase true level progress
	level_progress += 1	
#	var pos = player_tile * TILE_SIZE
#	spawn_label("level completed", 0, pos)
	interlude_setup()

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
					refresh_hp()
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
					refresh_hp()
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
				message_log.add_message("You drink from the goblet. Max health +10!")
				refresh_hp()
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
	
	# make sure player isn't dead
	player_anims.play("Idle")
	
	# start with blank map
	rooms.clear()
	map.clear()
	tile_map.clear()
	
	extralife_used = false
	shop_visited = false
	
	# clean up all that blood
	for bloodstain in bloodstains:
		bloodstain.queue_free()
	bloodstains.clear()
	
	# remove slime too
	for slimestain in slimestains:
		slimestain.queue_free()
	slimestains.clear()
	
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
	if level_num < LEVEL_SIZES.size():
		level_size = LEVEL_SIZES[level_num]
	else:
		level_size = LEVEL_SIZES[LEVEL_SIZES.size() - 1]
	
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
	for _i in range(num_rooms):
		add_room(free_regions)
		if free_regions.empty():
			break
			
	connect_rooms()
	
	# place player
	
	var start_room = rooms.front()
	var player_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
	var player_y = start_room.position.y + 1 + randi() % int(start_room.size.y - 2)
	
	player_start_pos = Vector2(player_x, player_y)
	player_tile = player_start_pos
	
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
	# TODO: spawn shop only if we have enough coins?
	# also only in higher levels
	if coins > 3 && shopchance > 60:
		var shop_x = start_room.position.x + 1 + randi() % int(start_room.size.x - 2)
		var shop_y = start_room.position.y
		if tile_map.get_cell(shop_x, shop_y) != Tile.Door:
			set_tile(shop_x, shop_y, Tile.ShopGrate)
			if shopchance > 75:
				var shop_dialogue = randi() % 3
				if shop_dialogue == 0:
					spawn_label("hey...", 1, Vector2(shop_x, shop_y) * TILE_SIZE)
				if shop_dialogue == 1:
					spawn_label("in here...", 1, Vector2(shop_x, shop_y) * TILE_SIZE)
				if shop_dialogue == 2:
					spawn_label("need some wares?", 1, Vector2(shop_x, shop_y) * TILE_SIZE)
				if shop_dialogue == 3:
					spawn_label("nice coins...", 1, Vector2(shop_x, shop_y) * TILE_SIZE)
	
	# place enemies
	
	var num_enemies = LEVEL_ENEMY_COUNT[level_num]
	for _i in range(num_enemies):
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
				# this makes sure enemies won't spawn on ladders
				break
			
		if !blocked:
			var enemychoose = clamp(level_num, 0, LEVEL_SIZES.size() - 1)
			var enemy = Enemy.new(self, randi() % (enemychoose + 1), enemy_x, enemy_y)
			enemies.append(enemy)
			
	# place items
	
	var num_items = LEVEL_ITEM_COUNT[level_num] + 2
	for _i in range(num_items):
		var room = rooms[randi() % (rooms.size())]
		var x = room.position.x + 1 + randi() % int(room.size.x - 2)
		var y = room.position.y + 1 + randi() % int(room.size.y - 2)
		var r = randi() % 100
		if r >= 70:
			items.append(Item.new(self, x, y, 16))
		else:
			items.append(Item.new(self, x, y, 18))
	
	randomize()
	
	# TODO: powerups
#	var num_powers = LEVEL_POWERUP_COUNT[level_num]
#	if num_powers > 0:
#		for _i in range(num_powers):
#			var room = rooms[1 + randi() % (rooms.size() - 1)]
#			var x = room.position.x + 1 + randi() % int(room.size.x - 2)
#			var y = room.position.y + 1 + randi() % int(room.size.y - 2)
#			var r = randi() % 100
#			if r >= 50:
#				items.append(Item.new(self, x, y, 20))
#			else:
#				items.append(Item.new(self, x, y, 21))
	
	# show level complete text
	
#	if level_num > 0:
#		var pos = player_tile * TILE_SIZE
#		spawn_label("level completed", 0, pos)
	
	call_deferred("update_visuals")

	
	# update ui
	if level_num > 0:
		$CanvasLayer/Level.text = "Basement Level " + str(level_progress)
		message_log.add_message("You enter level " + str(level_progress) + " of the dungeon.")
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
	
	# if we're encountering multiple enemies
	var enemies_to_remove = []
	
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
				
				
				if player_status.scaryface.active == true:
					enemy.take_damage(self, player_status.scaryface.damage)
					# check if this kills them
					if enemy.dead:
						# add to removal list
						enemies_to_remove.append(enemy)
						for bx in range(enemy.tile.x - 1, enemy.tile.x + 2):
							for by in range(enemy.tile.y - 1, enemy.tile.y + 2):
								if tile_map.get_cell(bx, by) == Tile.Floor:
									var blood = BloodScene.instance()
									blood.position = Vector2(bx, by) * TILE_SIZE
									bloodstains.append(blood)
									add_child(blood)
						# spawn blood particles
						var particles = BloodParticles.instance()
						particles.position = Vector2(enemy.tile.x + 0.2, enemy.tile.y + 0.2) * TILE_SIZE
						add_child(particles)
					else:
						# not dying but getting hurt
						play_sfx(player_sound, snd_enemy_hurt, 0.8, 1)
					
				spawn_label("!", 3, enemy.sprite_node.position)
				
				# add to count of enemies that spotted you
				enemies_spotted.append(enemy.enemy_name)
	
	# remove exploded enemies
	
	if enemies_to_remove.size() > 0:
		play_sfx(player_sound, snd_enemy_death, 0.4, 0.5)
	
	for enemy in enemies_to_remove:
		enemy.remove()
		enemies.erase(enemy)
	enemies_to_remove = []
				
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
	
	# play hurt anim
	player_anims.stop(true)
	player_anims.play("Hurt")
	
	player_hp = max(0, player_hp - dmg)
	message_log.add_message(me.enemy_name + " attacks you for " + str(dmg) + " damage!")
	refresh_hp()
	if player_hp == 0:
		
		# TODO: move enemies back and reset the level?
		
		# extra life check
		if player_status.extralife.active && !extralife_used:
			# move back to start
			player_tile = player_start_pos
			player_hp = max_hp
			extralife_used = true
			var pos = player_tile * TILE_SIZE
			spawn_label("resurrected", 2, pos)
			refresh_hp()
			update_visuals()
		
		else:
			# die for real
			player_anims.play("Dead")
			play_music(music_sound, snd_music_death)
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
	for _i in range(pairs):
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


func _on_PlayerAnims_animation_finished(anim_name):
	if anim_name == "Hurt":
		player_anims.stop(true)
		player_anims.play("Idle")
