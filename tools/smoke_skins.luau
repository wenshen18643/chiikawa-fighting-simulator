local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Modules.Config.Assets)
local CompanionSkins = require(Shared.Modules.Config.CompanionSkins)
local Skeleton = require(Shared.Modules.Anim.Skeleton)
local SkinLook = require(Shared.Modules.SkinLook)
local SkinLooks = require(Shared.Modules.Config.SkinLooks)

local FOLDER_NAME = "SkinLineup"
local COLUMN_SPACING = 8
local ROW_SPACING = 14
local TARGET_HEIGHT = 4
local ORIGIN = Vector3.new(0, 6, 0)

local EXPECTED_TOTAL = 45
local EXPECTED_PER_RARITY = 9
local LEGACY_IDS = {
	"chiikawa_common_01",
	"chiikawa_uncommon_01",
	"chiikawa_rare_01",
	"chiikawa_epic_01",
	"chiikawa_legendary_01",
	"hachiware_common_01",
	"hachiware_uncommon_01",
	"hachiware_rare_01",
	"hachiware_epic_01",
	"hachiware_legendary_01",
	"usagi_common_01",
	"usagi_uncommon_01",
	"usagi_rare_01",
	"usagi_epic_01",
	"usagi_legendary_01",
}

local failures = {}

local function check(condition: boolean, message: string)
	if not condition then
		table.insert(failures, message)
	end
end

local function normalise(model: Model)
	local size = model:GetExtentsSize()
	local largest = math.max(size.X, size.Y, size.Z)
	if largest > 0.01 then
		model:ScaleTo(TARGET_HEIGHT / largest)
	end
end

local function label(model: Model, anchor: BasePart, skin, rarity)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SkinLabel"
	gui.Size = UDim2.fromScale(9, 2.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, TARGET_HEIGHT * 0.85, 0)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.Text = `{skin.name}\n{string.upper(rarity.name)}{if skin.showcase then "  (showcase)" else ""}`
	text.TextColor3 = rarity.color
	text.TextScaled = true
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.TextStrokeTransparency = 0.4
	text.Parent = gui
	model:SetAttribute("SkinId", skin.id)
end

local function build(skin, position: Vector3): Model?
	local spec = (Assets.MODELS :: any)[skin.characterId]
	local models = ReplicatedStorage:FindFirstChild("Assets")
	models = if models then models:FindFirstChild("Models") else nil
	local template = if models and spec then models:FindFirstChild(spec.template) else nil
	if not template or not template:IsA("Model") then
		table.insert(failures, `{skin.id}: no base model for "{skin.characterId}"`)
		return nil
	end

	local wasArchivable = template.Archivable
	template.Archivable = true
	local model = template:Clone()
	template.Archivable = wasArchivable
	model.Name = skin.id

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Humanoid") or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end

	local root = Skeleton.prepare(model, skin.characterId)
	if not root then
		table.insert(failures, `{skin.id}: Skeleton.prepare returned no root`)
		model:Destroy()
		return nil
	end

	local look = SkinLooks.get(skin.id)
	check(look ~= nil, `{skin.id}: has no authored look`)

	local zones = SkinLook.zones(model, skin.characterId)
	if look and look.palette then
		for zone in look.palette do
			check(zones[zone] ~= nil, `{skin.id}: palette names zone "{zone}", which this character has no parts for`)
		end
	end

	local created = SkinLook.apply(model, skin.characterId, look)
	local rarity = CompanionSkins.RARITIES[skin.rarity]
	if rarity.order >= 2 then
		check(#created > 0, `{skin.id}: {rarity.name} produced no decoration parts`)
	end
	if look and look.parts then
		local wanted = 0
		for _, spec2 in look.parts do
			wanted += if spec2.orbit then math.max(1, spec2.orbit.count) else 1
		end
		check(#created == wanted, `{skin.id}: expected {wanted} decoration parts, built {#created}`)
	end

	normalise(model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	model:PivotTo(CFrame.new(position))
	label(model, root, skin, rarity)
	return model
end

local existing = Workspace:FindFirstChild(FOLDER_NAME)
if existing then
	existing:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = FOLDER_NAME
folder.Parent = Workspace

check(#CompanionSkins.SKINS == EXPECTED_TOTAL, `expected {EXPECTED_TOTAL} skins, found {#CompanionSkins.SKINS}`)
for _, id in LEGACY_IDS do
	check(CompanionSkins.get(id) ~= nil, `legacy id "{id}" is gone - this wipes owned copies on load`)
end

local perRarity = {}
local showcase = 0
for _, skin in CompanionSkins.SKINS do
	perRarity[skin.rarity] = (perRarity[skin.rarity] or 0) + 1
	if skin.showcase then
		showcase += 1
	end
end
for _, rarityId in CompanionSkins.RARITY_ORDER do
	check(
		perRarity[rarityId] == EXPECTED_PER_RARITY,
		`{rarityId}: expected {EXPECTED_PER_RARITY} looks, found {perRarity[rarityId] or 0}`
	)
	check(CompanionSkins.poolSize(rarityId) > 0, `{rarityId}: drop pool is empty`)
end

local built = 0
for rowIndex, characterId in CompanionSkins.CHARACTER_ORDER do
	local column = 0
	for _, rarityId in CompanionSkins.RARITY_ORDER do
		for _, skin in CompanionSkins.SKINS do
			if skin.characterId ~= characterId or skin.rarity ~= rarityId then
				continue
			end
			local position = ORIGIN + Vector3.new(column * COLUMN_SPACING, 0, (rowIndex - 1) * ROW_SPACING)
			local model = build(skin, position)
			if model then
				model.Parent = folder
				built += 1
			end
			column += 1
		end
	end
end

print(`[smoke_skins] built {built} / {#CompanionSkins.SKINS} looks into Workspace.{FOLDER_NAME}`)
print(`[smoke_skins] {showcase} showcase looks are excluded from the drop pool`)
for _, rarityId in CompanionSkins.RARITY_ORDER do
	print(`[smoke_skins]   {rarityId}: {perRarity[rarityId]} total, {CompanionSkins.poolSize(rarityId)} droppable`)
end

if #failures == 0 then
	print("[smoke_skins] PASS")
else
	warn(`[smoke_skins] FAIL - {#failures} issue(s):`)
	for _, message in failures do
		warn(`  {message}`)
	end
end
