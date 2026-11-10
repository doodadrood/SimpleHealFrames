# SimpleHeal Changelog

## v1.1.5 (2026-11-09)
- **Universal `togglemenu` & Special Action Support**: `togglemenu`, `openbuffmenu`, and `caststoredbuff` now work across all mouse buttons (`LeftButton` through `Button5`) and all modifier combinations (`Shift`, `Ctrl`, `Alt`, `Ctrl+Alt`, `Ctrl+Alt+Shift`), including when modifier keys are released slightly before mouse-up.
- **Right-Click Menu Fix**: Prevented plain Right-Click or unbound modified Right-Clicks from falsely opening unit context menus when bound to a heal spell or left unbound.
- **Combat Secret Aura Protection (WoW 12.0)**: Fixed missing-buff alerts (`~ Name ~` tags and gold frame outline) falsely triggering during combat when WoW 12.0 locks unit aura inspection as secret values. Pre-combat buff state is preserved in combat and immediately updates if you cast the assigned buff during combat.
- **Performance & Headless Test Suite**: Added 13 automated headless LuaJIT test suites covering click bindings, secret string/aura taint guards, and zero-allocation combat health/mana event handling.
- **CurseForge & GitHub Automated Releases**: Configured automated testing and packaging for CurseForge (`1786366`) and GitHub Releases.
