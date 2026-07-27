--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ProgressionConfig = require(ReplicatedStorage.Shared.Config.ProgressionConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local setReadyRemote = remotes:WaitForChild("SetPlayerReady") :: RemoteEvent
local selectClassRemote = remotes:WaitForChild("SelectConvoyClass") :: RemoteEvent
local selectLoadoutRemote = remotes:WaitForChild("SelectGarageLoadout") :: RemoteEvent
local progressionUpdatedRemote = remotes:WaitForChild("ProgressionUpdated") :: RemoteEvent
local lobbyStatusRemote = remotes:WaitForChild("LobbyStatusUpdated") :: RemoteEvent
local sessionStateRemote = remotes:WaitForChild("SessionStateChanged") :: RemoteEvent
local getPlayerData = remotes:WaitForChild("GetPlayerData") :: RemoteFunction
local purchaseCosmetic = remotes:WaitForChild("PurchaseCosmetic") :: RemoteFunction

local currentPhase = "Lobby"
local isReady = false
local selectedClass = "Ute"
local selectedPrimary = "MachineGun"
local selectedCosmetic = "Default"
local profileData: any = nil
local classButtons: { [string]: TextButton } = {}
local weaponButtons: { [string]: TextButton } = {}
local cosmeticButtons: { [string]: TextButton } = {}

local GarageController = {}

function GarageController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaGarage"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "GaragePanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(680, 520)
	panel.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "CONVOY LOBBY"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 103, 65)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 14)
	title.Size = UDim2.fromOffset(300, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local profileLabel = Instance.new("TextLabel")
	profileLabel.Name = "Profile"
	profileLabel.Text = "Credits: 0  |  Wins: 0  |  Races: 0"
	profileLabel.Font = Enum.Font.GothamMedium
	profileLabel.TextSize = 14
	profileLabel.TextColor3 = Color3.fromRGB(238, 220, 189)
	profileLabel.BackgroundTransparency = 1
	profileLabel.Position = UDim2.fromOffset(18, 50)
	profileLabel.Size = UDim2.fromOffset(644, 24)
	profileLabel.TextXAlignment = Enum.TextXAlignment.Left
	profileLabel.Parent = panel

	local instruction = Instance.new("TextLabel")
	instruction.Name = "Instruction"
	instruction.Text = "Choose a convoy. Your class locks when you ready."
	instruction.Font = Enum.Font.GothamMedium
	instruction.TextSize = 14
	instruction.TextColor3 = Color3.fromRGB(180, 174, 164)
	instruction.BackgroundTransparency = 1
	instruction.Position = UDim2.fromOffset(18, 78)
	instruction.Size = UDim2.fromOffset(644, 24)
	instruction.TextXAlignment = Enum.TextXAlignment.Left
	instruction.Parent = panel

	local classInfo = {
		{ Id = "Roadtrain", Label = "ROADTRAIN\n1 HEAVY" },
		{ Id = "Ute", Label = "UTES\n2 BALANCED" },
		{ Id = "Bike", Label = "BIKES\n3 FAST" },
	}
	for index, entry in classInfo do
		local button = Instance.new("TextButton")
		button.Name = entry.Id .. "Button"
		button.Text = entry.Label
		button.Font = Enum.Font.GothamBold
		button.TextSize = 16
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.BackgroundColor3 = Color3.fromRGB(64, 56, 52)
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(18 + (index - 1) * 216, 112)
		button.Size = UDim2.fromOffset(204, 82)
		button.Parent = panel
		button.MouseButton1Click:Connect(function()
			if currentPhase ~= "Lobby" or isReady then
				return
			end
			selectClassRemote:FireServer(entry.Id)
		end)
		classButtons[entry.Id] = button
	end

	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Name = "WeaponLabel"
	weaponLabel.Text = "STARTING PRIMARY"
	weaponLabel.Font = Enum.Font.GothamBold
	weaponLabel.TextSize = 13
	weaponLabel.TextColor3 = Color3.fromRGB(180, 174, 164)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Position = UDim2.fromOffset(18, 202)
	weaponLabel.Size = UDim2.fromOffset(644, 22)
	weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
	weaponLabel.Parent = panel

	local primaryWeapons = { "MachineGun", "RocketLauncher", "Flamethrower" }
	for index, weaponId in primaryWeapons do
		local definition = WeaponConfig.Weapons[weaponId]
		local button = Instance.new("TextButton")
		button.Name = weaponId .. "Button"
		button.Text = if definition then definition.DisplayName else weaponId
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.BackgroundColor3 = Color3.fromRGB(64, 56, 52)
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(18 + (index - 1) * 216, 228)
		button.Size = UDim2.fromOffset(204, 44)
		button.Parent = panel
		button.MouseButton1Click:Connect(function()
			if currentPhase ~= "Lobby" or isReady then
				return
			end
			selectLoadoutRemote:FireServer({
				PrimaryWeapon = weaponId,
			})
		end)
		weaponButtons[weaponId] = button
	end

	local cosmeticLabel = Instance.new("TextLabel")
	cosmeticLabel.Name = "CosmeticLabel"
	cosmeticLabel.Text = "PAINT PRESET - CLICK TO BUY OR EQUIP"
	cosmeticLabel.Font = Enum.Font.GothamBold
	cosmeticLabel.TextSize = 13
	cosmeticLabel.TextColor3 = Color3.fromRGB(180, 174, 164)
	cosmeticLabel.BackgroundTransparency = 1
	cosmeticLabel.Position = UDim2.fromOffset(18, 282)
	cosmeticLabel.Size = UDim2.fromOffset(644, 22)
	cosmeticLabel.TextXAlignment = Enum.TextXAlignment.Left
	cosmeticLabel.Parent = panel

	local cosmeticIds = { "Default", "Scavenger", "SaltRunner", "WarRig" }
	for index, cosmeticId in cosmeticIds do
		local definition = ProgressionConfig.Cosmetics[cosmeticId]
		local button = Instance.new("TextButton")
		button.Name = cosmeticId .. "Button"
		button.Text = if definition
			then string.format("%s\n%d CREDITS", definition.Name, definition.Cost)
			else cosmeticId
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.TextWrapped = true
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.BackgroundColor3 = if definition
			then definition.PrimaryColor
			else Color3.fromRGB(64, 56, 52)
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(18 + (index - 1) * 162, 308)
		button.Size = UDim2.fromOffset(150, 54)
		button.Parent = panel
		button.MouseButton1Click:Connect(function()
			if currentPhase ~= "Lobby" or isReady then
				return
			end
			task.spawn(function()
				pcall(function()
					purchaseCosmetic:InvokeServer(cosmeticId)
				end)
			end)
		end)
		cosmeticButtons[cosmeticId] = button
	end

	local rosterLabel = Instance.new("TextLabel")
	rosterLabel.Name = "Roster"
	rosterLabel.Text = "Waiting for ready players..."
	rosterLabel.Font = Enum.Font.GothamMedium
	rosterLabel.TextSize = 14
	rosterLabel.TextColor3 = Color3.fromRGB(238, 220, 189)
	rosterLabel.BackgroundTransparency = 1
	rosterLabel.Position = UDim2.fromOffset(18, 374)
	rosterLabel.Size = UDim2.fromOffset(644, 62)
	rosterLabel.TextXAlignment = Enum.TextXAlignment.Left
	rosterLabel.TextYAlignment = Enum.TextYAlignment.Top
	rosterLabel.TextWrapped = true
	rosterLabel.Parent = panel

	local readyButton = Instance.new("TextButton")
	readyButton.Name = "ReadyButton"
	readyButton.Text = "READY FOR RUN"
	readyButton.Font = Enum.Font.GothamBold
	readyButton.TextSize = 17
	readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	readyButton.BackgroundColor3 = Color3.fromRGB(184, 73, 42)
	readyButton.BorderSizePixel = 0
	readyButton.Position = UDim2.fromOffset(18, 452)
	readyButton.Size = UDim2.fromOffset(644, 50)
	readyButton.Parent = panel

	local function refresh()
		for classId, button in classButtons do
			local selected = classId == selectedClass
			button.BackgroundColor3 = if selected
				then Color3.fromRGB(184, 73, 42)
				else Color3.fromRGB(64, 56, 52)
			button.AutoButtonColor = currentPhase == "Lobby" and not isReady
		end
		for weaponId, button in weaponButtons do
			button.BackgroundColor3 = if weaponId == selectedPrimary
				then Color3.fromRGB(184, 73, 42)
				else Color3.fromRGB(64, 56, 52)
			button.AutoButtonColor = currentPhase == "Lobby" and not isReady
		end
		for cosmeticId, button in cosmeticButtons do
			local definition = ProgressionConfig.Cosmetics[cosmeticId]
			local unlocked = profileData
				and profileData.UnlockedCosmetics
				and profileData.UnlockedCosmetics[cosmeticId] == true
			button.Text = if definition
				then string.format(
					"%s\n%s",
					definition.Name,
					if cosmeticId == selectedCosmetic
						then "EQUIPPED"
						elseif unlocked then "OWNED"
						else string.format("%d CREDITS", definition.Cost)
				)
				else cosmeticId
			button.BorderSizePixel = if cosmeticId == selectedCosmetic then 3 else 0
			button.BorderColor3 = Color3.fromRGB(255, 255, 255)
			button.AutoButtonColor = currentPhase == "Lobby" and not isReady
		end
		readyButton.Text = if isReady then "READY — CLICK TO UNREADY" else "READY FOR RUN"
		readyButton.BackgroundColor3 = if isReady
			then Color3.fromRGB(42, 150, 73)
			else Color3.fromRGB(184, 73, 42)
		if profileData then
			profileLabel.Text = string.format(
				"Credits: %d  |  Wins: %d  |  Races: %d  |  Mastery: %d",
				profileData.Credits or 0,
				profileData.Wins or 0,
				profileData.Races or 0,
				(profileData.Mastery and profileData.Mastery[selectedClass]) or 0
			)
		end
		gui.Enabled = currentPhase == "Lobby" or currentPhase == "Countdown"
	end

	readyButton.MouseButton1Click:Connect(function()
		if currentPhase ~= "Lobby" and currentPhase ~= "Countdown" then
			return
		end
		setReadyRemote:FireServer(not isReady)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and input.KeyCode == Enum.KeyCode.G
			and (currentPhase == "Lobby" or currentPhase == "Countdown")
		then
			gui.Enabled = not gui.Enabled
		end
	end)

	progressionUpdatedRemote.OnClientEvent:Connect(function(profile: any)
		profileData = profile
		if profile and typeof(profile.EquippedClass) == "string" then
			selectedClass = profile.EquippedClass
		end
		if profile and typeof(profile.EquippedWeapon) == "string" then
			selectedPrimary = profile.EquippedWeapon
		end
		if profile and typeof(profile.EquippedCosmetic) == "string" then
			selectedCosmetic = profile.EquippedCosmetic
		end
		refresh()
	end)

	lobbyStatusRemote.OnClientEvent:Connect(function(status: any)
		if typeof(status) ~= "table" then
			return
		end
		local lines = {
			string.format(
				"Ready humans: %d/%d minimum (%d maximum)  |  %d AI rivals  |  %d total",
				status.ReadyCount or 0,
				status.MinPlayers or 1,
				status.MaxPlayers or 4,
				status.AIPlayers or 2,
				status.TotalCompetitors or 3
			),
		}
		if typeof(status.Players) == "table" then
			for _, entry in status.Players do
				table.insert(
					lines,
					string.format(
						"%s — %s — %s",
						entry.Name or "Player",
						entry.ClassId or "Ute",
						if entry.Ready then "READY" else "CHOOSING"
					)
				)
				if entry.UserId == localPlayer.UserId then
					isReady = entry.Ready == true
					selectedClass = entry.ClassId or selectedClass
				end
			end
		end
		rosterLabel.Text = table.concat(lines, "\n")
		refresh()
	end)

	sessionStateRemote.OnClientEvent:Connect(function(newPhase: string, data: any)
		currentPhase = newPhase
		if newPhase == "Countdown" and typeof(data) == "number" then
			instruction.Text = string.format("Run starts in %d — unready to cancel", data)
		elseif newPhase == "Lobby" then
			instruction.Text = "Choose a convoy. Your class locks when you ready."
		elseif newPhase == "InRun" then
			instruction.Text = "Loadout locked for this run"
		end
		refresh()
	end)

	task.spawn(function()
		local success, result = pcall(function()
			return getPlayerData:InvokeServer()
		end)
		if success and typeof(result) == "table" then
			profileData = result
			selectedClass = result.EquippedClass or selectedClass
			selectedPrimary = result.EquippedWeapon or selectedPrimary
			selectedCosmetic = result.EquippedCosmetic or selectedCosmetic
			refresh()
		end
	end)
	refresh()
end

return GarageController
