# Jason personal website

Speak Chinese with Jason. The public site is bilingual; the game remains English.

## Persistent design decision — 2026-10-19

Whenever Jason adds another game, first remind him to choose that game's own background, color palette, visual atmosphere, and the transition from the portfolio into its world. Each game lives in an independent space. Do not silently apply Forest Wanderer's theme to a new game. The portfolio is the shared entrance. The first theme is the forest.

## Source and release rules

- Keep Sites project_id `appgprj_6ad2dc3761bc81918b546e708b10733b`; never register a duplicate Site. Existing audience is public.
- `dist/assets/content.js` is the public content registry: profile, optional contacts, games, themes and bilingual copy. Never invent contact details. null values remain hidden.
- Add a game to the registry and give it its own directory under `dist/games/`. Confirm its theme with Jason before implementing it. Keep only one actual game until another is supplied.
- Game binary resources, native PNGs, and original game releases are read-only sources. All site wrapper changes stay here. Preserve Rowan A as Forest Wanderer's cover and preserve the original WASM/PCK bytes and native image quality.
- No game engine or data downloads on the home page. Downloads begin only after a visitor presses the game's start button. Preserve safe-area/DPR rendering, one owner for browser suspension, and full simulation pause.
- Check actual browser startup and interactions before moving an accepted candidate to `output/personal-website x.x.x/`. Evidence and intermediates belong under `tests/personal-website/x.x.x/`.
- Credential tokens belong in memory and helper stdin only. Use the Sites workflow to open/push/package/publish and retain project identity. Never persist credentials in files or logs.
- No second automatic duplicate publication. Save and deploy only the pushed and tested source state; record the returned URL and deployment result.
