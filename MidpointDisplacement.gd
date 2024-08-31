@tool
extends Resource
class_name MidpointDisplacement

## Starting vector. get_displacement(start.x) -> start.y
@export var start: Vector2 = Vector2.ZERO

## Ending vector. get_displacement(end.x) -> end.y 
@export var end: Vector2 = Vector2.RIGHT

## Amount of displacement. You can expect this to be the absolute maximum displacement, but not guaranteed (especially at low smoothness).
@export var vertical_displacement: float = 0.5

## Decay of displacement. High values mean displacement will decay rapidly, resulting in smoother results.
@export var smoothness: float = 1.0:
	get:
		return smoothness
	set(value):
		smoothness = max(value, 0.0001)

## If negative or positive, displacement will have a bias towards negative or positive values. Otherwise, it is unbiased.
@export_range(-1, 1) var bias: int:
	get:
		return bias
	set(value):
		bias = clampi(value, -1, 1)

## Number of displacement points between start and end. len(points)=(2^density)+1
@export_range(2, 16) var density: int = 8

var _start: Vector2
var _end: Vector2
var _points: PackedVector2Array = []
var _norm: float
var _shift: float = 0

## Return displacement y at x. x is pingponged if out of bounds.
func get_displacement(x: float) -> float:
	if _points.size() == 0:
		regenerate()
	
	# still weird around x=0
	x = pingpong(x - _start.x + _shift, _norm)
	x = (x - _start.x) / _norm
	
	if x == _end.x:
		return _end.y
	
	x = x * _points.size()
	var i = floori(x)
	var r = fmod(x, i) if i > 0 else x
	return _points[i].lerp(_points[i + 1], r).y
	
func regenerate():
	_start = start
	_end = end
	if _start.x > _end.x:
		_start = end
		_end = start
	elif _start.x == _end.x:
		_end.x = _start.x + 1
	
	if start.x < 0:
		_shift = abs(_start.x)
		_start.x += _shift
		_end.x += _shift
	
	_norm = _end.x - _start.x
	_points = _generate_midpoint_displacement()
#
func _generate_midpoint_displacement() -> PackedVector2Array:
	# Final number of points = (2^iterations)+1
	var x: Array[float] = [start.x, end.x]
	var y: Array[float] = [start.y, end.y]

	var points = func():
		var p: Array[Vector2] = []
		for i in range(len(x)):
			p.append(Vector2(x[i], y[i]))
		return p

	var iteration = 1
	var vert = vertical_displacement
	while iteration <= density:
		var p = points.call()
		for i in range(len(p)-1):
			var v = p[i].lerp(p[i+1], 0.5)
			var j = x.bsearch(v.x)
			x.insert(j, v.x)
			if iteration == 1 and bias != 0:
				y.insert(j, v.y + (vert * bias))
			else:
				y.insert(j, v.y + (vert * (-1 if randf() < 0.5 else 1)))
		vert *= 2 ** (-smoothness)
		iteration += 1

	return PackedVector2Array(points.call())
