-- MaterialVariants for The Halfway House (docs/ART.md, Materials). Each turns
-- one of the uploaded textures in Assets.Textures into a material that room
-- templates name as a surface ("Wallpaper", "OakFloor", ...). Most textures
-- are greyscale, so the part's Color gives a surface its colour: one
-- wallpaper serves the sage, rose and blue rooms. A few are in colour (the
-- floral stripe, the cellar's brick, the quarry tile): their parts' colour
-- stays near white.
--
-- base:    the built-in material underneath (footstep sounds, physics, and what
--          shows if the texture can't load)
-- studs:   studs per tile of the texture
-- organic: Roblox breaks up the tiling, for surfaces with no regular pattern
--
-- Every surface has a roughness map of its own (the visual rework V4a,
-- tools/surfaces.py): a waxed floor is worn duller where people walk, a
-- glazed tile shines and its grout doesn't, a damp cellar wall is wet in
-- patches. Before, each had one flat roughness.
--
-- The variants live in the place (assets/materials, written by
-- `lune run tools/materials`): game scripts can't make them.

local Assets = require(script.Parent.Parent.Assets)

local T = Assets.Textures

local function surface(name, base, maps, studs, organic)
	return { name = name, base = base, maps = maps, rough = maps.rough, studs = studs, organic = organic }
end

local Materials = {
	-- 1980s calico wallpaper: rosebud sprigs in a half-drop, hung in strips.
	surface("Wallpaper", "Plaster", T.WallpaperSprig, 6),
	-- Regency stripes for the formal rooms: satin bands on matt paper.
	surface("WallpaperStripe", "Plaster", T.WallpaperStripe, 7),
	-- Old painted plaster, stained, cracked and patched.
	-- (7 studs a tile: at 16 its stipple read as stucco in a lamp's raking light.)
	surface("OldPlaster", "Plaster", T.Plaster, 7, true),
	surface("PopcornCeiling", "Plaster", T.Popcorn, 6, true),
	-- Worn strip oak, a little wider than real so it reads at this scale.
	surface("OakFloor", "WoodPlanks", T.WoodFloor, 5),
	-- 1970s walnut V-groove panelling.
	surface("Panelling", "Wood", T.WoodPanel, 6),
	-- (3 studs a tile: at 8 its tufts read as lumps.)
	surface("PileCarpet", "Carpet", T.Carpet, 3, true),
	-- Vinyl tile in a checkerboard, waxed.
	surface("CheckerLino", "Plastic", T.Linoleum, 11),
	surface("HexTile", "CeramicTiles", T.HexTile, 6),
	surface("StainedConcrete", "Concrete", T.Concrete, 16, true),
	-- The golden area (the visual rework V3, the owner's picks of 2026-10-12):
	-- tone-on-tone damask, its motif satin on a matt ground (the hall green,
	-- the dining room oxblood); a faded 1980s floral stripe in colour (the
	-- living room; its wall colour near white); dark oak chevron parquet, waxed
	-- and worn (the hall's floor).
	surface("Damask", "Plaster", T.Damask, 7),
	surface("FloralStripe", "Plaster", T.FloralStripe, 8),
	surface("Parquet", "WoodPlanks", T.Parquet, 8),
	-- New in V4a, for what the house drew in Roblox's own materials: the
	-- cellar's old brick (in colour: whitewash, salt bloom, damp), rough-sawn
	-- boards (the attic's floors, the cellar's and attic's ceilings), glazed
	-- bathroom wall tile, flagstones (the cellars, the mudroom, the pantry),
	-- terracotta quarry tile (the sunroom; in colour), the weathered
	-- clapboard outside (Config.Exterior.Facade), the drive's gravel.
	surface("CellarBrick", "Brick", T.Brick, 8),
	surface("RoughBoards", "WoodPlanks", T.RoughBoards, 8),
	surface("BathTile", "CeramicTiles", T.BathTile, 4),
	surface("Flagstone", "Slate", T.Flagstone, 10, true),
	surface("QuarryTile", "CeramicTiles", T.QuarryTile, 6),
	surface("Clapboard", "WoodPlanks", T.Clapboard, 6),
	surface("Gravel", "Pebble", T.Gravel, 6, true),
	-- The Guest's overcoat (Stalker/StalkerModel, his fallback): black wool,
	-- matte so the torch never shines on it; the carpet's pile, small, reads
	-- as a coarse weave.
	surface("CoatWool", "Fabric", T.Carpet, 2, true),
}

local byName = {}
for _, material in Materials do
	byName[material.name] = material
end

return {
	List = Materials,
	ByName = byName,
}
