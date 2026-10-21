extends SceneTree

const WorldGeometry = preload("res://world_geometry.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS geometry: ", label)
	else:
		failures += 1
		push_error("FAIL geometry: " + label)

func polygon(coordinates: Array[Vector2]) -> PackedVector2Array:
	return PackedVector2Array(coordinates)

func _initialize() -> void:
	var square := polygon([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)])
	var contained := polygon([Vector2(2, 2), Vector2(3, 2), Vector2(3, 3), Vector2(2, 3)])
	var separated := WorldGeometry.transform_polygon(square, Vector2(20, 0))
	var touching := WorldGeometry.transform_polygon(square, Vector2(10, 0))
	check(WorldGeometry.polygons_overlap(square, contained), "full containment")
	check(WorldGeometry.polygons_overlap(contained, square), "containment symmetry")
	check(not WorldGeometry.polygons_overlap(square, separated), "separated polygons")
	check(WorldGeometry.polygons_overlap(square, touching), "touching edge blocks")
	check(WorldGeometry.polygons_overlap(square, WorldGeometry.transform_polygon(square, Vector2(10, 10))), "touching corner blocks")
	var horizontal := polygon([Vector2(-5, -1), Vector2(5, -1), Vector2(5, 1), Vector2(-5, 1)])
	var vertical := polygon([Vector2(-1, -5), Vector2(1, -5), Vector2(1, 5), Vector2(-1, 5)])
	check(WorldGeometry.polygons_overlap(horizontal, vertical), "crossing-only overlap without contained vertices")
	check(WorldGeometry.polygons_overlap(vertical, horizontal), "crossing-only overlap symmetry")
	var concave := polygon([Vector2(0, 0), Vector2(10, 0), Vector2(10, 3), Vector2(3, 3), Vector2(3, 10), Vector2(0, 10)])
	var notch := WorldGeometry.transform_polygon(contained, Vector2(3, 3))
	check(not WorldGeometry.polygons_overlap(concave, notch), "concave notch remains walkable")
	check(WorldGeometry.polygons_overlap(concave, contained), "concave filled arm blocks")
	check(not WorldGeometry.point_in_polygon_or_boundary(Vector2(5, 5), concave), "point in concave gap is outside")
	check(WorldGeometry.point_in_polygon_or_boundary(Vector2(3, 5), concave), "point exactly on concave boundary is inside")
	var clockwise := square.duplicate()
	clockwise.reverse()
	check(WorldGeometry.point_in_polygon_or_boundary(Vector2(5, 5), clockwise), "clockwise winding remains supported")
	check(WorldGeometry.polygons_overlap(clockwise, contained), "mixed winding remains supported")
	check(WorldGeometry.segment_intersects_polygon(Vector2(-5, 5), Vector2(15, 5), square), "line crossing polygon")
	check(WorldGeometry.segment_intersects_polygon(Vector2(2, 2), Vector2(3, 3), square), "line entirely contained")
	check(not WorldGeometry.segment_intersects_polygon(Vector2(5, 5), Vector2(8, 8), concave), "line entirely inside concave notch")
	check(WorldGeometry.segment_intersects_polygon(Vector2(-5, 0), Vector2(5, 0), square), "line collinear with boundary")
	check(WorldGeometry.segment_intersects_polygon(Vector2(10, 10), Vector2(15, 15), square), "line starts on corner")
	check(not WorldGeometry.segment_intersects_polygon(Vector2(-5, -1), Vector2(15, -1), square), "nearby parallel line remains clear")
	check(WorldGeometry.segment_intersects_polygon(Vector2(5, 5), Vector2(5, 5), square), "zero-length line inside")
	check(not WorldGeometry.segment_intersects_polygon(Vector2(15, 5), Vector2(15, 5), square), "zero-length line outside")
	check(WorldGeometry.segments_intersect(Vector2.ZERO, Vector2(10, 0), Vector2(5, 0), Vector2(15, 0)), "collinear segments overlap")
	check(not WorldGeometry.segments_intersect(Vector2.ZERO, Vector2(10, 0), Vector2(11, 0), Vector2(15, 0)), "separated collinear segments")
	check(WorldGeometry.segments_intersect(Vector2.ZERO, Vector2(10, 10), Vector2(0, 10), Vector2(10, 0)), "diagonal edge crossing")
	var transformed := WorldGeometry.transform_polygon(square, Vector2(30, 40), Vector2(2, 3), PI * 0.5)
	check(transformed[0].is_equal_approx(Vector2(30, 40)) and transformed[1].is_equal_approx(Vector2(30, 60)), "scale then rotation then translation")
	check(WorldGeometry.polygon_bounds(transformed).is_equal_approx(Rect2(Vector2(0, 40), Vector2(30, 20))), "transformed polygon bounds")
	check(WorldGeometry.bounds_overlap(Rect2(Vector2.ZERO, Vector2(10, 10)), Rect2(Vector2(10, 10), Vector2(2, 2))), "broad phase includes touching boundaries")
	check(WorldGeometry.bounds_overlap(Rect2(Vector2(10, 10), Vector2(-10, -10)), Rect2(Vector2(2, 2), Vector2(1, 1))), "broad phase handles negative rectangles")
	var ellipse := WorldGeometry.ellipse_polygon(Vector2(40, 20), Vector2(10, 6), 20)
	check(ellipse.size() == 20 and WorldGeometry.polygon_bounds(ellipse).is_equal_approx(Rect2(Vector2(30, 14), Vector2(20, 12))), "ellipse foot dimensions and smooth contour")
	check(WorldGeometry.point_in_polygon_or_boundary(Vector2(40, 20), ellipse), "ellipse center contained")
	check(not WorldGeometry.point_in_polygon_or_boundary(Vector2(49, 25), ellipse), "ellipse excludes former square corner")
	var capsule := WorldGeometry.capsule_polygon(Vector2(40, 20), 10, 6, 10)
	check(capsule.size() == 22 and WorldGeometry.polygon_bounds(capsule).is_equal_approx(Rect2(Vector2(30, 14), Vector2(20, 12))), "capsule foot dimensions")
	check(not WorldGeometry.polygons_overlap(PackedVector2Array(), square), "empty contours are safe")
	check(not WorldGeometry.segment_intersects_polygon(Vector2.ZERO, Vector2.ONE, PackedVector2Array()), "empty line target is safe")
	print("GEOMETRY_RESULTS checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
