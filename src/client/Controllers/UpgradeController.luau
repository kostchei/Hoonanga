--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradeConfig = require(ReplicatedStorage.Shared.Config.UpgradeConfig)
local InputModeController = require(script.Parent.InputModeController)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local upgradeOfferedRemote = remotes:WaitForChild("UpgradeOffered") :: RemoteEvent
local claimUpgradeRemote = remotes:WaitForChild("ClaimUpgrade") :: RemoteEvent
local sessionStateRemote = remotes:WaitForChild("SessionStateChanged") :: RemoteEvent

local UpgradeController = {}

function UpgradeController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaUpgradeOffer"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 20
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 290)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BorderSizePixel = 0
	panel.Parent = shade

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "CHOOSE ONE RUN UPGRADE"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 14)
	title.Size = UDim2.new(1, -36, 0, 34)
	title.Parent = panel

	local buttons: { TextButton } = {}
	for index = 1, 3 do
		local button = Instance.new("TextButton")
		button.Name = "Choice" .. index
		button.Font = Enum.Font.GothamBold
		button.TextSize = 16
		button.TextWrapped = true
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.BackgroundColor3 = Color3.fromRGB(64, 56, 52)
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(18 + (index - 1) * 234, 65)
		button.Size = UDim2.fromOffset(216, 205)
		button.Visible = false
		button.Parent = panel
		buttons[index] = button
	end

	local function close()
		gui.Enabled = false
		InputModeController.SetModalOpen(false)
		for _, button in buttons do
			button.Visible = false
			button:SetAttribute("UpgradeId", nil)
		end
	end

	for _, button in buttons do
		button.MouseButton1Click:Connect(function()
			local upgradeId = button:GetAttribute("UpgradeId")
			if typeof(upgradeId) == "string" then
				claimUpgradeRemote:FireServer(upgradeId)
			end
		end)
	end

	upgradeOfferedRemote.OnClientEvent:Connect(function(upgradeIds: any)
		if typeof(upgradeIds) ~= "table" or #upgradeIds == 0 then
			close()
			return
		end
		for index, button in buttons do
			local upgradeId = upgradeIds[index]
			local definition = if typeof(upgradeId) == "string"
				then UpgradeConfig.Upgrades[upgradeId]
				else nil
			button.Visible = definition ~= nil
			if definition then
				button:SetAttribute("UpgradeId", upgradeId)
				button.Text = string.format(
					"%s\n\n%s\n\n%s",
					definition.Name,
					definition.Description,
					string.upper(definition.Category)
				)
			end
		end
		gui.Enabled = true
		InputModeController.SetModalOpen(true)
	end)

	sessionStateRemote.OnClientEvent:Connect(function(phase: string)
		if phase ~= "InRun" then
			close()
		end
	end)
end

return UpgradeController
