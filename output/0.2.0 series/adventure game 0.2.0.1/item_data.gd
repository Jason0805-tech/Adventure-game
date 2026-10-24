extends RefCounted
const ITEMS = {
 "branch":{"name":"Branches","category":"material","stack":20,"family":"resource","icon":0,"description":"Loose branches. Collect by hand; use for handles and field crafting."},
 "rock":{"name":"Rocks","category":"material","stack":20,"family":"resource","icon":3,"description":"Loose stones collected by hand. Used for stone tools and repairs."},
 "rope":{"name":"Fibers","category":"material","stack":20,"family":"utility","icon":8,"description":"Plant fibers from grass. Used to bind tools and make fishing line."},
 "log":{"name":"Logs","category":"material","stack":20,"family":"utility","icon":0,"description":"Timber from felled trees. Build workbenches and advanced tools."},
 "ore":{"name":"Iron ore","category":"material","stack":20,"family":"utility","icon":1,"description":"Mine blue-gray ore veins with a pickaxe. Used for an iron axe and upgrades."},
 "fish":{"name":"Fish","category":"food","stack":20,"family":"utility","icon":2,"description":"Fresh catch. Equip and press Space or click to restore up to 25 fullness and 4 sanity. Sanity gain scales with food actually restored."},
 "medicine":{"name":"Medicine","category":"food","stack":10,"family":"equipment","icon":7,"description":"Restores 40 health, day or night. Press H or equip and use."},
 "crystal":{"name":"Magic stone","category":"ward","stack":10,"family":"equipment","icon":6,"description":"Blocks one animal attack automatically. One stone is consumed per blocked hit."},
 "stone_sword":{"name":"Large stone sword","category":"tool","stack":1,"family":"equipment","icon":0,"mesh":0,"tool":"weapon","power":4,"durability":80,"description":"A strong blade. Equip and press Space or click to strike animals in front of you."},
 "stone_knife":{"name":"Short stone knife","category":"tool","stack":1,"family":"equipment","icon":1,"mesh":1,"tool":"weapon","power":2,"durability":60,"description":"A small field-crafted blade. Equip and use to defend yourself against wildlife."},
 "stone_axe":{"name":"Stone axe","category":"tool","stack":1,"family":"utility","icon":7,"mesh":2,"tool":"axe","power":3,"durability":60,"strength":1,"description":"Equip to chop trees. Hold E near a tree or use the tool with Space / click."},
 "wood_knife":{"name":"Wooden knife","category":"tool","stack":1,"family":"equipment","icon":3,"mesh":3,"tool":"weapon","power":2,"durability":40,"description":"A simple wooden blade. Craft it by hand from branches and fibers."},
 "wood_sword":{"name":"Wooden sword","category":"tool","stack":1,"family":"equipment","icon":4,"mesh":4,"tool":"weapon","power":3,"durability":50,"description":"A wooden blade for early defense. Equip it and face an animal before striking."},
 "amazing_sword":{"name":"Amazing stone sword","category":"tool","stack":1,"family":"equipment","icon":5,"mesh":5,"tool":"weapon","power":6,"durability":100,"description":"Fast 0.60 s swings and 48 damage. Workbench upgrade replaces the original blade."},
 "pickaxe":{"name":"Stone pickaxe","category":"tool","stack":1,"family":"utility","icon":3,"mesh":6,"tool":"pick","power":2,"durability":60,"strength":1,"description":"Equip to mine iron ore veins. Loose rocks can still be collected by hand."},
 "fishing_rod":{"name":"Fishing rod","category":"tool","stack":1,"family":"utility","icon":4,"mesh":7,"tool":"rod","power":0,"durability":40,"description":"Stand beside water and hold E or use to cast. Move to cancel the cast."},
 "iron_axe":{"name":"Iron axe","category":"tool","stack":1,"family":"utility","icon":6,"mesh":8,"tool":"axe","power":4,"durability":100,"strength":2,"description":"Fast chopping: 0.58 s swings, two tree damage per hit. Repair it at a workbench."},
 "workbench":{"name":"Workbench","category":"placeable","stack":1,"family":"utility","icon":5,"description":"Equip and use to place on clear ground ahead of you. E opens advanced crafting."},
 "beacon_lens":{"name":"Beacon lens","category":"quest","stack":1,"family":"beacon","icon":0,"description":"A thick glass lens fished from Stillwater Lake. One of three parts for the old beacon."},
 "bronze_gear":{"name":"Bronze gear","category":"quest","stack":1,"family":"beacon","icon":1,"description":"An ancient gear sealed inside the rune rock. One of three parts for the old beacon."},
 "ember_core":{"name":"Ember core","category":"quest","stack":1,"family":"beacon","icon":2,"description":"A warm stone from the northwest shrine. One of three parts for the old beacon."},
 "torch":{"name":"Torch","category":"light","stack":1,"family":"paint","icon":0,"fuel":120.0,"description":"T toggles an off-hand torch without changing your weapon. Lights 5 metres for 120 seconds. Craft with 2 branches + 2 fibers."}
}
const RECIPES = [
 {"id":"stone_axe","cost":{"branch":2,"rock":3,"rope":1},"bench":false,"tier":1},
 {"id":"stone_knife","cost":{"branch":1,"rock":2},"bench":false,"tier":1},
 {"id":"wood_sword","cost":{"branch":4,"rope":1},"bench":false,"tier":1},
 {"id":"wood_knife","cost":{"branch":2,"rope":1},"bench":false,"tier":1},
 {"id":"workbench","cost":{"log":4,"branch":3,"rock":2,"rope":2},"bench":false,"tier":1},
 {"id":"pickaxe","cost":{"branch":3,"rock":4,"rope":2},"bench":true,"tier":2},
 {"id":"fishing_rod","cost":{"branch":4,"rope":3},"bench":true,"tier":2},
 {"id":"stone_sword","cost":{"branch":3,"rock":4,"rope":3},"bench":true,"tier":2},
 {"id":"iron_axe","cost":{"log":2,"ore":3,"rope":2},"bench":true,"tier":3,"learn":true},
 {"id":"amazing_sword","cost":{"ore":3,"rock":1},"bench":true,"upgrade":"stone_sword","tier":3,"learn":true},
 {"id":"torch","cost":{"branch":2,"rope":2},"bench":false,"tier":1},
 {"id":"crystal","cost":{"ore":1,"rock":2,"rope":1},"bench":true,"tier":3,"learn":true}
]
const TIER_NAMES = ["", "I  Field", "II  Workbench", "III  Iron & lore"]
const REPAIR_COST = {"branch":2,"rock":1,"rope":1}
static func info(id:String)->Dictionary: return ITEMS.get(id,{})
static func label(id:String)->String: return str(info(id).get("name",id))
