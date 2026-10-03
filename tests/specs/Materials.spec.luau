return function(test, check, Shared, require)
	local fs = require("@lune/fs")
	local serde = require("@lune/serde")
	local Materials = require(Shared.Data.Materials)

	local DIR = "assets/materials"

	test("every material has an up-to-date Rojo model file (lune run tools/materials)", function()
		local files = {}
		for _, name in fs.readDir(DIR) do
			local id = string.match(name, "^(.+)%.model%.json$")
			if id then
				files[id] = true
			end
		end
		for _, m in Materials.List do
			check.truthy(files[m.name], m.name .. " has no model file")
			files[m.name] = nil
			local model = serde.decode("json", fs.readFile(DIR .. "/" .. m.name .. ".model.json"))
			local p = model.properties
			check.equal(model.className, "MaterialVariant", m.name .. " class")
			check.equal(p.BaseMaterial, m.base, m.name .. " base")
			check.equal(p.ColorMap, m.maps.color, m.name .. " colour map")
			check.equal(p.NormalMap, m.maps.normal or "", m.name .. " normal map")
			check.equal(p.RoughnessMap, m.rough or "", m.name .. " roughness map")
			check.equal(p.StudsPerTile, m.studs, m.name .. " studs per tile")
			check.equal(p.MaterialPattern, if m.organic then "Organic" else "Regular", m.name .. " pattern")
		end
		check.equal(next(files), nil, "a model file has no entry in Data/Materials")
	end)

	test("the project syncs the material files into MaterialService", function()
		local project = serde.decode("json", fs.readFile("default.project.json"))
		local service = project.tree.MaterialService
		check.truthy(service and service["$path"] == DIR, "MaterialService is not mapped to " .. DIR)
	end)
end
