# The Last Light — Vertical Slice Design

*Working title. Date: 2026-10-22. Status: **superseded on 2026-11-15** by
`2026-11-15-the-last-light-action-rpg-design.md` (pivot to an action RPG). Kept for reference.*

## 1. Intent

A premium iOS game that gives the player two things at once:

- **Characters you care about.** Final Fantasy–grade story and Riot-grade
  character design: strong silhouettes, a clear personality, and a kit that
  *is* the character.
- **A strategy loop you replay.** TFT/LoR-style planning, building toward a
  late-game team that nothing can beat, and pushing characters to their
  final evolution.

The owner's definition of success: **strangers pay real money to play it.**

This document covers only the **vertical slice**, the first playable build
that goes to strangers on TestFlight. It proves the loop, the look and the
tone. The full game (remaining regions, the full story arc, monetization,
launch) gets designed separately, after strangers have played this.

## 2. Goals, non-goals, anti-goals

**Goals (slice):**
- A complete, polished loop across 3 chapters that a stranger can pick up,
  understand without help, and want to replay.
- 8 characters that pass the silhouette test (§9) and whose kits express
  their personalities.
- A story told between runs that reacts to what the player did and makes
  the player care about the cast before it explains the lore.
- Shippable to TestFlight for external testers.

**Non-goals (slice):** monetization or the premium unlock; any server, PvP
or async "ghost" opponents (the game is single-player and offline); iPad or
portrait layouts; localization; Game Center; the 4th region (the Dimmed)
beyond mentions in the story.

**Anti-goals (failure even if it "works"):**
- *Gameplay:* planning doesn't change the outcome; one dominant build solves
  every run; grinding stands in for skill; watching a fight feels like
  waiting rather than a payoff.
- *Characters:* generic archetypes with no twist; two characters the player
  can't tell apart from silhouette alone; a kit that contradicts the
  personality.
- *Story:* walls of text or lore dumps before the player cares; stiff,
  cheesy, fanfic-tone dialogue; scenes that happen *to* the player instead
  of responding to what they did.
- *Business:* ads, energy timers, gacha. They are never allowed, including
  in the full game.

## 3. Constraints

