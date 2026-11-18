# Rules for working in the Universe Bible

These rules apply to any AI assistant (Claude Code included) that reads or edits this folder, or writes game
content from it.

## Canon

- **Never invent a fact and present it as established.** New ideas are labelled **PROPOSED** and go to the
  creator.
- **Only the creator makes something LOCKED.** A locked fact needs an explicit, dated approval in
  `DECISION_LOG.md`. A suggestion in this folder is not canon just because it is written here. "The creator didn't
  object" is not approval.
- **UNKNOWN means leave it open.** Do not solve the collapse, the origin of magic or the AI's mandate on your own
  initiative, not even in a codex entry, a boss speech or a commit message.
- **When a new decision contradicts older text, say so.** Name the files and lines. Do not overwrite history
  silently; mark the old idea **RETIRED** and log why.
- **Respect the sources in this order:** creator's explicit decisions > SHIPPED text > ART > approved specs >
  PROPOSED ideas. When two of them disagree, record the conflict in `CANON_AUDIT.md` and ask.

## Writing

- Keep to one topic per file and link related files. Keep `README.md` and `CANON.md` current.
- Mark every section or statement with its label.
- Record what an in-world source **claims**, never omniscient truth. A Foundry log, a Dawnfaith manuscript and a
  Lantern ledger can all describe one night differently.
- Avoid generic fantasy and sci-fi tropes. Distinctive and internally consistent beats familiar.
- No faction is purely evil or secretly right.

## Working with the creator

- Work in small pieces. When a decision is needed, give two or three options, their narrative consequences, and
  one recommendation.
- After a decision, update every affected file in the same change and list them in the decision log.
- Do not change a character's established identity (name, title, faction, look, quote) without approval.
- The creator keeps verdicts on all writing. Drafts are drafts.

## Using the bible in a game

- Game text that states something about the world must be checkable against `CANON.md`. If it isn't there, it is
  local to that game (see `Games/ContinuityAndEndings.md`) or it needs a decision.
- A game may ship something marked WORKING, and the bible then tags it SHIPPED. It may not ship anything that
  contradicts LOCKED.
- Store reference images in `ArtReferences/`, never generated art mixed in with them.
