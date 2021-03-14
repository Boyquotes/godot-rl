extends Node2D

# constants for level generation -----------------------------------------------

const TILE_SIZE = 10

const LEVEL_SIZES = [
	Vector2(80, 80),
	Vector2(40, 40),
	Vector2(50, 50),
]

const LEVEL_ROOM_COUNT = [5, 7, 9, 12, 15]
const MIN_ROOM_DIMENSION = 5
const MAX_ROOM_DIMENSION = 8

# enum to get tiles by index ---------------------------------------------------
enum Tile {Player, Stone, Floor, Ladder, Wall, Door}

# current level data -----------------------------------------------------------

var level_num = 0
var map = []
var rooms = []
var level_size

# references to commonly used nodes --------------------------------------------
# ref via scene node name, onready to reference only after setup

onready var tile_map = $TileMap
onready var player = $Player

# TODO: set up player object

# game states ------------------------------------------------------------------

var player_tile
var score = 0

# Called when the node enters the scene tree for the first time ----------------
func _ready():
	OS.set_window_size(Vector2(400,300))
	randomize()
	build_level()

# function to generate and build level -----------------------------------------

func build_level():
	# start with blank map
	rooms.clear()
	map.clear()
	tile_map.clear()
	
	# look up size of this level
	level_size = LEVEL_SIZES[level_num]
	
	# make everything start as stone
	for x in range(level_size.x):
		map.append([])
		for y in range(level_size.y):
			map[x].append(Tile.Stone)
			tile_map.set_cell(x, y, Tile.Stone)
			

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
