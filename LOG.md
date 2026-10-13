<!-- ABOUTME: Maintenance log for the Apocalypse Barista repository. -->
<!-- ABOUTME: One row per task, dated YYYY-MM-DD. Add new rows at the bottom. -->

# LOG

## Instructions
This log tracks all tasks completed in this project. Use one record per task with the following format:
- **Timestamp**: Date in YYYY-MM-DD format
- **Task**: Brief description of what needed to be done
- **Action**: Specific steps taken, including key commands/tools used
- **Result**: Outcome and any relevant metrics/details

Add new entries at the bottom of the table.

## Records
| Timestamp | Task | Action | Result |
|-----------|------|--------|--------|
| 2026-10-13 | Set up local environment | Checked tool versions: node v26.11.1, claude 2.1.284, gdformat 4.5.0. Found Godot 4.7.2 at /Applications/Godot.app as a manual install. Made a symlink to /opt/homebrew/bin/godot. No sudo needed. Java is absent. Deferred Java to Android export day. | Godot 4.7.2 on PATH. All other tools verified. |
| 2026-10-13 | Start git history | Renamed the unborn master branch to main. Committed GAME_DESIGN.md and brainstorm.md as the root commit. | Root commit 8742746 on main. |
| 2026-10-13 | Scaffold Godot project | Created game/project.godot: Compatibility renderer, 1280x720, stretch mode canvas_items. Vendored the GdUnit4 v6.2.2 addon (549 files). Added Makefile targets (import, lint, fmt, test, check, run), GitHub Actions CI (.github/workflows/ci.yml: Godot 4.7.2 Linux binary, gdtoolkit, make check), root .gitignore, README.md, CLAUDE.md. Agent persona "Maximum Froth", director "Niko Digger". | Commit 78b3aec. CI runs make check on push. |
| 2026-10-13 | Build vertical slice | Added a main menu (Play, Quit). Added a cafe level with walls. Player moves with WASD or arrows. Space or left-click throws a coffee cup toward the mouse. Added three sleepwalkers with states: wander, chase, hug, awake. A cup hit wakes a sleepwalker. A hug fills the sleep meter over ~3.7 s net, then the player sleeps: game over overlay with Restart. Wake all three to see the win overlay. Polygon2D placeholder visuals. | Commit 708de77. Full core loop plays. |
| 2026-10-13 | Fix two bugs found by tests | Bug 1: Area2D body_entered signal order is not guaranteed for siblings. The sense signal clobbered the HUG state. Fix: the sleepwalker now polls its sensor areas every physics frame. Bug 2: the player physics step ran before the sleepwalker fill, so is_asleep never saw 1.0. Fix: the sleepwalker announces sleep at fill time through player.fall_asleep(). | Both regression tests pass. States stay stable. |
| 2026-10-13 | Verify final state | Ran make check. It covers 9 GdUnit4 tests, unit and integration, headless, with real physics. | make check green. Output pristine. 0 orphans. Commits: 8742746, 78b3aec, 708de77, 9161d85 (icon .import metadata). |
| 2026-10-13 | Record deferred work | Deferred by decision: Java and Android SDK, APK builds, Godot MCP bridges, touch controls, real art. Note: Niko edited GAME_DESIGN.md live (brewing methods, brewing masters). That edit stays uncommitted and untouched. | Scope and open edit recorded for the next session. |
| 2026-10-13 | Complete the V1 game design document | Reconstructed the garbled Croatian transcript in brainstorm.md and confirmed unclear points with Niko. Locked canon: Sleep Debt story chain, the ever-looping address as antagonist, Decaf City as decaf capital. Named the world: United States of Americano, San Coffesco, Steamtle, Pourtland, and seven later cities. Defined enemies and bosses (The Karen, Sam Oatman, Second Snooze, Sleepvana, Fish Throwers), brewing methods and masters, the SleepyDex, weapons on the coffee=health+mana+ammo economy, the sleepy meter with wake-ups, Normal/Hardcore modes. Cut tank, driving, and all economy (no money, scavenging only). Scoped V1 to three cities, Android first, first city free with one payment to unlock. Wrote sections 1-24 including items, recipes, V1 roster, level design rules, save system, tutorial, art direction, loop audio rules, Dr. Morgen opening script, post-game + Double Shot NG+, Moonwalker mystery. | GAME_DESIGN.md +174 lines. make check green (9/9 tests) before commit. Design ready for V1 implementation. |
