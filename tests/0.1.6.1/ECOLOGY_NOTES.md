# 0.1.6.1 ecology and movement validation

Runtime changes are in wildlife.gd, wildlife_data.gd and npc_roaming.gd.
Normal gameplay uses randomized RNG seeds (resource_seed = 0). Nonzero seeds are only for reproducible testing. Spawn habitat position, individual temperament, destination, rest time, escape side, decision cadence and replenishment timing vary. Walking phase always advances in order from actual traveled distance.

Predators see the player within their individual notice range. At a shorter range (78% of notice), they can investigate scent around a ground obstacle. Investigation has a bounded ten-second search window; attacking still requires clear line of sight, a stopped windup and locked aim. Rabbits, deer and foxes choose stable escape legs instead of changing their target every frame.

The initial human navigation graph made wolves and bears catch on tree corners. The wildlife graph now caches species clearance per map navigation revision, and direct shortcuts use a swept ground-footprint test. Wider side-facing clearance either blocks unsafe wolf route cells or increases traversal cost around large-bear corners while retaining front-facing passages. These are navigation margins only; exact existing authored ground polygons and heading-dependent paw capsules remain the physical collision authority on every 1.5-unit movement substep.

Measured cold graph construction in wildlife-proximity-world.log: wolf 3404 us, bear 4085 us. Cached graphs are reused between decisions and invalidated by nav_revision after map changes. They are not rebuilt each frame. No collision art/profile assets changed.

Latest evidence:
- wildlife-logic.log: 76 checks, 0 failures.
- ecology-behavior.log: 66 checks, 0 failures.
- wildlife-proximity-world.log: 1425 checks, 0 failures; actual rabbit/fox escape; wolf/bear chase, stopped warning, hit and recovery; original tree detours; autonomous occluded scent investigation; no ground penetration, no camp entry, no walking while planted/blocked.
- ecology-world.log: 54377 checks, 0 failures, all five species move in the actual forest over three seeds and four time transitions.
- npc-world.log: 4128 checks, 0 failures; Rowan walked 881.9 units across 16 map cells, Ash 1833.0 across 51 during a 70-second daytime simulation. Both walk to protected camp for night, without teleporting or entering ground solids.

Read-only integration review: torch fuel references and drop/recollection, off-hand torch with equipped weapons, full menu freeze, period synchronization and map-revision invalidation are consistent. NPC pause preserves its exact walk distance and moving flag, retaining the same rendered pose; setting moving=false would instead jump to the idle pose. These are headless real-game logic checks, not a claimed native manual playthrough.
