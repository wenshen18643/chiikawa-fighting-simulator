--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SafeZone = require(Shared.Modules.Config.SafeZone)
local SafeZoneFurniture = {}
local palette = SafeZone.palette

export type Context = {
	piece: (config: { [string]: any }) -> Part,
	toWorld: (x: number, y: number, z: number) -> CFrame,
	surfaceFrame: (azimuth: number, y: number) -> CFrame,
	parent: Instance,
	floorY: number,
	deckY: number,
}

local WOOD = Enum.Material.Wood
local PLANK = Enum.Material.WoodPlanks
local CLOTH = Enum.Material.Fabric
local STONE = Enum.Material.Concrete
local CERAMIC = Enum.Material.SmoothPlastic
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local BOOKS = {
	Color3.fromRGB(226, 128, 132),
	Color3.fromRGB(140, 186, 226),
	Color3.fromRGB(238, 204, 132),
	Color3.fromRGB(154, 202, 148),
	Color3.fromRGB(206, 172, 224),
	Color3.fromRGB(232, 168, 128),
}

local PLUSH = {
	Color3.fromRGB(250, 226, 190),
	Color3.fromRGB(196, 224, 240),
	Color3.fromRGB(246, 196, 202),
	Color3.fromRGB(214, 232, 200),
}

local function put(ctx: Context, base: CFrame, config: { [string]: any }): Part
	local at = config.at :: Vector3?
	local turn = config.turn :: CFrame?
	config.at = nil
	config.turn = nil
	config.parent = ctx.parent
	config.cframe = base * CFrame.new(at or Vector3.zero) * (turn or CFrame.identity)
	return ctx.piece(config)
end

local function post(ctx: Context, base: CFrame, name: string, size: Vector3, at: Vector3, color: Color3): Part
	return put(ctx, base, {
		name = name,
		size = size,
		at = at,
		color = color,
		material = WOOD,
		collide = false,
		castShadow = false,
	})
end

local function pillar(ctx: Context, base: CFrame, config: { [string]: any }): Part
	config.shape = Enum.PartType.Cylinder
	config.turn = config.turn or UPRIGHT
	return put(ctx, base, config)
end

local builders: { [string]: (Context, SafeZone.Furnishing, CFrame) -> () } = {}

function builders.hearth(ctx, row, base)
	local span = row.span or 18
	local pier = 3.4
	local mouth = span / 2 - pier

	put(ctx, base, {
		name = "HearthBreast",
		size = Vector3.new(span, 15, 2.2),
		at = Vector3.new(0, 7.5, -1.1),
		color = palette.stone,
		material = STONE,
	})
	put(ctx, base, {
		name = "HearthBack",
		size = Vector3.new(mouth * 2, 8.4, 0.8),
		at = Vector3.new(0, 4.2, -2.6),
		color = palette.timberDark,
		material = STONE,
	})

	for _, side in { -1, 1 } do
		put(ctx, base, {
			name = "HearthPier",
			size = Vector3.new(pier, 8.4, 5.4),
			at = Vector3.new(side * (span / 2 - pier / 2), 4.2, -3.9),
			color = palette.stone,
			material = STONE,
		})
	end

	put(ctx, base, {
		name = "HearthLintel",
		size = Vector3.new(span, 2.6, 5.4),
		at = Vector3.new(0, 9.7, -3.9),
		color = palette.stone,
		material = STONE,
	})
	put(ctx, base, {
		name = "HearthMantel",
		size = Vector3.new(span + 2.4, 1, 7),
		at = Vector3.new(0, 11.5, -4.1),
		color = palette.timber,
		material = PLANK,
	})
	put(ctx, base, {
		name = "HearthStone",
		size = Vector3.new(span + 1, 0.6, 7.6),
		at = Vector3.new(0, 0.3, -4.6),
		color = palette.stone,
		material = STONE,
	})

	for index = -1, 1 do
		put(ctx, base, {
			name = "HearthLog",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(5.4, 1.5, 1.5),
			at = Vector3.new(index * 1.5, 0.9 + math.abs(index) * 0.8, -4.2 + index * 0.6),
			color = palette.timberDark,
			material = WOOD,
			collide = false,
			castShadow = false,
			turn = CFrame.Angles(0, math.rad(index * 14), 0),
		})
	end

	local fire = put(ctx, base, {
		name = "HearthFire",
		size = Vector3.new(mouth * 1.4, 2.2, 3),
		at = Vector3.new(0, 1.5, -4.2),
		color = palette.honey,
		material = Enum.Material.Neon,
		transparency = 0.4,
		collide = false,
		castShadow = false,
	})

	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Texture = "rbxasset://textures/particles/fire_main.dds"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 214, 152), Color3.fromRGB(248, 152, 118))
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	flame.Rate = 9
	flame.Lifetime = NumberRange.new(0.7, 1.2)
	flame.Speed = NumberRange.new(1.5, 3)
	flame.SpreadAngle = Vector2.new(12, 12)
	flame.LightEmission = 0.8
	flame.Parent = fire

	local glow = Instance.new("PointLight")
	glow.Brightness = 1.6
	glow.Range = 32
	glow.Color = Color3.fromRGB(255, 198, 140)
	glow.Shadows = false
	glow.Parent = fire

	for _, side in { -1, 1 } do
		pillar(ctx, base, {
			name = "MantelJar",
			size = Vector3.new(2.6, 2, 2),
			at = Vector3.new(side * (span / 2 - 2.4), 13, -4.2),
			color = if side < 0 then palette.mint else palette.trim,
			material = CERAMIC,
			collide = false,
			castShadow = false,
		})
	end
