# Battle Simulation Core Implementation Plan

> **Superseded on 2026-11-15.** The game pivoted to an action RPG (see `docs/superpowers/specs/2026-11-15-the-last-light-action-rpg-design.md`). This plan was completed and merged; its code is kept but unused by the new game.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic, unit-tested pure-Swift battle simulator for The Last Light. It covers formation, targeting, auto-attacks, charge and abilities, adjacency bonds and evolution stages, plus a balance CLI that flags dominant units.

**Architecture:** A SwiftPM package `LastLightCore` with no SpriteKit and no networking. `BattleSimulator.run(_:)` is a pure function from `BattleSetup` to `BattleResult`, where the result is the outcome plus a timestamped event log. The SpriteKit layer (a later plan) only plays back events. Ticks run at 30 per second, and actions due on the same tick resolve simultaneously against the tick-start state, so ties are fair and there's no hidden ordering bias.

**Tech Stack:** Swift 6.2 (strict concurrency), SwiftPM, Swift Testing (`import Testing`), Xcode 26.2. Tests run on macOS with `swift test`; no simulator is needed.

**Spec:** `docs/superpowers/specs/2026-10-22-the-last-light-slice-design.md` (§6.3–6.5 and §10)

**Where this sits.** Milestone 1 (spec §11) spans several subsystems, so it gets several plans. This one is step 2. The rest follow in order, each with its own plan: (a) the cast and world sheet, which is creative work with an owner gate and runs in parallel with this plan; (b) the iOS app shell and style-B battle rendering of one character against one machine, including the 60 fps proof; (c) the run loop; (d) Chapter 1 content; (e) story beats, the reaction-line system and the portrait pilot; (f) onboarding, saves, sound, opt-in PostHog and TestFlight. Test fixtures here use placeholder units. Real cast data arrives with plan (d).

## Global Constraints

- Deployment floor: **iOS 18**, plus macOS 15 for the test host. Swift language mode 6.
- `LastLightCore` must not import SpriteKit, UIKit, SwiftUI or any networking API. It is Foundation only.
- The battle simulation is deterministic: the same `BattleSetup` always produces an identical `BattleResult`.
- Formation: 2 columns (front, back) × 3 rows. **Player cap 5 units**, enemy cap 6.
- Bonds link exactly two specific characters, and **apply only when both are present and orthogonally adjacent**.
- Evolution: **3 stages** per character.
- No paid third-party services and no new dependencies. The package has zero external packages.

## Review Focus

1. **Both sides die on the same tick.** The result must be `.draw`, not a win for whichever side was processed first. Tested in Task 6.
2. **An empty formation on either side.** The battle ends at tick 0 with a defined outcome and no crash. Tested in Task 6.
3. **A stalemate (damage too low to ever finish).** It must end at the tick cap as `.timedOut` and must not hang the balance runner. Tested in Task 6.
4. **Healing or shields beyond the limits.** HP never exceeds max HP, and a shield absorbs before HP drops. Tested in Task 7.
5. **The same character placed twice, or a sixth player unit.** These are rejected when the formation is built, not discovered mid-battle. Tested in Task 3.

---

### Task 1: Package scaffold, git and seeded RNG

**Files:**
- Create: `.gitignore`
- Create: `LastLightCore/Package.swift`
- Create: `LastLightCore/Sources/LastLightCore/Random/SeededRandom.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/SeededRandomTests.swift`

**Interfaces:**
- Produces: `public struct SeededRandom: RandomNumberGenerator, Sendable { public init(seed: UInt64); public mutating func next() -> UInt64 }` (SplitMix64).

- [ ] **Step 1: Initialize the repo**

Run `git init` at the project root. `.gitignore` contains: `.superpowers/`, `.build/`, `DerivedData/`, `*.xcuserstate`, `xcuserdata/`, `.DS_Store`.

- [ ] **Step 2: Write `Package.swift`**

swift-tools-version 6.0; platforms `.iOS(.v18)` and `.macOS(.v15)`; library product `LastLightCore`; executable target `lastlight-sim` that depends on `LastLightCore` (an empty `main.swift` for now, filled in Task 9); test target `LastLightCoreTests`.

- [ ] **Step 3: Write the failing test**

