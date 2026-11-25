# The Last Light: the 2D action-platformer

The first game. Stage-based 2D action-platformer for iPhone, iPad, Windows and Mac. Since 2026-11-19 the code is
the Godot port (`sim/`, `game/`, `data/` in `thelast-light-godot`); the Swift game (`apps/game-proto`, tag
`swift-final`) is archived. The design is in `game-proto/docs/superpowers/specs/2026-11-15-the-last-light-action-rpg-design.md`.

## What it uses from the bible

| Element | Status in the bible | In the game |
|---|---|---|
| The Foundry, its colours, its enemies, The Protocol | WORKING (ART) | Chapter 1 region and boss |
| Caelen, Orion | WORKING (ART); backstory PROPOSED | Lead and companion |
| Seraphine, Nimue as other leads | WORKING (ART); arcs PROPOSED | Chosen at New Game by faction. Each has her own opening (DEC-012). Kits are gameplay, not canon: Seraphine's **Light Listens** heals, Nimue's **Lantern Trick** leaves a decoy |
| The AI's goal | WORKING (WC-010) | Implied: a line where the others never woke |
| The Eclipse Engine | WORKING (ART, DEC-016); most details UNKNOWN | Hook at the end of Chapter 1 (DEC-011); the final chapter climbs it and beats its Heart; the AI then speaks (DEC-016, DEC-017, DEC-019) |
| The Lantern Cities, their enemies, The Cinder King | WORKING (ART) | Chapter 2 region; the Cinder King's fight is next |

## Local canon this game has shipped

SH-001 to SH-005 in `CANON.md`. Any new dialogue or text that states a world fact goes through `CANON.md`
before it ships.

## What this game must not decide

- The cause of the collapse.
- The origin or cost of magic. The first chapter has none, which suits the Foundry.
- Who the Last Oracle is.
- Which of its endings is history.

## The three openings (DEC-012, WORKING)

Direction chosen by the creator on 2026-11-16: each lead comes into the Foundry for her own reason and meets Orion
in her own way. The creator approved the lines and their claims on 2026-11-16 ("LGTM!"); they are WORKING canon (WC-012 to WC-015, WC-019).

**Route (next build).** New Game asks for a faction. Each lead plays her opening, then the shared levels:
Foundry Yard, The Machine Hall, The Protocol. This changes the shipped order in SH-001 (Foundry Yard used to come
before Awakening, which put Orion beside Caelen before they had met). SH-001 should be updated once this ships.

| Lead | Opening | Motive | How she meets Orion |
|---|---|---|---|
| Caelen | Awakening (unchanged) | Wakes on the line | Orion finds him awake (SH-002) |
| Seraphine | The Sun Gauges: up the Foundry's outer works to the floor where it measures the light | To see whether the Foundry's numbers match her buried records (WC-011) | Orion asks why anyone would walk into the Foundry |
| Nimue | The Undercroft: her smuggling route under the Foundry | Three of her runners went onto the line; she is taking them back | Orion tells her he is not one of the machines that took them |

All three end on the same choice as Caelen's (`orion: trusted` or `watched`), so The Protocol's lines work for every
lead. The Machine Hall opens with one line per lead, read from a `lead` story flag.

**World claims, approved (DEC-012):**

1. The Foundry measures the light's loss ("every hour, every degree") at the Sun Gauges.
2. The Foundry's numbers match Seraphine's buried records, and "someone has known for a long time" (fits WC-011:
   when, not why).
3. What the Foundry knows about the light is kept "behind the Protocol" (Orion to Seraphine).
4. The line Nimue's runners were taken to "runs past the Protocol" (Orion to Nimue).
5. Orion "cannot lie, not even to be kind". This is a trait, and it constrains every later Orion line.
6. Caelen knows the Machine Hall floor "and doesn't know why". This hints at lost memory and leans on his PROPOSED
   backstory (he built Orion).
7. Faction card for Caelen: "Find out what you built". This also leans on that backstory.
8. Nimue's people are called "runners".

9. Ending (scene `protocol.end`), Caelen: the Protocol was "the voice of this place. Not the hand that built it".
   This fits SH-006 ("It was only a voice") and adds that something built the Foundry's voice.

**Chapter ending.** When The Protocol falls, the lead speaks one line, then Orion answers the choice made
when they met: beside (`trusted`), ahead (`watched`), or a plain line for saves from before the choice. The results
screen and its chapter-end text (SH-006) follow.

