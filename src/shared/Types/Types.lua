local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BigNumber = require(ReplicatedStorage:WaitForChild("Shared").Modules.BigNumber)

export type BigNum = BigNumber.BigNum

export type SkillMap = {
	tobatsu: BigNum,
	resilience: BigNum,
	kusatori: BigNum,
	examprep: BigNum,
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

export type CompanionState = {
	selected: string?,
	owned: { [string]: boolean }?,
}

export type CompanionSkinState = {
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
}

export type WeaponSkinState = {
	copies: { [string]: number },
	equipped: { [string]: string },
	rarePlusMisses: number,
	legendaryMisses: number,
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
	skill: string?,
	stat: string?,
	expiresAt: number,
}

export type FurniturePlacement = {
	id: string,
	cf: { number },
}

export type Home = {
	furniture: { FurniturePlacement },
	comfort: number,
}

export type FarmCropState = {
	id: string,
	plantedAt: number,
	maturesAt: number,
}

export type FarmPlotSnapshot = {
	plotId: number,
	ownerUserId: number?,
	ownerName: string?,
	leaseEndsAt: number?,
	crop: FarmCropState?,
	highestBid: number?,
	highestBidderUserId: number?,
	highestBidderName: string?,
	minimumBid: number,
	serverNow: number,
}

export type PlayerProfile = {
	skills: SkillMap,
	certifications: { [string]: number },
	studyProgress: { [string]: number },
	examAttempts: { [string]: number },
	currencies: Currencies,
	seasons: number,
	companions: CompanionState,
	companionSkins: CompanionSkinState,
	weaponSkins: WeaponSkinState,
	gear: Gear,
	recipes: { [string]: boolean },
	dishes: { [string]: number },
	workOrders: {
		completed: { string },
		active: { [string]: number },
		rank: number,
	},
	unlockedRegions: { [string]: boolean },
	home: Home,
	gamepasses: { [number]: boolean },
	boosts: { Boost },
	foodBuffs: { any },
	settings: { autoWork: boolean, vfxQuality: string, musicVolume: number },
	farm: { claimedCredits: { [string]: boolean }, claimedCreditOrder: { string } },
	version: number,
	meta: { createdAt: number, lastPlayed: number, playtime: number, introShown: boolean },
}

export type StateSnapshot = {
	skills: { [string]: BigNum },
	yen: BigNum,
	unlimitedYen: boolean,
	stamps: BigNum,
	seasons: number,
	certifications: { [string]: number },
	certificationCap: number,
	study: {
		subject: string,
		readiness: number,
		attempts: number,
		certificationOrder: number,
		focusExpiresAt: number,
		factId: number,
	},
	gainPerAction: BigNum?,
	yenPerSecond: BigNum,
	regionId: number,
	unlockedRegions: { [string]: boolean },
	ingredients: { [string]: number },
	seasonings: { [string]: number },
	dishes: { [string]: number },
	boosts: { Boost },
	foodBuffs: { any },
	showIntro: boolean,
}

return {}
