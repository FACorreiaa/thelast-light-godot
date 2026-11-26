# Hero progression: design

Status: for the creator's approval (2026-11-26). Abilities, names and card text are PROPOSED (DRAFT-015).

## Intent

Spec §4.7 says "a short ability track per hero, unlocked by story progress. No stat grinding." Swift never
built it. The creator wants it for two things:

- **A sense of the hero growing** over the run.
- **More variety late in the run**, so Chapters 3 and 4 do not play like Chapter 1.

## Decided with the creator

- **Shape (option C):** three steps per hero, the same shape for everyone:
  1. a **new move**,
  2. a **special upgrade**,
  3. a **signature move**.
- **When:** a step unlocks on beating the boss of Chapters 1, 2 and 3. Chapter 4 is played with the full kit.
- **Orion grows too**, on the same beats, beside any lead.
- **Kept per lead, per run.** A new run with another lead starts that lead at step 0. Replaying an earlier
  chapter keeps what was earned. **A New Game resets the lead to step 0**, with its cards and hints shown again
  (creator, 2026-11-26), so the growth is felt on every run and Chapters 1–3 keep their tuning.
- **How it shows:** a "NEW ABILITY" card on the chapter results screen (name, one line, the button it is on),
  and a one-line hint the first time it matters. No skill tree, no menu, no choices.
- **No stat bumps.** Unlocks add or change behaviour; health, damage and cooldowns stay as tuned.
- **The bot and the AI partner use unlocked moves**, so the "every level finishes" tests exercise them and
  Orion visibly grows.
- **Balance:** checked after each step; retuned only where a fight turns trivial, with numbers reported.
- **Build approach (option 1):** the track lives in data, and the steps are handed to the simulation
  explicitly. With no steps given, nothing changes.

- **Context triggers replace the plain swing** in their window (Riposte after a parry, Sunburst out of a
  dodge, Shadowstep after a pass-through dodge), with no extra button or timing (creator, 2026-11-26).

## Goals, non-goals, anti-goals

**Goals:**
- 12 abilities, each readable in one line, each triggered from presses the player already makes.
- Step 0 is today's game, bit for bit. All 64 Swift and 12 Godot reference runs replay unchanged.
- Every ability is used by the bot and covered by tests.

**Non-goals:**
- Progression for Elyra, Valen, Lira or Jax. They are not playable yet; their tracks come with their kits.
- Unlock choices or respecs.
- New art beyond poses and effects in the existing code-drawn style.

**Anti-goals** (a failure even if it works):
- Any stat bump dressed as an ability (bigger heal, longer mark, shorter cooldown).
- A move that needs a button chord, a hold-to-charge or precision timing to use at all.
- A step-0 behaviour change: a moved golden is a bug, not a re-record.
- Chapter 4 becoming trivial with the full kit, or unfair without it (e.g. via `--level`).

## Constraints from the code

- **Inputs.** `InputFrame` has `move_x, jump, jump_held, attack, dodge, special, switch_hero`. Every trigger
  is context on existing presses: chain position, airborne, just after a dodge or a parry, decoy standing. No
  new input field: that would change trace encoding and the `--pilot` comparison.
- **Attack slots.** `spec.attacks` is not extended. Adapt's counter uses `attacks.size() - 1`, chaining tests
  `i + 1 < attacks.size()`, and the boss choosers clamp to `size() - 1`. New swings are **named slots** in
  `progression.json` (`finisher`, `riposte`, `backstab`, `dodge_strike`), using the same attack fields as
  `tuning.json`, and the fighter records which slot it is swinging.
- **The air swing already exists** (an attack in the air starts swing 0). No step replaces it.
- **Determinism.** Every new branch in the sim, the partner brain and the autopilot is gated on the step
  **before** any RNG draw, so step 0 consumes the same random numbers. `--pilot` replays compare autopilot
  inputs, so the autopilot is held to this too.
- **`tuning.json`'s Swift entries stay untouched.** They are shared with the 64 Swift goldens. Balance levers are
  ability numbers in `progression.json`, Chapter 4 level data, and the port-only Chapter 4 specs in
  `tuning.json` (the Mason and the Heart, which no Swift golden uses). Godot goldens they move are re-recorded
  in their own commit.
- **Eclipse guards.** `ECLIPSE_MARGIN`, the 12-frame allowance in `eclipse_escape`, `ECLIPSE_JUMP_FRAMES` and
  the ground-only edge stop are sized for today's swings. Every new swing that moves the hero goes through
  the same guards (`_navigate`, the edge stop, `eclipse_air_unsafe`); so do the moves that relocate a hero without
  a swing (Switchback, Interpose). Acceptance: `test_eclipse`'s drop loop
  and `test_levels` pass with each lead at the step its chapter grants.

