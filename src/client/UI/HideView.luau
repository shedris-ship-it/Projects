-- What you see from inside a hiding place (the squad playtest, 2026-10-08:
-- "be able to peek from the hiding spot instead of seeing everything
-- perfectly"). Tucked in, the room shows only through a slit shaped by what
-- you're in (Logic/HideRules.Slits): the gap between a wardrobe's louvred
-- doors, a locker's vents, the strip under a bed's skirt, under a
-- tablecloth's hem, past a curtain's edge. Hold right click (LT) to peek and
-- it opens up as your eye moves to the gap (Controllers/ActionController).
-- Frames and gradients only: nothing uploaded.

local Players = game:GetService("Players")

local Ui = require(script.Parent.Parent.Lib.Ui)

local player = Players.LocalPlayer

local DARK = Color3.fromRGB(4, 3, 3)
local WOOD = Color3.fromRGB(16, 11, 8)

local HideView = {}
HideView.__index = HideView

-- A dark panel covering part of the screen, its inner edge feathered.
local function panel(parent: Instance, position: UDim2, size: UDim2, color: Color3, feather: string?)
	local frame = Ui.new("Frame", {
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if feather then
		local gradient = Instance.new("UIGradient")
		-- Transparent at the feathered edge: the light leaks round it.
		local keys = {
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.82, 0),
			NumberSequenceKeypoint.new(1, 0.85),
		}
		gradient.Transparency = NumberSequence.new(keys)
		gradient.Rotation = ({ right = 0, left = 180, down = 90, up = 270 })[feather] or 0
		gradient.Parent = frame
	end
	return frame
end

-- Thin dark bars across a gap (louvres, vent slats, a skirt's fringe).
local function slats(parent: Instance, position: UDim2, size: UDim2, count: number, thickness: number, color: Color3)
	local holder = Ui.new("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for i = 1, count do
		Ui.new("Frame", {
			Position = UDim2.fromScale(0, (i - 0.5) / count - thickness / 2),
			Size = UDim2.fromScale(1, thickness),
			BackgroundColor3 = color,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Parent = holder,
		})
	end
	return holder
end

local BUILDERS = {
	-- A wardrobe's or a cupboard's doors: a narrow gap down the middle,
	-- louvres across it.
	louvre = function(root: Instance)
		panel(root, UDim2.fromScale(0, 0), UDim2.fromScale(0.44, 1), WOOD, "right")
		panel(root, UDim2.fromScale(0.56, 0), UDim2.fromScale(0.44, 1), WOOD, "left")
		slats(root, UDim2.fromScale(0.42, 0), UDim2.fromScale(0.16, 1), 22, 0.022, WOOD)
	end,
	-- A locker's door: five vents high up, the rest steel.
	vents = function(root: Instance)
		panel(root, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3), DARK)
		panel(root, UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38), DARK)
		panel(root, UDim2.fromScale(0, 0.3), UDim2.fromScale(0.3, 0.32), DARK)
		panel(root, UDim2.fromScale(0.7, 0.3), UDim2.fromScale(0.3, 0.32), DARK)
		slats(root, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.4, 0.32), 5, 0.12, DARK)
	end,
	-- Under a bed: the mattress over you, a strip of floor under the skirt.
	skirt = function(root: Instance)
		panel(root, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.62), DARK, "down")
		slats(root, UDim2.fromScale(0, 0.58), UDim2.fromScale(1, 0.08), 1, 0.6, Color3.fromRGB(30, 22, 24))
		panel(root, UDim2.fromScale(0, 0.9), UDim2.fromScale(1, 0.1), DARK, "up")
	end,
	-- Under a table: its cloth hanging down over the top of your view.
	hem = function(root: Instance)
		panel(root, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.42), Color3.fromRGB(26, 22, 18), "down")
		panel(root, UDim2.fromScale(0, 0.42), UDim2.fromScale(0.12, 0.58), DARK, "right")
		panel(root, UDim2.fromScale(0.88, 0.42), UDim2.fromScale(0.12, 0.58), DARK, "left")
	end,
	-- Behind a curtain: cloth over most of your view, hanging in folds, the
	-- room past its edge.
	edge = function(root: Instance)
		local cloth = panel(root, UDim2.fromScale(0, 0), UDim2.fromScale(0.68, 1), Color3.fromRGB(24, 18, 20), "right")
		for i = 0, 6 do
			local fold = Ui.new("Frame", {
				Position = UDim2.fromScale(i / 7, 0),
				Size = UDim2.fromScale(1 / 7, 1),
				BackgroundColor3 = Color3.fromRGB(46, 34, 36),
				BorderSizePixel = 0,
				Parent = cloth,
			})
			local shade = Instance.new("UIGradient")
			shade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			shade.Parent = fold
		end
		panel(root, UDim2.fromScale(0.9, 0), UDim2.fromScale(0.1, 1), DARK, "left")
	end,
}

function HideView.new(ctx)
	local self = setmetatable({ ctx = ctx, kind = nil, alpha = 0 }, HideView)
	-- Under the HUD and the prompts, over the world.
	local gui = Ui.screen("ConsensusHideView", 2, ctx.playerGui)
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	self.gui = gui
	self.root = Ui.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	return self
end

function HideView:Update(dt: number)
	local slit = player:GetAttribute("HideSlit")
	local hidden = typeof(slit) == "string" and self.ctx.state:IsHidden()
	if hidden and slit ~= self.kind then
		self.kind = slit
		for _, child in self.root:GetChildren() do
			child:Destroy()
		end
		local build = BUILDERS[slit] or BUILDERS.louvre
		build(self.root)
	end
	-- Fades in as you tuck in, and opens up as you peek.
	local actions = self.ctx.controllers.ActionController
	local peek = actions and actions.PeekBlend and actions:PeekBlend() or 0
	local target = hidden and (1 - 0.8 * peek) or 0
	self.alpha += (target - self.alpha) * math.clamp(dt * 8, 0, 1)
	self.root.GroupTransparency = 1 - self.alpha
	self.gui.Enabled = self.alpha > 0.01
	if not hidden and self.alpha <= 0.01 then
		self.kind = nil
	end
end

return HideView
