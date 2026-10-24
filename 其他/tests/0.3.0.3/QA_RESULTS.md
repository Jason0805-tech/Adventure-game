# v0.3.0-alpha.3 QA (2026-10-24)

- Headless suites (run_all.sh): regions 139, world 93977, progression 2450, alpha1 78, beacon 1220, dialog_close 9, dialog_fit ok, edges 24, hunting 19, nights 51, predators 72, stumps 6, survival 46, boot ok — 0 failures, 0 script errors.
- Desktop renders (gl_compatibility, shots/): bridge, plaza, gate, well, Old Ferry, willow bend, north ford, ruins.
- Web export packs all 24 assets/region PNGs (keep importers). Payload part hashes verified in the itch zip.
- Browser (built-in Claude browser): itch zip served by 0.1.7/flaky_server.py (pck.00 dropped, pck.03 stalled) -> retried and booted into the map at desktop size and at 740x360 phone landscape.
- Browser fixture (fixture-regions, ?at=): Fallen Gate and bridge render with the new art.
- Not tested: physical iPhone, file://.
