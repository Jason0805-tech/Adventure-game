# 0.1.5.11 — ground-plane collision and visual occlusion

Research checked on 2026-10-16. Sources below are official engine/editor documentation and the engine's own published demo, not forum guesses.

The player's suggestion is feasible: for this projected top-down game, treat the character's boots and each object's ground volume as physical bodies. A roof, canopy or arch lintel can occupy the same screen pixels as a walking character without occupying the same ground position. Rendering determines what covers what; physics determines where the boots may go. A fixed “bottom half” crop is only a rough heuristic. Author each object's actual footprint and overhead parts separately.

## Evidence and application

- **Godot's Isometric Game demo** demonstrates movement, sliding around objects and being occluded in front/behind scenery. The actual character scene has a 128-pixel animation frame painted above its origin (`Sprite2D.position = (0, -35)`, scale 0.8), while its physical capsule has radius 7 and height 14 at `(0, -7)`. Thus the small ground contact body is explicitly separate from the tall character artwork. [Demo](https://github.com/godotengine/godot-demo-projects/tree/master/2d/isometric), [actual character scene](https://github.com/godotengine/godot-demo-projects/blob/master/2d/isometric/player/goblin.tscn).
- **The same demo's vase** places its sprite at `(0, -29)` and a horizontally rotated radius-9 capsule at `(0, -9)`. The tall picture is not the physical contour. This is a concrete small-prop example of the intended architecture. [Actual vase scene](https://github.com/godotengine/godot-demo-projects/blob/master/2d/isometric/decorations/vase_1.tscn).
- **CanvasItem Y-sort** draws higher ground Y positions in front, with all the relevant objects on the same z index. A character and its held tool should remain one coherent render unit. [Godot CanvasItem Y-sort](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-y-sort-enabled).
- **TileMapLayer Y-sort origin** explicitly allows a visual height offset for top-down games. Sorting height can be configured separately from a tile's image extent and collision data. [Godot TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html#class-tilemaplayer-property-y-sort-origin).
- **Tiled** stores authored collision shapes as per-tile metadata and can show them over the map for verification. It does not require the collision to match a sprite's complete painted outline. [Tiled tile collision editor](https://doc.mapeditor.org/en/stable/manual/editing-tilesets/#tile-collision-editor).

Do not confuse Godot `LightOccluder2D` polygons with character visibility masks: the former affect lighting/shadows. Our partial transparency and ordered painter layers are game-specific visibility behavior, inferred from this architecture rather than prescribed by the source.

## Release acceptance

1. Arch pillars block at their feet, while the central ground corridor can be walked through north/south and under the lintel. The painted header can cover/fade above the character; it must not become an invisible physical wall.
2. Building ground volume and closed entrance remain solid. The player can traverse legitimate ground behind the roof/chimney image. A roof can obscure/fade over the player while base walls remain legible; the player must not be forcibly drawn on top of the whole building.
3. Trees have trunk/root footprints. Elevated branches and canopy images do not block ground walking. From behind, the canopy visibly covers/fades over the coherent character. From in front, head/body/hands stay in front of the roots.
4. Each low prop, stump, workbench, ore and shoreline stone keeps an authored base footprint, with matching side/front/back depth. Passable plants and collected remnants do not gain artificial walls.
5. Preserve all native art pixels, HD actor cells (192×320), action cells (384×384), world scale, tool registration, speed and daylight duration.

Verification must include **positive blocking, negative passability, complete routes, and actual ordered Canvas alpha**. Testing only points inside existing polygons would accept the previous overblocking bug. Software Canvas replays are reproducible drawing evidence; they are not native GPU screenshots or a manual playthrough.
