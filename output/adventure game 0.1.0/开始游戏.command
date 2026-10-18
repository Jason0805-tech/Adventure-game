#!/bin/zsh
GAME_DIR="${0:A:h}"
open -n -a /Applications/Godot.app --args --path "$GAME_DIR" --position 80,80
