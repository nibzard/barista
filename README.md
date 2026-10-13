<!-- ABOUTME: README for the Apocalypse Barista repository. -->
<!-- ABOUTME: Tells a new contributor what the game is and how to build and test it. -->

# Apocalypse Barista

Comedy top-down 2D action-adventure for Android. A barista wakes a nation of
sleepwalkers, one cup at a time. The design spec lives in `GAME_DESIGN.md`.

## Stack

- Godot 4.7.2, Compatibility renderer, typed GDScript
- GdUnit4 for tests, vendored in `game/addons/gdUnit4/`
- gdformat / gdlint, Makefile, GitHub Actions

## Commands

| Command | What it does |
| --- | --- |
| `make check` | Format check, lint, headless test run |
| `make run` | Launch the game on desktop |
| `make fmt` | Auto-format GDScript |

First-time setup: install Godot 4.7.2, then `pipx install 'gdtoolkit==4.*'`.
