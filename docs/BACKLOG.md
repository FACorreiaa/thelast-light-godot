# The Last Light: backlog

Carried over from the Swift game (`apps/game-proto`, tag `swift-final`). The Godot port is now the only codebase
that gets new content. Sources: the action-RPG spec (`game-proto/docs/superpowers/specs/2026-11-15-the-last-light-action-rpg-design.md`),
the cast sheet (`game-proto/docs/design/cast-sheet.md`), the universe bible (`game-proto/UniverseBible/`), and PRs #24 to #26.

## What the port has (checked 2026-11-19 against `swift-final`)

Nothing landed in Swift after the tag except a CI change for Xcode 27, so this is everything Swift had.

- **Heroes:** Caelen, Seraphine and Nimue as leads, Orion as the companion, and Nimue's decoy. Kits match Swift.
- **Chapters:**
  - **1, The Foundry:** three faction openings (Awakening, Sun Gauges, Undercroft), then the Foundry Yard, the
    Machine Hall, the Lock Works (puzzle), the Warden's Gate (mid-boss) and the Protocol.
  - **2, The Lantern Cities:** the Ember Market, the Toll Canal, the Lantern Roofs, Lamp Row (the Lamplighter,
    mid-boss), the Cinder Docks and the Cinder Vault (the Cinder King).
  - **3, The Dawnfaith:** the Pilgrim Road, the Bell Tower, the Sun Cloister, the Cloister Gate (the Sworn, twin
    mid-boss), the Choir Stair and the Oracle's Terrace (the Last Oracle).
- **Bosses:** the Line Warden, the Protocol (Judgement, Ascension, Execution), the Lamplighter, the Cinder King,
  the Sworn Shield and Sworn Spear, and the Last Oracle.
- **Enemies:**
  - The Foundry: Scrap Drone, Forged Soldier, Sentry Core, Dogma Frame.
  - The Lantern Cities: Ratborn, Lantern Gunner, Smuggler Brute, Night Weaver and its images.
  - The Dawnfaith: Zealot, Radiant Acolyte, Solar Guard, Halo Disciple.
  - The training dummy.
- **Levels:** levers, plates, gates and lamps, hazards, checkpoints, pickups, and partner hand-offs.
- **Story:** 35 scenes, decisions and lead-specific lines.
- **Proof:** 64 golden runs replay bit-exact against Swift, and every route is finishable by the autopilot.

## Still to build (from the Swift plans)

1. **The final chapter: the Eclipse Engine.** Chapter 1 ends on it as a hook, and the boss roster names it the final
   boss ("a world without life"; mechanics: multi-stage, reality shifts).
   - Decided (DEC-016, DEC-017): a half-built structure over a drowned city, six levels, eclipse phases, personal
     epilogues.
   - Built (2026-11-25): the eclipse-phase mechanic in the sim (`tests/test_eclipse.gd`), its placeholder drawing,
     and all six levels as placeholders: the Drowned Approach, the Scaffold Ways, the Still Quarter, the Mason's
     Span (mid-boss), the Corona Stair and the Heart (boss). Chapter 4 is in `index.json` for every lead and can be
     finished, with a placeholder ending line. Godot goldens cover each level, walking and fighting.
   - Decided 2026-11-25 (DEC-019): the Heart is beaten and the AI speaks (option 2); the ten claims are approved;
     Chapter 4 was hidden until its lines were in (DEC-020) and is open again since 2026-11-25. The mechanism
     stays: `"hidden": true` on a chapter in `index.json` hides it, `--all-chapters` shows it.
   - Decided 2026-11-25 (DEC-020): voice A, every DRAFT-013 line, the ending line, the level names and the boss
     figures, cards and tips as they stand. The lines go into `data/story/chapter4.json`; then the chapter opens.
   - Next: the three personal epilogue scenes, drafted as DRAFT-014 for the creator's verdict (they then need an
     epilogue cue after the ending line), and showing voice A on screen (machines on the frame speaking; the Heart's arena has none yet, so
     adding them is a level change plus a Godot golden re-record).
   - Known, left as is:
     - A boss's leftover summons stay alive during the victory delay and can still kill the lead before the level
       completes. That is the Swift rule; changing it is a design call and needs a Swift golden check plus a
       re-record.
     - Walk-mode autopilot cannot shake a chaser while it waits for the rhythm. The Corona Stair drone at x 1100
       sits on a waiting landing; seeds 1-9 pass, but a level edit can expose it.
     - The Heart's balance is thin for Nimue: over seeds 1-30 every lead wins, but Nimue's closest win ends at 5 HP
       (Caelen 44, Seraphine 46). The Heart spends about 8% of a fight staggered (the Mason 5-7%).
     - Ledge play is unproven: the autopilot wins both boss fights, but nothing checks that it uses the arena
       ledges as shelter.
     - A player's own jump, or walking off an edge, can take them over gone ground, like any pit. Lunges and
       dodges stop at the edge for every hero, the player included.
2. **The other four heroes as playable kits:** Elyra (Engineer, Foundry: control and debuff), Valen (Paladin,
   Dawnfaith: tank and protect), Lira (Scholar, Dawnfaith: buff and strike) and Jax (Broker, Lantern Cities: steal
   and burst). The owner brief says all eight become playable. The cast sheet says Jax needs a new name, because a
   League of Legends champion already has it.
3. **Progression** (spec 4.7): a short ability track per hero, unlocked by story progress, with no stat grinding.
   Not built in Swift either.
4. **Personal epilogues** (spec 5): one ending scene per lead. Each chapter currently ends on a single line.
5. **Bible verdicts:**
   - DRAFT-010 holds 9 PROPOSED world claims (Lantern Cities).
   - Character backstories are decided one character at a time (DEC-010).
6. **Art.** The owner has said it comes last (confirmed 2026-11-19). Saved for when it starts:
   - **Scenarios.** Each place is a distinct, playable space, not a backdrop. It introduces a memorable
     platforming mechanic, reveals something about its faction, and shows a different symptom of the world's
     decline. Mood references, one per region, are in `UniverseBible/ArtReferences/Scenarios/`.
   - **Characters, enemies and bosses.** The creator's concept sheets (hero roster cards, faction line-up, enemy
     overview, Foundry enemies with The Protocol's phases and attacks) set names, looks, roles and attacks. They
     are not on disk yet; save them into `UniverseBible/ArtReferences/` (see its README).
   - **How.** Godot draws, lights and animates the art but does not make it. The owner's plan: model and animate in
     Blender, then render sprite sheets or use the 3D models directly with a side-on camera. The simulation does not
     depend on the drawing, so either works. Painted scenario art becomes parallax layers; the playable ground is
     tiles and props that match the collision. Higgsfield is connected and can generate images and 3D (spend needs
     the owner's approval). A Meshy MCP would be a new agent tool, which the quarter's rules rule out.
7. **Release.**
   - The port ships under the "LastLight GdSpike" App Store Connect record, while the real record is "The Last
     Light - Chapter Zero" (`com.fernandocorreia.lastlight`). Move the bundle id over before strangers test it.
   - Steam once the game is done: $100 one-time per game, refunded after $1,000 gross.
8. **Technical leftovers:**
   - `test_flow` prints about 480 "Lambda capture at index 0 was freed" errors from the start of the run (already
     there at 89e4962; it still passes). Some lambda outlives the node it captured; find it.
   - A Windows font for the menus (SF Pro falls back to a system font there).
   - A two-object leak at exit after the demo bot plays.
   - Android export, if wanted.
