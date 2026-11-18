# The Last Light: architecture for growth

Owner direction, 2026-11-16:

> Build the first game with future expansion in mind, not future expansion as a requirement. Use modular
> character definitions, separate lore and narrative data, reusable asset pipelines, and DLC-ready content
> manifests. But spend the first development budget on making the base game genuinely excellent.

This document turns that into rules: what every change follows now, what is deferred, and what triggers each
deferred step.

## The rule above the rules

**The base game comes first.** Expansion-readiness is a way of writing code, not a feature to build. A change
that makes Chapter 1 better beats a change that makes Chapter 2 cheaper.

In practice:

- **Shape new code so it can grow, at no extra cost.** That means data instead of `if kind == ...`, one file per
  concern, and no hard-coded counts.
- **Don't build systems for content that doesn't exist yet.** No manifest loader, mod format, download
  service or plugin API until a real second pack needs one.
- **Make each structural move once, when a trigger fires.** The triggers are listed per pillar below. Until then,
  write down where the move would happen; that is enough.
- **No rewrite of working code just to make it ready for expansion.** This also follows the global rule: no
  re-architecture until 10 strangers have played the current version. Moves happen as part of real feature
  work.

## Layers (as built)

```
LastLightCore (Swift package, no UI)
  ActionCore     pure, deterministic game rules: World, Fighter, Brain, Level, Story, Tuning
  LastLightCore  the old autobattler core, unused by the game; SeededRandom is reused
LastLight (app, iOS + macOS)
  SpriteKit      GameScene, FighterNode, Effects, HUD, TouchControls: draws the World, reacts to events
  SwiftUI        menus, dialogue, results
  Data           Story/*.json
```

These lines hold for every change:

1. **ActionCore never imports SpriteKit, SwiftUI or AVFoundation.** It steps at a fixed 60 Hz, is seeded, and
   is tested. Anything a player could notice in the rules belongs here.
2. **The app only draws and reacts.** It reads `World` state and `GameEvent`s and decides nothing about
   outcomes. Art, sound and effects can then be replaced without touching the rules.
3. **Feel numbers live in `Tuning`.** No magic numbers in brains or the world.
4. **Each piece of content is checked by a test.** Every level must be finishable by the autopilot, every
   enemy shows its signature behaviour, every story scene must resolve.

**Puzzles** are level data, like hazards: `Lever`, `Plate` and `Gate` in `Level`, solved by `World.puzzleRules`.
A gate is a solid block appended to the level's platforms, so collision needs nothing new; it slides up as it
opens and won't shut on anyone standing in it. Levers and plates write ids into `World.signals`; a gate opens when
all its inputs are on (or, inverted, when any is off). Heroes throw levers with a swing and press plates by
standing on them (a decoy counts; enemies never do). A partner left on a plate when control passes away gets
`Fighter.holding` and stays put until the lead goes far on. The autopilot solves gates too (throw the lever, put
Orion on the plate, hand back, wait for the gate), so "every level is finishable by the autopilot" still holds
for puzzle levels.

## Pillar 1: modular character definitions

**Now.** A fighter is a `FighterKind` plus a `FighterSpec`, all data: size, HP, attacks, special, flags such as
`hovers`, `armored`, `boss`, `wardRadius`. Behaviour comes from a `Brain`. Heroes differ only by spec and
`SpecialSpec`, and everyone shares one combat system. The look is code in `FighterNode`, one builder per kind.

**Follow:**

- A new character is a new spec, plus a brain if it behaves differently. Add new behaviour as a spec field or
  an `AttackEffect`, never as a kind check inside `World`.
- If a check on a kind's name is tempting, add a capability flag to `FighterSpec` instead.
- Heroes stay on one shared kit system. A new hero's special is a new `SpecialSpec` case with its own tests.
- Keep the drawing of a figure in one place per kind, so swapping it for sprites touches one spot.

**Deferred, with triggers:**

| Move | Trigger |
|---|---|
| A `FighterSkin` protocol between `FighterNode` and the figure, so a sprite atlas replaces a code figure | The first real character art is approved (stage 5 style spike) |
| Specs loaded from JSON instead of Swift literals | Specs are edited by someone who is not changing code, or a second content pack adds fighters |
| `FighterKind` opened up from a closed enum to string IDs | A content pack must add a fighter without an app update |

## Pillar 2: lore and narrative kept apart from code

**Now.** Dialogue lives in `LastLight/LastLight/Story/chapter1.json` (scenes, lines, choices, flags, conditions)
and is run by `Story.swift`. Levels only place cues (`SceneTrigger`: start, reach x, partner joins, boss wakes,
complete). Story state is saved apart from the game (`story.json`). The world bible and cast are in
`docs/design/`.

**Follow:**

- Words the player reads go in story data, never in Swift. The exceptions are UI labels and level names, until
  the localization trigger.
- One JSON file per chapter or pack, named by its ID (`chapter1.json`). Scene IDs are namespaced
  (`awakening.orion`), so packs never collide.
- Flags are named for what happened in the story (`orion.trusted`), not for a mechanic. Later chapters and
  epilogues read them.
- Lore that isn't dialogue (character bios, codex, region notes) goes in `docs/design/` first. It moves into
  game data only when a screen shows it.

