-- MaterialVariants for The Halfway House (docs/ART.md, Materials). Each turns
-- one of the uploaded textures in Assets.Textures into a material that room
-- templates name as a surface ("Wallpaper", "OakFloor", ...). The textures are
-- greyscale, so the part's Color gives a surface its colour: one wallpaper
-- serves the sage, rose and blue rooms.
--
-- base:    the built-in material underneath (footstep sounds, physics, and what
--          shows if the texture can't load)
-- studs:   studs per tile of the texture
-- organic: Roblox breaks up the tiling, for surfaces with no regular pattern
--
-- WorldService creates them in MaterialService when the server starts.

local Assets = require(script.Parent.Parent.Assets)

local T = Assets.Textures
local R = Assets.Roughness

local Materials = {
	-- 1980s wallpaper: flower sprigs in a half-drop between pinstripes.
	{ name = "Wallpaper", base = "Plaster", maps = T.WallpaperSprig, rough = R.Matte, studs = 6 },
	-- Regency stripes for the formal rooms.
	{ name = "WallpaperStripe", base = "Plaster", maps = T.WallpaperStripe, rough = R.Matte, studs = 7 },
	-- Old painted plaster, stained and never quite clean.
	{ name = "OldPlaster", base = "Plaster", maps = T.Plaster, rough = R.Matte, studs = 16, organic = true },
	{ name = "PopcornCeiling", base = "Plaster", maps = T.Popcorn, rough = R.Matte, studs = 6, organic = true },
	-- Worn oak boards, a little wider than real ones so they read at this scale.
	{ name = "OakFloor", base = "WoodPlanks", maps = T.WoodFloor, rough = R.Satin, studs = 5 },
	{ name = "Panelling", base = "Wood", maps = T.WoodPanel, rough = R.Satin, studs = 6 },
	{ name = "PileCarpet", base = "Carpet", maps = T.Carpet, rough = R.Matte, studs = 8, organic = true },
	{ name = "CheckerLino", base = "Plastic", maps = T.Linoleum, rough = R.Satin, studs = 11 },
	{ name = "HexTile", base = "CeramicTiles", maps = T.HexTile, rough = R.Satin, studs = 6 },
	{ name = "StainedConcrete", base = "Concrete", maps = T.Concrete, rough = R.Matte, studs = 16, organic = true },
	-- The Guest's overcoat (Stalker/StalkerModel): black wool, matte so the
	-- torch never shines on it; the carpet's pile, small, reads as a coarse
	-- weave.
	{ name = "CoatWool", base = "Fabric", maps = T.Carpet, rough = R.Matte, studs = 2, organic = true },
}

local byName = {}
for _, material in Materials do
	byName[material.name] = material
end

return {
	List = Materials,
	ByName = byName,
}