```swift
import Testing
@testable import LastLightCore

@Test func sameSeedSameSequence() {
    var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
    #expect((0..<100).map { _ in a.next() } == (0..<100).map { _ in b.next() })
}

@Test func differentSeedsDiffer() {
    var a = SeededRandom(seed: 1), b = SeededRandom(seed: 2)
    #expect(a.next() != b.next())
}

@Test func knownFirstValue() {
    var r = SeededRandom(seed: 0)
    #expect(r.next() == 0xE220A8397B1DCDAF) // SplitMix64 reference output for seed 0
}
```

- [ ] **Step 4: Run `cd LastLightCore && swift test`.** Expected: FAIL, "cannot find 'SeededRandom'".
- [ ] **Step 5: Implement SplitMix64** (state `&+= 0x9E3779B97F4A7C15`, then the standard xor-shift-multiply mix).
- [ ] **Step 6: Run `swift test`.** Expected: 3 tests pass.
- [ ] **Step 7: Commit**: `git add -A && git commit -m "chore: scaffold LastLightCore package with seeded RNG"`

---

### Task 2: Units, stages and abilities (the data model)

**Files:**
- Create: `LastLightCore/Sources/LastLightCore/Units/UnitDefinition.swift`
- Create: `LastLightCore/Sources/LastLightCore/Units/Ability.swift`
- Create: `LastLightCore/Tests/LastLightCoreTests/Fixtures.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/UnitDefinitionTests.swift`

**Interfaces:**
- Produces:
  - `public typealias UnitID = String`
  - `public enum Region: String, Sendable, CaseIterable { case foundry, dawnfaith, lanternCities, machine }`
  - `public enum Stage: Int, Sendable, CaseIterable, Comparable { case one = 1, two, three }`
  - `public struct UnitStats: Sendable, Equatable { public var maxHP: Int; public var attack: Int; public var armor: Int; public var attackInterval: Int /* ticks, > 0 */; public var chargeMax: Int /* > 0 */; public var chargePerAttack: Int; public var chargePerHitTaken: Int }`
  - `public enum TargetSelector: Sendable, Equatable { case basicTarget, backlineFirst, lowestHPAlly, selfOnly, allEnemies, enemyFrontColumn }`
  - `public enum AbilityEffect: Sendable, Equatable { case damage(multiplier: Double), heal(amount: Int), shield(amount: Int) }`
  - `public struct Ability: Sendable, Equatable { public let id: String; public let target: TargetSelector; public let effect: AbilityEffect }`
  - `public struct StageData: Sendable, Equatable { public let stats: UnitStats; public let ability: Ability }`
  - `public struct UnitDefinition: Sendable { public let id: UnitID; public let name: String; public let region: Region; public init(id:name:region:stages:) throws(UnitDefinitionError); public func data(for stage: Stage) -> StageData }`. `stages` is `[StageData]` with exactly 3 entries.
  - `public enum UnitDefinitionError: Error, Equatable { case wrongStageCount(Int), invalidStats(stage: Int, reason: String) }`
  - `public struct UnitInstance: Sendable { public let definition: UnitDefinition; public let stage: Stage; public var id: UnitID { definition.id } }`

- [ ] **Step 1: Write the failing tests**

```swift
@Test func requiresExactlyThreeStages() {
    #expect(throws: UnitDefinitionError.wrongStageCount(2)) {
        try UnitDefinition(id: "x", name: "X", region: .foundry, stages: [.dummy, .dummy])
    }
}

@Test func rejectsZeroAttackInterval() {
    var bad = StageData.dummy.stats; bad.attackInterval = 0
    #expect(throws: UnitDefinitionError.invalidStats(stage: 1, reason: "attackInterval must be > 0")) {
        try UnitDefinition(id: "x", name: "X", region: .foundry,
                           stages: [StageData(stats: bad, ability: StageData.dummy.ability), .dummy, .dummy])
    }
}

@Test func stageLookup() throws {
    let def = try UnitDefinition.dummy(id: "x", hp: [100, 150, 220])
    #expect(def.data(for: .three).stats.maxHP == 220)
}
```

Also validate `chargeMax > 0` (reason `"chargeMax must be > 0"`) and `maxHP > 0` (reason `"maxHP must be > 0"`).

