<!-- ABOUTME: Working notes that saved time across tasks. One fact per bullet. -->
<!-- ABOUTME: Verified during T050 on 2026-11-19 unless noted. -->

# Learnings

- A scripted ride or walk that holds one fixed move direction across a
  city block stalls forever once a solid building lands between start and
  goal (T063: the touch ride's straight-down DOOR lesson pressed the cafe
  wall west of the door gap). Aim the held stick at a world anchor the beat
  must cross, like the door position, or teleport past the beat.
- The city look stage (dusk, weather, paper grain) veils exact-color pixel
  samples of world geometry in live-run screenshots. Probe the bare city map
  scene and free its LookStage child to sample kit colors and wall bands
  (T063 verified the cafe shell this way); sample the full run only for
  dusk-modulated presence checks.
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
- A SceneTree `-s` probe that paints a node in `_init` silently no-ops on
  `@onready` members (the appearance setter's build call sees a null visual
  and returns): await one `process_frame` after add_child before painting,
  then verify a part by node name, not by eye (seen T045, 2026-11-19).
- gdlint class-definitions-order fires when a const sits below the @export
  block of the same script; move consts above the exports (T045).
- The road west (T096) returns through a per-city world map, not through
  the slot's single run state: SaveData v6 stores city_worlds[city_id] with
  the progress, boss, outro, moving-day, tutorial, cold-brew, and tower
  fields, refreshed by every save point of its own city only. A return trip
  reads the world for the city beats and the MoveHandoff traveler for the
  player fields; the saved position never applies on a travel arrival, so
  the player spawns at the cafe like a first visit.
- The quest log rides the traveler now: park_traveler takes the QuestLog,
  and the chain (travel_east before parking, travel_west the same) names
  the arrival city, so side-quest states and route beats cross both roads.
- city_run.gd sat at both gdlint caps (1000 lines, 20 public methods) when
  T096 arrived: extract rather than append. CityRoads owns the triggers,
  arming, and the traveler park; MasterSchool owns the resident masters and
  the interact key; run accessors became public vars (roads, master_school)
  because vars do not count against max-public-methods.
- A west arrival into city 1 must take the parked van level too: _build_van
  gated the VanHandoff take on city_index > 1, which dropped the van level
  on the only city that never loaded one otherwise.
- The outro toast is the discoverability beat for the road west:
  POST_GAME_TEXT now says the road west is open; no second toast fires at
  arming time because the outro owns the screen of the last city.
- A city-scene west link must stay a path string, never an ext_resource:
  the east links already chain san_coffesco -> steamtle -> pourtland, so a
  west ext_resource closes a load cycle; the engine logs "referenced
  non-existent resource", binds one side null, and the broken runs surface
  far away (van economy counts, nil quest stages). Load the west scene at
  travel time, like the tutorial scene (T096).
- An Area2D trigger armed by set_deferred reads a STALE overlap when the
  player teleported off it in the same script turn: the physics server has
  not synced the body move, so body_entered fires for the old spot and the
  travel fires "by itself" (freed-city errors in the next asserts). Always
  await one physics frame between a teleport off a trigger and the beat
  that arms it (T096).
- A test that completes a city for a later REVISIT must cure the boss
  through the scene (demo_table/head/band try_wake with a 99.0 perfect
  cup), not by calling notify_boss_cured directly: the direct call marks
  the progress model but saves the boss scene uncured, so the returned
  city rebuilds the fight (T096).
- A custom Control that must show a meter value should extend Range, not
  Control: setting value or max_value clamps and calls queue_redraw on its
  own (verified by an Xvfb probe in T133), so the subclass only overrides
  _draw. ProgressBar compatibility for free. But Range rounds every set
  value to whole steps (step defaults to 1): 12.5 reads back 13, and
  99.9917 reads back 100. Meter tests must derive expected numbers from
  fill_fraction(), never from the float they assigned.
- Color has no length(): subtracting two Colors returns a Color. Measure a
  color distance through Vector3(c.r, c.g, c.b). And auto_free() returns a
  Variant, so "var x := auto_free(...)" trips inference-on-variant as an
  error; write "var x: Type = auto_free(...)" (T133).
- A newly added class_name does not parse in --script probes or the test
  runner until "godot --headless --path game --import" refreshes
  .godot/global_script_class_cache.cfg. The error reads "Could not find
  type X in the current scope" in the scripts that reference it (T133).
- The street crowd restores by per-walker flags in spawn order (T134): the
  block-kit markers build the crowd in one deterministic order per city
  definition and balance, so one bool per index maps the saved street onto
  the rebuilt one (a shorter street after a balance change just sleeps its
  tail). sleepwalker.gd sits at the 20-method cap, so the silent restore is
  a wake_up(restore := false) parameter, not a new method: no spoke line,
  no woke_up signal, and SleeperFigure.set_awake takes an instant flag so
  the color front stands complete instead of running its 0.9 s beat on
  every restored walker. city_run.gd sat one line under the file cap, so
  the snapshot helpers live in CrowdBuilder (awake_flags captures the live
  crowd, saved_flags reads the world dict) and the run changed two lines.