## Approaches considered

1. **Data track, steps passed to the sim (chosen).** `data/progression.json` holds each hero's three
   abilities and their numbers. `World.from_level` takes a `steps` dictionary (`{"caelen": 2, "orion": 2}`);
   each ability's code switches on at its step. Cost: real sim code and tests per move, unavoidable for moves.
2. **One hero definition per step.** Number-only upgrades would need no code, but moves still do, and it
   makes twelve near-duplicate definitions where an unlock is only visible as a diff. Rejected.
3. **Presentation-only unlocks.** Moves live in the sim; faking them on screen breaks determinism and the bot.
   Ruled out.

## The abilities (PROPOSED, DRAFT-015)

Step 1 after Chapter 1, step 2 after Chapter 2, step 3 after Chapter 3. "Card" is the text on the NEW
ABILITY card. "Lore" flags anything that claims something about the world.

| # | Hero | Step | Name | Card | Trigger | What it does in the sim | Bot use | Lore |
|---|---|---|---|---|---|---|---|---|
| 1 | Caelen | 1 | Riposte | Attack right after a parry for a heavy counter-cut. | attack within 40 frames of a successful parry (replaces the chain step it would have been) | starts the `riposte` slot: one heavy cut | autopilot and partner attack after a `parried` event | none |
| 2 | Caelen | 2 | Command: Break Guard | Enemies you mark cannot block. | Command (unchanged) | a marked non-boss enemy's frontal block and guard-while-swinging do not stop heroes' hits; bosses keep their shields (Line Warden, Sworn Shield: the shield is the fight) | step-gated: the autopilot marks the nearest shielded enemy; both bots treat a marked enemy as unguarded (no dodge-through, no stand-off) | none |
| 3 | Caelen | 3 | Full Arc | A fourth swing ends your chain, cutting both ways. | attack during the third swing's chain window | starts the `finisher` slot, `bothSides: true` | chains as today; reaches it naturally | none |
| 4 | Seraphine | 1 | Binding Bolt | A last bolt ends your chain and slows what it hits. | attack during the second swing's (her first bolt's) chain window | starts the `finisher` slot: a second, long bolt with `slowFrames` | chains as today | none |
| 5 | Seraphine | 2 | Light Listens: Shelter | Your heal also shields both of you from the next hit. | Light Listens (unchanged) | each hero the heal reaches gets a ward for 180 frames that cancels the next enemy hit (melee, projectile, explosion); hazards and falls ignore it; a parried or evaded hit does not use it up; it casts even when nobody is hurt | heals as today, plus casts when a telegraph is close and a hero is unwarded | the Light protects as well as heals (extends existing "Light Listens") |
| 6 | Seraphine | 3 | Sunburst | Attack out of a dodge to blast light all around you. | attack in a dodge's last 6 frames or the 10 after (replaces the plain swing there) | starts the `dodge_strike` slot: short-reach burst, both sides, big knockback | dodges as today; attacks out of it when 2+ enemies are near | none beyond 5 |
| 7 | Nimue | 1 | Shadowstep | Dodge through an enemy, then strike its back. | attack within 40 frames of a dodge that passed through an enemy (replaces the plain swing there) | turns her to face it; starts the `backstab` slot (heavy, ignores frontal block) | dodges through a shielded enemy, then attacks | none |
| 8 | Nimue | 2 | Lantern Trick: Flare | Your decoy bursts when it is struck or fades. | Lantern Trick (unchanged) | the decoy bursts once, when struck or on expiry, staggering non-boss enemies within reach | places decoys as today | none |
| 9 | Nimue | 3 | Switchback | Special while your decoy stands: swap places with it. | special while her decoy stands (no cooldown needed; a new input path, since special is read today only at cooldown 0) | swaps her position with the decoy's, once per decoy; refused (nothing happens) when the decoy is in the air or on eclipse ground that is gone or going (`eclipse_clear`/`eclipse_escape` rules) | swaps when the decoy is behind enemies or she is cornered | none |
| 10 | Orion | 1 | Follow-Through | A third strike ends your chain. | attack during the second swing's chain window | starts the `finisher` slot: heavy hit | chains as today | none |
| 11 | Orion | 2 | Adapt: Answer for Both | Your counter cuts both ways. | Adapt (unchanged) | the counter swing (and only the counter, not his second chain hit, which is the same attack entry) hits both sides | adapts as today | none |
| 12 | Orion | 3 | Interpose | Dodge toward your partner to guard at their side. | dodge toward the other hero when within 160 px, with Adapt ready (otherwise a plain dodge) | the dodge ends at their side in Adapt's guard and spends Adapt's cooldown; while that guard lasts, an enemy hit that would land on the other hero lands on Orion's guard instead (a new redirect rule in hit resolution, which today resolves the lead first) | the partner brain uses it when a telegraph will land on the lead | Orion shields his lead (fits trusted/watched; no new claim) |