`Fixtures.swift` provides `StageData.dummy` (hp 100, atk 10, armor 0, interval 30, chargeMax 100, perAttack 10, perHit 0, ability `.damage(multiplier: 2)` on `.basicTarget`). It also provides `UnitDefinition.dummy(id:hp:attack:armor:interval:chargeMax:chargePerAttack:chargePerHitTaken:ability:region:)`, with a default for every parameter and `hp` either an `Int` (the same for all stages) or `[Int]`, plus `UnitInstance.fixture(_:stage:)`. Fixture helpers may `try!` because they are test-only.

- [ ] **Step 2: Run `swift test --filter UnitDefinitionTests`.** Expected: FAIL.
- [ ] **Step 3: Implement** the types above. Validate in the throwing init.
- [ ] **Step 4: Run `swift test`.** Expected: all pass, .
- [ ] **Step 5: Commit**: `feat(core): unit definitions with 3 evolution stages and abilities`

---

### Task 3: Slots and formation

**Files:**
- Create: `LastLightCore/Sources/LastLightCore/Formation/Slot.swift`
- Create: `LastLightCore/Sources/LastLightCore/Formation/Formation.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/FormationTests.swift`

**Interfaces:**
- Consumes: `UnitID`, `UnitInstance` from Task 2.
- Produces:
  - `public enum Column: Int, Sendable, CaseIterable { case front = 0, back = 1 }`
  - `public struct Slot: Hashable, Sendable, Comparable { public let column: Column; public let row: Int /* 0...2 */; public init?(column: Column, row: Int); public func isAdjacent(to other: Slot) -> Bool; public static let all: [Slot] }`. Ordering is column, then row.
  - `public enum Side: Sendable, Hashable { case player, enemy }`; `public var cap: Int` (player 5, enemy 6).
  - `public struct Formation: Sendable { public let side: Side; public private(set) var units: [Slot: UnitInstance]; public init(side: Side); public mutating func place(_ unit: UnitInstance, at slot: Slot) throws(FormationError) }`
  - `public enum FormationError: Error, Equatable { case slotOccupied(Slot), full(cap: Int), duplicateCharacter(UnitID) }`. `duplicateCharacter` applies to the player side only. Enemy formations may repeat a definition.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func adjacency() {
    let f0 = Slot(column: .front, row: 0)!, f1 = Slot(column: .front, row: 1)!
    let b0 = Slot(column: .back, row: 0)!, b1 = Slot(column: .back, row: 1)!
    #expect(f0.isAdjacent(to: f1))      // same column, neighbouring rows
    #expect(f0.isAdjacent(to: b0))      // same row, other column
    #expect(!f0.isAdjacent(to: b1))     // diagonal
    #expect(!f0.isAdjacent(to: Slot(column: .front, row: 2)!))
    #expect(!f0.isAdjacent(to: f0))
}

