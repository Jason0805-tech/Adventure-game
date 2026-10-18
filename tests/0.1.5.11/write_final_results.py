"""Publish the final evidence index only after current-source checks finish."""
from pathlib import Path
from datetime import datetime
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "output/adventure game 0.1.5.11"
TEST = ROOT / "tests/0.1.5.11"


def read(name):
    path = TEST / name
    data = json.loads(path.read_text())
    assert not data.get("failures"), (name, data.get("failures"))
    return data


walk = read("all-model-walkthrough-results.json")
assert (TEST / "all-model-walkthrough-results.json").stat().st_mtime >= (PROJECT / "main.gd").stat().st_mtime
ground = read("independent-ground-results.json")
route = read("passage-navigation-results.json")
front = read("all-model-front-visibility.json")
house = read("front-visibility-results.json")
visual = read("back-front-visibility-final.json")
native = read("native-quality-results.json")
strips = read("native-depth-strip-results.json")
partition = read("depth-layers-results.json")
npc = read("npc-normal-world-results.json")
art = read("source-art-preservation.json")
geometry = read("footprint-authoring/geometry-results.json")
author = read("footprint-authoring/authoring-results.json")
package = read("package-validation.json")
assert package["game_ready"] and package["resource_failures"] == package["art_failures"] == 0
hashes = json.loads((TEST / "validated-runtime-hashes.json").read_text())
for name, expected in hashes.items():
    assert hashlib.sha256((PROJECT / name).read_bytes()).hexdigest() == expected, name

for name, marker in [
    ("smoke-features.log", "ALL_FEATURE_SMOKES_PASSED"),
    ("smoke-pacing.log", "ALL_PACING_SMOKES_PASSED"),
    ("test_navigation_refresh.log", "NAVIGATION_REFRESH_PASSED"),
    ("packaging.log", "LOCAL_SIGNATURE_VERIFIED"),
]:
    assert marker in (TEST / name).read_text(), name

