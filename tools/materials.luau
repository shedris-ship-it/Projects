-- Writes the house's MaterialVariants as Rojo model files, one per entry in
-- src/shared/Data/Materials.luau, into assets/materials/. Rojo syncs that
-- folder into MaterialService (default.project.json). Game scripts can't
-- create MaterialVariants at runtime, so they have to live in the place.
--
-- Run from the repository root after changing Data/Materials or the texture
-- ids in Assets.luau:
--
--     lune run tools/materials
--
-- tests/specs/Materials.spec.luau fails if the files fall out of date.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("../tests/harness")

local Shared = Harness.root("src/shared", "Shared")
local Materials = Harness.require(Shared.Data.Materials)

local OUT = "assets/materials"

if fs.isDir(OUT) then
	for _, name in fs.readDir(OUT) do
		if string.match(name, "%.model%.json$") then
			fs.removeFile(OUT .. "/" .. name)
		end
	end
else
	fs.writeDir(OUT)
end

for _, m in Materials.List do
	local model = {
		className = "MaterialVariant",
		properties = {
			BaseMaterial = m.base,
			ColorMap = m.maps.color,
			NormalMap = m.maps.normal or "",
			RoughnessMap = m.rough or "",
			StudsPerTile = m.studs,
			MaterialPattern = if m.organic then "Organic" else "Regular",
		},
	}
	fs.writeFile(OUT .. "/" .. m.name .. ".model.json", serde.encode("json", model, true) .. "\n")
	print("wrote " .. m.name)
end