end

function builders.counter(ctx, row, base)
	local span = row.span or 26

	put(ctx, base, {
		name = "CounterBody",
		size = Vector3.new(span, 6, 5),
		at = Vector3.new(0, 3, -2.5),
		color = palette.linen,
		material = PLANK,
	})
	put(ctx, base, {
		name = "CounterTop",
		size = Vector3.new(span + 1, 0.8, 5.8),
		at = Vector3.new(0, 6.4, -2.9),
		color = palette.timber,
		material = PLANK,
	})
	put(ctx, base, {
		name = "CounterSplash",
		size = Vector3.new(span, 6, 0.6),
		at = Vector3.new(0, 9.8, -0.3),
		color = palette.mint,
		material = CERAMIC,
		collide = false,
	})
	put(ctx, base, {
		name = "CounterSink",
		size = Vector3.new(6, 0.6, 4),
		at = Vector3.new(span / 4, 6.9, -2.9),
		color = palette.glass,
		material = Enum.Material.Metal,
		collide = false,
		castShadow = false,
	})
	post(ctx, base, "SinkTap", Vector3.new(0.4, 2.4, 0.4), Vector3.new(span / 4, 8, -1.2), palette.glass)

	local doors = math.max(2, math.floor(span / 7))
	local doorWidth = (span - 1) / doors
	for index = 1, doors do
		local x = -span / 2 + doorWidth * (index - 0.5) + 0.5
		post(ctx, base, "CounterDoor", Vector3.new(doorWidth - 0.6, 4.4, 0.4), Vector3.new(x, 3, -5.1), palette.shell)
		put(ctx, base, {
			name = "CounterKnob",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.6, 0.6, 0.6),
			at = Vector3.new(x + doorWidth / 2 - 1, 4.6, -5.3),
			color = palette.trimDeep,
			collide = false,
			castShadow = false,
		})
	end

	put(ctx, base, {
		name = "CounterShelf",
		size = Vector3.new(span - 5, 0.6, 3),
		at = Vector3.new(0, 12.4, -1.5),
		color = palette.timber,
		material = PLANK,
		collide = false,
	})

	for index = -2, 2 do
		pillar(ctx, base, {
			name = "ShelfJar",
			size = Vector3.new(2.4, 1.8, 1.8),
			at = Vector3.new(index * 3.2, 13.9, -1.5),
			color = BOOKS[(index + 3) % #BOOKS + 1],
			material = CERAMIC,
			collide = false,
			castShadow = false,
		})
	end
end

function builders.bookcase(ctx, row, base)
	local span = row.span or 16
	local height = row.y or 14
	local shelves = math.max(2, math.round(height / 3.5))
	local rng = Random.new(row.seed or 7)

	put(ctx, base, {
		name = "CaseBack",
		size = Vector3.new(span, height, 0.6),
		at = Vector3.new(0, height / 2, -0.3),
		color = palette.timberDark,
		material = PLANK,
	})

	for _, side in { -1, 1 } do
		put(ctx, base, {
			name = "CaseSide",
			size = Vector3.new(0.8, height, 5),
			at = Vector3.new(side * (span / 2 - 0.4), height / 2, -2.8),
			color = palette.timber,
			material = PLANK,
		})
	end

	for index = 0, shelves do
		local y = 0.4 + (height - 1) * (index / shelves)
		put(ctx, base, {
			name = "CaseShelf",
			size = Vector3.new(span - 1.6, 0.6, 5),
			at = Vector3.new(0, y, -2.8),
			color = palette.timber,
			material = PLANK,
			castShadow = false,
		})

		if index == shelves then
			continue
		end

		local x = -span / 2 + 1.6
		while x < span / 2 - 2.2 do
			local width = rng:NextNumber(0.7, 1.3)
			local tall = rng:NextNumber(2.4, 3.4)
			put(ctx, base, {
				name = "Book",
				size = Vector3.new(width, tall, 3.4),
				at = Vector3.new(x + width / 2, y + 0.3 + tall / 2, -2.6),
				color = BOOKS[rng:NextInteger(1, #BOOKS)],
				material = CLOTH,
				collide = false,
				castShadow = false,
				turn = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4))),
			})
			x += width + rng:NextNumber(0.08, 0.5)
		end
	end
