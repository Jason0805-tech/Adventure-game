#!/bin/sh
# Usage: SPOTS="x,y;x,y" [MAP=1] run_shot.sh <project dir> <out dir>
# Windowed Godot with the web build's renderer; saves shot_N.png per spot.
cp "$(dirname "$0")/shot.gd" "$1/shot.gd"
/Applications/Godot.app/Contents/MacOS/Godot --rendering-method gl_compatibility --path "$1" --script res://shot.gd > "$2/log.txt" 2>&1 &
pid=$!
( sleep 150; kill $pid 2>/dev/null ) &
dog=$!
wait $pid
kill $dog 2>/dev/null
rm -f "$1/shot.gd"