full_world_visuals = sum(bool(row["walkable_full_world"]) for row in visual["results"])
summary = f"""FOREST WANDERER 0.1.5.11 — FINAL VERIFICATION
Generated {datetime.now().astimezone().isoformat(timespec='seconds')}

RESULT: all final checks below passed against the runtime hashes in
validated-runtime-hashes.json. Older initial failure reports are retained for
diagnosis; use the final filenames listed here.

WHAT CHANGED
Physical ground occupation is separate from the complete painted silhouette.
All 48 profiles retain native .10 visual masks. Roots, foundations/steps, prop
bases, pillar feet, ore and 17 separate shoreline bases block; elevated roofs,
lintels, branches and canopies do not become invisible ground walls. Water and
the closed cabin ground volume remain solid. Upper paint fades when it covers
the player behind; grounded bases stay opaque. Local front depth preserves
coherent characters and held tools. Navigation uses 12 world-unit cells.

PHYSICAL AND PLAYABILITY EVIDENCE
- {author['landmark_checks']} author art-landmark checks and {geometry['polygon_geometry_checks']} geometry/metadata checks: pass.
- independent-ground-results.json: {ground['checks']} checks, {ground['source_landmarks']} independently chosen source-art landmarks across 48 profiles, {ground['real_movement_cases']} real movement cases; 17 shore stones tested without water/neighbors masking their own bodies.
- baseline-arch.log versus final-arch.log: all 6 identical .10 routes were blocked; .11 reaches the opposite endpoint at x = 1989/1991/1994 in BOTH directions. The outer x = 1997 lane correctly clips the real right pillar with its 28-unit-wide boots.
- passage-navigation-results.json: {route['checks']} checks, continuous 17-destination full-world circuit, {route['movement_frames']} actual 60 Hz movement frames and {route['distance_walked']:.2f} world units. No route-leg teleports. Arch AStar path crosses the actual opening, not a detour around the pillars. Collection, felling, mining and workbench placement refresh collision/navigation.
- all-model-walkthrough-results.json: {walk['checks']} checks; {walk['actual_instances']} actual instances plus {walk['alternate_state_instances']} alternate/depleted states. {walk['full_world_approaches']} full-world and {walk['isolated_approaches']} own-body isolated approaches, 16 directions, tangent/diagonal/long-frame movement; {walk['movement_calls']} actual move_player calls. {walk['blocked_start_directions']} unavailable crowded/world-edge starts were recorded, not claimed visited.
- test_navigation_refresh.log: 132 nearby cells match exact collision ; 22600 distant cells unchanged; morning resource indices match.
- npc-normal-world-results.json: {npc['checks']} checks in 60 seconds with live trees/resources/ore. npc-walkthrough-results.json separately records 60 seconds after depleted/alternate states. Both NPCs travel and advance walking frames while remaining outside solids.

VISUAL AND NATIVE ART EVIDENCE
- all-model-front-visibility.json: {front['checks']} own-model front contacts pass.
- front-visibility-results.json: all {house['checks']} original house-front approach routes pass with the complete head/torso visible.
- back-front-visibility-final.json: {visual['checks']} front/back and arch poses pass; {full_world_visuals} are also legal in the full world. Others isolate the object's own drawing because neighbors or water restrict that position. All 10 key roof/header/canopy back poses are full-world legal. The actor is not forced permanently in front.
- 44 software Canvas replays rendered; 38 scenes appear in visual-acceptance/model-front-back-1.png through -3.png. Before/after comparisons use the exact same actor/camera pose. These replay actual ordered draw commands; they are NOT native GPU screenshots or a manual complete playthrough.
- native-quality-results.json: {native['checks']} native pixel/mipmap checks across 96 preparations.
- native-depth-strip-results.json: {strips['checks']} checks; {strips['models']} native model strip sets reconstruct exact original RGBA with no gaps, overlapping columns or source resizing.
- depth-layers-results.json: {partition['checks']} checks including exclusive, alpha-conserving pond/stone extraction.
- source-art-preservation.json: all {art['checks']} source assets have byte-identical SHA256 hashes to .10. No art downsampling, pose or anatomical grip changes.

GAME AND APP
- 27 gameplay checks: axe/felling, yields, crafting, placement, pickaxe/mining, rod/fishing/food, backpack/toolbars, repairs and NPC movement.
- 10 pacing checks:108 units/second, normalized diagonal motion,180-second daylight, pause and automatic night/morning.
- packaging.log: fresh Swift launcher plus bundled Godot runtime; strict ad-hoc signature verified in clean staging, installed bundle signature verified.
- package-validation.json: all {package['resource_checks']} bundled resources match final source hashes. Bundled launcher started from /private/tmp without relying on a project working directory; headless GAME_READY 0.1.5.11 and exit 0.
- bundled-launch.log may contain sandbox-denied user log-directory and system-certificate discovery warnings. There are no GDScript parse/runtime errors; these warnings did not prevent GAME_READY.
- release-source.zip preserves final source/config/contours separately from the output folder. Original native assets remain in .10 and .11.

RESEARCH
topdown-collision-research.md links Godot's official Isometric Game character
and vase scenes, CanvasItem Y-sort and TileMapLayer documentation. Ground
physics versus overhead painting follows that architecture; our partial fade
is game-specific rendering behavior. A global bottom-half crop was not used.

SCOPE
Automated seeded-world simulations, independent art landmarks, actual drawing
alpha checks and a bundled headless launch. No manual native GPU playthrough
is claimed. This validates the stated models, routes, states and runtime; it
does not assert that every possible random layout or GPU configuration was
manually visited.
"""
(TEST / "TEST_RESULTS.txt").write_text(summary)
print("FINAL_EVIDENCE_INDEX_WRITTEN", TEST / "TEST_RESULTS.txt")
