-- What Roblox will charge you for each thing on sale (2026-10-16; Creator
-- Docs, "Regional pricing"). Roblox sells for less where prices run lower and
-- takes a subscriber's discount off, and its prompt shows that price, so every
-- Robux label asks Roblox, once a session (MarketplaceService:
-- GetProductInfoAsync answers a client with its own player's price;
-- Logic/PriceLevels.shown). Until it answers, or if it can't, a label shows
-- Data/Products' `robux`. Display only: the server never takes a price from a
-- client, and the prompt is Roblox's.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PriceLevels = require(Shared.Logic.PriceLevels)
local Products = require(Shared.Data.Products)
local Signal = require(Shared.Lib.Signal)

local TRIES = 3

local Prices = {}
Prices.Changed = Signal.new() -- (name): Roblox's price for it arrived

local known = {}
local asked = false

-- The Robux you'd pay for a product or pass in Data/Products, by its name.
function Prices.robux(name: string): number?
	return known[name] or PriceLevels.listed(Products, name)
end

-- Asks Roblox every price on sale, once a session (each screen showing one
-- calls it as it's built, so the prices are in before anyone reaches a till).
function Prices.ask()
	if asked then
		return
	end
	asked = true
	for _, item in PriceLevels.onSale(Products) do
		task.spawn(function()
			local kind = item.pass and Enum.InfoType.GamePass or Enum.InfoType.Product
			for try = 1, TRIES do
				local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, item.id, kind)
				if ok then
					local price = PriceLevels.shown(info)
					if price then
						known[item.name] = price
						Prices.Changed:Fire(item.name)
					end
					return -- (an answer with no price: the listed one stays)
				end
				task.wait(5 * try)
			end
		end)
	end
end

return Prices