**Deferred, with triggers:**

| Move | Trigger |
|---|---|
| Story strings moved into string catalogs | The first non-English language |
| A codex or lore screen and its data file | The owner approves a lore feature for a release |
| Story files that list their own cues instead of `Level` holding them | Two leads need different scenes on the same level and a flag can't do it. Stage 4 didn't fire it: each opening is its own level, and the one shared scene that differs by lead (`hall.enter`) branches on the `lead` flag |

## Pillar 3: reusable asset pipelines

**Now.** There are no asset files. Figures, effects and sound are made in code and are placeholders. The owner
keeps verdicts on all art. The planned sources are Blender and, with approval, Higgsfield.

**Follow:**

- **The game consumes sprite atlases.** Whatever the source (Blender render, GLB, generated frames), it ends up as
  a named atlas with fixed animation names: `idle`, `run`, `jump`, `fall`, `attack1`..`n`, `dodge`, `hurt`, `dead`,
  plus each kit's extras. The pipeline converts sources into that format. The game never changes for a new
  source.
- **Keep one script per step, in the repo** (`tools/`): render, trim, pack, name. Run it from a clean checkout
  so a new character costs a pipeline run, not a hand session.
- **Fix scale and pivot rules once**: feet at the pivot, one world unit per pixel at 1x. Record them in the
  pipeline README.
- **Code-made effects stay.** `Effects.swift` builds particles from one generated texture. New effects follow that
  pattern until art is approved.
- **Sound follows the same pattern.** `Sound.render` is the swap point. Recorded sound replaces buffers by
  effect name, and callers don't change.
- **Higgsfield spend needs the owner's approval, every time.**

**Deferred, with triggers:**

| Move | Trigger |
|---|---|
| `tools/` pipeline scripts and README | The first approved character art (stage 5 style spike) |
| An atlas loader with a fallback to the code figure | Same moment, so placeholders and art can live side by side |
| An audio file pipeline | The first recorded or designed sound the owner approves |

## Pillar 4: DLC-ready content manifests

**Now.** Content is compiled in. A `Chapter` (`Chapter.swift`) is the pack in all but name: an ID that also names its
story file (`chapter1.json`, `chapter2.json`), a number, a title, its ending line, and its levels for a given lead.
`Chapter.all` is the order of play; the run is every chapter's route for the chosen lead. `Level.all` lists every
level once.

**Follow:**

- **Think of Chapter 1 as a content pack**, even though nothing loads it as one. Its pieces are its levels
  (`Level.all`), its story file (`chapter1.json`), its fighters and its future art.
- **Put new content in places a pack could own.** Use one file per level group and one story file per chapter,
  and don't let one chapter's code reach into another's.
- **Save data names content by ID, not by array position.** Today the current level is saved as an index
  (`progress.levelName` with `progress.lead`). Since Chapter 2 it is saved by the level's name, its ID, so a new chapter never moves a save. Switch it to a level ID when the second chapter or pack arrives,
  before it ships, so old saves migrate once.
- **Owned content is decided by the app**, never by data inside a pack. When paid content exists, StoreKit
  entitlements decide what loads.

**The manifest, when it is built** (shape only, not code yet):

```json
{
  "id": "chapter1",
  "title": "Chapter 1: The Foundry",
  "version": 1,
  "requires": [],
  "levels": ["foundryYard", "awakening", "machineHall", "theProtocol"],
  "story": "chapter1.json",
  "fighters": ["scrapDrone", "forgedSoldier", "sentryCore", "dogmaFrame", "theProtocol"],
  "atlases": [],
  "entitlement": null
}
```

The base game becomes the first manifest, and DLC is another manifest plus an entitlement. Content that
downloads (On-Demand Resources or Background Assets) is a separate later step.

**Deferred, with triggers:**

| Move | Trigger |
|---|---|
| Manifest file and loader; `Chapter.all` built from manifests | A pack must load without an app update. Chapter 2 got a `Chapter` type instead, with no loader |
| Saves keyed by content ID | Done with Chapter 2: the level's name is its ID |
| Entitlements (StoreKit) | The owner decides to sell content (monetization is out of the first release) |
| Downloaded content | The app size or a pack's size makes bundling a problem |

## Where the first budget goes

In order. Expansion work appears only as triggers above.

1. **Feel and clarity**: combat feel, readable telegraphs, camera, touch controls on real devices.
2. **Chapter 1 quality**: level pacing, boss fight, difficulty, results, menus, save and resume.
3. **Story**: the three leads and openings (stage 4), after the owner's verdict on the cast and scripts.
4. **Look and sound**: the art style spike, then art for the slice (stage 5).
5. **Strangers**: TestFlight to 10 people who don't know the project. That count is the measure.

## Checklist for a change

- [ ] Rules in ActionCore, drawing in the app, numbers in `Tuning`.
- [ ] New character: spec data plus a brain, no kind checks in `World`, tested.
- [ ] New words for the player: in story JSON, with namespaced IDs.
- [ ] New content: in a file a pack could own; saves refer to it by ID once there are packs.
- [ ] No system built for content that doesn't exist; if it's tempting, add a trigger row here instead.
- [ ] It makes the base game better, or it's the move a trigger asked for.
