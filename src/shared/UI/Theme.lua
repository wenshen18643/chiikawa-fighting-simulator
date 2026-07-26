--[[
	Design tokens.

	--------------------------------------------------------------------------
	THE ARCADE PASS
	--------------------------------------------------------------------------

	This used to be a light "paper and ink" set: cream panels, warm brown text,
	hairline borders. It has been retuned to the chunky arcade look the genre
	actually uses — dark panels, heavy near-black outlines, saturated stat
	colours, white text.

	The KEY NAMES did not change, only their values. `paper` is still "the
	surface a panel is made of" and `ink` is still "text on that surface"; they
	are now dark and light respectively rather than light and dark. Every card,
	chip, button, toast and world-space sign in the game reads these, so the
	whole interface moved together and nothing needed a per-call-site override.

	That is the point of the indirection, and it is why nothing here is ever a
	literal Color3 at a call site.

	One consequence worth knowing: Glyphs draws cut-outs (the hole in the lock,
	the fold lines on the map) in `paper`, on the assumption that it matches the
	panel behind. That still holds — the value flipped, the relationship did not.
]]

local Theme = {}

Theme.color = {
	-- Canvas surfaces. Dark, slightly blue, so the saturated stat colours read
	-- as lit rather than as stickers.
	paper = Color3.fromRGB(28, 30, 42),
	paperDeep = Color3.fromRGB(17, 18, 27),
	glass = Color3.fromRGB(255, 255, 255),
	glassDark = Color3.fromRGB(12, 13, 20),

	-- Text.
	ink = Color3.fromRGB(245, 247, 252),
	inkSoft = Color3.fromRGB(168, 176, 198),
	inkFaint = Color3.fromRGB(110, 118, 142),

	-- The outline. Near-black and thick is what makes this style read as
	-- arcade rather than as a dark-mode dashboard.
	line = Color3.fromRGB(9, 10, 16),

	-- Chiikawa Stat Palette, pushed to full saturation for the dark surface.
	tobatsu = Color3.fromRGB(255, 84, 72),
	resilience = Color3.fromRGB(64, 190, 255),
	kusatori = Color3.fromRGB(126, 226, 96),
	examprep = Color3.fromRGB(255, 138, 226),

	-- Legacy aliases
	strength = Color3.fromRGB(255, 84, 72),
	durability = Color3.fromRGB(64, 190, 255),
	agility = Color3.fromRGB(126, 226, 96),
	special = Color3.fromRGB(255, 138, 226),

	-- Accents
	rest = Color3.fromRGB(255, 176, 72),
	gold = Color3.fromRGB(255, 198, 64),
	sky = Color3.fromRGB(96, 186, 255),
	white = Color3.fromRGB(255, 255, 255),
	leaf = Color3.fromRGB(126, 226, 96),
	leafDeep = Color3.fromRGB(72, 176, 56),
}

Theme.font = {
	display = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
	light = Enum.Font.Gotham,
}

-- Rounder than before. `pill` is the round skill buttons and side-rail buttons.
Theme.radius = { card = 20, pill = 999, bar = 10, chip = 14 }

Theme.space = { tight = 6, snug = 10, base = 14, loose = 22 }

Theme.text = { caption = 11, small = 13, body = 15, title = 22, display = 30 }

--[[
	Outline weights. Named rather than passed as numbers so "the heavy one" is
	a decision made once instead of a 3 typed in forty places.
]]
Theme.stroke = { hair = 1.5, base = 2.5, heavy = 4 }

return Theme
