# game-3

A cozy incremental work-and-friendship simulator, Chiikawa-inspired. Roblox experience managed with [Rojo](https://rojo.space/).

## Controls

| Input | Action |
|---|---|
| `W A S D` / stick | Walk |
| `Shift` / `L3` | Sprint — the world is 27,000 studs long, and running **raises Grit** |
| `Space` | Jump — also raises Grit |
| **Click `LMB`** / `R2` / Work button | Work. **One click is one gain**, anywhere |
| `1`–`4` / click a skill button | Pick which skill you train off a pad — the round buttons along the bottom, numbered to match the keys |
| `E` | Talk to a character when the prompt appears |
| `M` / minimap button | Minimap — hidden by default, summoned when you need it |
| `N` / `Select` / Atlas button | Atlas — map, the whole skill ladder, fast travel |
| `H` / `F1` / `?` button | Field Guide — controls, mechanics, progression, first 30 minutes |

The Field Guide opens by itself on a player's first session. It is split into six responsive,
device-aware chapters and can be reopened at any time. Closing it begins a hands-on control lesson:
move, sprint, jump, then perform one work action. Each prompt advances only after the game detects
the real action; completing or deliberately skipping the lesson saves onboarding as finished.

**A worksite pad is a multiplier, not a gate.** You can train anywhere: clicking on open ground
raises whichever skill you have selected, at base rate. A pad raises its own skill at ×2 up to
×5000 — so a district is worth walking to for the same reason it always was, without the game ever
refusing a click. Standing on a pad you have *not* unlocked trains that pad's skill at base rate, so
arriving somewhere early is never wasted. **Idling still only earns on a pad**, except Exam Prep:
reading never advances while idle and requires a page flip for every point award.

Running and jumping raise **Grit** — §4 defines it as endurance, and crossing this world is exactly
that. It is a trickle next to clicking, so travel is productive rather than optimal.

The bottom-centre **work core** is one control with three states: on a pad it shows what you are
working, its multiplier and what a click is worth; on a locked pad it shows what that pad wants while
still crediting you; on open ground it shows the skill you are training and points at the nearest
better pad. The health ring wraps all three, so how close you are to going down is never somewhere
else on the screen from the thing that is putting you there.

Holding the mouse button does nothing after the first click. That is deliberate — see the §17
deviations table in `docs/GAME.md`, which records both the original move to hold-to-work and its
reversal.

## Exam Prep and Kusatori Grade 5

Pressing skill 4 opens a full-screen book. Exam Prep cannot be earned from the regular Work action or
from passive pad ticks; every gain comes from clicking the book to flip one page. Each page has a base
value of 2 Exam Prep. Standing anywhere on the Exam Prep district's Study Deck doubles that to 4; an
occupied study pad uses its own configured multiplier instead, so the deck bonus never double-stacks
with pad tiers. Every accepted flip has a 10% chance to reveal a
procedural plant fact, followed shortly by a three-image recall question. Correct answers add 20%
Readiness; missed answers add 8% because reviewing a mistake is still learning. Nothing is lost.

A correct recall also has a 15% chance to grant **Focus**: 2x Exam Prep points from page flips for
the next 30 seconds. Winning Focus again refreshes its duration. It does not affect other skills.

At 100% Readiness and 100 Kusatori, the pink bookmark offers the five-question Kusatori Grade 5
exam. Four answers pass. A failed attempt preserves Readiness and asks for two correct review cards
before the next attempt. Passing awards Kusatori certification order 1, which already feeds the
shared gain and wage formulas (2x Kusatori gain and +50% base wage multiplier).

Practice companions have small story moments rather than stat multipliers: Hachiware crosses out a
distractor, while Usagi sometimes blurts out the answer. Exam questions never provide companion
hints. The server owns questions, answers, readiness, attempts and the certification award; clients
send only page, choice and sit-exam intent.

## Structure

```
src/
├── server/                  -> ServerScriptService.Server
│   └── Services/
│       ├── DataService        profile load/save, reconcile, migration
│       ├── AssetService       uploaded decor models: load once, clone, fall back
│       ├── TerrainBuilder     chunked, progressive terrain + land bridges
│       ├── WorldService       plazas, fences, gates, collision groups, lighting, void catch
│       ├── SafeZoneService    the cottage; the spawn; what "safe" MEANS
│       ├── NpcService         procedural mascot characters, dialogue prompts
│       ├── CompanionService   the follower that trails you + the friend stand (E)
│       ├── AssetProbeService  measures a model template in-world (off by default)
│       ├── WorksiteService    lays six skill districts per area; occupancy + validation
│       ├── SkillService       the only writer of profile.skills
│       ├── CurrencyService    the only writer of Yen/Stamps
│       ├── WorkService        work actions: rate limit, validate, credit
│       ├── StudyService       field notes, recall, Grade 5 exam, certification
│       ├── RegionService      area unlock, gate access groups, fast travel
│       ├── TrainingService    movement raises Grit; rejects spoofed distance
│       ├── ReplicationService server -> client state snapshots
│       └── NotifyService      toast copy
├── client/                  -> StarterPlayer.StarterPlayerScripts.Client
│   ├── Controllers/
│   │   ├── StateController      snapshot mirror
│   │   ├── MovementController   walk + sprint
│   │   ├── WorkController       click input; local click signal
│   │   ├── GuideController      "which pad should I walk to" — headless
│   │   ├── FeedbackController   what a click LOOKS like
│   │   ├── GestureController    per-skill arm animation, procedural
│   │   ├── SoundController      per-skill sound; ids live in Config/Feedback
│   │   └── WorldController      area title cards, gate veils
│   └── UI/
│       ├── HUD                identity block, side rail, toasts; hosts the rest
│       ├── SkillBar           bottom-centre round skill buttons, numbered 1-4
│       ├── WorkCore           above the bar: health ring + what/where
│       ├── StudySession       open-book field notes, recall and exam UI
│       ├── Minimap            local view + world strip, drawn from Layout
│       ├── Atlas              full-screen map, ladder grid, guide (N)
│       ├── ControlsPanel      responsive, paginated first-run Field Guide
│       ├── ControlTutorial    move/run/jump/work practice prompts
│       ├── TutorialContent    player-facing mechanics + first-30-minute route
│       └── CompanionMenu      the friend picker, opened from the stand
└── shared/                  -> ReplicatedStorage.Shared
    ├── Areas/                 ONE FILE PER AREA — see below
    │   ├── Area               shared base: types, validation, decor helpers
    │   ├── init               registry; explicit ORDER, bridge chain validated on load
    │   └── Town, Woods, Riverside, Mountain, Island, Ruins
    ├── UI/                    SHARED COMPONENT LIBRARY — client and server
    │   ├── Theme              design tokens (colour, font, radius, spacing)
    │   ├── Motion             named easing presets + reduced-motion
    │   ├── Glyphs             icons drawn as geometry — no image assets
    │   ├── Primitives         corner, stroke, padding, gradient, shadow, ring, vignette
    │   ├── Components         card, label, bar, chip, button, sign, ticker, pips, tabs, modal
    │   └── init               the barrel: `require(Shared.UI)`
    ├── Modules/
    │   ├── BigNumber          mantissa/exponent numbers (§12)
    │   ├── Mascot             the part-built mascot silhouette — NPCs and companions
    │   ├── Formulas           every derived number, pure functions
    │   ├── Constants          all tunables
    │   ├── RateLimiter        token bucket
    │   ├── Remotes            remote tree
    │   └── Config/            Skills, Worksites, Certifications, Npcs, SafeZone, Layout, Feedback, Assets
    └── Types/
```

## Where things are: `Config/Layout.lua`

**Every world position in the game comes from one pure module.** `Layout` takes the area and worksite
config and returns CFrames: the plaza, the six district plates, every pad, the land bridges, the map
bounds. It touches no Instance, reads no Workspace and never yields.

That is load-bearing rather than tidy. The world runs with `StreamingEnabled`, so most of it does not
exist on the client at any moment — a minimap or a guide arrow built by scanning Workspace would be
blind to everything worth walking to. Because the server *builds* from `Layout` and the client
*draws* from it, there is no second description of where anything is that could drift.

If you move a district, retune an area's size, or add a tier, change it there and both realms follow.

## Adding an area

Each area is one self-contained file in `src/shared/Areas/`. Copy an existing one, then add its
module name to `ORDER` in `Areas/init.lua` — that list is explicit because it is the player-facing
Travel order, and `GetChildren()` order is not guaranteed.

```lua
local Area = require(script.Parent.Area)

return Area.define({
    id = 7,
    key = "harbour",
    name = "The Harbour",
    flavour = "Cold water and colder mornings.",
    gate = { skillTotal = { m = 5, e = 9 }, certificationTotal = 22 },
    -- Areas sit edge to edge along +X. Leave BRIDGE_GAP studs of clear space
    -- between this area's western edge and its neighbour's eastern one.
    origin = Vector3.new(29800, 0, 0),
    terrain = { material = "Sand", islandSize = 6600 },
    -- Omit on the LAST area: its eastern edge is outer perimeter, not a gate.
    -- The one before it must add `bridgeTo = "harbour"` or nothing connects.
    bridgeTo = nil,
    palette = { ground = ..., prop = ..., sky = ... },

    decorate = function(ctx)
        ctx.helpers.signpost(ctx, { title = "Harbour", subtitle = "mind the gap", x = 0, z = 40 })
        ctx.helpers.scatter(ctx, 60, function(x, z)
            ctx.helpers.tree(ctx, x, z, 12, 10)
        end)
    end,
})
```

`Areas/init.lua` validates the bridge chain at load: a `bridgeTo` naming a missing area, pointing
west, or leaving overlapping footprints fails loudly rather than producing a hole in the ground
somewhere in the middle of a 27,000-stud world.

`Area.define` validates the table at load, so a typo fails loudly instead of producing an invisible
area three services later. `decorate` runs inside a `pcall` — one broken area file cannot take the
whole world down.

**`ctx` gives you:** `origin`, `parent`, a per-area seeded `rng` (so every server looks identical),
`helpers` (`block`, `tree`, `bush`, `log`, `stone`, `hut`, `signpost`, `scatter`,
`cluster`, `ring`),
`isReserved(x, z)`, and **`UI`** — the shared component library, so area signage is built from the
same components as the HUD:

```lua
ctx.UI.sign(post, { title = "Ramen", subtitle = "hot bowls" })
```

Helper `y` is measured from the **terrain surface**, not world origin, so area files never touch
`TERRAIN_TOP` and cannot repeat the "everything is buried underground" bug.

`isReserved` is the ground `Layout` has claimed — the plaza, the six districts, and the road between
the land bridges. `scatter` and `cluster` already honour it, so a tree can never grow through a
worksite. It arrives as a closure rather than as a zone list so `Areas` never has to require
`Layout` (which requires `Areas`) and the module graph stays a tree.

An area does **not** own which worksite tiers live in it — that stays in `Config/Worksites.lua` so
the skill ladder is defined once and cannot drift across six files. Nor does it own *where* they
sit; that is `Config/Layout.lua`.

## Adding models

Every model is served from this repo. Nothing is fetched from the marketplace at
runtime — there is no `InsertService` call anywhere in the codebase.

`src/shared/Modules/Config/Assets.lua` maps an asset key to a `.rbxmx` under
`assets/Models/`. `AssetService` clones each template once at boot, strips
scripts, anchors every part and keeps it in `ServerStorage`; area decor then
clones from there.

```lua
sakuraTree = { template = "SakuraTree", scale = 1, canopy = true },
```

`template` is the file name under `assets/Models/` without the extension. A key
with no matching file warns at boot and the procedural version takes over.

`tree`, `grass`, `stone`, `log`, `bush` and `house` have no entry at all, so
those helpers always build from parts. Drop a `.rbxmx` in and add the key to
switch them over.

## Adding sounds

`src/shared/Modules/Config/Feedback.lua` gives every skill a gesture and a sound. The gestures are
already there — they are keyframed joint rotations, so they need no uploaded assets. **The sound ids
are deliberately blank**, because audio is the one asset that cannot be synthesised in-engine and a
guessed id is either silence or somebody else's audio playing in your game.

To add one, find a sound in the Creator Marketplace and paste its id:

```lua
weeding = {
    gesture = { ... },
    sound = { id = "rbxassetid://1234567890", volume = 0.4, pitchMin = 0.93, pitchMax = 1.07 },
},
```

A blank id plays nothing. `SoundController` warns once at startup naming every skill still silent, so
this is discoverable rather than mysterious. Pitch is randomised per click so six clicks a second do
not machine-gun one identical waveform.

The same file holds the gestures. If one reads wrong on your rig, fix the numbers there — never the
controller. Pitch carries every gesture on purpose, since R6 and R15 orient the shoulder joint
differently and yaw/roll do not read identically across both.

## Setup

1. Install [Aftman](https://github.com/LPGhatguy/aftman), then from this directory:
   ```
   aftman install
   ```
   This pulls Rojo, Wally, Selene, and StyLua pinned in `aftman.toml`.
2. Install dependencies:
   ```
   wally install
   ```
   **Do this before any public test.** Without `Packages/ProfileService`, DataService falls back to an
   unlocked DataStore — fine for solo Studio testing, unsafe in production (two servers holding the
   same player can duplicate currency). The fallback warns loudly at startup.
3. Start the Rojo server:
   ```
   rojo serve
   ```
4. In Roblox Studio, install the Rojo plugin and click **Connect**, then press Play.

### Or just reload

For a build-and-restart cycle without live sync, `tools/rojo.exe` is bundled — no setup needed:

```
./reload.sh              # Git Bash
.\reload.ps1             # PowerShell
```

Builds `Chiikawa Fighting Simulator.rbxl`, regenerates `sourcemap.json`, runs `selene`, then restarts Studio on the new
build. Flags: `--no-open` / `-NoOpen` to build without touching Studio, `--check` / `-Check` to also
run [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp/releases) type analysis and stop there. Both
warn when `Packages/` is missing, since that silently downgrades data safety.

Each tool is taken from `PATH` if present and from `tools/` otherwise, so the gate runs the same
whether or not the machine has been through `aftman install`. `tools/globalTypes.d.luau` is the
Roblox API definitions file — **without it, `luau-lsp` treats `Instance`, `Enum` and `Color3` as
unknown globals and buries any real error under a couple of thousand fake ones.** The analyzer does
not download it; refresh it from
[the luau-lsp repo](https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.d.luau)
when Roblox ships new API.

### Saving

DataStores need a **published place** *and* **Game Settings → Security → Enable Studio Access to API
Services**. Without either, `DataStoreService` throws, and DataService drops to an **in-memory
backend**: the game is fully playable, but nothing is saved and every player is told so on join.
The server log states which backend is active at startup.

There is nothing to place by hand in Studio. The world — terrain, land bridges, gates, plazas, every
worksite pad and label, and the cottage you spawn in — is generated at runtime from
`src/shared/Modules/Config` and `src/shared/Areas`.

**World generation is progressive.** Town is filled synchronously at boot; the other five areas and
the land bridges arrive on a background task that yields every few terrain tiles. The server log
prints both timings. If the far end of the world is missing, check that line before assuming a bug —
nothing east of Town is reachable in the seconds it takes, since it is gated behind a skill total
nobody has on their first frame.

## Conventions

- **Server is authoritative for all game state.** See `.claude/skills/roblox-engineer` and `docs/GAME.md` §13.
  The client sends intent, never numbers. `Work.Perform` deliberately carries no arguments.
- **Config-as-data (§15).** Adding a worksite tier, skill, or region is a table row in
  `src/shared/Modules/Config/` — never a new script. The greybox world follows automatically.
- **Positions come from `Config/Layout`, not from Workspace.** The world streams, so the client
  cannot assume any distant Instance exists. Anything that needs to know where something *is* asks
  the same pure function the server built it with.
- **The safe zone is a rule, not decoration.** `SafeZoneService.isProtected(player)` is the single
  predicate; when combat lands in Slice 5, it calls that before resolving anything. The ForceField
  and the health guard are backstops for code that forgets.
- **Anything that might not exist on a given Roblox build is guarded and deferred.** Assigning to a
  property that is absent is a hard error, not a no-op, and a service that throws during `init` takes
  everything downstream with it. `Workspace.StreamingIntegrityMode` and the post-2022 collision-group
  API are both optional here: they are `pcall`ed, they set a flag, and world generation does not
  depend on either. Gates **fail open** when collision groups are unavailable — the region check in
  `WorksiteService.canUse` still refuses to pay out, so the cost is cosmetic, whereas failing closed
  would be an impassable wall.
- **Every quantity that can grow is a BigNumber**, not a Lua number. Doubles lose precision past
  ~9e15 and the multiplier stack passes that easily.
- **Tone charter (§2) is binding on code, not just art.** No death state, no item loss, no
  durability, no punishment copy. If a feature needs an exception, it is the wrong feature.
- Shared code must be safe to expose to the client — no secrets, no privileged logic.
- Run `selene src` and `stylua src` before committing.
