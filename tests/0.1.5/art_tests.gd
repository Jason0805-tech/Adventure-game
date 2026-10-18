extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, title: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("FAIL " + title)
 else: print("PASS ", title)
func _initialize():
 var game = load("res://main.gd").new()
 game.build_world()
 game.load_art()
 check(game.art.size() == 6 and game.traveler_art.size() == 8 and game.resource_art.size() == 9 and game.pond_art.size() == 3 and game.npc_art.size() == 4 and game.variant_art.size() == 6 and game.equipment_art.size() == 8 and game.blend_art.size() == 6, "All 50 independent sprite regions load")
 for tex in game.traveler_art + game.npc_art:
  var foot := Vector2(400, 600)
  var rect: Rect2 = game.sprite_rect(tex, foot, 67)
  var pivot: Vector2 = game.foot_anchors[tex] * 67.0 / tex.get_height()
  check((rect.position + pivot).distance_to(foot) < 0.01 and rect.size.x > 0, "Sprite soles stay at ground anchor without negative width")
 for texture in game.art + game.traveler_art + game.resource_art + game.pond_art + game.npc_art + game.variant_art + game.equipment_art + game.blend_art:
  check(texture.get_width() > 10 and texture.get_height() > 10 and texture.get_image().detect_alpha() != Image.ALPHA_NONE, "Sprite is nonempty with real transparency")
 check(game.direction_index(Vector2.LEFT) == 1 and game.direction_index(Vector2.RIGHT) == 2 and game.direction_index(Vector2.UP) == 3 and game.direction_index(Vector2.DOWN) == 0, "Four real directional frames")
 for pool in game.pools: check(not game.walkable(pool.get_center()), "Each pond center blocks walking")
 check(game.walkable(Vector2(920,350)), "Dry corner outside curved shore remains walkable")
 for tree in game.trees: check(not game.walkable(tree), "Tree trunk blocks feet")
 for shrub in game.shrubs: check(not game.walkable(shrub), "Shrub footprint blocks feet")
 check(not game.walkable(game.npc_home) and not game.walkable(game.npc_position), "Both NPCs have foot collisions")
 check(not game.walkable(Vector2(350,590)), "Cabin ground footprint blocks movement")
 check(not game.walkable(game.gate + Vector2(-43,0)) and not game.walkable(game.gate + Vector2(43,0)), "Gate pillars are solid")
 check(game.walkable(game.gate), "Gate center can be approached")
 for item in game.items: check(game.walkable(item.pos), "Every material spawn remains accessible")
 game.obstacles.clear()
 game.obstacles.append(Rect2(450, 730, 20, 80))
 game.player = Vector2(360,760)
 game.npc_home = Vector2(0,0); game.npc_position = Vector2(0,0)
 game.move_player(Vector2.RIGHT, 2.0)
 check(game.player.x < 440, "Large movement cannot tunnel through a thin obstacle")
 var event := InputEventKey.new()
 event.pressed = true; event.physical_keycode = KEY_F3
 game._unhandled_key_input(event)
 check(game.show_collision, "F3 exposes hitboxes")
 game._unhandled_key_input(event)
 check(not game.show_collision, "F3 hides hitboxes")
 game.free()
 print("ART_RESULT: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
