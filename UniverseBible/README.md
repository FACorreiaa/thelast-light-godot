# The Last Light: Universe Bible

**Version 0.1 · 2026-11-16 · working draft**

> A world is dying. Three civilizations have explanations. None has proof.

This is the single source of truth for what is true in *The Last Light* universe, for every game, DLC,
cinematic and piece of art. It is separate from the games on purpose: the bible says **what is true in the
world**, and a game design document says **what the player does**.

Write in Markdown, keep it in Git, and use one topic per file. Obsidian can open this folder as a vault.

## Read first

| # | File | What it holds |
|---|---|---|
| 1 | [CANON.md](CANON.md) | The register: what is locked, working, proposed, unknown |
| 2 | [DECISION_LOG.md](DECISION_LOG.md) | Every creator decision, dated, with the files it touched |
| 3 | [CANON_AUDIT.md](CANON_AUDIT.md) | v0.1 audit: every source, and the contradictions waiting for a decision |
| 4 | [WORLD_OVERVIEW.md](WORLD_OVERVIEW.md) | Premise, pillars, rules for writers |
| 5 | [COLLAPSE_MYSTERY.md](COLLAPSE_MYSTERY.md) | Why the world is dying: three faction theories, no answer |
| 6 | [TIMELINE.md](TIMELINE.md) | Eras, provisional |
| 7 | [Systems/](Systems/) | [Magic](Systems/Magic.md), [Technology](Systems/Technology.md), [how they meet](Systems/MagicVsTechnology.md) |
| 8 | [Factions/](Factions/) | [Foundry](Factions/Foundry.md), [Dawnfaith](Factions/Dawnfaith.md), [Lantern Cities](Factions/LanternCities.md), [between them](Factions/Relations.md) |
| 9 | [Characters/](Characters/) | The eight heroes, one file each, plus [relationships](Characters/Relationships.md) and the [template](Characters/_TEMPLATE.md) |
| 10 | [Bestiary/](Bestiary/) | Enemies and bosses by faction, and [the Eclipse Engine](Bestiary/EclipseEngine.md) |
| 11 | [Locations/](Locations/) | Regions and places, starting with the Foundry |
| 12 | [Games/](Games/) | [Continuity and endings](Games/ContinuityAndEndings.md), [the 2D game](Games/TheLastLight2D.md) |
| 13 | [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) | The ten decisions that matter most, with options |
| 14 | [ArtReferences/](ArtReferences/) | Manifest of the reference images |
| 15 | [CLAUDE.md](CLAUDE.md) | Rules for AI-assisted writing in this folder |

## Canon labels

Every statement in this bible carries one of these labels, either on the statement itself or on its section.

| Label | Meaning |
|---|---|
| **LOCKED** | The creator decided it explicitly. Every game must respect it. Changing it needs a new decision. |
| **WORKING** | The current direction, often backed by the concept art or an approved game spec. Can still change. |
| **PROPOSED** | An idea waiting for the creator. Not canon, however good it sounds. |
| **UNKNOWN** | Deliberately undecided. Nobody, human or AI, fills it in without a decision. |
| **ALTERNATE** | True for one playthrough or ending. It doesn't bind other games. |
| **RETIRED** | Kept for history. Not for new use. |

Two more tags describe where something comes from, not how certain it is:

- **ART:** visible in the creator's concept sheets (names, titles, quotes, looks, roles).
- **SHIPPED:** in a build players have played (dialogue, level names). Changing it means changing the game too.

## Principles

1. **A faction's explanation is not the truth.** All three theories may be partly right, all wrong, or about
   different symptoms.
2. **Separate three things:** what happened, what people believe happened, what the audience has been allowed to
   learn.
3. **Every game tells a complete story** even while the world's central mystery stays open.
4. **Every faction has people who disagree with its leadership:** kind scientists, corrupt priests, honest
   smugglers.
5. **Gameplay does not make canon.** An attack name, a boss phase or a technical constraint is not a fact about the
   cosmos.
6. **A character's identity holds across genres.** Abilities can change between a platformer and an RPG; history
   and personality don't, unless the creator decides otherwise.

## How the bible grows

Work chapter by chapter, never the whole universe in one pass. When a decision is needed, present two or three
options with their consequences and a recommendation. After the creator decides, log it in
`DECISION_LOG.md`, update `CANON.md`, then update every file the decision touches. Silence is not approval.
