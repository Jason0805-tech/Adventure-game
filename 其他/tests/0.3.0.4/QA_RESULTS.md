# v0.3.0-alpha.4 QA (2026-10-24)

- Headless suites (run_all.sh): alpha4 44 (new), regions 139, world 93977, progression 2474, alpha1 78, beacon 1232, dialog_close 9, dialog_fit ok, edges 24 (updated copy), hunting 19, nights 51, predators 72, stumps 6, survival 47 (updated copy), boot ok — 0 failures.
- Desktop renders: collide/ (bridge band = deck between rails, dock walkable), mapshot/ (map rendered from the real ground), state-*/ (sanity 60/30/10/0, fullness 15, health 25).
- Browser (built-in): itch zip via 0.1.7/flaky_server.py (pck.00 dropped, pck.03 stalled) boots at desktop and 740x360 phone landscape. Fixture: world map renders the painted ground in WebGL; sanity 0 shows the narrowed sight and status line.
- Not tested: physical iPhone, file://.