Notes:
- Orion's Adapt counter does not chain into Follow-Through.
- Every step-2 upgrade changes behaviour, not a number: no shields broken → shields broken; heal → heal and
  ward; decoy fades → decoy bursts; counter one way → both ways.
- The slot numbers (damage, reach, frames) are the builder's first pass, tuned only by the balance pass.
- New poses and effects (finisher sweeps, burst, ward glow, swap flash) are drawn in the current code-drawn
  style. Their look is the creator's verdict.

## Saving and who gets which step

- **New Game** clears that lead's earned step and its seen cards and hints, alongside the story reset it
  already does.
- **Earned step:** `progress/steps/<lead>` in `progress.cfg`. Beating the boss of Chapter N (N ≤ 3) sets it
  to `max(stored, N)`, saved at completion, before the results screen.
- **Orion** plays at the current lead's step. He has no save of his own.
- **Old saves** have no steps key. The step is derived from the saved level's chapter (Chapter N's levels
  imply step N − 1), so current players do not enter Chapter 4 at step 0.
- **One helper, `chapter_step(level_id)`** (the chapter's index, capped at 3) serves old-save migration, the
  demo (which plays each level at its chapter's step) and the level tests.
- **Playing a level** uses `max(earned, chapter_step(level))`. Replaying keeps the earned step, and
  `--level` never drops anyone into Chapter 4 with the base kit.
- **The Training Room** (`World.partner_slice`) uses the earned step.
- **Developer flag:** `--steps N` overrides, beside `--level` and `--lead`, so the creator can feel any step
  on any level.

## Showing it

- **Results screen** at the end of Chapters 1–3: under the chapter's ending line, a NEW ABILITY card per
  unlock (the lead's, then Orion's): name, card text, button glyph. Shown only the first time it is earned.
- **Seen per ability.** A step reached without beating the boss (an old save migrated, or a later chapter
  picked from the chapter list) shows no card; its abilities still get their hints.
- **Hint:** on the first level played after an unlock, a one-line HUD message the first time the trigger
  could fire (e.g. after the first parry: "Attack now — Riposte"). Once per ability, saved.

## Testing and acceptance

- **Step 0 unchanged:** all 64 Swift and 12 Godot goldens replay (state hashes for all; autopilot inputs too
  for the 58 unscripted Swift runs and all 12 Godot runs); no re-record.
- **Golden headers** gain `"steps"`; replay defaults a missing field to `{}` (step 0).
- **New Godot goldens:** each lead at its chapter's step on the Chapter 2, 3 and 4 chapter-final boss levels,
  fighting.
  Recorded in their own commit.
- **Per-ability sim tests** in a new `tests/test_progression.gd`: at step N−1 the trigger does nothing new;
  at step N it does; each one mutation-checked.
- **Level tests and the eclipse drop loop** run each lead at its chapter's step.
- **Flow tests:** the step is granted and saved at chapter end; the card shows once; an old save migrates;
  replaying Chapter 1 keeps the step; `--steps` overrides.
- **Balance report** to the creator: for each lead × boss (mid-chapter bosses included), win rate and lowest HP margin over seeds, at the
  chapter's step and at step 0. A fight whose margin more than doubles gets a retune proposal.

## Delivery order

1. **Vertical slice: Caelen and Orion, all three steps** (abilities 1–3 and 10–12), with all the shared parts:
   `progression.json`, `steps` in the sim, save and migration, card and hint, `--steps`, goldens and the
   balance report. **The creator plays it.** Feel and pixel verdicts before more is built.
2. **Seraphine and Nimue** (abilities 4–9), applying what the slice taught.
3. Docs: BACKLOG, the spec's §4.7, the Bible (DRAFT-015 → DEC on the creator's verdict).

## Left to the builder

- Exact frame and damage numbers for the new slots (first pass, then balance).
- How the fighter records its active slot (`attack_slot` string or int), as long as step 0's state hash is
  unchanged.
- Hint wording beyond the card text, for the creator to check.
