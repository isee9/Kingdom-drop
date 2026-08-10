# KINGDOM DROP — ART PACK GUIDE

This pack is intended to replace the prototype/default web visuals with a polished fantasy-casual mobile-game presentation.

## Visual target
`reference/visual_target_reference.png`

Use this as the overall look-and-feel reference: royal blue/navy panels, gold trim, glossy colourful puzzle blocks, strong fantasy castle imagery, large premium buttons, and readable mobile UI.

## Branding
- `branding/kingdom_drop_logo.png` — main title/logo artwork.
- `branding/app_icon_crown.png` — app/store icon concept.

## Backgrounds
- `backgrounds/home_castle_sunset.png` — home / kingdom landing screen background.
- `backgrounds/gameplay_twilight.png` — gameplay background behind the puzzle board.
- `backgrounds/castle_mountains.png` — alternate kingdom / progression background.
- `backgrounds/night_castle_ui_backdrop.png` — alternate darker screen backdrop for menus, game over, shop or challenges.

All UI should keep text and controls readable over the artwork using dark translucent overlays where needed.

## Kingdom progression
- `kingdoms/forgotten_keep_progression_v1.png`
- `kingdoms/forgotten_keep_progression_v2.png`

These show ruined -> partially restored -> completed Forgotten Keep states. Claude may crop/slice the best progression artwork into individual scene assets if required.

## UI art
- `ui/ui_kit_primary.png` — buttons, panels, bars and royal-blue/gold UI treatment.
- `ui/ui_panels_secondary.png` — additional panels for game over, daily rewards, shop, challenge and related screens.

Where possible, treat UI sprite sheets as visual source art and slice individual components. For dynamic labels, use text rendered by the app over text-free or neutral panels rather than baking changing text into images.

## Icons
`icons/game_icons.png`

Contains visual concepts for:
- coins
- crowns
- XP
- treasure chests
- daily/calendar
- hammer
- bomb
- shuffle
- second chance
- mystery chest
- shop/settings/support-style icons

Slice into individual PNG assets where useful.

## Puzzle tiles
`tiles/puzzle_tiles.png`

Contains glossy coloured block styles and board-state references. Use these as source art for:
- red tile
- yellow tile
- green tile
- blue tile
- purple tile
- orange tile
- empty board cell
- valid placement indicator
- invalid placement indicator

Maintain consistent tile size and corner radius across the 7x7 board.

## Integration notes for Claude
1. Do not redesign the art direction from scratch.
2. Match `reference/visual_target_reference.png` as closely as practical while keeping the existing game mechanics intact.
3. Replace flat prototype backgrounds, plain CSS boxes and default controls with this art direction.
4. Use responsive cropping / `BoxFit.cover`-style behaviour for portrait backgrounds.
5. Preserve safe areas and mobile readability.
6. Keep the game board highly legible against backgrounds.
7. Use proper code-rendered text for dynamic values, scores, prices and labels.
8. Slice sprite sheets programmatically or manually into reusable assets if the project benefits from separate files.
9. Optimise exported assets for mobile/web without visibly degrading quality.
10. Do not stretch artwork non-proportionally.

## Recommended target folder in the app
`assets/art/`

Suggested subfolders:
- branding/
- backgrounds/
- kingdoms/
- ui/
- icons/
- tiles/

## Important
This is a complete V1 visual foundation. Some sprite sheets still contain multiple elements on one image; Claude should slice/crop these during integration where necessary. Final store submission may benefit from later artwork iterations, but this pack is sufficient to replace the current prototype visuals and establish the commercial look.
