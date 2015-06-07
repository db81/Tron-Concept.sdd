return {

	name        = "Tron",
	shortname   = "",
	description = "An excercise in neonity.",
	author      = "ikinz",
	version     = "Concept",
	modtype     = 3, --// 1=primary, 0=hidden, 3=map
	depend      = {"Map Helper v1"},
	replace     = {},

	maphardness     = 100,
	notDeformable   = false,
	gravity         = 130,
	tidalStrength   = 10,
	maxMetal        = 0.02,
	extractorRadius = 100.0,
	voidWater       = false,
	autoShowMetal   = true,

	atmosphere = {
		minWind      = 5.0,
		maxWind      = 25.0,

		fogStart     = 0.99,
		fogEnd       = 1.0,
		fogColor     = {0.1, 0.1, 0.1},

		sunColor     = {0.0, 0.0, 0.0},
		skyColor     = {0.0, 0.0, 0.0},
		skyDir       = {0.0, 0.0, -1.0},
		skyBox       = "",

		cloudDensity = 0.0,
	},

}
