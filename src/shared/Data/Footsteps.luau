-- How footsteps sound (owner, 2026-10-03): which sample set each floor gets,
-- and how a room colours the sound. Surfaces are keyed by the BASE material
-- the floor part has (Humanoid.FloorMaterial.Name; the MaterialVariant sits on
-- top of it, see Data/Materials), and the sample ids live in Assets.Footsteps.

return {
	-- FloorMaterial name -> surface
	Materials = {
		WoodPlanks = "Wood",
		Wood = "Wood",
		Carpet = "Carpet",
		Fabric = "Carpet",
		Plastic = "Tile", -- the checkered lino
		CeramicTiles = "Tile",
		Marble = "Tile",
		Concrete = "Concrete",
		Slate = "Concrete",
		Cobblestone = "Concrete",
	},
	Default = "Wood",

	-- Per surface: loudness and pitch of the whole set, softer carpets.
	Surfaces = {
		Wood = { volume = 1, pitch = 0.95 },
		Carpet = { volume = 0.7, pitch = 0.9 },
		Tile = { volume = 1, pitch = 1 },
		Concrete = { volume = 1, pitch = 0.92 },
	},

	-- Per room reverb type (Data/Rooms `reverb`): a short echo on steps in hard
	-- or long rooms. Rooms not listed have none, so carpeted rooms stay dead.
	Rooms = {
		Bathroom = { delay = 0.07, feedback = 0.35, wet = 0.45 },
		StoneRoom = { delay = 0.14, feedback = 0.4, wet = 0.4 },
		CarpettedHallway = { delay = 0.1, feedback = 0.2, wet = 0.18 },
	},
}
