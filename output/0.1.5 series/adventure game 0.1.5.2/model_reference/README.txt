TRAVELER MODEL REFERENCE

Import traveler-reference.gltf in Godot to inspect the neutral traveler and
stone sword from any angle. It uses the same proportions and anatomical
right-hand position that produced the 2D game frames.

The game uses pre-rendered 2D atlases: sixteen headings, eight walking poses
and one standing pose. Twelve headings cover 30-degree increments; four
additional headings cover the exact WASD diagonals. Body and weapons share
one camera, one root anchor and a right-hand joint.

Model source and numerical motion checks are in ../../../tests/0.1.5.2/model/.

In the front view the anatomical right hand appears on the left side of
the image; in the rear view it appears on the right. It is the same hand.