end

function builders.wardrobe(ctx, row, base)
	local _ = row

	put(ctx, base, {
		name = "WardrobeBody",
		size = Vector3.new(12, 16, 6),
		at = Vector3.new(0, 8, -3),
		color = palette.linen,
		material = PLANK,
	})
	put(ctx, base, {
		name = "WardrobeCornice",
		size = Vector3.new(13.4, 1, 7),
		at = Vector3.new(0, 16.5, -3.2),
		color = palette.timber,
		material = PLANK,
		castShadow = false,
	})

	for _, side in { -1, 1 } do
		post(ctx, base, "WardrobeDoor", Vector3.new(5.4, 13.4, 0.5), Vector3.new(side * 2.9, 8.2, -6.2), palette.shell)
		put(ctx, base, {
			name = "WardrobeKnob",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.7, 0.7, 0.7),
			at = Vector3.new(side * 0.9, 8.2, -6.5),
			color = palette.trimDeep,
			collide = false,
			castShadow = false,
		})
	end

	put(ctx, base, {
		name = "WardrobeBasket",
		size = Vector3.new(5, 2.6, 4),
		at = Vector3.new(0, 17.9, -3.2),
		color = palette.timber,
		material = CLOTH,
		collide = false,
		castShadow = false,
	})
end

function builders.dresser(ctx, row, base)
	local span = row.span or 14

	put(ctx, base, {
		name = "DresserBody",
		size = Vector3.new(span, 6.4, 5),
		at = Vector3.new(0, 3.2, -2.5),
		color = palette.timber,
		material = PLANK,
	})
	put(ctx, base, {
		name = "DresserTop",
		size = Vector3.new(span + 1.2, 0.7, 5.6),
		at = Vector3.new(0, 6.75, -2.8),
		color = palette.timberDark,
		material = PLANK,
	})

	for index = 0, 2 do
		local y = 1.2 + index * 2
		post(ctx, base, "DresserDrawer", Vector3.new(span - 1.6, 1.6, 0.4), Vector3.new(0, y, -5.1), palette.linen)
		put(ctx, base, {
			name = "DresserPull",
			size = Vector3.new(2.4, 0.4, 0.4),
			at = Vector3.new(0, y, -5.4),
			color = palette.trimDeep,
			collide = false,
			castShadow = false,
		})
	end

	pillar(ctx, base, {
		name = "DresserVase",
		size = Vector3.new(3.4, 2.2, 2.2),
		at = Vector3.new(-span / 2 + 3, 8.2, -2.8),
		color = palette.mint,
		material = CERAMIC,
		collide = false,
		castShadow = false,
	})

	for index = 1, 3 do
		put(ctx, base, {
			name = "VaseBloom",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.6, 1.6, 1.6),
			at = Vector3.new(-span / 2 + 3 + (index - 2) * 1.1, 10.4 + (index % 2) * 0.6, -2.8),
			color = palette.trim,
			collide = false,
			castShadow = false,
		})
	end

	local bulb = put(ctx, base, {
		name = "DresserLamp",
		size = Vector3.new(3.4, 3, 3.4),
		at = Vector3.new(span / 2 - 3, 8.7, -2.8),
		color = palette.honey,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})
	post(ctx, base, "LampStem", Vector3.new(0.5, 1.4, 0.5), Vector3.new(span / 2 - 3, 7.5, -2.8), palette.timberDark)

	local light = Instance.new("PointLight")
	light.Brightness = 0.8
	light.Range = 20
	light.Color = Color3.fromRGB(255, 228, 190)
	light.Shadows = false
	light.Parent = bulb
