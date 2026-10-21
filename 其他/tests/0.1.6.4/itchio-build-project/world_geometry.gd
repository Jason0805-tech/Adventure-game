extends RefCounted
## Ground-plane geometry for painted sprites. All contours are expressed in
## world units after transformation; concave polygons do not need triangulation.

const EPSILON: float = 0.0001

static func ellipse_polygon(center: Vector2, radii: Vector2, segments: int = 20) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var count: int = maxi(8, segments)
	var radius := radii.abs()
	for index in range(count):
		var angle: float = TAU * float(index) / float(count)
		polygon.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return polygon

static func feet_polygon(center: Vector2, radii: Vector2 = Vector2(10, 6), segments: int = 20) -> PackedVector2Array:
	return ellipse_polygon(center, radii, segments)

## A horizontal capsule is useful when a body needs a flatter central contact
## surface than an ellipse. half_width includes the round end caps.
static func capsule_polygon(center: Vector2, half_width: float, half_height: float, arc_segments: int = 10) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var radius: float = maxf(EPSILON, absf(half_height))
	var end_offset: float = maxf(0.0, absf(half_width) - radius)
	var count: int = maxi(4, arc_segments)
	for index in range(count + 1):
		var angle: float = -PI * 0.5 + PI * float(index) / float(count)
		polygon.append(center + Vector2(end_offset + cos(angle) * radius, sin(angle) * radius))
	for index in range(count + 1):
		var angle: float = PI * 0.5 + PI * float(index) / float(count)
		polygon.append(center + Vector2(-end_offset + cos(angle) * radius, sin(angle) * radius))
	return polygon

static func transform_polygon(points: PackedVector2Array, offset: Vector2, scale: Vector2 = Vector2.ONE, rotation: float = 0.0) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append((point * scale).rotated(rotation) + offset)
	return transformed

static func polygon_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point in points:
		minimum = Vector2(minf(minimum.x, point.x), minf(minimum.y, point.y))
		maximum = Vector2(maxf(maximum.x, point.x), maxf(maximum.y, point.y))
	return Rect2(minimum, maximum - minimum)

## Rect2.intersects excludes touching edges. Ground collision and navigation
## must retain those edges, otherwise narrow gaps and contour corners leak.
static func bounds_overlap(a: Rect2, b: Rect2) -> bool:
	var first: Rect2 = a.abs()
	var second: Rect2 = b.abs()
	return first.position.x <= second.end.x + EPSILON \
		and first.end.x >= second.position.x - EPSILON \
		and first.position.y <= second.end.y + EPSILON \
		and first.end.y >= second.position.y - EPSILON

static func point_on_segment(point: Vector2, start: Vector2, finish: Vector2) -> bool:
	var edge: Vector2 = finish - start
	var length: float = edge.length()
	if length <= EPSILON:
		return point.distance_squared_to(start) <= EPSILON * EPSILON
	if absf(edge.cross(point - start)) > EPSILON * length:
		return false
	var along: float = edge.dot(point - start)
	return along >= -EPSILON * length and along <= edge.length_squared() + EPSILON * length

static func point_in_polygon_or_boundary(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside: bool = false
	for index in range(polygon.size()):
		var start: Vector2 = polygon[index]
		var finish: Vector2 = polygon[(index + 1) % polygon.size()]
		if point_on_segment(point, start, finish):
			return true
		if (start.y > point.y) != (finish.y > point.y):
			var crossing_x: float = start.x + (point.y - start.y) * (finish.x - start.x) / (finish.y - start.y)
			if point.x < crossing_x:
				inside = not inside
	return inside

static func segments_intersect(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2) -> bool:
	if not bounds_overlap(Rect2(a_start, a_end - a_start), Rect2(b_start, b_end - b_start)):
		return false
	# Include collinear overlap, shared vertices and zero-length segments.
	if point_on_segment(a_start, b_start, b_end) or point_on_segment(a_end, b_start, b_end) \
		or point_on_segment(b_start, a_start, a_end) or point_on_segment(b_end, a_start, a_end):
		return true
	var a_edge: Vector2 = a_end - a_start
	var b_edge: Vector2 = b_end - b_start
	var first: float = a_edge.cross(b_start - a_start)
	var second: float = a_edge.cross(b_end - a_start)
	var third: float = b_edge.cross(a_start - b_start)
	var fourth: float = b_edge.cross(a_end - b_start)
	return (first < 0.0) != (second < 0.0) and (third < 0.0) != (fourth < 0.0)

static func polygons_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	if not bounds_overlap(polygon_bounds(a), polygon_bounds(b)):
		return false
	# Edge intersections detect crossing-only overlaps even when neither
	# polygon has a vertex inside the other (for example two thin crossing logs).
	for first in range(a.size()):
		for second in range(b.size()):
			if segments_intersect(a[first], a[(first + 1) % a.size()], b[second], b[(second + 1) % b.size()]):
				return true
	# With no boundary crossing, overlap can only be complete containment.
	return point_in_polygon_or_boundary(a[0], b) or point_in_polygon_or_boundary(b[0], a)

static func segment_intersects_polygon(start: Vector2, finish: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	if not bounds_overlap(Rect2(start, finish - start), polygon_bounds(polygon)):
		return false
	if point_in_polygon_or_boundary(start, polygon) or point_in_polygon_or_boundary(finish, polygon):
		return true
	for index in range(polygon.size()):
		if segments_intersect(start, finish, polygon[index], polygon[(index + 1) % polygon.size()]):
			return true
	return false