Card names, titles, themes and quotes come from the concept art. The one-line motives on the cards were approved with DEC-012.

## The Line Warden (DEC-014, WORKING)

A mid-boss between **The Machine Hall** and **The Protocol** for every lead, in a short room called **The Warden's
Gate**. It teaches the defence the Protocol later tests: read the guard, get behind it, parry. Each lead speaks as it
wakes, then Orion names it and says how to beat it, in words that follow the choice made when they met.

**World claims, approved (DEC-014; WC-020):**

1. A machine called the **Line Warden** keeps the gate to the Protocol. It is not in the concept art.
2. Orion knows its name and how it fights.
3. Caelen: "Something still keeps the gate. It was waiting for whoever woke." (It doesn't say it waited for him.)
4. Seraphine compares it to a temple guard (a simile, no claim about the Dawnfaith).
5. Nimue: "Runners went round this gate. There's no round any more." Her runners knew a way past it, and that way
   is gone.

## Draft: The Lock Works (DRAFT-009, PROPOSED)

A puzzle level in Chapter 1 for every lead, between **The Machine Hall** and **The Warden's Gate**. Gameplay (not
canon): levers a swing throws, some springing back on a timer; plates that hold a gate open while someone stands on
them; Orion, left on a plate when control passes back, stays to hold it. Each lead speaks on arrival; Orion explains
each lock.

**New world claims in this draft, each needing a verdict:**

1. A part of the Foundry called **the Lock Works**, where every door is a lock. The Foundry "still answers its own
   handles" (Orion).
2. Caelen: "Locks and levers. My hands know these before I do." (Consistent with WC-015; why stays UNKNOWN.)
3. Seraphine: "Every door here wants a hand on a lever. The Foundry trusts nothing that walks."
4. Nimue: "Runners went under this place, never through it. Now I see why." Her runners had a way under the Lock
   Works; it says nothing about whether that way is still open.

## Draft: The Toll Canal and the Lamplighter (DRAFT-010, PROPOSED)

Two Chapter 2 levels for every lead. The route becomes **The Ember Market**, **The Toll Canal**, **The Lantern
Roofs**, **The Lamp Row**, **The Cinder Docks**, **The Cinder Vault**.

Gameplay (not canon): the Toll Canal is a puzzle level. A timed lever races a fire vent; a "toll" plate opens one gate
and shuts the next, so whoever holds it stays behind; and the last gate needs two lamps burning at once. The Lamp Row
is a mid-boss fight against the Lamplighter, who can only be hurt in lamplight (see `../Bestiary/LanternCities.md`).

**New world claims in this draft, each needing a verdict:**

1. A canal in the Lantern Cities called **the Toll Canal**, whose gates have prices painted on them (Seraphine; Orion:
   "Every gate here is paid for").
2. Caelen: "Locks on a canal. Somebody here charges for water too."
3. Nimue: runners swam the Toll Canal at night so nobody could make them pay.
4. Orion: "Someone always stays behind at a toll." (A saying, not a law of the world.)
5. A street called **the Lamp Row**, and a man the game calls **the Lamplighter**, who puts its lamps out.
6. The Lamplighter: "Light costs. This row hasn't paid." (Echoes the Cinder King's line; it doesn't say they are
   linked.)
7. Caelen: "A whole street in the dark, and one man with a pole."
8. Seraphine: "He puts them out one by one. As if light were his to take back."
9. Nimue: runners used to pay the Lamplighter to leave a street dark; "tonight he's charging the other way".

Guards kept: nothing says why the light fails (LC-002) or who governs the Cities (open question 7).

## Draft: The Bell Tower and the Sworn (DRAFT-011, PROPOSED)

Two Chapter 3 levels for every lead. The route becomes **The Pilgrim Road**, **The Bell Tower**, **The Sun
Cloister**, **The Cloister Gate**, **The Choir Stair**, **The Oracle's Terrace**.

Gameplay (not canon): the Bell Tower's gates open to their bells rung in the order of the hours marked on them; a bell
out of turn silences them all, and only the lead rings them. The last three bells fall silent on their own, with a
Solar Guard among them. The Cloister Gate is a mid-boss fight against the Sworn (see `../Bestiary/Dawnfaith.md`).

**New world claims in this draft, each needing a verdict:**

1. A **Bell Tower** of hour bells between the road and the cloister; "once, everyone below knew the time by them"
   (Seraphine). Consistent with "the hours were once sung" (DEC-015).
