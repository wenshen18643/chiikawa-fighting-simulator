local Theme = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Theme.color = {
	paper = rgb(253, 248, 242),
	paperDeep = rgb(243, 232, 224),
	paperRaised = rgb(255, 253, 250),
	paperSunken = rgb(234, 220, 211),
	glass = rgb(255, 255, 255),
	glassDark = rgb(96, 72, 66),

	ink = rgb(74, 56, 52),
	inkSoft = rgb(108, 86, 80),
	inkFaint = rgb(128, 105, 99),
	inkInverse = rgb(255, 252, 248),

	line = rgb(122, 96, 90),
	lineSoft = rgb(214, 194, 186),
	lineBright = rgb(255, 255, 255),

	tobatsu = rgb(246, 132, 124),
	resilience = rgb(140, 196, 240),
	kusatori = rgb(158, 210, 138),
	examprep = rgb(238, 160, 208),

	strength = rgb(246, 132, 124),
	durability = rgb(140, 196, 240),
	agility = rgb(158, 210, 138),
	special = rgb(238, 160, 208),

	rest = rgb(250, 190, 130),
	health = rgb(244, 146, 152),
	gold = rgb(248, 202, 106),
	sky = rgb(150, 202, 244),
	white = rgb(255, 255, 255),
	leaf = rgb(158, 210, 138),
	leafDeep = rgb(112, 172, 96),

	blush = rgb(250, 198, 202),
	lavender = rgb(198, 182, 238),
	mint = rgb(168, 224, 208),
	sand = rgb(240, 220, 186),

	success = rgb(140, 202, 132),
	warning = rgb(248, 190, 112),
	danger = rgb(240, 128, 124),
	info = rgb(150, 194, 240),

	shadow = rgb(150, 118, 110),
	scrim = rgb(78, 58, 54),
}

Theme.surface = {
	canvas = { fill = Theme.color.paper, top = Theme.color.paperRaised, bottom = Theme.color.paperDeep },
	raised = { fill = Theme.color.paperRaised, top = Theme.color.white, bottom = Theme.color.paper },
	sunken = { fill = Theme.color.paperSunken, top = Theme.color.paperDeep, bottom = Theme.color.paperSunken },
	overlay = { fill = Theme.color.paper, top = Theme.color.white, bottom = Theme.color.paperDeep },
}

Theme.elevation = {
	flat = { layers = 0, spread = 0, opacity = 1 },
	low = { layers = 1, spread = 2, opacity = 0.78 },
	base = { layers = 2, spread = 3, opacity = 0.72 },
	high = { layers = 4, spread = 3, opacity = 0.66 },
	lifted = { layers = 5, spread = 4, opacity = 0.62 },
}

Theme.font = {
	display = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	light = Enum.Font.Gotham,
}

Theme.radius = { card = 22, pill = 999, bar = 12, chip = 14, tile = 18, well = 16 }

Theme.space = { hair = 3, tight = 6, snug = 10, base = 14, loose = 22, wide = 32 }

Theme.text = { caption = 11, small = 13, body = 15, subtitle = 18, title = 22, display = 30, hero = 42 }

Theme.stroke = { hair = 1.5, base = 2.5, heavy = 4, chunky = 5.5 }

Theme.state = {
	hover = { lighten = 0.16, lift = 2 },
	press = { darken = 0.1, lift = -1 },
	disabled = { fade = 0.55 },
	focus = { thickness = 3 },
}

Theme.opacity = { veil = 0.42, scrim = 0.3, ghost = 0.75, sheen = 0.86 }

function Theme.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Theme.color.white, math.clamp(amount, 0, 1))
end

function Theme.darken(color: Color3, amount: number): Color3
	return color:Lerp(Theme.color.glassDark, math.clamp(amount, 0, 1))
end

local function channel(value: number): number
	return if value <= 0.04045 then value / 12.92 else ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color: Color3): number
	return channel(color.R) * 0.2126 + channel(color.G) * 0.7152 + channel(color.B) * 0.0722
end

local function contrast(first: Color3, second: Color3): number
	local a = luminance(first)
	local b = luminance(second)
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

function Theme.readable(background: Color3): Color3
	return if contrast(background, Theme.color.ink) >= contrast(background, Theme.color.inkInverse)
		then Theme.color.ink
		else Theme.color.inkInverse
end

return Theme