@Test func slotRejectsOutOfRangeRow() { #expect(Slot(column: .front, row: 3) == nil) }

@Test func playerCapIsFive() throws {
    var f = Formation(side: .player)
    for (i, slot) in Slot.all.prefix(5).enumerated() { try f.place(.fixture("u\(i)"), at: slot) }
    #expect(throws: FormationError.full(cap: 5)) { try f.place(.fixture("u5"), at: Slot.all[5]) }
}

@Test func playerRejectsDuplicateCharacter() throws {
    var f = Formation(side: .player)
    try f.place(.fixture("jin"), at: Slot.all[0])
    #expect(throws: FormationError.duplicateCharacter("jin")) { try f.place(.fixture("jin"), at: Slot.all[1]) }
}

@Test func enemyAllowsDuplicatesAndSix() throws {
    var f = Formation(side: .enemy)
    for slot in Slot.all { try f.place(.fixture("drone"), at: slot) }
    #expect(f.units.count == 6)
}

@Test func occupiedSlotRejected() throws {
    var f = Formation(side: .enemy)
    try f.place(.fixture("a"), at: Slot.all[0])
    #expect(throws: FormationError.slotOccupied(Slot.all[0])) { try f.place(.fixture("b"), at: Slot.all[0]) }
}
```

`UnitInstance.fixture(_ id:)` is a test-only helper in `Tests/LastLightCoreTests/Fixtures.swift`. It builds a stage-1 instance of `UnitDefinition.dummy(id:)` (Task 2).

- [ ] **Step 2: Run `swift test --filter FormationTests`.** Expected: FAIL to compile.
- [ ] **Step 3: Implement** `Slot`, `Side`, `Formation` and `FormationError` as specified. Check in this order: occupied, then full, then duplicate.
- [ ] **Step 4: Run `swift test`.** Expected: all pass.
- [ ] **Step 5: Commit**: `git commit -am "feat(core): formation grid with adjacency and caps"` (`git add` the new files first)

---

### Task 4: Bonds and the bond resolver

**Files:**
- Create: `LastLightCore/Sources/LastLightCore/Bonds/Bond.swift`
- Create: `LastLightCore/Sources/LastLightCore/Bonds/BondResolver.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/BondResolverTests.swift`

**Interfaces:**
- Consumes: `Formation`, `Slot.isAdjacent(to:)`, `UnitID`.
- Produces:
  - `public typealias BondID = String`
  - `public struct BondEffect: Sendable, Equatable { public var attackPercent: Int; public var maxHPPercent: Int; public var chargePerAttackBonus: Int }`
  - `public struct Bond: Sendable { public let id: BondID; public let partners: (UnitID, UnitID); public let levels: [BondEffect] /* exactly 3 */ }`. The init throws if `levels.count != 3` or the two partners are the same.
  - `public struct ActiveBond: Sendable, Equatable { public let bondID: BondID; public let level: Int; public let slots: [Slot] /* 2, sorted */; public let effect: BondEffect }`
  - `public enum BondResolver { public static func active(bonds: [Bond], levels: [BondID: Int], in formation: Formation) -> [ActiveBond] }`. A bond is active when it has a level of 1–3 in `levels`, both partners are in the formation, and their slots are adjacent. The result is sorted by `bondID`. Levels outside 1...3 count as inactive.

- [ ] **Step 1: Write the failing tests**, using a bond `"trust"` between `"kai"` and `"vex"` with levels `[+20%, +35%, +50%]` attack:

```swift
@Test func activeWhenAdjacentSameColumn()  // kai front0, vex front1, level 1 → one ActiveBond, effect.attackPercent == 20
@Test func activeWhenAdjacentSameRow()     // kai front0, vex back0 → active
@Test func inactiveWhenDiagonal()          // kai front0, vex back1 → []
@Test func inactiveWhenPartnerMissing()    // only kai → []
@Test func inactiveWhenNotUnlocked()       // levels [:] → []; levels ["trust": 0] → []
@Test func levelSelectsEffect()            // level 3 → attackPercent == 50
@Test func unitCanHoldTwoBonds()           // kai bonded to vex and to "lia"; both adjacent → 2 ActiveBonds, sorted by id
```

Write each as a full `@Test` with `#expect` on the result's count, `bondID`, `level` and `effect` values above.

- [ ] **Step 2: Run `swift test --filter BondResolverTests`.** Expected: FAIL.
- [ ] **Step 3: Implement** `Bond` and `BondResolver.active`.
- [ ] **Step 4: Run `swift test`.** Expected: all pass.
- [ ] **Step 5: Commit**: `feat(core): adjacency bonds and resolver`

---

### Task 5: Combatants and targeting

**Files:**
- Create: `LastLightCore/Sources/LastLightCore/Battle/Combatant.swift`
- Create: `LastLightCore/Sources/LastLightCore/Battle/Targeting.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/TargetingTests.swift`

**Interfaces:**
- Consumes: `Slot`, `Side`, `UnitInstance`, `UnitStats`, `TargetSelector`.
- Produces:
  - `public struct CombatantID: Hashable, Sendable, Comparable { public let side: Side; public let slot: Slot }`. Ordering: player before enemy, then by slot.
  - `struct Combatant: Sendable` (internal) with `id`, `unitID`, `stats: UnitStats` (bonds already applied), `ability`, `hp`, `shield`, `charge`, `cooldown`, `isAlive`.
  - `enum Targeting { static func targets(for selector: TargetSelector, actor: Combatant, allies: [Combatant], enemies: [Combatant]) -> [CombatantID] }`. Only living combatants are considered.

**Rules (decided here; the spec leaves them to the builder):**
- `.basicTarget`: the enemy front column if anyone there is alive, otherwise the back column. Within that column, pick the smallest `|row − actor.row|`, with ties going to the lower row. Returns one target.
- `.backlineFirst`: the same, but it tries the back column first.
- `.enemyFrontColumn`: every living enemy in the column `.basicTarget` would use.
- `.allEnemies`: every living enemy, in `CombatantID` order.
- `.lowestHPAlly`: the living ally (actor included) with the lowest `hp / maxHP`, ties going to the lower `CombatantID`.
- `.selfOnly`: the actor.
- With no valid target, return `[]`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func basicPrefersFrontNearestRowTieLower()   // actor row 1; enemies alive at front0, front2, back1 → [front0]
@Test func basicFallsBackToBackColumn()            // enemy front column all dead; back0, back2 alive; actor row 2 → [back2]
@Test func backlineFirstIgnoresFront()             // front0 and back1 alive, actor row 0 → [back1]
@Test func frontColumnHitsAllInColumn()            // front0, front1, back0 alive → [front0, front1]
@Test func lowestHPAllyIncludesSelf()              // actor at 30/100, ally at 50/100 → [actor]
@Test func noLivingEnemiesGivesEmpty()             // → []
```

Write these with concrete `Combatant` values built by a test helper `Combatant.test(side:slot:hp:maxHP:)` in `Fixtures.swift`.

- [ ] **Step 2: Run, and confirm it fails.** Step 3: **implement.** Step 4: **run `swift test`; all pass.**
- [ ] **Step 5: Commit**: `feat(core): combatants and targeting rules`

---

### Task 6: Battle simulator: auto-attacks, deaths, outcomes

**Files:**
- Create: `LastLightCore/Sources/LastLightCore/Battle/BattleSetup.swift`
- Create: `LastLightCore/Sources/LastLightCore/Battle/BattleEvent.swift`
- Create: `LastLightCore/Sources/LastLightCore/Battle/BattleSimulator.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/BattleSimulatorTests.swift`

**Interfaces:**
- Consumes: `Formation`, `Targeting`, `Combatant`, `CombatantID`.
- Produces:
  - `public struct BattleSetup: Sendable { public let player: Formation; public let enemy: Formation; public let bonds: [Bond]; public let bondLevels: [BondID: Int]; public init(player:enemy:bonds: = [], bondLevels: = [:]) }`. Precondition: `player.side == .player` and `enemy.side == .enemy`.
  - `public enum BattleOutcome: Sendable, Equatable { case playerWon, enemyWon, draw, timedOut }`
  - `public enum BattleEvent: Sendable, Equatable { case bondActivated(tick: Int, bondID: BondID, members: [CombatantID]); case attack(tick: Int, source: CombatantID, target: CombatantID, damage: Int, hpAfter: Int); case abilityCast(tick: Int, source: CombatantID, abilityID: String, targets: [CombatantID]); case damage(tick: Int, source: CombatantID, target: CombatantID, amount: Int, absorbed: Int, hpAfter: Int); case heal(tick: Int, source: CombatantID, target: CombatantID, amount: Int, hpAfter: Int); case shield(tick: Int, source: CombatantID, target: CombatantID, amount: Int); case death(tick: Int, unit: CombatantID); case ended(tick: Int, outcome: BattleOutcome) }`
  - `public struct BattleResult: Sendable, Equatable { public let outcome: BattleOutcome; public let durationTicks: Int; public let events: [BattleEvent]; public let finalHP: [CombatantID: Int] }`
  - `public enum BattleSimulator { public static let ticksPerSecond = 30; public static let maxTicks = 2700 /* 90 s */; public static func run(_ setup: BattleSetup) -> BattleResult }`

**Rules:**
- Each combatant starts with `cooldown = attackInterval` and `charge = 0`. On each tick, decrement every living combatant's cooldown. When it reaches 0, the combatant acts, then resets to `attackInterval`.
- **Simultaneous resolution.** Every combatant that acts on tick *t* picks targets from the state at the *start* of *t*, and effects apply in `CombatantID` order. A combatant killed during *t* still acts on *t*. Deaths are checked once, after all effects on *t* have applied (`hp <= 0`), and `.death` events come out in `CombatantID` order.
- Basic attack damage: `max(1, attack − targetArmor)`. Ability damage: `max(1, Int((Double(attack) * multiplier).rounded()) − targetArmor)`. Damage hits the shield first, and the rest comes off HP.
- End check, after tick 0 setup and after each tick: neither side alive → `.draw`; only the player side alive → `.playerWon`; only the enemy side alive → `.enemyWon`; reaching `maxTicks` with both sides alive → `.timedOut`. An empty formation counts as "not alive" at tick 0.
- `.attack` events carry `hpAfter` with the shield already accounted for. `.ended` is always the final event.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func simpleWinTimeline() throws {
    // P: hp 100 atk 10 interval 30 | E: hp 25 atk 1 interval 30, both armor 0
    let r = BattleSimulator.run(.oneVsOne(player: .dummy(id: "p", hp: 100, attack: 10),
                                          enemy:  .dummy(id: "e", hp: 25, attack: 1)))
    #expect(r.outcome == .playerWon)
    #expect(r.durationTicks == 90)
    #expect(r.events.contains(.death(tick: 90, unit: .enemy(.front0))))
    #expect(r.finalHP[.player(.front0)] == 97)   // enemy also hit on ticks 30, 60, 90
}

@Test func armorFloorsDamageAtOne() // P atk 10 vs E armor 15 → every .attack from P has damage == 1
@Test func simultaneousKillIsDraw()  // both hp 10 atk 10 interval 30 → outcome .draw, durationTicks 30, two .death events at tick 30
@Test func stalemateTimesOut()       // both hp 1000 atk 1 armor 5 → .timedOut, durationTicks 2700
@Test func emptyEnemyIsInstantWin()  // → .playerWon, durationTicks 0, events == [.ended(tick: 0, outcome: .playerWon)]
@Test func bothEmptyIsDraw()         // → .draw at tick 0
@Test func deterministic()           // the same 5v6 setup run twice → results ==
@Test func endedIsLastEvent()
```

`BattleSetup.oneVsOne`, `CombatantID.player(_:)` / `.enemy(_:)` and `Slot.front0` and friends are test helpers in `Fixtures.swift`.

- [ ] **Step 2: Run, and confirm it fails.** Step 3: **implement** (without charge and abilities; set `chargeMax` high in these fixtures so abilities never fire). Step 4: **run `swift test`; all pass.**
- [ ] **Step 5: Commit**: `feat(core): tick-based battle simulator with simultaneous resolution`

---

### Task 7: Charge and abilities

**Files:**
- Modify: `LastLightCore/Sources/LastLightCore/Battle/BattleSimulator.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/AbilityTests.swift`

**Interfaces:**
- Consumes: `Ability`, `AbilityEffect`, `Targeting.targets`.
- Produces: no new public API. It adds `.abilityCast`, `.damage`, `.heal` and `.shield` events.

**Rules:**
- After a basic attack, the actor gains `chargePerAttack`. Each target hit by an attack or damaging ability gains `chargePerHitTaken`.
- When an actor's turn comes up with `charge >= chargeMax`, it casts its ability *instead of* attacking, and charge resets to 0. Casting gives no charge for the cast.
- `.heal` caps HP at `maxHP`, and the event's `amount` is what was actually healed. `.shield` adds to the current shield, uncapped. An ability whose targets come back `[]` still emits `.abilityCast` with `targets: []` and does nothing.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func castsWhenChargeFull() {
    // P atk 10 interval 30 chargeMax 20 perAttack 10, ability .damage(multiplier: 3) on .basicTarget
    // E hp 1000, interval 10_000 (never acts)
    // expect .attack at ticks 30 and 60, .abilityCast at tick 90, then .damage(tick: 90, …, amount: 30, absorbed: 0, hpAfter: 950)
}
@Test func healCapsAtMax()           // ally at 95/100 is healed by 20 → .heal amount 5, hpAfter 100
@Test func shieldAbsorbsFirst()      // target shield 15 takes a 10-damage basic attack → hpAfter unchanged, shield 5; the next 10 → absorbed 5, hp −5
@Test func hitsTakenBuildCharge()    // E perHitTaken 25, chargeMax 50, hit by P at 30 and 60 → E casts on its next turn
@Test func emptyTargetCastIsHarmless()
```

Write each with exact `#expect` values as shown.

