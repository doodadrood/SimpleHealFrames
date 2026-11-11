# SimpleHeal Changelog

## v1.1.7 (2026-11-11)
- **Multi-Buff Dynamic Duration Cycling (`Ctrl+Alt+Shift+Left-Click`)**: Casting stored buffs on a player with multiple assigned buffs now intelligently cycles through all of them instead of only recasting the first buff:
  - **Out of Combat**: Evaluates remaining aura durations across all assigned buffs and automatically prioritizes any missing buffs first, followed by whichever buff has the shortest remaining duration. Rapid clicks seamlessly refresh each buff as they run low.
  - **In Combat**: Uses a secure `/castsequence` pre-sorted by pre-combat duration priority that advances on each successful cast and automatically resets to the top of the sequence after an idle window.
  - **Independent Unit Cycles**: Each unit frame retains its own sequence state so switching targets immediately begins at the top of that specific player's priority list.
- **Configurable In-Combat Cycle Reset Delay**: Added `/shf buffcycle <seconds>` to customize the in-combat multi-buff cycle reset delay (1–60s, default 5s).

## v1.1.6 (2026-11-10)
- **Multi-Buff Toggle Selector (`Ctrl+Alt+Shift+Right-Click`)**: Buff buttons in the selector menu now toggle ON (`[x]`) and OFF (`[ ]`) without immediately closing the menu, allowing multiple buffs (e.g., *Divine Spirit* and *Power Word: Fortitude*) to be tracked and cast per player.
- **Dynamic Missing-Buff Alert & Macro Queue (`Ctrl+Alt+Shift+Left-Click`)**: Checks all enabled buffs on each player; if one or more assigned buffs are missing, displays the `~ Name ~` tags and gold outline and automatically updates `caststoredbuff` to cast whichever buff is currently missing.
- **Right-Click Class-Wide Buff Assignment**: Right-clicking a buff in the selector menu toggles that buff ON or OFF for every member of that player's class across your party or raid group. Added `"Left Click: Individual | Right Click: Class"` header to the top of the menu.
- **Click-Away & Escape Dismissal**: The buff selector menu now closes cleanly when clicking anywhere outside the menu (`GLOBAL_MOUSE_DOWN`) or pressing `Escape` (`UISpecialFrames` + `OnKeyDown`).

## v1.1.5 (2026-11-09)
- **Universal `togglemenu` & Special Action Support**: `togglemenu`, `openbuffmenu`, and `caststoredbuff` now work across all mouse buttons (`LeftButton` through `Button5`) and all modifier combinations (`Shift`, `Ctrl`, `Alt`, `Ctrl+Alt`, `Ctrl+Alt+Shift`).
- **Right-Click Menu Fix**: Prevented plain Right-Click or unbound modified Right-Clicks from falsely opening unit context menus when bound to a heal spell or left unbound.
- **Combat Secret Aura Protection (WoW 12.0)**: Fixed missing-buff alerts (`~ Name ~` tags and gold frame outline) falsely triggering during combat when WoW 12.0 locks unit aura inspection as secret values.
