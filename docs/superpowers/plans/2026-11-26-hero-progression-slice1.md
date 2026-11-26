# Hero Progression, Slice 1 (Caelen + Orion) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Caelen and Orion each grow through three unlockable abilities (1–3 and 10–12 of the design), with all the
shared machinery (data, sim steps, save, card, hints, goldens, balance report), so the creator can play the slice
before Seraphine and Nimue are built.

**Architecture:** `data/progression.json` describes each hero's abilities and their attack slots; `sim/progression.gd`
loads it. `World.from_level`/`partner_slice` take a `steps` dictionary and stamp each hero fighter with its step;
every ability's sim code is gated on `Fighter.step` before any RNG draw, so step 0 is today's game bit for bit. The
game layer owns earning, saving and showing.

**Tech Stack:** Godot 4.7.2, statically typed GDScript, headless test scripts (`extends SceneTree`).

**Spec:** `docs/superpowers/specs/2026-11-26-hero-progression-design.md` (approved 2026-11-26).

## Global Constraints

- Step 0 is today's game: all 64 Swift and 12 Godot goldens replay unchanged after every sim task. A moved golden is a bug, not a re-record.
- Every new branch in the sim, the partner brain and the autopilot is gated on the step **before** any RNG draw.
- No new `InputFrame` field. Triggers are context on existing presses.
- `spec.attacks` is never extended; new swings are named slots.
- `tuning.json`'s Swift entries stay untouched. Levers: ability numbers in `progression.json`, Chapter 4 level data, the port-only Mason/Heart specs.
- New `Fighter` fields appear in `to_canon()` / `state_canon()` / event dictionaries **only when non-default**, so step-0 hashes do not move.
- `Fighter.copy()` copies every new field.
- `tools/check_sim.sh` must pass: no `minf`/`maxf`/`clampf`/`Vector2` in `sim/`.
- Godot golden re-records and new goldens go in their own commit, saying why.
- Git: `export GIT_DIR="$PWD/.git" GIT_WORK_TREE="$PWD"`. Godot: `G=~/Downloads/Godot.app/Contents/MacOS/Godot`.
- Card text and ability names are exactly the design table's (PROPOSED, DRAFT-015).

## Review Focus

1. **Player-controlled Orion dodging toward Caelen with Adapt ready** expects a real dodge (travel, i-frames) that then guards. Pinned in Task 6.
2. **A level restart or checkpoint retry** keeps the run's step (the world is rebuilt through `_make_world`). Pinned in Task 8.
3. **An old save on a Chapter 4 level with no steps key** must play at step 3, not 0. Pinned in Task 8.
4. **A swing that reaches both Caelen and an interposing Orion** is absorbed once and counters once. **An interposer too far away** absorbs nothing. Pinned in Task 6.
5. **A Break Guard mark that expires mid-fight** brings the shield back. Pinned in Task 4.

---

### Task 1: Progression data, loader and steps plumbing (no behaviour)

**Files:**
- Create: `data/progression.json`, `sim/progression.gd`, `tests/test_progression.gd`
- Modify: `sim/fighter.gd` (field `step`, copy, canon), `sim/world.gd:97` (`from_level`), `sim/world.gd:90` (`partner_slice`), `sim/world.gd` `spawn()`, `tools/run_tests.sh`

**Interfaces:**
- Produces:
  - `class_name Progression`
    - `static func load_default() -> Progression`, cached.
    - `func abilities(kind: String) -> Array[Dictionary]`, ordered by step.
    - `func ability(kind: String, id: String) -> Dictionary`
    - `func slot(kind: String, id: String) -> Specs.AttackSpec`, built with the same parser as `tuning.json` attacks (`Specs.AttackSpec.from_json` or its equivalent at `sim/specs.gd:~90`).
    - `static func chapter_step(level_id: String) -> int`: the 0-based index of the first chapter in `data/index.json` whose any-lead route contains the id, capped at 3; 0 if not found.
    - `static func has(f: Fighter, id: String) -> bool`: true when `f.kind`'s ability `id` has `step <= f.step`.
  - `Fighter.step: int = 0`.
  - `World.steps: Dictionary` (kind → int).
  - `World.from_level(p_level, hero, p_tuning, seed, from_checkpoint := -1, p_collected := {}, p_steps := {}) -> World`
  - `World.partner_slice(seed, p_tuning, p_steps := {}) -> World`
  - `spawn()` sets `f.step = steps.get(f.kind, 0)` for team "hero".

