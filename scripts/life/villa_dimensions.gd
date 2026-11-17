extends RefCounted
## Shared structural dimensions: 4.8 metres clear height plus the existing floor slab.
const BASE := .675
const RISE := 5.25
const CLEAR_HEIGHT := 4.8
const WALL_CENTER := BASE+CLEAR_HEIGHT*.5
const DOOR_HEIGHT := 3.0
const CEILING := BASE+CLEAR_HEIGHT
const TOP := BASE+RISE+CLEAR_HEIGHT
const UPPER_FLOOR := BASE+RISE

const NORTH := -6.1
const SOUTH := 18.3
const CENTER_Z := 6.1
const DEPTH := 24.4
const WEST := -10.98
const EAST := 14.5
const BOUNDS := Rect2(WEST,NORTH,EAST-WEST,DEPTH)
const MAIN_LEFT := -10.88
const MAIN_RIGHT := 8.0
const MAIN_WIDTH := MAIN_RIGHT-MAIN_LEFT
const MAIN_CENTER_X := (MAIN_LEFT+MAIN_RIGHT)*.5
const STAIR_DOOR_NORTH := .3
const STAIR_DOOR_SOUTH := 4.5
const STAIR_DOOR_HEIGHT := 4.45
const STAIR_WIDTH := 2.2
const FLIGHT_X := [9.25,12.0]
const STAIR_FRONT := .05
const STAIR_BACK := -3.95

const STAIR_OPENING_NORTH := STAIR_BACK-1.5

const BALCONY_DOOR_X := 3.2
const BALCONY_DOOR_WIDTH := 2.8
const BALCONY_RECT := Rect2(-7.0,18.2,14.45,8.0)
