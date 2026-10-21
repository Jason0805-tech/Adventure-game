FOREST WANDERER 0.1.6.2 — ORIGINAL PAINTED ANIMAL LEGS

Open Forest Wanderer.app. It contains its own Godot runtime.
To edit: import project.godot in Godot 4.7 and press F6/F5.
The interface is English. Closing the game resets the current run.

Movement and wildlife
Animals use the original 0.1.6 painted bodies, legs and paws, with an articulated
2D gait. Fur colours, brush texture, native painted edges and paw shapes come
directly from the original atlases. The flat procedural legs from 0.1.6.1 are
replaced. Idle animals display the complete original painting.
Feet follow support, lift, forward recovery and landing in a complete cycle.
Animation advances from actual distance travelled; blocked animals do not walk in place.
Each species retains its own leg phase pattern and movement pace.
Bodies, shadows and 40 heading-specific ground footprints stay registered.
Depth-facing strides are foreshortened for the painted view; this is stylized
2D animation, not a claim of exact world-coordinate foot locking in every heading.

Every run randomizes ecological spawn locations and individual activity.
Animals choose reachable destinations, rest, look around and vary their pace.
Rabbit and deer: daylight only; fox: day/dusk; wolf and bear: night only.
Rabbits, deer and foxes flee nearby players. Wolves and bears approach, warn,
then commit to a bite/swipe. Brief perception memory avoids chase/idle flicker.
NPCs choose random destinations in their own areas and walk back to camp at dusk.

Day, darkness and light
A day is 180 seconds, dusk 6 seconds and night 90 seconds. Survive 3 nights.
Dawn, noon, evening and midnight have continuous brightness and colour changes.
Night gradually brightens before dawn; no forced camp teleport or abstract damage.
Midnight outside light is dense dark blue fog. Camp has a permanent lantern.
Craft a torch in C: 2 branches + 2 fibers, no workbench needed.
It lights about 5 metres (160 world units) with a soft edge and lasts 120 lit seconds.
T puts it out or relights it, saving fuel. A spent torch is consumed; craft a spare.
A torch occupies the anatomical left hand; your selected weapon stays in the right.
Dark wolves show red eyes; bears show green. Eyes follow the actual head, blink,
and disappear when the body enters enough light. Rear-facing heads show no eyes.
Ground obstacles block eye visibility. Canopy leaves are overhead, not sight walls.

Controls
WASD / arrows: move. E: gather, talk or use a nearby resource/workbench.
Space / left click: use the selected item or swing the held tool.
1–6 / mouse wheel: toolbar. B: backpack. C: crafting. H: medicine. T: torch.
Esc: close a menu or pause. F3: ground collision overlay. R: restart after win/loss.
Backpack, crafting, conversations and Esc pause time, fuel, hunger, AI and actions.

Existing features retained
Chopping, stumps, mining, fishing, workbenches, crafting, repair, medicine, wards,
24-slot backpack, six-slot toolbar, ecological resources and the three-night goal.
Ground, scenery and human/weapon textures keep all native source pixels.
Ground footprints and elevated scenery depth layers are preserved from 0.1.5.11.

Original wildlife paintings/prompts: ../../素材整理/动物/0.1.6/
Articulated rig archive: ../../素材整理/动物/0.1.6.2/
Tests, logs and staged Canvas-replay previews: ../../tests/0.1.6.2/TEST_RESULTS.txt
Previews use the release's actual drawing commands and native source textures;
they are software replays, not a claimed manual native-GPU playthrough.
