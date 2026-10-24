#!/bin/sh
# Runs every regression suite against v0.3.0-alpha.3, one after another.
T="$(cd "$(dirname "$0")/.." && pwd)"
P="$T/../../output/0.3.X/adventure game 0.3.0.3"
O="$T/0.3.0.3"
for s in 0.3.0.3/test_regions 0.3.0.3/test_world 0.3.0.3/test_progression 0.3.0.3/test_alpha1 0.3.0.3/test_beacon 0.3.0.3/test_boot 0.1.6.5/test_dialog_close 0.1.7/test_dialog_fit 0.1.6.4/test_edges 0.1.9/test_hunting 0.2.0/test_nights 0.1.6.4/test_predators 0.2.0.1/test_stumps 0.1.7.1/test_survival; do
  n=$(basename $s)
  sh "$O/run_suite.sh" "$P" "$T/$s.gd" "$O/$n-stdout.txt" 600; echo "$n exit $?"
done
echo ALL_DONE
