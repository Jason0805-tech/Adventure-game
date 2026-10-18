extends SceneTree
const OUT := "res://../../tests/0.1.5.11/"
var Layers = preload("res://depth_layers.gd")
var checks := 0
var failures: Array[String] = []
var records: Array = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func audit(layers: Variant, texture: Texture2D, profile: Dictionary, key: String, world_size: Vector2) -> void:
	var original: Image = texture.get_image()
	var before: PackedByteArray = original.get_data()
	var base: Image = original.duplicate()
	base.clear_mipmaps()
	base.convert(Image.FORMAT_RGBA8)
	var width: int = base.get_width()
	var height: int = base.get_height()
	var reconstructed := Image.create(width,height,false,Image.FORMAT_RGBA8)
	reconstructed.fill(Color.TRANSPARENT)
	var bands: Array[Dictionary] = layers.bands(texture,profile,key,world_size)
	var baseline: Array[Dictionary] = layers.bands(texture,profile,key+":legacy")
	var levels := PackedFloat64Array()
	levels.resize(width)
	for band in baseline:
		for x in range(int(band.source.position.x),int(band.source.end.x)): levels[x] = float(band.depth_v)*world_size.y
	var consumed := 0
	var source_pixels := 0
	for band in bands:
		var source: Rect2 = band.source
		check(source.position.x == consumed,key+" strips join at native column "+str(consumed))
		check(source.position.y == 0.0 and source.size.y == height,key+" full native source height")
		check(source.size.x >= 1.0 and source.size.x == int(source.size.x),key+" source width remains whole native columns")
		check(absf(float(band.depth_v)*world_size.y/2.0-roundf(float(band.depth_v)*world_size.y/2.0))<0.0001,key+" world depth quantized independently of raster pixels")
		reconstructed.blit_rect(base,Rect2i(source),Vector2i(source.position))
		for x in range(int(source.position.x),int(source.end.x)):
			var difference := float(band.depth_v)*world_size.y-levels[x]
			check(difference >= -world_size.y/height-0.0001 and difference < 2.0001,key+" depth deviation bounded independently from native pixel "+str(x))
		consumed += int(source.size.x)
		source_pixels += int(source.size.x*source.size.y)
	check(consumed == width,key+" complete native width partition")
	check(source_pixels == width*height,key+" exact full native source pixel coverage")
	check(reconstructed.get_data() == base.get_data(),key+" strip reconstruction preserves all RGBA bytes")
	check(texture.get_image().get_data() == before,key+" input texture bytes and mipmaps unchanged")
	var cache_before: int = layers.band_cache.size()
	layers.bands(texture,profile,key,world_size)
	check(layers.band_cache.size() == cache_before,key+" repeat lookup reuses prepared bands")
	layers.bands(texture,profile,key,Vector2(world_size.x,world_size.y+0.25))
	check(layers.band_cache.size() == cache_before+1,key+" world height has independent cache identity")
	records.append({"key":key,"source_size":[width,height],"world_size":[world_size.x,world_size.y],"native_pixel_count":width*height,"legacy_band_count":baseline.size(),"production_band_count":bands.size(),"exact_rgba_reconstruction":true})

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Variant = load("res://main.gd").new()
	game.resource_seed = 159
	root.add_child(game)
	game.set_process(false)
	var layers = Layers.new()
	for entry in game.scenery_entries():
		var kind: String = str(entry.kind)
		var spec: Dictionary = game.model_spec(kind,entry.p,int(entry.index))
		if spec.is_empty() or (kind == "tree" and game.tree_live(entry.p)): continue
		var rect: Rect2 = game.sprite_rect(spec.texture,Vector2.ZERO,float(spec.height))
		audit(layers,spec.texture,game.collision_profiles[spec.profile],str(entry.id),rect.size)
	for i in range(game.pond_paint_layers.size()):
		var stone_index := 0
		for rock in game.pond_paint_layers[i].rocks:
			audit(layers,rock.texture,rock.profile,"bank_rock:%d:%d" %[i,stone_index],rock.rect.size*game.pools[i].size)
			stone_index += 1
	var file := FileAccess.open(OUT+"native-depth-strip-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"models":records.size(),"scope":"Independent native source column continuity, exact RGBA reconstruction, bounded depth change and cache-identity checks. No source pixel resizing, collider mutation or manual GPU playthrough.","records":records},"  "))
	print("NATIVE_DEPTH_STRIP_TESTS ",checks," checks ",failures.size()," failures models=",records.size())
	for failure in failures.slice(0,12): push_error(failure)
	game.queue_free();quit(0 if failures.is_empty() else 1)
