# SimpleHeal (SimpleHealFrames)

Lightweight, zero-bloat click-casting, solo/pet unit frames, and missing-buff alert addon for **World of Warcraft**.

## Features
- **Universal Click-Casting**: Bind heals, dispels, `target`, `togglemenu`, `openbuffmenu`, or `caststoredbuff` across Left, Right, Middle, Button4, and Button5 clicks with `Shift`, `Ctrl`, `Alt`, `Ctrl+Alt`, and `Ctrl+Alt+Shift` modifiers.
- **Built-in Class Profiles**: Automatic out-of-the-box defaults for Paladin, Priest, Druid, and Shaman.
- **Per-Player Buff Assignments & Missing Buff Alerts**:
  - `Ctrl+Alt+Shift + Right-Click` any unit frame to assign a buff to that player.
  - `Ctrl+Alt+Shift + Left-Click` to cast their assigned buff.
  - Displays a gold frame border and `~ Name ~` indicator when an assigned buff is missing (with WoW 12.0 Secret Value & combat lockdown protection).
- **Solo & Pet Frames**: Clean, draggable unit frames with health and mana deficit readouts.

## Slash Commands (`/shf`)
- `/shf ui` — Open the click-binding configuration window
- `/shf move` — Toggle frame drag/unlock mode (`lock` / `unlock`)
- `/shf buffalert` — Toggle missing-buff alerts on or off
- `/shf buffalert outline` — Toggle the gold frame border alert
- `/shf buffalert tags` — Toggle the `~ Name ~` text tags
- `/shf clearbuffs` — Clear all stored per-player buff assignments

## Development & Headless Testing
Run the automated test suite locally using LuaJIT:

```bash
luajit -bl SimpleHeal.lua /dev/null
luajit tests/test_simpleheal.lua
```