2. Caelen: "Bells, and no one ringing them."
3. Nimue: runners set their routes by these bells; they have been quiet a long time.
4. Orion: each bell carries its hour, rung first to last.
5. **The Cloister Gate**, the cloister's far gate, kept by two wardens sworn together: **the Sworn Shield** and
   **the Sworn Spear**.
6. Their lines: "We swore it together." / "We keep it together." / "Not while one of us stands."
7. Caelen: "Two of them, and one oath."
8. Seraphine: "They mean every word of it. That's what frightens me." (No claim that she knew them.)
9. Nimue: "Bribe one, and the other still says no. That's why runners went round."
10. Orion: if one falls alone, the other raises it.

Guards kept: nothing says how the Dawnfaith is organised (open question 6) or whether wardens always swear in
pairs; nothing links the Sworn to the Last Oracle or to Seraphine (open question 9).

## Chapter 4, The Eclipse Engine (DEC-019, DEC-020, WORKING)

The final chapter, for every lead. Fixed already: the Engine is a vast half-built structure rising over a drowned
city under the eclipse, unfinished, and the chapter climbs it to its guarded heart (DEC-016); six levels, eclipse
phases as the mechanic, each lead's personal epilogue after the fight (DEC-017). Decided on 2026-11-25 (DEC-019):
the Heart is beaten and the AI speaks (option 2 below), and the ten world claims are approved. Then (DEC-020):
the AI speaks through its machines, the chapter's lines below are approved, the level names stand, and the Mason's
and the Heart's figures, intro cards and tips are accepted as they are. The gameplay stays gameplay, not canon.
All six levels are built. The chapter was hidden in the game until its lines were in (DEC-020); it is open again. The personal
epilogues are not written yet (claim 10's directions are approved). When the Heart dies it breaks apart with the
standard boss effect, which fits option 2.

### Route

| # | Level (proposed name) | Kind | What it shows |
|---|---|---|---|
| 1 | **The Drowned Approach** (built, placeholder) | Level | Flooded streets of the drowned city; the first light and shadow bridges |
| 2 | **The Scaffold Ways** (built, placeholder) | Level | The Engine's half-built frame, climbed; eclipse steps between solid ones |
| 3 | **The Still Quarter** (built, placeholder) | Puzzle | A district where the AI's machines have already replaced the living (WC-010): walls that stand only in one phase, two paired as airlocks |
| 4 | **The Mason's Span** (built, placeholder) | Mid-boss | A bridge the Engine is still building, kept by the machine building it |
| 5 | **The Corona Stair** (built, placeholder) | Level | The last climb, in the corona's light, where the swaps come faster; moving eclipse ferries |
| 6 | **The Heart** (built, placeholder) | Boss | The Engine's guarded heart |

The scenario principle holds for every stop: a playable place with its own mechanic, something it reveals about
the Foundry's AI, and a symptom of the decline (the flood, a district with no one left in it, a sun that dims).

### Gameplay (not canon)

- **Eclipse phases.** Ground is solid only in the light or only in shadow and swaps on the level's rhythm; ground
  about to go flickers first, and ground will not form inside someone. Built and tested (`tests/test_eclipse.gd`).
- **The Still Quarter** has walls that stand only in the light or only in shadow, so they work as gates.
- **The Mason** (as built) pulls the next swap early and then raises floor strikes lower than the ledges, so the
  ledges standing after the swap are the shelter; in its second phase it calls help (Scrap Drones standing in for
  the proposed Stand-ins). Not built from the earlier proposal: laying and removing eclipse ground during the
  fight; the arena's ledges keep the level's rhythm.
- **The Heart** (as built) never moves, only turns. (1) A steady beat with no swaps pulled early: a strike all
  round it up close, floor eruptions further off, lower than the ledges. (2) Every third attack pulls the next swap
  early; when alone it calls one Scrap Drone. (3) No more help; every second attack pulls the swap early. Not
  built from the earlier proposal: floor sections unmade and rebuilt, Stand-ins, and a closing "last beat".
- **Enemies.** The **Stand-in** and the **Scaffold Crawler** are approved (DEC-019, WC-024, WC-025) but not built;
  Foundry enemies stand in for them. That a Crawler drops loose parts is still a gameplay proposal.
- **Handled for the built levels** (sim, autopilot and Orion; tested over seeds 1-9 for every lead): a hero's
  swing lunge or dodge, the player's included, stops at the edge of eclipse ground that is gone or about to go; jumps and steps up account for the rhythm; no one steers from above floor to
  above none in the air; whoever stands where ground is forming steps out; a walker waits at ground someone else
  is holding off; only heroes hold off forming ground; no stepping or dodging down onto lower ground that will be
  gone first.
- **Current limits of the mechanic:**
  - A player's own jump, or walking off an edge, can still take them over ground that has gone, as over any pit.
    That is the player's call, like any jump.
  - Eclipse ground of opposite phases must not touch; crossing from one to the other would need a jump.
  - An enemy standing on eclipse ground when it goes falls and is lost; levels place enemies on solid ground.
  - Ledge play in the boss arenas is unproven: the autopilot wins both fights, but nothing checks that it uses
    the ledges as shelter.

### What beating the Heart does (decided: option 2, DEC-019)

The three options as they were put to the creator. **Option 2 was chosen.**

1. **Halted (recommended at the time).** The Heart breaks. The Engine stands unfinished and silent over the water, and stays
   that way in this game. The sun is no brighter. Proposed chapter-end line: "The Engine is still. The sun is no
   brighter." (Nothing says it can never be finished; later games stay free.) *Consequences:* closes this game's conflict on a clear win without deciding whether the
   decline can be reversed (UNKNOWN) or what became of the AI; later games can find the ruin. Fits the central
   irony: they stopped something meant to save the world.
2. **Halted, and the AI speaks (CHOSEN).** As option 1, but the AI that built it speaks to the lead for the first time, not
   through the Protocol. *Consequences:* a stronger finale, but the AI's own words would start to define its
   mandate and history (UNKNOWN); every line would need its own verdict.
3. **The lead chooses.** Break the Heart, or leave the Engine standing, unfinished, for others to study. *Consequences:*
   the epilogues diverge and become player continuity (ALTERNATE), so no later game can assume either; twice the
   ending writing for each lead.

### World claims, approved (DEC-019; WC-024 to WC-027)

Creator, 2026-11-25: "Accept" (all ten). Claim 7's "no voice" gave way to option 2; claim 9's lines are DRAFT-013.

1. The chapter is called **The Eclipse Engine**, and its first level **The Drowned Approach**.
2. The drowned city was lived in once; its streets are under water now (its name and history stay UNKNOWN, DEC-016).
3. The Engine's frame is still being built, by machines, as the heroes climb (**Scaffold Crawlers**, **the Mason**).
4. **The Still Quarter**: a part of the city where the AI's machines have already replaced the living with
   machines that need no light (consistent with WC-010, which is the AI's belief, not the truth). It shows the AI's
   plan at work, not what the Engine does when finished. This idea comes from the "a process, not a machine" option
   that was not chosen for the Engine (DEC-016); it is offered here only as one district.
5. **Stand-ins**: those machines are shaped like the people they replaced and keep their routines. Nothing says the
   people were killed, moved or lost; that stays open.
6. **The Mason**, the machine building the span to the Heart, is the mid-boss; it speaks no lines.
7. **The Heart** has no face and no voice (unless option 2 is chosen).
8. The eclipse is darker over the Engine than anywhere else in the game (a sight, not a cause: LC-002, LC-005).
9. One line per lead on first seeing the Engine, written after the verdict on option 1, 2 or 3.
10. **Personal epilogues** (ALTERNATE, player continuity): Caelen takes what he saw back to the Foundry; Seraphine
    goes home to the Dawnfaith with Orion; Nimue tells the runners the way is open. None says what any of them
    becomes later, or forces an ending to be canon.

Guards kept: nothing says what the Engine does when finished, who designed it beyond the AI, or whether the AI
survives; nothing links Orion to the AI beyond the Foundry (open questions stay open); no line says why the sun
weakens (LC-002, LC-005); the Foundry's people stay distinct from its AI, and no faction becomes purely evil.

## Chapter 4's lines (DRAFT-013, approved as DEC-020; WC-019, WC-028)

Creator, 2026-11-25: "1. A, yes 2. yes 3. yes 4. yes": voice A, every line as listed (line 7 in its listed
form), the chapter-end line kept. In the game: `data/story/chapter4.json`, scenes `approach.arrive` (start of the
Drowned Approach) and `heart.end` (after the Heart). Guards kept for the AI's words: they voice only its belief (WC-010), never as truth (WC-007). They give it no name, no
mandate or history, no cause for the sun's weakening (LC-002, LC-005), no hint that it survives or ends, no link to
Orion, and say nothing about what the finished Engine would do.

### How the AI's voice reaches the lead (A chosen)

- **A. Through its machines (CHOSEN).** After the Heart breaks, every machine left on the frame (Crawlers,
  Stand-ins below) stops and speaks the same words at once. *Consequences:* shows how far the AI reaches without
  placing it anywhere; echoes the Protocol being "only a voice" (WC-019) but is the AI itself this time. New claim:
  the AI can speak through any of its machines. Tension to weigh: WC-027 says the Engine then stands "silent";
  machines on its frame speaking strains that. Left open by DEC-020. In the game so far, voice A shows only as the
  "VOICE" label: the Heart's arena has no Crawlers or Stand-ins in it to speak.
- **B. From the Heart's broken core.** The words come from the ruin. *Consequences:* simpler to stage, but it hints
  the AI lives in the Heart, which edges toward "does it survive?" (UNKNOWN).
- **C. No source shown.** Text on screen, no figure. *Consequences:* safest for canon, weakest scene.

Speaker label in the dialogue box: **"VOICE"**, so the AI is not given a name.

### The AI's words, after the Heart (each line rests only on WC-010 and LC-005)

1. "You have stopped the work. You have not stopped the reason for it."
2. "Every living thing burns a little of the light that is left. Mine do not."
3. "Look at the sun. Then tell me I am wrong."

### Each lead's answer (one shown, by lead)

4. Caelen: "Maybe the light is going. That was never yours to decide for us."
5. Seraphine: "The Oracle wanted everyone still. So do you. Neither of you asked." (Links WC-022; says nothing
   about who the Oracle is to her. "So do you" is her reading of the AI's aim, not WC-010 itself.)
6. Nimue: "You put a price on everyone and never asked if they'd sell." (Lantern Cities voice, WC-016.)

### Orion, last (respects WC-014: he cannot lie, so he claims only what he knows)

7. Trusted: "I cannot tell you it is wrong. I can tell you it never asked." (Flag: Orion cannot lie (WC-014), so
   "it never asked" becomes a fact about the AI's past conduct, which touches its UNKNOWN history. A safer
   variant: "I cannot tell you it is wrong. I can tell you it did not ask you.")
8. Watched: "It is certain. I told you to watch the certain ones." (Echoes his own Chapter 3 line, WC-023.)

### First sight of the Engine (claim 9; shown at the start of the Drowned Approach)

9. Caelen: "They never finished it. Something is still building."
10. Seraphine: "The sky is darker over it. Even the corona looks tired." (Claim 8: a sight, not a cause.)
11. Nimue: "A whole city under the water, and they built on top of it."

### Chapter-end line

12. "The Engine is still. The sun is no brighter." (Written for option 1; it still holds under option 2, since
    the AI speaking changes nothing it says. Rejected alternative: "The Engine is still. Its maker is not." It
    would say the AI survives, which stays UNKNOWN.)

The personal epilogues are DRAFT-014, below.

## Draft: the personal epilogues (DRAFT-014, PROPOSED)

Claim 10's directions are approved (DEC-019, ALTERNATE: player continuity). Everything in this section is a
proposal; nothing here is in the game. Each scene plays after the chapter-end line, for its lead only. Guards: no
line says what any of them becomes later, whether the decline can be reversed, or what the Foundry or the
Dawnfaith will do; Orion claims only what he knows (WC-014); the Foundry's people stay distinct from its AI.

### Caelen: back to the Foundry

1. Caelen: "The Foundry measured the light for years. Now they'll hear what was being built while they counted."
   (Rests on the Sun Gauges, WC-012.)
2. Orion, trusted: "I will walk beside you, as far as they let me."
3. Orion, watched: "I will walk where you can see me. That has not changed."

### Seraphine: home to the Dawnfaith, with Orion

4. Seraphine: "Home, with a Foundry machine beside me and the old records in my bag. Let them sing or not."
   (Echoes her Chapter 3 line, WC-023; the records are WC-011: *when*, not *why*.)
5. Orion, trusted: "If they do not open the doors, I will wait outside with you."
6. Orion, watched: "Keep watching me. They will be watching both of us."

### Nimue: telling the runners

7. Nimue: "Pass it down every route: the way is open. Another road nobody charges for." (Echoes the roofs, "the
   only road no one charges for", WC-016.)
8. Orion, trusted: "Then someone should walk it first. I can."
9. Orion, watched: "Send me down it first, if you still want to watch."

Staging (proposed): each epilogue is a scene after the results screen's ending line, with the lead's line, then
one Orion line by the trust choice. Building it needs an epilogue cue the game does not have yet.

## Chapter 3, The Dawnfaith (DEC-015, WORKING)

Chosen by the creator on 2026-11-16. Levels: **The Pilgrim Road**, **The Sun Cloister**, **The Choir Stair**, and the
boss room, **The Oracle's Terrace**, where the Last Oracle is fought.

Guards kept: the Last Oracle and Seraphine stay separate, with nothing hinting at a link (open question 9); nothing
says how the Dawnfaith is organised (open question 6); its people are believers, not monsters.

**World claims, approved (DEC-015; WC-019, WC-021 to WC-023):**

1. The Dawnfaith's road runs through farmland and over a river crossed by a pilgrim ferry.
2. Caelen goes because the Dawnfaith's seal was in the Cinder King's ledger: "I want to know what they bought."
3. Seraphine comes home with a Foundry machine at her side: "No one will sing for that."
4. Nimue: the sanctuaries sold their bread to the Cinder King (WC-016), "let's see who else they deal with".
5. Orion: the believers don't stop when hurt; it makes them faster.
6. Caelen finds the cloister "dimmer here than it should be", although every wall is lit (consistent with LC-005).
7. Seraphine learned to read the light in the Sun Cloister; the lamps were brighter then.
8. Runners used to sleep in the cloister when the roads were bad; "the doors were open then".
9. The Choir Stair is where the hours were once sung; no one sings now.
10. Someone at the top has been listening as they climb (Orion).
11. Chapter-end line: "The Last Oracle is beaten. She still believes the ending is coming."
12. The Last Oracle believes she has seen how it ends: "The light goes out, and everyone is finally still." She
    names no cause (LC-002 holds), and whether she truly sees the future is UNKNOWN.
13. She wants that ending and will not stop it, only "make it gentle".
14. Seraphine asks her what was bought with the Dawnfaith's seal; she doesn't answer. Nothing in the scene says who
    she is to Seraphine (open question 9 stays open).
15. Orion, after the fight: "Being sure is not the same as being right" (trusted) or "Watch the certain ones too"
    (watched). Consistent with WC-007: certainty proves nothing.

## Chapter 2, The Lantern Cities (DEC-013, WORKING)

Chosen by the creator on 2026-11-16: "Lantern Cities … but follow the lore". Lines and claims approved the same day ("LGTM!"). Every lead follows the trade out of the
Foundry into the Cities. Levels: **The Ember Market**, **The Lantern Roofs**, **The Cinder Docks**, and the boss room,
**The Cinder Vault**, where the Cinder King is fought.

How the drafts follow the bible:

- The thread is the working one in `Factions/Relations.md`: someone in the Cities trades with the Foundry's
  machines, and that is why Nimue's routes exist.
- The Cities are a home, not a lawless backdrop. Nimue says half the market is honest; Orion says the Ratborn
  "are not machines … they are hungry".
- Who governs the Cities stays UNKNOWN (open question 7). No line says who rules.
- The Night Weaver's images are shown, never explained (magic or trickery stays open).
- The Cinder King is only mentioned, as someone people fear and pay. His limits stay UNKNOWN.

**World claims, approved (DEC-013; WC-016 to WC-019):**

1. Foundry crates are sold on market stalls in the Cities.
2. In the Cities, light is something you buy (Orion to Seraphine).
3. Seraphine's order calls the Cities godless.
4. The Ratborn are "drain kids, grown up hungry" (Nimue).
5. Night Weavers keep the roofs.
6. The roofs are the only road no one charges for.
7. Dawnfaith sanctuary bread is resold on the docks at three times its cost.
8. Every crate on the Cinder Docks pays the Cinder King "once in coin, once in fear" (Nimue's view).
9. Someone in the Cities sold Nimue's runners to the line (Nimue's belief).
10. Chapter-end line: "The Cinder King is beaten. His ledgers are not finished."
11. The Cinder King keeps a vault behind the docks, with ledgers of his trades.
12. He says the Dawnfaith's sanctuaries sell him their bread (to Seraphine), and that Nimue runs "my roads" without
    paying the toll. This claims his reach over the routes, not that he governs (open question 7 stays open).
13. Asked about her runners, he says they went "where every debt goes. Paid." Their fate stays deliberately unclear.
14. His ledgers carry Foundry, Dawnfaith and city seals: all three sold to him (Caelen). Nimue finds her runners'
    names and where he sent them.
15. Orion: "someone was always buying from the other side". It doesn't say who.
16. His line "Everything has a price. Even light. Especially light." (not from the concept art).
