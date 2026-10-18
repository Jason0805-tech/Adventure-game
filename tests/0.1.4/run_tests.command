#!/bin/zsh
cd -- "${0:A:h}/../.." || exit 1
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --path "output/adventure game 0.1.4" --script "../../tests/0.1.4/tests.gd" || exit 1
"$GODOT_BIN" --headless --path "output/adventure game 0.1.4" --script "../../tests/0.1.4/art_tests.gd"
