-- Server bootstrap. Every ModuleScript directly inside Services is a service
-- with optional Init(services) and Start() methods. Init wires references;
-- Start begins work once every service has been initialised.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Build)
local Net = require(Shared.Net)

print("[Consensus] server build " .. Build.id .. ": " .. Build.note)

Net.createAll()

local runState = ReplicatedStorage:FindFirstChild("RunState") or Instance.new("Folder")
runState.Name = "RunState"
runState.Parent = ReplicatedStorage

local services = {}
for _, module in script.Parent.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, service = pcall(require, module)
		if ok then
			services[module.Name] = service
		else
			warn("[Consensus] failed to load service " .. module.Name .. ": " .. tostring(service))
		end
	end
end

-- Init in a stable order so failures are reproducible.
local names = {}
for name in services do
	table.insert(names, name)
end
table.sort(names)

for _, name in names do
	local service = services[name]
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service, services)
		if not ok then
			warn("[Consensus] " .. name .. ".Init failed: " .. tostring(err))
		end
	end
end

for _, name in names do
	local service = services[name]
	if type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn("[Consensus] " .. name .. ".Start failed: " .. tostring(err))
			end
		end)
	end
end

print(string.format("[Consensus] server ready (%d services)", #names))
