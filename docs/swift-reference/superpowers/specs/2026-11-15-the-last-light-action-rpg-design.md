# The Last Light — Action RPG Design

*Date: 2026-11-15. Status: draft for owner approval. Supersedes
`2026-10-22-the-last-light-slice-design.md` (the autobattler).*

## 1. Intent

A premium, character-driven, chapter-based action RPG for iPhone: side-view
sword combat in the Castlevania tradition, JRPG-style story and companions, and
personal endings. The characters and bosses in the owner's illustrations are the
main attraction.

The owner's definition of success is unchanged: **strangers pay real money to
play it.**

This document covers the **first release**. Later regions, the other heroes and
the final boss get designed after strangers have played it.

## 2. What carries over from the old spec

- **World.** The sun is dying. The Foundry built an AI to save it; the AI
  concluded that life burns too much light and is replacing it with machines.
  It believes it is saving the world.
- **Regions and light.** The Foundry (cyan), the Dawnfaith (gold), the Lantern
  Cities (warm orange). The AI's machines always glow **red**; nothing in the
  player's cast does.
- **Anti-goals.** Ads, energy timers and gacha are never allowed. No walls of
  text or lore before the player cares. No stiff or cheesy dialogue. No
  grinding in place of skill.
- **Owner gates.** The owner keeps the verdict on every visual and written
  asset, and on how the game feels.
- **Constraints.** Solo build with AI-made assets. Swift and SpriteKit.
  Offline, local saves, no backend. No paid third-party services beyond what is
  already installed. Higgsfield spend needs the owner's approval each time.
- **Success measure.** 10 strangers finish the first release on TestFlight.

Dropped: the formation grid, automatic fights, adjacency bonds, in-run
evolution, the run currency, and the balance runner.

## 3. The first release

| Item | Content |
|---|---|
| Opening | The player chooses a faction. Each gives a lead hero and a short personal opening that leads into the shared Foundry levels |
| Leads | **Caelen** (Foundry), **Seraphine** (Dawnfaith), **Nimue** (Lantern Cities) |
| Companion | **Orion**, the defector, recruited inside the Foundry by all three leads |
| Region | The Foundry |
| Enemies | Scrap Drone, Forged Soldier, Sentry Core, Dogma Frame |
| Boss | The Protocol: Judgement, Ascension, Execution |
| Story | A few real decisions, companion reactions, three personal epilogues, a hook toward The Eclipse Engine |
| Sessions | Levels of 5–10 minutes, checkpoints, resume where you left off |
| Platform | iPhone, landscape, iOS 18+. Keyboard and controller work from the start. macOS follows the iPhone release |

**Calls made by Claude, for the owner to check:**
- The source plan named Caelen, Orion and Seraphine as the three playable
  heroes. A faction pick needs a Lantern lead, so Nimue leads the Lantern
  Cities and Orion becomes the shared companion. That is four playable kits.
- The three openings are short and reuse Foundry environments and enemies.
- Elyra, Valen, Lira and Jax appear in the story at most; they are not playable
  in this release.

## 4. Combat

### 4.1 Controls
Landscape. A virtual stick on the left. On the right: **attack, dodge, special,
switch**, and jump. No button combinations, no precision platforming.

### 4.2 The shared system
Every hero uses the same moves, with different numbers and one special:

- **Attack chain.** Each swing has a windup, an active window and a recovery.
  Pressing attack during recovery chains into the next swing.
- **Dodge.** A short dash with invulnerable frames and a cooldown.
- **Parry.** Starting an attack just before an enemy's hit lands deflects it
  and staggers the attacker. Parrying rewards reading telegraphs; it is never
  required to win.
- **Special.** One ability per hero on a cooldown.
- **Telegraphs.** Every enemy attack shows a clear windup. Hitboxes are
  generous to the player.

### 4.3 The companion
The companion fights beside the player under AI control. **Switch** hands
control to the other hero at once; the one left behind is taken over by the AI.
Each has their own health. If the controlled hero falls, control passes to the
other; the mission fails when both are down. The partner AI must help without
stealing the fight: it follows, attacks what the player attacks, and dodges
obvious telegraphs.

### 4.4 Kits

| Hero | Basic | Special | Feel |
|---|---|---|---|
| Caelen | Sword, three-swing chain | **Command**: marks an enemy; the partner focuses it and it takes extra damage | Parry and direct |
| Orion | Fast two-hit strikes | **Adapt**: a short guard that absorbs the next hit and answers with a counter | Versatile, forgiving |
| Seraphine | Staff bolts at mid range | **Light Listens**: heals both heroes over a few seconds | Support at range |
| Nimue | Thrown blades, light on her feet | **Lantern Trick**: leaves a decoy that enemies target | Tricks and space |