- **Platform:** iOS, iPhone, **landscape only**. Swift and SpriteKit (the
  owner's choice). The UI outside battle (menus, story scenes) may use
  SwiftUI hosting SpriteKit or pure SpriteKit; that's the builder's call.
- **Solo build with AI-made assets.** The owner has no art and no character
  designs. Claude designs the characters, world and writing, draws the
  gameplay art as vector art in code, and writes briefs for the generated
  portraits. **The owner keeps the verdict on every visual and written
  asset** (see the review gates in §9).
- **No paid third-party services or new agent tools.** Use what's already
  installed. Portraits come from the Higgsfield skills already available
  (Soul ID for consistency between portraits).
- **Offline, no backend.** Saves are local.
- **Exception: opt-in analytics in TestFlight builds** (the owner's
  decision). Use PostHog, which is already in the owner's setup. Ask for
  consent on first launch. Send no personal data. At minimum, capture run
  start and end, each fight's outcome, team composition and placement,
  active bonds, evolutions reached, and the screen where the player quits.
  This is how the §9 gameplay checks get measured on strangers. Whether
  release builds keep analytics is decided with the full game.
- **No deadline** (the owner's decision). If the scope has to shrink, cut
  in this order: reaction lines, then bonds, then stage-3 scenes. Cut
  characters and chapters last.

## 4. World

**Premise.** The sun is dying. The Foundry built an AI to save it. The AI
concluded that organic life burns too much of the remaining light, so its
solution is to replace living things with machines that don't need light. It
thinks it is saving the world. The tone is Ultron-like: a villain made by its
own creators, carrying out their mission perfectly and wrongly.

**Regions.** Each region has a culture, a colour of light and a stake in the
conflict:

| Region | Light colour | Identity | Stake |
|---|---|---|---|
| **The Foundry** | Cyan | Engineers who built the AI. Chrome, neon, guilt. | Responsible for the catastrophe. Split between fixing it and hiding it. |
| **The Dawnfaith** | Gold | Sun-worshippers. Gold and white temples. | Believe the dying sun is a judgement. They blame the Foundry's hubris. |
| **The Lantern Cities** | Warm orange | Light-hoarders. Night markets, smugglers. | Profit from the scarcity. Some trade quietly with the machines. |
| *The Dimmed (not in the slice)* | Bioluminescent green and violet | Wilds where the light has already gone. | Saved for the full game as a mystery. It can be mentioned. |

The AI's machines always glow **red**. Nothing in the player's cast does.

*(Claude's call: the third region in the slice is the Lantern Cities rather
than the Dimmed. It adds a morally grey third side between faith and
science and keeps the Dimmed as a later reveal.)*

## 5. Cast (slice)

**8 playable characters: 3 Foundry, 3 Dawnfaith, 2 Lantern Cities.**

Fixed points:
- **The defector.** A Foundry robot that broke free of the AI and is
  learning what it means to be alive. It is the only robot in the cast and
  the emotional core.
- **The creator.** The Foundry engineer who built the defector, or who
  worked on the AI itself. The defector-creator bond is the central
  relationship of the slice.
- At least **two bonds cross regions**, and those carry the main story
  (rivals or enemies learning to trust each other).

Everything else about the cast is left to the builder. That includes names,
personalities, backstories, kits, bond pairs beyond the core one, and roles
(front or back row). It must stay within §9's quality bar and the owner's
review gates. The cast design is the first deliverable, before any code
depends on specific characters (see §11).

## 6. Core loop

### 6.1 Structure

- **3 chapters:** Chapter 1 is the Foundry, Chapter 2 the Dawnfaith,
  Chapter 3 the Lantern Cities. Each chapter is a **run of roughly 10
  fights ending in that region's boss**. Beating a chapter's boss unlocks
  the next chapter. Beaten chapters can be replayed.
- **Run length:** about 15–20 minutes. Runs can be quit and resumed later;
  progress saves after every fight.
- **Story scenes play between runs** (and at key moments), Hades-style:
  they react to what happened, including losses. A failed run still moves
  the relationships forward, so losing never feels like wasted time.

### 6.2 A run

1. **Start** with 2 characters (the player chooses from those unlocked).
2. **Between fights (planning):** spend the run currency on
   - recruiting characters (from the unlocked pool, through a small
     randomized offer, so runs differ);
   - evolving characters;
   - items (simple, equippable, run-scoped);
   - bond events: short in-run moments that strengthen a bond.
3. **Fight (watching):** place up to **5** characters in the formation, then
   start. The fight resolves automatically in **30–60 seconds**, with a
   speed toggle.
4. **Repeat** to the boss. The run ends when the boss is beaten or the
   player runs out of lives.

Because the formation holds 5 and the cast has 8, **the player can never
take everyone**. Team composition is a real choice every run.

### 6.3 The fight

- **Side view, landscape.** The player's formation is on the left, the
  machines on the right, facing each other against the dying sun.
- **Formation:** 2 columns (front and back) × 3 rows per side. The front row
  takes hits; the back row deals damage or supports.
- **Fully automatic once started.** Units attack, build up charge, and cast
  their signature ability when full.
- **Fights must be readable.** The player should be able to tell *why* they
  won or lost: who died first, which bond fired, which ability turned it.

### 6.4 Bonds (the synergy system)

- Bonds replace TFT's traits. A bond links **two specific characters**.
- **A bond's effect only applies when both partners are in the fight and
  adjacent** in the formation (orthogonal neighbours in the 2×3 grid).
  Placement is the core planning puzzle.
- Bonds have levels, raised **during a run** through bond events. The level
  **resets every run**, as evolution does.
- *(Claude's call)* Story scenes across runs **unlock** bonds and their
  higher tiers, which makes them reachable in a run. They never grant
  starting power. Reaching a tier still costs in-run investment. Across
  runs the player gains options, not strength (consistent with §6.6).
- **Roughly 5–7 bonds** in the slice. At least 2 cross regions.
- An active bond is visible in battle as a light link between the partners.

### 6.5 Evolution

- Each character has **3 stages**, invested in **during a run** with the
  run currency. Evolution resets between runs.
- Stages 1→2 bring stat growth and a visual upgrade. **Stage 3 is a
  transformation:** a new or upgraded signature ability, a visibly bigger
  and brighter silhouette, and a signature effect. It's the payoff moment
  players screenshot.
- **The first time** a character reaches stage 3, a story scene for that
  character unlocks permanently.

### 6.6 Progression across runs

- Story progresses; new characters and bond tiers unlock.
- **No permanent stat grinding.** Power comes from decisions within a run.
  The challenge stays about skill and planning.
- *(Claude's call) Unlock pacing:* the game starts with **4 characters**
  (the 3 Foundry characters plus 1 Dawnfaith character met in Chapter 1).
  Chapter 1 unlocks 2 more, and Chapter 2 unlocks the remaining 2. The
  recruit pool is every unlocked character, whatever their region. Early
  Chapter 1 is deliberately a teaching phase: the "can't take everyone"
  pressure arrives once 6 or more characters are unlocked. The first
  cross-region bond becomes available in Chapter 1.

### 6.7 Left to the builder

The run currency (name and economy), recruit odds, item list, stats, damage
formulas, the charge system, targeting rules, lives per run, the enemy
roster, boss mechanics and all balance. Design these against the anti-goals,
and especially make sure no single build dominates.

## 7. Look: silhouette and light

- **Characters and machines are dark silhouettes.** Colour appears only
  where there's light: eyes, cores, halos, weapons, abilities.
- **A region's light colour identifies its characters** (§4). Machines are
  always red. *(Claude's call)* Each character gets its own **shade within
  the region's hue family**, plus a distinct light *placement* (eye, chest
  core, weapon, halo), so the 3 Foundry characters never read as the same
  cyan. The silhouette stays the main identifier. The five colours in the
  board mockup were placeholders. Violet and green belong to the Dimmed and
  don't appear on the cast in the slice.
- **Silhouettes are designed in profile**, because the side view is the
  only camera.
- **Gameplay art is vector art made in code with cutout animation:**
  characters are built from parts (head, torso, limbs, weapon) that
  SpriteKit moves and rotates. Evolution stages add or swap parts and add
  light. Enemy robots are geometric, so a large, varied roster is cheap.
- **Story portraits are higher-fidelity generated art** (Higgsfield, with
  Soul ID for consistency). That's where faces and expression live. They
  keep the region palette so both kinds of art feel like one game.
- Approved references: the mockups in
  `.superpowers/brainstorm/*/content/art-style.html` (option B) and
  `board-layout.html` (option C).

Left to the builder: the exact asset pipeline (for example, vector source
rasterized to texture atlases at build time, versus nodes drawn at runtime),
how glow is rendered, and the animation tooling. Constraint: it has to hold
60 fps on a recent iPhone with a full board, glow and ability effects on
screen.

## 8. Story (slice)

- **Around 6 story scenes** across the 3 chapters, plus one unlock scene for
  each character's first stage-3 evolution.
- *(Claude's call) How the reactivity works:* the 6 scenes are **fixed
  beats** (chapter openings, first boss wins, the slice ending). On top of
  them sits a **pool of short reaction lines**, 1–3 lines played between
  runs. Each line has conditions (who you brought, who fell first, who
  evolved, how you lost) and a priority, and lines don't repeat until the
  pool runs out. That gives every run, including a failed one, something
  new without writing a full scene each time. The dialogue system has to
  support condition-and-priority line selection, not only linear scripts.
  The owner approves the beats and the pool.
- **Format:** portraits and dialogue, short. Character and conflict come
  before lore. Scenes reference the player's recent runs where possible:
  who they brought, who fell, who evolved.
- **The slice's arc:** the defector and its creator are the spine. Each
  chapter brings the cast closer to understanding what the AI is doing and
  who's to blame. The slice ends on a hook into the full game, not a
  resolution.

Left to the builder: the full plot of the slice, the scripts and the
dialogue system implementation, all within §9's gates.

## 9. Quality bar and the owner's review gates

The owner judges gameplay, characters and story. Each has a concrete check
before it counts as done:

| Area | Check | Gate |
|---|---|---|
| Character design | **Silhouette test:** all 8 identifiable from a pure black shape. **Kit check:** each ability set reads as that personality. | The owner approves the cast sheet before any implementation depends on it. |
| Portraits | Consistent across scenes. Region palette followed. | The owner picks from generated options. |
| Writing | A **read-aloud pass:** no line that sounds stiff, cheesy or like lore dumping. | The owner approves the scripts. |
| Gameplay | Playtests: planning visibly changes outcomes, more than one viable build per chapter, fights readable. | Internal playtests, then strangers. |
| Overall | **External TestFlight with strangers.** | **"Played" means finished at least one full run.** The Chapter 1 milestone (§11) goes to strangers first. The slice succeeds when **10 strangers** have played it. The feedback and analytics decide what Chapters 2–3 and the full game change. |
| Portrait spend | **Pilot first:** generate one character's portraits, measure the credits spent per accepted portrait, and report it. **Check Higgsfield's commercial-use terms** before any portrait is treated as final art. | The owner approves the spend for the rest of the cast ("depends" on the pilot's numbers). |

## 10. Tech decisions

- Swift, SpriteKit, iPhone, landscape. *(Claude's call: minimum iOS 18.)*
- Single-player, offline, local saves.
- *(Claude's call)* Keep the battle simulation as pure Swift, separate from
  SpriteKit, deterministic with a seeded RNG, and unit-tested. Rendering
  plays back what the simulation produced. This allows automated balance
  simulations (thousands of fights) to catch dominant builds, which is the
  first gameplay anti-goal.
- Sound: simple music and effects (sourcing is the builder's call; use
  free or self-made sources, no paid services).

## 11. Milestones and suggested order (for the planner)

**Two milestones (the owner's decision): Chapter 1 goes to strangers
first.**

**Milestone 1: Chapter 1 on TestFlight.**
1. Cast and world sheet for all 8 characters (concept, personality, kit,
   bonds, silhouette sketches) → **owner gate**. Design all 8 up front so
   later chapters don't force rework, but only build Chapter 1's 6.
2. Battle simulation core plus a test harness.
3. Battle rendering in style B, with one character and one machine
   end-to-end (proves the look and the 60 fps budget).
4. The run loop (planning screen, recruiting, evolution, items, bonds).
5. Chapter 1 content: 6 characters (4 to start plus 2 unlocked), the
   Foundry enemies, the Chapter 1 boss.
6. Chapter 1 story beats and reaction lines → **owner gate**. Portrait
   pilot → **owner spend gate**.
7. Onboarding, saves, sound, opt-in analytics, polish → **external
   TestFlight**.

**Milestone 2: the full slice.** Shaped by Milestone 1's feedback and
analytics: the last 2 characters, Chapters 2–3 with their enemies and
bosses, the remaining story, the remaining portraits → TestFlight update.

The planner may reorder steps within a milestone but should keep the owner
gates ahead of the work that depends on them.

## 12. Calls Claude made (for the owner to check)

- The third region is the Lantern Cities, not the Dimmed.
- The cast split is 3 Foundry, 3 Dawnfaith, 2 Lantern Cities.
- Formation size is 5, picked from a cast of 8.
- Evolution resets every run; the stage-3 story unlock is permanent.
- No permanent stat progression.
- Minimum iOS 18. The battle simulation is pure Swift, deterministic and
  unit-tested.
- Bond levels reset every run. Story unlocks bonds and tiers, never starting
  power.
- Unlock pacing: start with 4 characters, Chapter 1 unlocks 2 more, and
  Chapter 2 unlocks the last 2.
- Story reactivity: 6 fixed beats plus a pool of conditional reaction lines.
- Each character gets its own shade within its region's colour and its own
  light placement.
