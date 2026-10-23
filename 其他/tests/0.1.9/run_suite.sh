#!/bin/sh
# Usage: run_suite.sh <project dir> <test script> <log> [seconds]
# Runs a headless Godot suite with a watchdog (script errors leave Godot idle).
/Applications/Godot.app/Contents/MacOS/Godot --headless --path "$1" --script "$2" > "$3" 2>&1 &
pid=$!
( sleep "${4:-300}"; kill $pid 2>/dev/null && echo "WATCHDOG_TIMEOUT" >> "$3" ) &
dog=$!
wait $pid; code=$?
kill $dog 2>/dev/null
exit $code