`data/progression.json`: one object keyed by hero kind. Each ability has these fields:
- `id`, `step`, `name`, `card`, `button` (`"attack"|"special"|"dodge"`).
- `hint`: `{event, field, index?, text}`.
- Optionally `slot` (attack fields as in `tuning.json`) and `pose` (base attack index to draw).
- Optionally ability numbers (`window`, `reach`, `redirect`).

Slice 1 contents:

| kind | id | step | slot / numbers | hint |
|---|---|---|---|---|
| caelen | `riposte` | 1 | slot: windup 4, active 5, recovery 18, damage 26, reach 74, height 80, yOffset 6, knockback 320, lunge 120, hitstun 24, hitStop 6, effect strike; `window` 40; pose 1 | parried / by / "Attack now: Riposte" |
| caelen | `break_guard` | 2 | none | commanded / by / "Marked enemies cannot block" |
| caelen | `full_arc` | 3 | slot: windup 7, active 6, recovery 24, damage 24, reach 80, height 80, yOffset 6, knockback 360, lunge 60, hitstun 26, hitStop 7, bothSides true; pose 2 | swing / id / index 2 / "Attack again: Full Arc" |
| orion | `follow_through` | 1 | slot: windup 4, active 4, recovery 18, damage 15, reach 60, height 70, yOffset 10, knockback 300, lunge 140, hitstun 22, hitStop 5; pose 1 | swing / id / index 1 / "Attack again: Follow-Through" |
| orion | `answer_for_both` | 2 | slot: Orion's `tuning.json` attack 1 with bothSides true; pose 1 | absorbed / by / "Your counter cuts both ways" |
| orion | `interpose` | 3 | `reach` 160, `redirect` 100 | guarded / id / "Dodge toward your partner to guard them" |

Fields not listed take `holdsStill` false, `slowFrames` 0, `bothSides` false and `effect` "strike". Names, cards and buttons are verbatim from the design table.

- [ ] **Step 1: Write the failing tests** in `tests/test_progression.gd`, following `tests/test_eclipse.gd`'s `check()` and summary-line pattern (`progression: N checks, M failed`, exit 1 on failure):
  - `Progression.load_default().abilities("caelen").map(id) == ["riposte","break_guard","full_arc"]`; Orion's are `["follow_through","answer_for_both","interpose"]`.
  - `chapter_step("awakening") == 0`, `"cinder_vault" == 1`, `"oracles_terrace" == 2`, `"heart" == 3`, `"nope" == 0`.
  - `World.from_level(Level.load_id("protocol"), "caelen", t, 1, -1, {}, {"caelen": 2, "orion": 2})`: every hero fighter has `step == 2`. The same level with `{}` has `step == 0`.
  - `Progression.has(f, "break_guard")` is true at step 2 and false at step 1.
  - `slot("caelen","full_arc").both_sides == true`.
- [ ] **Step 2: Run, expect failure.** `$G --headless --path . -s tests/test_progression.gd` reports parse errors or FAILs.
- [ ] **Step 3: Implement** the JSON, `Progression`, `Fighter.step` (copied; in `to_canon()` only when non-zero), the `World` params and the `spawn()` stamp. Add `run '^progression: [0-9]+ checks, 0 failed' -s res://tests/test_progression.gd` to `tools/run_tests.sh` after eclipse.
- [ ] **Step 4: Run the test** (expect 0 failed), then `GODOT=$G tools/run_tests.sh`. Expect 64/64 and 12/12 replays, every suite green.
- [ ] **Step 5: Commit:** "Progression: data, loader and steps in the sim (no behaviour yet)".

### Task 2: Attack slots, Full Arc and Follow-Through

