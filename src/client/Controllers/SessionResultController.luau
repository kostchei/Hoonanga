--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local sessionStateRemote = remotesFolder:WaitForChild("SessionStateChanged") :: RemoteEvent

local SessionResultController = {}

function SessionResultController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaSessionResults"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "ResultPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(500, 300)
	panel.BackgroundColor3 = Color3.fromRGB(12, 14, 15)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "RUN COMPLETE - RESULTS"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 48)
	title.Position = UDim2.fromOffset(0, 16)
	title.Parent = panel

	local listLabel = Instance.new("TextLabel")
	listLabel.Name = "List"
	listLabel.Font = Enum.Font.GothamMedium
	listLabel.TextSize = 16
	listLabel.TextColor3 = Color3.fromRGB(238, 220, 189)
	listLabel.BackgroundTransparency = 1
	listLabel.Size = UDim2.new(1, -32, 1, -80)
	listLabel.Position = UDim2.fromOffset(16, 64)
	listLabel.TextYAlignment = Enum.TextYAlignment.Top
	listLabel.TextXAlignment = Enum.TextXAlignment.Left
	listLabel.Text = ""
	listLabel.Parent = panel

	sessionStateRemote.OnClientEvent:Connect(function(state: string, data: any)
		if state == "Results" and typeof(data) == "table" then
			local lines = {}
			for _, stats in data do
				table.insert(
					lines,
					string.format(
						"#%d %s [%s] - %.2f km | Kills: %d | Credits +%d | XP +%d",
						stats.Placement or 0,
						stats.Name or "Player",
						stats.ClassId or "Ute",
						(stats.Distance or 0) / 1000,
						stats.Kills or 0,
						stats.CreditsEarned or 0,
						stats.XpEarned or 0
					)
				)
			end
			listLabel.Text = table.concat(lines, "\n")
			gui.Enabled = true
		elseif state == "Lobby" or state == "InRun" then
			gui.Enabled = false
		end
	end)
end

return SessionResultController
