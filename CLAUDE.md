# Apocalypse Barista

Team: **Maximum Froth** (Claude Code, the agent) and **Niko Digger** (Nikola, game director). Address the human as Niko.

## What this is

Comedy top-down 2D action-adventure for Android: a barista wakes sleepwalkers with coffee.
The full concept spec is `GAME_DESIGN.md` at the repo root — read it before implementing gameplay.
`brainstorm.md` is Niko's raw Croatian voice transcript. Never edit it.

## Stack

- Godot 4.7.2, Compatibility renderer, landscape orientation.
- Statically typed GDScript. Annotate all function signatures and member types.
- GdUnit4 tests live in `game/tests/` (`unit/` for pure logic, `integration/` for scenes). The addon is vendored in `game/addons/gdUnit4/`.
- gdformat + gdlint via pipx `gdtoolkit==4.*`.
- Android is the target platform; desktop is the development platform.

## Commands

- `make check` — format check, lint, headless tests. Must pass before every commit.
- `make run` — launch the game on desktop.
- `make fmt` — auto-format GDScript.

## Architecture rules

- Small scenes; composition over inheritance.
- Reusable components live in `game/scripts/components/`.
- Decouple gameplay logic from presentation so tests never need rendered output.
- Balance values go into `.tres` resources, not hardcoded numbers.
- Signals for cross-node communication; keep autoloads minimal.
- Touch-first design: gameplay must work without a keyboard. Desktop keys are development conveniences only.
- Placeholder shapes are fine until real art exists; never block on assets.

## Quality rules

- Every gameplay mechanic ships with GdUnit4 tests.
- For bugfixes, write the failing test first.
- Never say a test passed unless you ran it and read the output.
- Test output must be pristine: no errors, no warnings, no stray prints.
- ASD-STE100 English in all comments and docs. Every code file starts with a two-line `ABOUTME:` header.
- Run `make check` until green before reporting work as complete.

## Agent safety

- Never edit `brainstorm.md`.
- Never delete source assets without approval.
- No new addons or dependencies without Niko's approval.
- Never touch signing credentials or store publishing.
- Android build targets come later; do not add them speculatively.