**Files:** Modify `sim/fighter.gd`, `sim/world.gd:444-458` (ATTACK branch), `sim/world.gd:493-496` (idle attack start), `sim/world.gd:524` area. Test: `tests/test_progression.gd`.

**Interfaces:**
- Consumes: `Progression.slot`, `Progression.has`.
- Produces:
  - Fields: `Fighter.slot: String = ""` and `Fighter.slot_attack: Specs.AttackSpec = null`. `enter()` clears both. `current_attack()` returns `slot_attack` when set and in ATTACK. `state_canon()` adds `"slot"` only when set.
  - `World._start_slot(f: Fighter, id: String, inp: InputFrame, events: Array) -> void`: like `_start_attack`, with `attack_index` = the ability's `pose`. It emits `{"case":"swing","id","index":pose,"slot":id}`.
  - `World._finisher_id(f: Fighter) -> String`: `"full_arc"` for caelen, `"follow_through"` for orion, when `has`; else `""`.
- The ATTACK branch reads `f.current_attack()` instead of `f.spec.attacks[i]`.
- Chaining happens only when `f.slot == ""`:
  - `i + 1 < size` starts swing `i + 1`.
  - Otherwise, a non-empty `_finisher_id` starts that slot.
- Slots never chain.

- [ ] **Step 1: Failing tests:**
  - Caelen at step 3 on a flat test arena (built like `test_eclipse.gd`'s `arena`) with a dummy enemy in reach. Pressing attack every frame for 120 frames emits swing events with indices 0, 1, 2, then one with `slot == "full_arc"`. At step 2, no `slot` key appears.
  - The full_arc hitbox spans both sides of Caelen, and an enemy behind him is hit.
  - Orion at step 1 chains 0, 1, then `follow_through`. At step 0 there is no slot.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the interfaces above.
- [ ] **Step 4:** Run `tests/test_progression.gd`, `tools/check_sim.sh` and the full `tools/run_tests.sh`. Expect all green, with 64/64 and 12/12 replays.
- [ ] **Step 5: Mutation check:** drop the `f.slot == ""` guard. The "slots never chain" check must fail; restore it. Commit: "Progression: attack slots; Caelen's Full Arc, Orion's Follow-Through".

### Task 3: Riposte

**Files:** `sim/fighter.gd` (`riposte_frames: int = 0`, canon only when > 0), `sim/world.gd` (`_land` parry branch around line 1210; buffer decrements around line 507; ATTACK chain and idle start). Test: `tests/test_progression.gd`.

**Interfaces:** Consumes `_start_slot`, `Progression.ability("caelen","riposte").window`.
- When a hero with `riposte` parries in `_land`, set `riposte_frames = window`.
- It decrements once per frame beside the other buffers.
- With `riposte_frames > 0` and an attack press, the next swing (chain point or idle start) is `_start_slot(f, "riposte")`, which zeroes `riposte_frames`.
- The riposte swing takes precedence over `i + 1` and the finisher.

- [ ] **Step 1: Failing tests:**
  - A forged soldier's slash parried by Caelen at step 1, then attack pressed within 40 frames: a swing with `slot == "riposte"` follows.
  - At step 0 the same inputs give swing index 1 (today's chain).
  - Pressing at frame 41 or later after the parry gives no riposte.
- [ ] **Step 2: Run, expect FAIL.** **Step 3: Implement.** **Step 4:** Progression tests plus the full suite, 64/64 and 12/12.
- [ ] **Step 5: Mutation check:** gate off the step check. The step-0 check must fail; restore it. Commit: "Progression: Caelen's Riposte".

### Task 4: Command: Break Guard, and the bots using it

**Files:** `sim/fighter.gd` (`mark_breaks_guard: bool = false`, canon only when true; `is_guarding()` returns false while `marked_frames > 0 and mark_breaks_guard`), `sim/world.gd` `_resolve_commands` (~1052, sets it when the marker `has` break_guard and the target `not spec.boss`; clearing a mark clears it), `sim/autopilot.gd` `_kit_special` "command" case (~482). Test: `tests/test_progression.gd`.

**Interfaces:**
- `Fighter.is_guarding()` is the single source of truth, so `_land` (`world.gd:1220`), `autopilot.gd:138` and `brains.gd:1056` follow automatically.
- Autopilot: when `me.step >= 2`, Command is ready and a non-boss foe with `spec.frontal_block` is within `special.range` in front, press special.

- [ ] **Step 1: Failing tests:**
  - Caelen at step 2 marks a forged soldier. His frontal hit lands (`hurt` event, no `blocked`).
  - Review Focus 5: after `marked_frames` reaches 0, a frontal hit is `blocked` again.
  - A boss (load `wardens_gate`; Line Warden) marked at step 2 still blocks.
  - At step 1 a marked soldier still blocks.
  - The autopilot at step 2, facing a soldier with Command ready, emits `commanded` within 60 frames.
- [ ] **Step 2: FAIL.** **Step 3: Implement.** **Step 4:** Progression tests plus the full suite, 64/64 and 12/12.
- [ ] **Step 5: Mutation check:** drop `not spec.boss`; the boss check must fail. Commit: "Progression: Command breaks guards (not bosses'); the autopilot uses it".

### Task 5: Adapt: Answer for Both, and a counter that never chains

**Files:** `sim/world.gd` `_land` adapt branch (1194-1209). Test: `tests/test_progression.gd`.

**Interfaces:**
- When the absorbing fighter's `step >= 1`, the counter starts as slot `"counter"` instead of plain `enter_attack(size - 1)`. Being a slot, it never chains into Follow-Through.
- At step 1 its `slot_attack` is the last base attack; with `answer_for_both`, it is that ability's slot.
- `swing_scale = counterScale` and the invulnerability use the counter's `total()`.
- At step 0 the code path is exactly today's.

- [ ] **Step 1: Failing tests:**
  - Orion at step 1 absorbs a hit: the counter swing has `slot == "counter"`, and attack presses during it do not start `follow_through`.
  - At step 2 the counter hits an enemy behind him.
  - At step 0 the swing event has no `slot`, as today.
- [ ] **Step 2: FAIL.** **Step 3: Implement.** **Step 4:** Progression tests plus the full suite, 64/64 and 12/12.
- [ ] **Step 5: Commit:** "Progression: Orion's Answer for Both; Adapt's counter never chains".

### Task 6: Interpose

**Files:**
- `sim/fighter.gd` (`interpose_for: int = -1`, canon only when ≥ 0).
- `sim/world.gd`:
  - `_start_dodge` (534).
  - The DODGE branch end (437-443).
  - The GUARD_STANCE exit (425).
  - `_resolve_hits` (1160).
- `sim/brains.gd` `partner()` (958, before the threat loop).
- Test: `tests/test_progression.gd`.

**Interfaces:**
- `_start_dodge`: an Orion with `interpose`, `special_cooldown == 0` and the other living hero within `reach` (160) in the dodge's direction sets `interpose_for = other.id`. Otherwise it is a plain dodge.
- At dodge end with `interpose_for >= 0`:
  - Enter `GUARD_STANCE` for Adapt's `window` and set `special_cooldown = cooldown`.
  - Emit `{"case":"guarded","id"}`.
- Leaving GUARD_STANCE resets `interpose_for = -1`.
- `World._interposer(target_id: int, target_x: float) -> int`: index of a living hero in GUARD_STANCE with `interpose_for == target_id` and `absf(dx) <= redirect` (100), else -1.
- In `_resolve_hits`, a hit on hero `t` with `_interposer >= 0` lands on the interposer instead (`_land(attack, a, g, ...)`). Both ids go into `hit_ids`, so the swing cannot also hit the other one.
- Partner brain: when `me.step >= 3` and Adapt is ready, the lead within 160 px, and a foe's strike in WINDUP with `windup - state_frame <= 10` reaching the lead, return a dodge toward the lead. This check runs before any `rng` call.

- [ ] **Step 1: Failing tests:**
  - **Review Focus 1:** Orion, controlled, at step 3, dodges toward Caelen 120 px away. He is dodge-invulnerable during the dodge, then in GUARD_STANCE, and his special cooldown is spent.
  - Without Adapt ready, the same dodge is plain (no guard).
  - **Review Focus 4:** a soldier's slash that would hit Caelen, with Orion interposing within 100 px:
    - Caelen's HP is unchanged.
    - One `absorbed` event with `by == orion.id`.
    - Exactly one counter swing.
  - Orion interposing 140 px away: Caelen takes the hit.
  - The partner brain at step 3 with Caelen threatened returns `dodge == true` toward Caelen.
  - At step 2 it consumes the same RNG sequence as today: compare `w.rng` state after 300 frames of a partner-slice run at steps `{}` and `{"orion": 2}`.
- [ ] **Step 2: FAIL.** **Step 3: Implement.** **Step 4:** Progression tests plus the full suite, 64/64 and 12/12.
- [ ] **Step 5: Mutation check:** remove the `hit_ids` double insert. The single-absorb check must fail; restore it. Commit: "Progression: Orion's Interpose".

### Task 7: Chapter steps in the level suites, golden headers, new goldens, balance report

**Files:**
- `tests/replay.gd:62-72` (`header.get("steps", {})` passed to both constructors).
- `tools/record_golden.gd` (`--chapter-steps` flag; header `"steps"`; run id suffix `-step%d` when > 0).
- `tests/test_levels.gd:26` and the `test_eclipse.gd` drop loop (~239): steps `{lead: cs, "orion": cs}` with `cs = Progression.chapter_step(id)`.
- Create `tools/balance.gd`.

**Interfaces:** `tools/balance.gd -- [--seeds=1-10]`:
- For each boss level (`protocol, wardens_gate, lamp_row, cinder_vault, cloister_gate, oracles_terrace, masons_span, heart`) × lead (caelen, seraphine, nimue) × step in `{0, chapter_step}`:
  - Play `Autopilot.new(true)` at damage scale 1.0 for up to 240 s.
  - Print a markdown row: level, lead, step, wins/seeds, lowest final hero HP over wins.

- [ ] **Step 1:** Run the full suite plus `tests/test_levels.gd` with the chapter steps wired. Expect levels 228/228 and eclipse green. **Acceptance:** the eclipse drop loop and `test_levels` pass at chapter steps. If anything fails, stop and debug (superpowers:systematic-debugging) before going on.
- [ ] **Step 2:** Commit: "Level suites play each chapter at its step; goldens carry steps".
- [ ] **Step 3: New goldens.** Run `record_golden.gd -- --levels=cinder_vault,oracles_terrace,heart --chapter-steps`, which records Caelen fighting at steps 1, 2 and 3. Then replay `--dir=golden_godot --pilot`; all must match. Commit on its own: "Godot goldens: Caelen at his chapter step on the Chapter 2-4 bosses".
- [ ] **Step 4:** Run `tools/balance.gd`. Save the table to `docs/balance/2026-11-26-progression-slice1.md` and commit it. Flag every row where the lowest final HP more than doubles from step 0 to the chapter step. Those rows go to the creator as retune proposals; do not retune here.

### Task 8: Earning, saving, migration, New Game reset, `--steps`

**Files:**
- `game/game_scene.gd`: load ~116-126, `_make_world` 217, the `levelComplete` handling ~1272, the save ~1004, `begin_as`.
- `game/game_app.gd:176` (`begin`).
- Test: `tests/test_flow.gd`.

**Interfaces:**
- `GameScene.earned_step: int`, `GameScene.seen: Array[String]`.
- Save keys: `progress/steps_<lead>` and `progress/seen_<lead>`.
- `static func GameScene.effective_step(earned: int, level_id: String, override: int) -> int`:
  - returns `override` when ≥ 0;
  - otherwise `maxi(earned, Progression.chapter_step(level_id))`.
- Load: `earned_step = saved.get_value("progress", "steps_" + lead, Progression.chapter_step(saved_level_id))`, which migrates old saves.
- `--steps N` sets the override (default -1). Demo mode uses `chapter_step`.
- `_make_world` passes `{lead: s, "orion": s}` to `from_level` and to `partner_slice`; in the Training Room, `s = earned_step`.
- On `levelComplete` of a chapter-ending level of Chapter N ≤ 3:
  - `old = earned_step`; `earned_step = maxi(old, N)`.
  - Save before emitting.
  - `_level_result()["unlocks"]` = the lead's and Orion's abilities with `old < step <= earned_step`, as `{name, card, button}`.
- `begin_as(lead)` (New Game) sets `earned_step = 0` and `seen = []` for that lead and saves.

- [ ] **Step 1: Failing flow tests:**
  - Finishing `protocol` as Caelen from step 0 sets `earned_step == 1`, and `unlocks` lists Riposte, then Follow-Through.
  - Replaying `protocol` at step 1 lists no unlocks.
  - **Review Focus 3:** a temp `progress.cfg` with `level = "masons_span"` and no steps key loads `earned_step == 3`.
  - New Game as Caelen resets it to 0.
  - `effective_step(0, "heart", -1) == 3`, `effective_step(3, "awakening", -1) == 3`, `effective_step(3, "heart", 0) == 0`.
  - **Review Focus 2:** after a restart (`_restart(false)`), the hero fighters still have `step == effective_step(...)`.
- [ ] **Step 2: FAIL.** **Step 3: Implement.** **Step 4:** Flow tests plus the full suite.
- [ ] **Step 5: Commit:** "Progression: earn steps at chapter bosses, save per lead, migrate old saves, reset on New Game, --steps".

### Task 9: The NEW ABILITY card, hints, and drawing the new moves

**Files:** `game/menu_overlay.gd:448` (`_results_screen`), `game/game_scene.gd` (event loop ~1260), `game/fighter_node.gd` (~949 sweeps), `game/hud.gd:191`. Test: `tests/test_flow.gd`.

**Interfaces:**
- **Results:** for each `r.unlocks` entry, below the ending line:
  - a `NEW ABILITY` label in `Palette` gold;
  - the name;
  - the card text;
  - the button word.
- **Hints:** in the event loop, for each ability `has` for the controlled fighter whose `hint.event` equals the event case:
  - `event[hint.field] == controlled_id`, and `hint.index` (if set) equals `event.index`;
  - its `"<kind>.<id>"` is not in `seen`;
  - then call `hud.show_message(hint.text)`, append it to `seen` and save.
- **Drawing:**
  - A slot swing draws its `pose` sweep.
  - `bothSides` draws it mirrored too.
  - The interpose guard draws Adapt's existing guard.
  - No new art style.

- [ ] **Step 1: Failing flow tests:**
  - The results overlay after finishing `protocol` from step 0 contains a label "Riposte" and a label "Follow-Through".
  - A parry by controlled Caelen at step 1 shows "Attack now: Riposte" once; a second parry shows nothing; the seen list holds "caelen.riposte".
- [ ] **Step 2: FAIL.** **Step 3: Implement.** **Step 4:** Flow tests plus the full suite, and `--demo --level 23 --smoke 300` exits cleanly.
- [ ] **Step 5: Commit:** "Progression: NEW ABILITY card, one-time hints, slot swings drawn".
- [ ] **Step 6: Hand to the creator.** Give the commands to feel each step, using the `!` prefix:
  - `$G --path . -- --level 5 --lead caelen --steps 1` (Protocol, Riposte).
  - `--level 17 --steps 2` (Oracle's Terrace, Break Guard).
  - `--level 23 --steps 3` (Heart, Full Arc and Interpose).

  Also give the balance table. Wait for the feel and pixel verdicts.

### Task 10: Docs, Bible draft, memory, phase review

**Files:** `docs/BACKLOG.md` (item 2), `UniverseBible/DECISION_LOG.md` (DRAFT-015 row: the 12 abilities as PROPOSED), memory `lastlight-godot-port.md`.

- [ ] **Step 1:** BACKLOG item 2: slice 1 done; Seraphine and Nimue next, after the creator's verdict. DRAFT-015 lists abilities 1–12 with their status, and any lore flags (5, 12).
- [ ] **Step 2:** Push, then wait for CI on the head (parity + windows) to come back green.
- [ ] **Step 3:** Phase-end Fable review of the slice diff, per the standing directive. Fix the findings in their own commits, then update memory.