### 4.5 Enemies

| Enemy | Behaviour |
|---|---|
| Scrap Drone | Fast and fragile, attacks in numbers, self-destructs at low health |
| Forged Soldier | Advances behind a shield that blocks hits from the front; its slash can be parried |
| Sentry Core | Hovers at range, locks on, fires a telegraphed beam that slows |
| Dogma Frame | Shields nearby machines; kill it first |

### 4.6 The Protocol
- **Judgement:** grounded; melee and Energy Slash.
- **Ascension:** takes flight; Summon Drones and Laser Rain.
- **Execution:** true form; Reality Pulse and the Execution Beam.

### 4.7 Progression
A short ability track per hero, unlocked by story progress. No stat grinding.

## 5. Story structure

- **Faction select**, then that lead's opening.
- **The Foundry**, shared by all three leads, with lines that change by lead.
- **Recruiting Orion** midway.
- **A few decisions** that change companion dialogue and the epilogue.
- **The Protocol**, then a **personal epilogue** for the lead, ending on the
  hook: the Eclipse Engine.
- Dialogue is short: portraits and lines, character before lore.

The cast is in `docs/design/cast-sheet.md`.

## 6. Look

The target is the owner's illustrations (`docs/design/reference/`): painted,
detailed characters, strong faction colour, red machines.

Until the look is settled, gameplay uses **placeholder figures drawn in code**:
dark cutouts with region-coloured light. They are not the final look. Rendering
sits behind a skin interface so sprite atlases (rendered from a 3D model, or
generated frames) can replace them without touching gameplay.

Whether in-game art can live up to the illustrations is the largest open risk.
It gets a dedicated spike on one character, with an owner verdict, before any
art is made for the rest.

## 7. Tech

- One Swift package. `ActionCore` is pure Swift: no SpriteKit, fixed 60 Hz
  step, deterministic, unit-tested. Rendering only draws what the core reports.
- Enemy AI and the partner AI produce the same input type the player does, so
  switching control swaps who reads the touchscreen and who reads a brain.
- SpriteKit for the game scene; SwiftUI for menus and dialogue; GameController
  for keyboard and pads.
- Every feel number lives in one tuning structure.
- 60 fps on a recent iPhone in the busiest fight.

## 8. Stages and gates

1. **Feel slice.** Caelen alone against a dummy, Scrap Drones and one Forged
   Soldier in a grey-box room. → **Owner plays it on an iPhone.** Nothing else
   is built until attacking and dodging feel good.
2. **Partner slice.** Orion as AI partner, plus switching. → **Owner gate.**
3. **Foundry vertical.** The other two enemies, the levels, The Protocol, HUD,
   sound, saves.
4. **Three leads and story.** Seraphine and Nimue, faction select, openings,
   decisions, epilogues. → **Owner gate on the scripts.**
5. **Look and release.** Art spike → **owner verdict**; art, cinematic, polish;
   TestFlight to strangers.

## 9. Addendum: the owner's brief (2026-11-15)

Later the same day the owner gave a fuller brief. Where it differs from the sections above, the brief wins.

- **Genre emphasis.** An action-*platformer*: movement quality is the first priority (momentum, coyote
  time, jump buffering, variable jump height, reliable platform and wall collisions), then combat.
  Levels have platforms, moving platforms, hazards, secrets and checkpoints.
- **Platforms.** iPhone, iPad and macOS from one codebase. The app target now builds for all three.
- **Characters.** All eight are playable eventually, each with its own kit. The first slice is Caelen
  only; the character system stays data-driven so the others are added without touching movement,
  combat or level code.
- **First slice.** Chapter 1, The Foundry, in three segments: Awakening, The Machine Hall, The Protocol.
- **Art.** The owner will model and animate characters in Blender and render sprites from them.
  Placeholders stay until that phase.
- **Stages, revised.** (1) Movement yard: one test level that exercises every basic. **Owner plays it.**
  (2) Chapter 1 segments A and B. (3) The Protocol, first phase. (4) Story architecture with one
  small example. Art and the other characters follow.

**The companion stays** (owner, 2026-11-15). Orion fights beside the lead inside levels. A level
either starts with him or places him further in, where he waits and joins when reached. He jumps the
gaps and walls he can clear and catches up in one step when left behind.

**Levels** are an ordered list (`Level.all`): the Foundry Yard (movement test), then Chapter 1:
Awakening, The Machine Hall, and next The Protocol. Clearing one leads to the next.
