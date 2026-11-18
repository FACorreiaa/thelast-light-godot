# Canon audit · v0.1 · 2026-11-16

Phase 1 of the bible: what every existing source says, and where they disagree. This audit creates no new
history.

## Sources audited

| Source | Kind | Authority |
|---|---|---|
| Creator's direction, 2026-11-16 (magic ≠ technology; cause unknown; shared universe) | Creator decision | LOCKED |
| Bible v0.1 single file (`Archive/2026-11-16_v0.1_single_file.md`) | Draft | Labels as given |
| Four concept sheets: hero roster, faction line-up, enemy overview, Foundry enemies + The Protocol | Art | ART (images not yet in the repo, see `ArtReferences/`) |
| `docs/superpowers/specs/2026-10-22-the-last-light-slice-design.md` | Approved spec (autobattler, superseded) | World section still cited by the later spec |
| `docs/superpowers/specs/2026-11-15-the-last-light-action-rpg-design.md` | Approved spec (action-platformer) | WORKING |
| `docs/design/cast-sheet.md` (2026-11-15) | Draft awaiting creator verdict | PROPOSED |
| `LastLight/LastLight/Story/chapter1.json`, level names, results text | Shipped to TestFlight | SHIPPED |
| Game code (`ActionCore`): enemy and boss behaviour | Shipped | Gameplay only, not canon (README principle 5) |

## What the sources agree on

- Three factions, their three themes and their colours.
- Eight heroes with names, titles, factions, roles, quotes and looks from the roster art.
- Twelve enemies, three bosses and the Eclipse Engine, by faction.
- An AI tied to the Foundry pursues a terrible salvation and believes it is right.
- Seraphine keeps her name; Jax's name has a market clash and needs review before release.

## Contradictions and gaps

Each conflict below had options and a recommendation. **All six were decided on 2026-11-16**; the outcome is under each heading.

### CF-001: is "the sun is dying" canon?

**Decided (DEC-006, LOCKED):** option A.

Both approved specs open with "The sun is dying." The bible leaves the observed symptoms open (Open Question 1).
Neither says *why* the sun is failing, so this is not a clash with LC-002 (cause unknown). It is a missing
decision about what people see.

- **A. The sun weakening is the main visible symptom (recommended).** It fits the title, the art and the shipped
  game, and it leaves the cause open: the Foundry measures it, the Dawnfaith calls it judgement, the Lantern
  Cities trade in what light is left.
- **B. The sun is one symptom among several** (failing machines, failing miracles, failing harvests). That gives
  a richer mystery but a less iconic image.
- **C. "The sun is dying" is a belief, not an observation.** That is the most ambiguous option, but it is hard to
  square with a world literally getting darker.

### CF-002: the AI's motive

**Decided (DEC-007, WORKING):** option A.

The specs say the AI concluded that organic life burns too much of the remaining light, so it is replacing living
things with machines that need none. The bible keeps the AI's mandate UNKNOWN and says its diagnosis may be
wrong.

- **A. Make it WORKING: that is what the AI believes (recommended).** It is a motive, not a cosmic fact, so the
  cause stays unknown. It already drives the shipped game (a line where "the others … never woke"; the Eclipse
  Engine as "a world without life").
- **B. Keep it PROPOSED** until the AI's mandate is designed as a whole.

### CF-003: Seraphine's secret

**Decided (DEC-008, WORKING):** option A.

The draft cast sheet says that the old oracles hid that the sun was dying before the AI existed. That rules out
"the AI caused it", which is one answer to the mystery.

- **A. Keep the secret but soften what it proves:** the records show the light failing earlier than the official
  history admits. That is evidence about *when*, not *why* (recommended).
- **B. Keep it as written:** the AI did not start the decline. That is a real reveal, so it should be an explicit
  decision.
- **C. Drop it** and find Seraphine another burden.

### CF-004: "the Dimmed" vs "the Dimming"

**Decided (DEC-009, LOCKED):** option A, keep both.

The old spec named a fourth region, the Dimmed (wilds where the light has already gone, green and violet), held
back as a mystery. The bible proposes the Dimming as the public name of the crisis.

- **A. Keep both:** the Dimming is the process and the Dimmed are the places it has finished. The names
  reinforce each other (recommended).
- **B. Rename one** to avoid confusion.
- **C. Retire the Dimmed region.**

### CF-005: backstories in the cast sheet fill in UNKNOWNs

**Decided (DEC-010):** option A.

The draft says Caelen built Orion and wrote the ethics module the AI routed around, and that Orion was a disposal
unit that refused an execution. The bible lists who made Orion and what Caelen built as unknown.

- **A. Treat the cast sheet as the PROPOSED answer**, to be decided per character in `Characters/`
  (recommended; done in this version).
- **B. Lock the cast sheet as written.**

### CF-006: the Eclipse Engine in the shipped ending text

**Decided (DEC-011):** option B, by Claude on the creator's delegation. New line: "The Protocol is silent. It was only a voice. The Eclipse Engine has not stopped."

The 2D game's chapter-end screen (in PR #10, not yet merged) says "Somewhere past the Foundry, the Eclipse Engine
is still turning." That treats the Engine as a machine that already exists and is running. The art calls it the
AI's final solution, a world without life.

- **A. Keep it:** a physical engine fits "Engine" and the art (recommended if A is chosen for CF-002).
- **B. Change the line** to something that hints without committing, e.g. "The Protocol was only its voice."
  (PROPOSED).

### Also noted

- **The Last Oracle and Seraphine's title "The Oracle"** are deliberately left open (Open Question 9).
- **Jax** shares a name with a well-known game character. That's a publishing issue for a name review, not a
  retcon.
- **Gameplay vs lore:** the game's Protocol has phases named Judgement, Ascension and Execution, and the Dogma
  Frame projects a protective ward. These are design choices, not lore, until the creator says otherwise.