end

function builders.genkan(ctx, row, base)
	local span = row.span or 30

	put(ctx, base, {
		name = "GenkanStep",
		size = Vector3.new(span, 1.2, 9),
		at = Vector3.new(0, 0.6, -4.5),
		color = palette.timber,
		material = PLANK,
	})
	put(ctx, base, {
		name = "GenkanMat",
		size = Vector3.new(12, 0.3, 6),
		at = Vector3.new(0, 1.35, -4.5),
		color = palette.mint,
		material = CLOTH,
		collide = false,
		castShadow = false,
	})

	local rackX = span / 2 - 5
	put(ctx, base, {
		name = "ShoeRack",
		size = Vector3.new(8, 0.6, 4.4),
		at = Vector3.new(rackX, 1.5, -3),
		color = palette.timberDark,
		material = PLANK,
		collide = false,
	})
	put(ctx, base, {
		name = "ShoeRack",
		size = Vector3.new(8, 0.6, 4.4),
		at = Vector3.new(rackX, 4.2, -3),
		color = palette.timberDark,
		material = PLANK,
		collide = false,
	})

	for _, side in { -1, 1 } do
		post(ctx, base, "RackLeg", Vector3.new(0.5, 4.5, 0.5), Vector3.new(rackX + side * 3.6, 2.25, -3), palette.timberDark)
		put(ctx, base, {
			name = "Shoe",
			size = Vector3.new(1.8, 1.1, 3.4),
			at = Vector3.new(rackX + side * 1.6, 2.4, -3),
			color = if side < 0 then palette.trim else palette.glass,
			material = CLOTH,
			collide = false,
			castShadow = false,
		})
		put(ctx, base, {
			name = "Shoe",
			size = Vector3.new(1.8, 1.1, 3.4),
			at = Vector3.new(rackX + side * 1.6, 5.1, -3),
			color = if side < 0 then palette.honey else palette.mint,
			material = CLOTH,
			collide = false,
			castShadow = false,
		})
	end

	local standX = -(span / 2 - 4)
	pillar(ctx, base, {
		name = "UmbrellaStand",
		size = Vector3.new(5, 3.6, 3.6),
		at = Vector3.new(standX, 2.5, -3),
		color = palette.mint,
		material = CERAMIC,
	})

	for index = -1, 1, 2 do
		pillar(ctx, base, {
			name = "Umbrella",
			size = Vector3.new(7, 0.8, 0.8),
			at = Vector3.new(standX + index * 0.7, 6.4, -3 + index * 0.4),
			color = if index < 0 then palette.trimDeep else palette.glass,
			collide = false,
			castShadow = false,
			turn = CFrame.Angles(0, 0, math.rad(index * 7)) * UPRIGHT,
		})
	end
end

function builders.crates(ctx, row, base)
	local _ = row
	local stack = { Vector3.new(0, 2.5, -2.5), Vector3.new(0.6, 7.4, -2.8), Vector3.new(5.6, 2.5, -2.2) }

	for index, at in stack do
		put(ctx, base, {
			name = "Crate",
			size = Vector3.new(5, 5, 5),
			at = at,
			color = palette.timber,
			material = PLANK,
			turn = CFrame.Angles(0, math.rad(index * 9 - 12), 0),
		})
		put(ctx, base, {
			name = "CrateBand",
			size = Vector3.new(5.3, 0.7, 5.3),
			at = at + Vector3.new(0, 1.6, 0),
			color = palette.timberDark,
			material = WOOD,
			collide = false,
			castShadow = false,
			turn = CFrame.Angles(0, math.rad(index * 9 - 12), 0),
		})
	end
end

function builders.planter(ctx, row, base)
	local _ = row

	pillar(ctx, base, {
		name = "PotBody",
		size = Vector3.new(4.2, 5, 5),
		at = Vector3.new(0, 2.1, 0),
		color = palette.trim,
		material = CERAMIC,
	})
	pillar(ctx, base, {
		name = "PotRim",
		size = Vector3.new(0.8, 5.6, 5.6),
		at = Vector3.new(0, 4.3, 0),
		color = palette.trimDeep,
		material = CERAMIC,
		collide = false,
		castShadow = false,
	})
	post(ctx, base, "PotStem", Vector3.new(0.5, 4, 0.5), Vector3.new(0, 6, 0), palette.leaf)

	local leaves = {
		{ at = Vector3.new(0, 8.6, 0), size = 5 },
		{ at = Vector3.new(-2, 7.2, 1.2), size = 3.6 },
		{ at = Vector3.new(2.2, 7.6, -1), size = 3.2 },
	}
	for _, leaf in leaves do
		put(ctx, base, {
			name = "PotLeaf",
			shape = Enum.PartType.Ball,
			size = Vector3.new(leaf.size, leaf.size * 0.8, leaf.size),
			at = leaf.at,
			color = palette.leaf,
			material = Enum.Material.Grass,
			collide = false,
			castShadow = false,
		})
	end
