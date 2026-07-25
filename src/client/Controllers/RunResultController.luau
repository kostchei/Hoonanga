--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
	panel.Size = UDim2.fromOffset(460, 238)
	panel.BackgroundColor3 = Color3.fromRGB(12, 14, 15)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
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
	stats.TextSize = 21
	stats.TextColor3 = Color3.fromRGB(238, 220, 189)
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, 0, 0, 112)
	stats.Position = UDim2.fromOffset(0, 78)
	stats.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Text = "Preparing the next run..."
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(160, 150, 140)
	hint.BackgroundTransparency = 1
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.Position = UDim2.new(0, 0, 1, -38)
	hint.Parent = panel

	local shownRunEnded = false
	RunService.RenderStepped:Connect(function()
		local ended = localPlayer:GetAttribute("RunEnded") == true
		if ended and not shownRunEnded then
			shownRunEnded = true
			local reason = localPlayer:GetAttribute("RunEndReason")
			title.Text = if reason == "OutOfFuel" then "OUT OF FUEL" else "CONVOY LOST"
			stats.Text = string.format(
				"Distance: %.2f km\nKills: %d\nControl transfers: %d",
				(localPlayer:GetAttribute("RunDistance") or 0) / 1000,
				localPlayer:GetAttribute("Kills") or 0,
				localPlayer:GetAttribute("ControlTransfers") or 0
			)
			gui.Enabled = true
		elseif not ended then
			shownRunEnded = false
			gui.Enabled = false
		end
	end)
end

return RunResultController
