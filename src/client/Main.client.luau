-- Client bootstrap: every ModuleScript in Controllers gets Init(controllers)
-- then Start(), mirroring the server.

local Controllers = script.Parent:WaitForChild("Controllers")

local Build = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Build"))
print("[Consensus] client build " .. Build.id)

local controllers = {}
for _, module in Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, controller = pcall(require, module)
		if ok then
			controllers[module.Name] = controller
		else
			warn("[Consensus] failed to load " .. module.Name .. ": " .. tostring(controller))
		end
	end
end

local names = {}
for name in controllers do
	table.insert(names, name)
end
table.sort(names)

for _, name in names do
	local controller = controllers[name]
	if type(controller.Init) == "function" then
		local ok, err = pcall(controller.Init, controller, controllers)
		if not ok then
			warn("[Consensus] " .. name .. ".Init failed: " .. tostring(err))
		end
	end
end

for _, name in names do
	local controller = controllers[name]
	if type(controller.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn("[Consensus] " .. name .. ".Start failed: " .. tostring(err))
			end
		end)
	end
end

-- Ask the server for everything we may have missed while loading.
task.delay(1, function()
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net).get("RequestSync"):FireServer()
end)
