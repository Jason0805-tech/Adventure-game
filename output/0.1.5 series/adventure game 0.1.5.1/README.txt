FOREST WANDERER 0.1.5.1

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Import project.godot in Godot 4.7.2 and press F6/F5.

Changes (walking correction)
- Removed the rejected procedural leg rig; legs are no longer rotated separately.
- Painted contact and passing poses replace the inconsistent six-frame sequence.
- Fixed upper-body registration prevents head/body jitter between poses.
- Mirrored side movement keeps left/right attachments consistent.
- Movement speed reduced to match the calmer walking cadence.
- Ground shadows remain independent of facing and stay beneath the character.

The current replacement uses four key poses per cycle. It is a basic cartoon
walk, not a finished high-frame-count animation. Automated checks verify
movement behavior; they do not establish that the animation looks natural.

Controls: WASD / arrows to move, E to interact, B for bag, C to craft,
Esc to close a panel or pause, F3 to toggle collision outlines.

Survive three nights. Each day lasts 90 seconds. Gather branches, rocks and
ropes, craft equipment and speak to Rowan and Ash. Backpack capacity: 10.
The backpack and crafting menu do not pause daylight. Esc pauses the game.
This prototype has no save system; closing the game resets progress.
All game text is English. Previous release folders are preserved.

Source art was generated with OpenAI image generation and integrated through
Godot image regions. Prompts: ART_PROMPTS.txt. Engine license: ENGINE_LICENSES.txt.
Test logs and visual captures are in ../../tests/0.1.5.1/.
