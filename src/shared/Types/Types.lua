--[[
	Shared type definitions. The profile shape is docs/GAME.md §16.

	Fields for slices that have not landed yet are present and initialised, not
	absent — that way DataService never has to migrate a field into existence
	for players who were created before the feature shipped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage:WaitForChild("Shared").Modules.BigNumber)

export type BigNum = BigNumber.BigNum

export type SkillMap = {
	weeding: BigNum,
	subjugation: BigNum,
	grit: BigNum,
	craft: BigNum,
	cooking: BigNum,
	charm: BigNum,
}

export type Currencies = {
	yen: BigNum,
	stamps: BigNum,
	ingredients: { [string]: number },
	seasonings: { [string]: number },
	materials: { [string]: number },
}

export type Companion = {
	id: string,
	level: number,
	mood: number,
	active: boolean,
}

export type Gear = {
	weedingTool: string?,
	armor: string?,
	weapon: string?,
	pochette: string?,
	charmItem: string?,
}

export type Boost = {
	id: string,
	multiplier: number,
	skill: string?, -- nil == applies to every skill
	stat: string?, -- "yen" | "staminaRegen": multiplies that number instead of a skill
	expiresAt: number,
}

export type FurniturePlacement = {
	id: string,
	cf: { number }, -- CFrame components; a CFrame itself is not DataStore-safe
}

export type Home = {
	furniture: { FurniturePlacement },
	comfort: number,
}

export type Stamina = {
	current: number,
	max: number,
}

export type PlayerProfile = {
	skills: SkillMap,
	certifications: { [string]: number }, -- skillId -> order, see Config/Certifications
	studyProgress: { [string]: number },
	examAttempts: { [string]: number },
	currencies: Currencies,
	seasons: number,
	companions: { Companion },
	gear: Gear,
	recipes: { string },
	dishes: { [string]: number }, -- cooked dishes owned, recipeId -> count
	workOrders: { completed: { string }, active: { [string]: number } },
	unlockedWorksites: { [string]: boolean },
	unlockedRegions: { [string]: boolean }, -- string keys: JSON has no integer keys
	home: Home,
	gamepasses: { [number]: boolean },
	boosts: { Boost },
	stamina: Stamina,
	settings: { autoWork: boolean, vfxQuality: string, musicVolume: number },
	version: number,
	meta: { createdAt: number, lastPlayed: number, playtime: number, introShown: boolean },
}

-- What the server pushes to the client each snapshot (§13: display data only).
export type StateSnapshot = {
	skills: { [string]: BigNum },
	yen: BigNum,
	stamps: BigNum,
	stamina: Stamina,
	resting: boolean,
	seasons: number,
	certifications: { [string]: number },
	study: {
		subject: string,
		readiness: number,
		skillReady: boolean,
		examReady: boolean,
		attempts: number,
		certificationOrder: number,
		reviewRemaining: number,
		focusExpiresAt: number,
		factId: number,
	},
	currentWorksite: string?,
	gainPerAction: BigNum?,
	yenPerMinute: BigNum,
	regionId: number,
	unlockedRegions: { [string]: boolean },
	ingredients: { [string]: number },
	seasonings: { [string]: number },
	dishes: { [string]: number },
	boosts: { Boost },
	showIntro: boolean,
}

return {}