end

function builders.loftRug(ctx, row, base)
	pillar(ctx, base, {
		name = "LoftRug",
		size = Vector3.new(0.2, row.span or 22, row.span or 22),
		at = Vector3.new(0, 0.2, 0),
		color = palette.trim,
		material = CLOTH,
		collide = false,
		castShadow = false,
	})
end

function builders.sideTable(ctx, row, base)
	local _ = row

	put(ctx, base, {
		name = "SideTop",
		size = Vector3.new(5.4, 0.5, 5.4),
		at = Vector3.new(0, 3.2, 0),
		color = palette.timber,
		material = PLANK,
	})

	for _, x in { -2.2, 2.2 } do
		for _, z in { -2.2, 2.2 } do
			post(ctx, base, "SideLeg", Vector3.new(0.5, 3.2, 0.5), Vector3.new(x, 1.6, z), palette.timberDark)
		end
	end

	local bulb = put(ctx, base, {
		name = "SideLamp",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.8, 2.8, 2.8),
		at = Vector3.new(0, 5.4, 0),
		color = palette.honey,
		material = Enum.Material.Neon,
		collide = false,
		castShadow = false,
	})
	post(ctx, base, "SideLampStem", Vector3.new(0.4, 1.4, 0.4), Vector3.new(0, 4.1, 0), palette.timberDark)

	local light = Instance.new("PointLight")
	light.Brightness = 0.6
	light.Range = 16
	light.Color = Color3.fromRGB(255, 226, 186)
	light.Shadows = false
	light.Parent = bulb

	put(ctx, base, {
		name = "SideBook",
		size = Vector3.new(2.6, 0.6, 3.4),
		at = Vector3.new(1.2, 3.75, 0.6),
		color = BOOKS[2],
		material = CLOTH,
		collide = false,
		castShadow = false,
	})
end

function builders.plushPile(ctx, row, base)
	local _ = row

	for index, color in PLUSH do
		local angle = (index / #PLUSH) * math.pi * 2
		local size = 2.6 + (index % 2) * 0.8
		put(ctx, base, {
			name = "Plush",
			shape = Enum.PartType.Ball,
			size = Vector3.new(size, size, size),
			at = Vector3.new(math.cos(angle) * 2.4, size / 2, math.sin(angle) * 2.4),
			color = color,
			material = CLOTH,
			collide = false,
			castShadow = false,
		})
		put(ctx, base, {
			name = "PlushEar",
			shape = Enum.PartType.Ball,
			size = Vector3.new(size * 0.4, size * 0.4, size * 0.4),
			at = Vector3.new(math.cos(angle) * 2.4, size * 0.95, math.sin(angle) * 2.4 - size * 0.3),
			color = color,
			material = CLOTH,
			collide = false,
			castShadow = false,
		})
	end
end

function builders.frames(ctx, row, base)
	local _ = row
	local sizes = { Vector3.new(5, 4, 0.4), Vector3.new(3.6, 5, 0.4), Vector3.new(4.4, 3.4, 0.4) }
	local offsets = { Vector3.new(-5.4, 1.2, -0.4), Vector3.new(0, -0.4, -0.4), Vector3.new(5, 1.6, -0.4) }

	for index, size in sizes do
		put(ctx, base, {
			name = "Frame",
			size = size,
			at = offsets[index],
			color = palette.timberDark,
			material = WOOD,
			collide = false,
			castShadow = false,
		})
		put(ctx, base, {
			name = "FramePicture",
			size = Vector3.new(size.X - 1, size.Y - 1, 0.5),
			at = offsets[index] + Vector3.new(0, 0, -0.15),
			color = BOOKS[index % #BOOKS + 1],
			material = CLOTH,
			collide = false,
			castShadow = false,
		})
	end
end

function builders.clock(ctx, row, base)
	local _ = row
	local face = CFrame.Angles(0, math.rad(90), 0)

	put(ctx, base, {
		name = "ClockCase",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, 7.4, 7.4),
		at = Vector3.new(0, 0, -0.4),
		color = palette.timberDark,
		material = WOOD,
		collide = false,
		castShadow = false,
		turn = face,
	})
	put(ctx, base, {
		name = "ClockFace",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.4, 6.4, 6.4),
		at = Vector3.new(0, 0, -0.9),
		color = palette.linen,
		material = CERAMIC,
		collide = false,
		castShadow = false,
		turn = face,
	})

	local hands = { { length = 2.2, angle = 20 }, { length = 3, angle = 122 } }
	for _, hand in hands do
		local turn = math.rad(hand.angle)
		put(ctx, base, {
			name = "ClockHand",
			size = Vector3.new(0.4, hand.length, 0.3),
			at = Vector3.new(math.sin(turn) * hand.length / 2, math.cos(turn) * hand.length / 2, -1.2),
			color = palette.timberDark,
			collide = false,
			castShadow = false,
			turn = CFrame.Angles(0, 0, -turn),
		})
	end

	for index = 0, 3 do
		local turn = index * math.pi / 2
		put(ctx, base, {
			name = "ClockTick",
			size = Vector3.new(0.4, 0.8, 0.3),
			at = Vector3.new(math.sin(turn) * 2.6, math.cos(turn) * 2.6, -1.2),
			color = palette.trimDeep,
			collide = false,
			castShadow = false,
			turn = CFrame.Angles(0, 0, -turn),
		})
	end
