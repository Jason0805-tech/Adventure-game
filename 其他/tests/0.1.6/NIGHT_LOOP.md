# 0.1.6 free nighttime exploration

The user explicitly selected free exploration and combat at night. The former camp teleport and three-choice abstract encounter are no longer reachable.

The normal loop is 180 seconds of daylight, six seconds of dusk, and 90 seconds of active night. Dusk and night preserve the player's location and accept movement, hotbar, gathering, tool use, food, medicine, backpack and crafting. The HUD displays time until night or time until dawn. Wolves and bears belong to the active night; rabbit and deer belong to daylight; the wildlife module owns the precise species population rules.

Opening backpack, crafting, conversation or Escape pause suspends the complete simulation: clock, movement, hunger, actions and wildlife. Players therefore cannot advance safely through a night by keeping frozen enemies behind a menu. This intentionally replaces the older daylight-only policy where menus left the clock running.

A completed real-time night awards one survival, then shows a dawn result. Enter starts the next day without changing player position. The third completion wins. Death prevents a survival award. Dawn does not perform an abstract power roll or automatically consume medicine or crystals. Actual animal attacks and equipped attacks are resolved by the wildlife module; any attack-specific crystal defense is separate from the dawn transition.

`active_exploration()` reports day/dusk/night while the run is alive. It does not imply that menus are closed. `wildlife_period()` reports day/dusk/night, treating dawn result and victory as daylight so species can synchronize immediately. `update_wildlife(0.0)` at dawn synchronizes populations without advancing AI motion. `choose_action()` remains a no-op only for older automation compatibility.

Focused regression: `test_night_cycle.gd`, `night-cycle.log`, 39 checks. This includes a real `_process` movement path with engine input events (108.0005 world units in one simulated second), night healing, food, crafting, a complete axe harvesting action and menu input, consistent suspension, nighttime starvation, guarded dawn completion and the three-night win. It is automated headless verification, not a manual native-window playthrough.
