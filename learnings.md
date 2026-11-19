<!-- ABOUTME: Working notes that saved time across tasks. One fact per bullet. -->
<!-- ABOUTME: Verified during T050 on 2026-11-19 unless noted. -->

# Learnings

- The Write tool can report success without creating files in this worktree
  (seen 2026-11-19). Verify every created file with `ls` or `test -f`, and
  fall back to Bash heredocs when a file is missing.
- A python3 edit script that asserts on its anchors applies no change at all
  when an assert fails: the file is never written. Re-run the remaining
  edits after fixing the failed anchor, or the fixed anchor silently keeps
  the old text.
- gdlint fires max-file-lines at 1001 lines (1000 passes) and
  max-public-methods at 21 (20 passes). city_run.gd, player.gd, and
  sleepwalker.gd sit at the 20-method cap: new behavior enters through
  public member variables (a component handle or an enum var) instead of
  new public functions.
- GDScript statement chains cannot continue with a leading dot outside
  parentheses. Wrap the chained assert in parentheses, or bind the long
  expression to a local first.
- A leading-dot enum placement breaks class-definitions-order: signals,
  then enums, then consts. Public vars must also precede private vars.
- A test helper that awaits must be awaited by every caller, or the test
  races ahead mid-helper and reads null handles (hit again in T050 after
  test_paywall_gate; the trap is in the memory index as
  gdscript-await-helper-coroutine-trap).
- Jumping a wrapping clock with `advance(cycle - t)` lands on the wrap point
  where float wobble can flip the window check. Aim mid-window:
  `advance(cycle + window * 0.5 - t)`.
- A minigame that input-locks the player while they stand still (the
  dance-off, about 7 s in a plaza) invites the plain crowd: a wandering
  neighbor reaches and grabs the locked player, so post-minigame asserts on
  player control read a grab, not the mechanic. Wake the whole sleeper group
  and settle frames before asserting rolls (verified 3/3 by probe; wake_up
  clears a HUG grab through player.clear_grab).
- Node2D.rotation reads back as float32: -0.3 becomes -0.30000001192093.
  Compare nonzero rotation pins with is_equal_approx(value, 0.01), the
  test_support_tools.gd precedent; exact is_equal works only for 0.0.
- begin_dodge gates on grabbed/asleep/stunned/dodging/cooldown, and the
  dodge lean and velocity apply on the player's next physics tick: assert
  begin_dodge's return first, await one frame, then read velocity,
  invulnerability, and rotation.
- Adding a field to the save document bumps SAVE_VERSION (the rule since
  the game-mode bump): every older slot reads as no save, so the version
  fixtures in test_save_store.gd and test_save_run_state.gd move with it.
- A save/load feature that must stay silent on reload (T130 boss cure)
  needs its own wake path, not the live beat: no spoke line, no wake
  signal, no deferred celebration, or the reload replays the story beat
  the slot already recorded.
- A thrown CoffeeCup's physics body flies a straight line from start to
  landing; the parabola is visual-only (visual.position). A raised stage
  like the Sleep Jam band (CollisionShape2D 140 px above the band origin)
  never catches a street-level throw: stand beside the stage at stage
  height and throw across it, like test_sleep_jam's STAGE_LOCAL_OFFSET.
- A new save point value (string) needs no SAVE_VERSION bump; only a new
  document field does.
- The ended outro never saved before T055: the slot kept the flow at
  ARRIVAL and every reload replayed the credits with the input locked.
  CityRun now records POINT_POST_GAME on flow.finished, the one-line
  lambda beside the POINT_PURCHASE precedent.
- The cafe-entry save fires on a rising edge of the cafe-area overlap, and
  the overlap of a fresh city lags a physics flush: a teleport right after
  the build can race the first save and capture the teleported spot. Walk
  out, wait ~12 physics frames for the flush, walk back in, and poll the
  slot for the position and the count together.
- The menu Play button continues straight into a saved city when the slot
  holds a run state. A test that wants the menu-creation-intro chain must
  wipe the slot first (hit in T055 modes: the assert diff showed the
  continue city path, not the creation path).
