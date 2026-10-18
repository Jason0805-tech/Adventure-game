# Mobile controls checkpoint —0.1.6.3

Runtime API: `enabled:bool`, `css_height:float` (CSS canvas height, default390), `handle_event(event,game)->bool`, `direction()->Vector2`, `interact_held`, `use_held`, `clear()`, `draw(game)`.

The host routes native ScreenTouch/ScreenDrag to controls first, reads held flags during simulation, calls clear on lifecycle/modal/rotation changes, and supplies `mobile_action(action)`, `paper_panel`, `label_at`, `draw_item_icon`, inventory/hotbar and viewport state. Controls own their touch regions. Unhandled touches can feed existing menu UI. Actions are `interact`, `use`, `bag`, `craft`, `torch`, `heal`, `pause`, and `slot_0` through `slot_5`.

Target sizing is max82virtual pixels or ceil(44×virtualHeight/CSSHeight). Typical390CSS→82virtual, Safari320CSS→99virtual. Separate fingers can hold joystick and Use/Gather; canceled gesture IDs cannot become menu drags or releases. Both menus and portrait suppress gameplay. All labels are English, with native parchment/teal brush marks and existing item paint; no raster source assets were changed.

`tests_summary.json` is the authoritative source-bound checkpoint. Four suites total13,159 checks; placement examines actual drawn UI geometry at twelve size combinations, including modal controls and toast/weather separation. These are native Godot synthetic events and Canvas submissions, not browser or physical iPhone validation. Browser publication and complete export packaging remain parent-task work.

This ZIP preserves current runtime integration source and tests/results without duplicating unchanged image assets. The release directory contains the complete project. It is a source/QA checkpoint, not a standalone runnable archive.
