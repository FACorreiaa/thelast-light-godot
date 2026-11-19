# Decision log

Each entry records the creator's decision as given, its date, and the files it touched. Drafts awaiting a
decision are listed separately.

## Decisions

| ID | Date | Decision | Status | Files touched |
|---|---|---|---|---|
| DEC-001 | 2026-11-16 | Magic and technology are fundamentally different forces; magic is genuinely supernatural rather than misunderstood technology. | LOCKED | CANON, WORLD_OVERVIEW, Systems/*, Factions/* |
| DEC-002 | 2026-11-16 | The true cause of the world's collapse is unknown at the start, and each of the three factions has a convincing but incomplete explanation. The truth may emerge across several games, and no game requires the others. | LOCKED | CANON, WORLD_OVERVIEW, COLLAPSE_MYSTERY, Factions/*, TIMELINE |
| DEC-003 | 2026-11-16 | The Last Light is one shared universe for standalone stories about different characters and events, not one continuous campaign. | LOCKED (direction) | CANON, Games/ContinuityAndEndings |
| DEC-004 | 2026-11-15 | Seraphine keeps her name. | LOCKED | Characters/Seraphine |
| DEC-005 | 2026-11-16 | The bible is a living encyclopedia: plain Markdown in Git, one topic per file, six canon labels, kept separate from game code. | LOCKED (process) | README, CLAUDE |
| DEC-006 | 2026-11-16 | CF-001, option A: the weakening sun is the main visible sign of the decline; its cause stays unknown. Creator: "ok". | LOCKED | CANON, WORLD_OVERVIEW, OPEN_QUESTIONS, Factions/Dawnfaith |
| DEC-007 | 2026-11-16 | CF-002, option A: the AI believes life burns too much light and is replacing living things with machines. That is its belief, not the truth. Creator: "ok". | WORKING | CANON, Systems/Technology, Games/TheLastLight2D |
| DEC-008 | 2026-11-16 | CF-003, option A: Seraphine's buried records show the light failing earlier than official history admits. They say when, not why. Creator: "ok". | WORKING | CANON, Characters/Seraphine, TIMELINE |
| DEC-009 | 2026-11-16 | CF-004: keep both names. The Dimming is the decline as lived; the Dimmed are the places where it has finished. Creator: "both". | LOCKED | CANON, WORLD_OVERVIEW, Locations |
| DEC-010 | 2026-11-16 | CF-005, option A: cast-sheet backstories stay PROPOSED and are decided one character at a time. Creator: "ok". | LOCKED (process) | CANON, Characters/* |
| DEC-011 | 2026-11-16 | CF-006, option B, chosen by Claude on the creator's delegation ("you decide"): the chapter-end line no longer says the Eclipse Engine is "still turning". New line: "The Protocol is silent. It was only a voice. The Eclipse Engine has not stopped." The Engine's physical form stays UNKNOWN. | WORKING (wording is the creator's verdict) | CANON, Bestiary/EclipseEngine, Games/TheLastLight2D, game text |
| DEC-012 | 2026-11-16 | DRAFT-005 approved: the three openings, the faction pick and their nine world claims (Sun Gauges, behind the Protocol, Orion cannot lie, Caelen's familiarity, runners, the Chapter 1 ending line). Creator: "LGTM!" | WORKING | CANON (WC-012 to WC-015, WC-019), Games/TheLastLight2D, Characters/Orion, Caelen, Nimue, Locations |
| DEC-013 | 2026-11-16 | DRAFT-006 approved: Chapter 2, the Lantern Cities and the Cinder King, and their sixteen world claims. Creator: "LGTM!" | WORKING | CANON (WC-016 to WC-019), Games/TheLastLight2D, Bestiary/LanternCities, Locations |
| DEC-014 | 2026-11-16 | DRAFT-007 approved: the Line Warden keeps the Warden's Gate before the Protocol; Orion knows it; the three lead lines, including Nimue's that her runners once went round the gate. Creator: "The five Line Warden claims: LGTM". | WORKING | CANON (WC-020), Bestiary/Foundry, Games/TheLastLight2D, Locations |
| DEC-015 | 2026-11-16 | DRAFT-008 approved: Chapter 3, the Dawnfaith lands, the Last Oracle and their fifteen world claims. Creator: "15 Chapter 3 claims: Looks good to me." | WORKING | CANON (WC-019, WC-021 to WC-023), Games/TheLastLight2D, Bestiary/Dawnfaith, Locations |
| DEC-016 | 2026-11-19 | The 2D game gets a final chapter in which the Eclipse Engine is reached and fought. Chosen from three options (work in progress / a process / tease only): **the Engine is a work in progress**, a vast half-built structure rising over a drowned city under the eclipse; the chapter climbs it and the boss guards its heart. It is not finished, so it can be stopped. Who built it and why stay as before (WC-007, WC-010; the AI's diagnosis is not automatically right). Creator picked the recommended option. | WORKING (game); the drowned city's name and history stay UNKNOWN | CANON open questions, Bestiary/EclipseEngine, Games/TheLastLight2D |
| DEC-017 | 2026-11-19 | Final chapter shape: six levels like Chapters 2 and 3 (four levels, a puzzle level and a mid-boss, then the Engine), each lead's personal epilogue after the fight, and **eclipse phases** as its platforming mechanic (ground solid only in the corona's light or only in shadow, swapping on a rhythm). Gameplay, not canon. Creator picked the recommended options. | WORKING (gameplay) | Games/TheLastLight2D |
| DEC-018 | 2026-11-19 | Chapter order: the bible's stands over the concept posters' labels. Chapter 2 is the Lantern Cities, Chapter 3 the Dawnfaith. Creator: "the bibble". | LOCKED (order) | ArtReferences/README |

## Drafts awaiting a decision

| ID | Date | Draft | Files |
|---|---|---|---|
| DRAFT-002 | 2026-11-16 | Faction theories: Cascade Hypothesis, the Severance, the Stolen Light. | COLLAPSE_MYSTERY, Factions/* |
| DRAFT-004 | 2026-11-15 | Cast sheet: backstories, Jax's new name, the Last Oracle title clash. | Characters/* |
| DRAFT-009 | 2026-11-16 | The Lock Works, a Chapter 1 puzzle level between the Machine Hall and the Warden's Gate: its name and the lead and Orion lines. | Games/TheLastLight2D, Locations |
| DRAFT-010 | 2026-11-18 | Chapter 2 additions: the Lamplighter (mid-boss) and the Lamp Row, the Toll Canal puzzle level, and their lead and Orion lines. | Games/TheLastLight2D, Locations, Bestiary/LanternCities |
| DRAFT-011 | 2026-11-18 | Chapter 3 additions: the Sworn (mid-boss) at the Cloister Gate, the Bell Tower puzzle level, and their lines. | Games/TheLastLight2D, Locations, Bestiary/Dawnfaith |

## How to amend

When the creator approves a draft, record their exact wording and the date, update `CANON.md`, update every
affected file, and scan the bible and the shipped game text for contradictions.
