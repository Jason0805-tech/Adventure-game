TRAVELER MOTION AND DEPTH REFERENCE — 0.1.5.3

This neutral 3D mesh is an anatomical and occlusion guide only.
The game's visible torso is a hand-painted 2D cutout produced with imagegen.
The model is not displayed as a 3D character in the game.

The sixteen headings, eight walking poses and idle pose share one root
and camera. The anatomical right hand stays on negative local X.
In front it appears at image left; at the rear it appears at image right.
The body may hide the hand and weapon at some headings; it never swaps hands.
Tools are attached to the same palm before their visible pixels are rendered.

Motion generation and numerical checks:
../../../tests/0.1.5.3/model/painted_rig.py
../../../tests/0.1.5.3/model/validate_painted_avatar.py
