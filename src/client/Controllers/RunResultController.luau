--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer

local RunResultController = {}

function RunResultController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaRunResult"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(460, 220)
	panel.BackgroundColor3 = Color3.fromRGB(12, 14, 15)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "RUN OVER"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 34
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 56)
	title.Position = UDim2.fromOffset(0, 18)
	title.Parent = panel

	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.Font = Enum.Font.GothamMedium
	stats.TextSize = 22
	stats.TextColor3 = Color3.fromRGB(238, 220, 189)
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, 0, 0, 90)
	stats.Position = UDim2.fromOffset(0, 84)
	stats.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Text = "Respawning..."
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(160, 150, 140)
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.Position = UDim2.new(0, 0, 1, -42)
	hint.Parent = panel

	-- Distance/kills are captured from the last living frame rather than
	-- read after Destroyed flips true, since the chassis can already be
	-- gone (or mid-explosion) by the time this notices.
	local trackedVehicle: Model? = nil
	local resultShownFor: Model? = nil
	local lastDistance = 0

	RunService.RenderStepped:Connect(function()
		local vehicle = VehicleLocator.ForPlayerIncludingDestroyed(localPlayer)
		if not vehicle then
			return
		end

		if vehicle ~= trackedVehicle then
			trackedVehicle = vehicle
			lastDistance = 0
		end

		if vehicle:GetAttribute("Destroyed") then
			if resultShownFor ~= vehicle then
				resultShownFor = vehicle
				stats.Text = string.format(
					"Distance: %.2f km\nKills: %d",
					lastDistance / 1000,
					localPlayer:GetAttribute("Kills") or 0
				)
				gui.Enabled = true
			end
		else
			if vehicle.PrimaryPart then
				lastDistance = math.max(0, -vehicle.PrimaryPart.Position.Z)
			end
			if gui.Enabled then
				gui.Enabled = false
			end
		end
	end)
end

return RunResultController