end

local GARLAND_SEGMENTS = 12

function builders.garland(ctx, row, _base)
	local from = row.from or -60
	local to = row.to or 60
	local height = row.y or 26
	local sag = 4.5
	local radius = SafeZone.interiorRadiusAt(height) - 2

	local function nodeAt(fraction: number): Vector3
		local azimuth = math.rad(from + (to - from) * fraction)
		local drop = math.sin(fraction * math.pi) * sag
		return ctx.toWorld(math.sin(azimuth) * radius, height - drop, math.cos(azimuth) * radius).Position
	end

	local previous = nodeAt(0)
	for index = 1, GARLAND_SEGMENTS do
		local current = nodeAt(index / GARLAND_SEGMENTS)
		local span = (current - previous).Magnitude

		ctx.piece({
			name = "GarlandCord",
			size = Vector3.new(0.16, 0.16, span),
			color = palette.timberDark,
			collide = false,
			query = false,
			castShadow = false,
			parent = ctx.parent,
			cframe = CFrame.lookAt((previous + current) / 2, current),
		})

		ctx.piece({
			name = "GarlandFlag",
			size = Vector3.new(1.8, 2.4, 0.12),
			color = BOOKS[index % #BOOKS + 1],
			material = CLOTH,
			collide = false,
			query = false,
			castShadow = false,
			parent = ctx.parent,
			cframe = CFrame.lookAt(current - Vector3.new(0, 1.4, 0), current - Vector3.new(0, 1.4, 0) + Vector3.zAxis)
				* CFrame.Angles(0, 0, math.rad(if index % 2 == 0 then 8 else -8)),
		})

		previous = current
	end
end

local function anchorOf(ctx: Context, row: SafeZone.Furnishing): CFrame
	local baseY = if row.on == "loft" then ctx.deckY else ctx.floorY

	if row.azimuth then
		local azimuth = math.rad(row.azimuth)
		local reach = SafeZone.interiorRadiusAt(baseY + (row.y or 14)) - (row.inset or 2)
		return ctx.toWorld(math.sin(azimuth) * reach, baseY, math.cos(azimuth) * reach)
			* CFrame.Angles(0, azimuth, 0)
	end

	return ctx.toWorld(row.x or 0, baseY, row.z or 0) * CFrame.Angles(0, math.rad(row.yaw or 0), 0)
end

function SafeZoneFurniture.build(ctx: Context)
	for _, row in SafeZone.FURNITURE do
		local make = builders[row.kind]
		if not make then
			warn(`[SafeZoneFurniture] no builder for "{row.kind}"`)
			continue
		end
		make(ctx, row, anchorOf(ctx, row))
	end

	for _, row in SafeZone.WALL_ART do
		local make = builders[row.kind]
		if not make then
			warn(`[SafeZoneFurniture] no builder for "{row.kind}"`)
			continue
		end
		make(ctx, row, ctx.surfaceFrame(math.rad(row.azimuth or 0), row.y or 14))
	end
end

return SafeZoneFurniture