- [ ] **Step 2: Run, and confirm it fails.** Step 3: **implement.** Step 4: **run `swift test`; all pass, and all of Task 6's tests still pass.**
- [ ] **Step 5: Commit**: `feat(core): charge and signature abilities`

---

### Task 8: Bonds and stages in battle

**Files:**
- Modify: `LastLightCore/Sources/LastLightCore/Battle/BattleSimulator.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/BattleBondTests.swift`

**Interfaces:**
- Consumes: `BondResolver.active`, `UnitInstance.stage`, `UnitDefinition.data(for:)`.

**Rules:**
- Base stats and ability come from `definition.data(for: instance.stage)`.
- At tick 0, resolve the player's active bonds. For each one, both members get `attack += attack * attackPercent / 100` (integer division), the same for `maxHP` (and they start at the new max HP), and `chargePerAttack += chargePerAttackBonus`. Bonuses from several bonds add up. Emit `.bondActivated(tick: 0, …)` in `bondID` order before any other event. Enemy formations have no bonds.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func adjacentBondBuffsAttack()   // kai atk 10 + "trust" level 3 (+50%) adjacent to vex → kai's .attack damage == 15
@Test func diagonalBondDoesNothing()   // same setup, diagonal → damage == 10, no .bondActivated
@Test func bondEventComesFirst()       // events.first is .bondActivated(tick: 0, bondID: "trust", members: [player front0, player front1])
@Test func stageThreeUsesStageThreeStats() // a stage .three instance with hp [100, 150, 220] → finalHP when untouched == 220
@Test func stackedBondsAdd()           // kai in two active +20% bonds → atk 10 → 14
```

- [ ] **Step 2: Run, and confirm it fails.** Step 3: **implement.** Step 4: **run `swift test`; everything passes.**
- [ ] **Step 5: Commit**: `feat(core): apply bonds and evolution stages in battle`

---

### Task 9: Balance runner and CLI

**Files:**
- Create: `LastLightCore/Sources/LastLightCore/Balance/BalanceRunner.swift`
- Modify: `LastLightCore/Sources/lastlight-sim/main.swift`
- Test: `LastLightCore/Tests/LastLightCoreTests/BalanceRunnerTests.swift`

**Interfaces:**
- Consumes: `BattleSimulator.run`, `SeededRandom`, `Formation`, `Bond`.
- Produces:
  - `public struct BalanceReport: Sendable { public let trials: Int; public let overallWinRate: Double; public let unitWinRates: [UnitID: Double]; public let bondWinRates: [BondID: Double]; public func dominantUnits(margin: Double) -> [UnitID] }`. "Dominant" means the unit's win rate minus `overallWinRate` is greater than `margin`. Results are sorted by how far above the margin the unit is, highest first.
  - `public enum BalanceRunner { public static func run(pool: [UnitDefinition], bonds: [Bond], bondLevel: Int, stage: Stage, enemy: Formation, teamSize: Int, trials: Int, seed: UInt64) -> BalanceReport }`. Each trial draws `teamSize` distinct units from `pool` and places them in random distinct slots, all using `SeededRandom`. It runs the battle and counts a win only on `.playerWon`. A unit's or bond's rate is the win rate of the trials where it was present (for bonds: active).

- [ ] **Step 1: Write the failing tests**

```swift
@Test func flagsOverpoweredUnit() {
    // pool: 7 dummies atk 10 plus "titan" atk 60; enemy is fixed so the average team wins ~50%
    let report = BalanceRunner.run(pool: pool, bonds: [], bondLevel: 1, stage: .one,
                                   enemy: enemy, teamSize: 4, trials: 2000, seed: 7)
    #expect(report.dominantUnits(margin: 0.15) == ["titan"])
}
@Test func sameSeedSameReport()   // two runs with seed 7 → identical unitWinRates
@Test func balancedPoolFlagsNothing() // 8 identical dummies → dominantUnits(margin: 0.15) == []
```

Tune the fixture enemy until `flagsOverpoweredUnit` is meaningful, meaning the average team without the titan wins 30–70% of the time. Record the chosen enemy stats in a comment.

- [ ] **Step 2: Run, and confirm it fails.** Step 3: **implement `BalanceRunner`.**
- [ ] **Step 4: Implement the CLI.** `swift run lastlight-sim --trials N --seed S` runs the runner against the built-in fixture pool (a `SamplePool.swift` in the executable target, to be replaced by real cast data in plan (d)). It prints one line per unit as `unit  winrate  Δ` sorted by Δ, then `DOMINANT: <ids>` or `DOMINANT: none`. The exit code is 0.
- [ ] **Step 5: Run `swift test`** (all pass) **and `swift run lastlight-sim --trials 500 --seed 1`** (it prints the table and finishes in under 10 s).
- [ ] **Step 6: Commit**: `feat(core): balance runner and lastlight-sim CLI`
