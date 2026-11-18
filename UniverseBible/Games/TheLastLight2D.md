# The Last Light: the 2D action-platformer

The first game. Stage-based 2D action-platformer for iPhone, iPad and Mac. The code lives in this repository
(`LastLight/`, `LastLightCore/`); the design is in
`docs/superpowers/specs/2026-11-15-the-last-light-action-rpg-design.md`.

## What it uses from the bible

| Element | Status in the bible | In the game |
|---|---|---|
| The Foundry, its colours, its enemies, The Protocol | WORKING (ART) | Chapter 1 region and boss |
| Caelen, Orion | WORKING (ART); backstory PROPOSED | Lead and companion |
| Seraphine, Nimue as other leads | WORKING (ART); arcs PROPOSED | Chosen at New Game by faction. Each has her own opening (DEC-012). Kits are gameplay, not canon: Seraphine's **Light Listens** heals, Nimue's **Lantern Trick** leaves a decoy |
| The AI's goal | WORKING (WC-010) | Implied: a line where the others never woke |
| The Eclipse Engine | WORKING (ART); details UNKNOWN | Hook at the end of Chapter 1 (DEC-011) |
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
