-- Doc section 4, "Rules every anomaly must follow".
return function(test, check, Shared, require)
	local Anomalies = require(Shared.Data.Anomalies)
	local Tells = require(Shared.Data.Tells)
	local CaseBoard = require(Shared.Logic.CaseBoard)

	test("there are 12 anomalies and every tell they reference exists", function()
		check.equal(#Anomalies.List, 12, "anomaly count")
		for _, anomaly in Anomalies.List do
			for _, tellId in anomaly.tells do
				check.truthy(Tells[tellId], anomaly.id .. " references unknown tell " .. tellId)
			end
		end
	end)

	test("deducible: 5-6 tells each, at least one camera-confirmable", function()
		for _, anomaly in Anomalies.List do
			check.atLeast(#anomaly.tells, 5, anomaly.id .. " tells")
			check.atMost(#anomaly.tells, 6, anomaly.id .. " tells")
			local camera = false
			for _, id in anomaly.tells do
				if Tells[id].camera then
					camera = true
				end
			end
			check.truthy(camera, anomaly.id .. " has no camera-confirmable tell")
		end
	end)

	test("social: at least half the tells need two Witnesses to compare", function()
		for _, anomaly in Anomalies.List do
			local social = 0
			for _, id in anomaly.tells do
				if Tells[id].social then
					social += 1
				end
			end
			check.atLeast(social * 2, #anomaly.tells, anomaly.id .. " social tells")
		end
	end)

	test("overlapping: each anomaly shares a tell with at least two others", function()
		for _, anomaly in Anomalies.List do
			local partners = 0
			for _, other in Anomalies.List do
				if other ~= anomaly then
					for _, id in anomaly.tells do
						if table.find(other.tells, id) then
							partners += 1
							break
						end
					end
				end
			end
			check.atLeast(partners, 2, anomaly.id .. " overlap partners")
		end
	end)

	test("any three tells of an anomaly leave two or fewer suspects", function()
		for _, anomaly in Anomalies.List do
			local worst = CaseBoard.worstCaseSuspects(Anomalies.List, anomaly.tells, 3)
			check.atMost(worst, 2, anomaly.id .. " worst-case suspects")
		end
	end)

	test("the vertical slice anomalies are implemented", function()
		for _, id in { "PhantomArchitecture", "Counterfeit", "Gaze" } do
			check.truthy(Anomalies.ById[id].implemented, id .. " not implemented")
		end
	end)

	test("every tell is used by at least one anomaly", function()
		for id in Tells do
			local used = false
			for _, anomaly in Anomalies.List do
				if table.find(anomaly.tells, id) then
					used = true
				end
			end
			check.truthy(used, id .. " is not used")
		end
	end)
end
