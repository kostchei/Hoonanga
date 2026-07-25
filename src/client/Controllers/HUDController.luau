--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer

local CROSSHAIR_READY = Color3.fromRGB(255, 196, 92)
-- GDD 11.3: the crosshair changes when the aim point is outside the mount's
-- traverse or the muzzle is obstructed, so "why is nothing happening" is
-- answered on screen rather than by the player experimenting.
local CROSSHAIR_BLOCKED = Color3.fromRGB(255, 82, 66)
local CROSSHAIR_OUT_OF_TRAVERSE = Color3.fromRGB(128, 176, 255)

local FIRE_STATE_TEXT: { [string]: string } = {
	Heating = "HEAT RISING",
	Ignited = "ON FIRE",
	Burning = "BURNING",
	Critical = "CRITICAL - FIND MUD",
}

local function makeLabel(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	textSize: number,
	alignment: Enum.TextXAlignment
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 0.28
	label.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	label.BorderSizePixel = 0
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(238, 220, 189)
	label.TextSize = textSize
	label.TextXAlignment = alignment
	label.Text = ""
	label.Parent = parent
	return label
end

local function currentVehicle(): Model?
	return VehicleLocator.ForPlayer(localPlayer)
end

local function memberStatus(vehicle: Model): string
	if vehicle:GetAttribute("Destroyed") then
		return "DESTROYED"
	elseif vehicle:GetAttribute("OperatorAlive") == false then
		return "OPERATOR LOST"
	elseif vehicle:GetAttribute("FireState") ~= "None" then
		return "BURNING"
	elseif vehicle:GetAttribute("Bogged") == true then
		return "BOGGED"
	end
	local hull = vehicle:GetAttribute("Hull")
	local maxHull = vehicle:GetAttribute("MaxHull")
	if
		typeof(hull) == "number"
		and typeof(maxHull) == "number"
		and maxHull > 0
		and hull / maxHull < 0.55
	then
		return "DAMAGED"
	end
	return "HEALTHY"
end

local function convoySummary(vehicle: Model): string
	local convoyId = vehicle:GetAttribute("ConvoyId")
	local world = workspace:FindFirstChild("HoonangaWorld")
	local vehicles = if world then world:FindFirstChild("Vehicles") else nil
	if typeof(convoyId) ~= "string" or not vehicles then
		return ""
	end
	local members = {}
	for _, candidate in vehicles:GetChildren() do
		if candidate:IsA("Model") and candidate:GetAttribute("ConvoyId") == convoyId then
			table.insert(members, candidate)
		end
	end
	table.sort(members, function(a, b)
		return (a:GetAttribute("FormationSlot") or 99) < (b:GetAttribute("FormationSlot") or 99)
	end)
	local rows = {}
	for _, member in members do
		local marker = if member:GetAttribute("ControlledByUserId") == localPlayer.UserId
			then ">"
			else "-"
		table.insert(
			rows,
			string.format(
				"%s %s  %s",
				marker,
				string.upper(member:GetAttribute("VehicleType") or "VEHICLE"),
				memberStatus(member)
			)
		)
	end
	return table.concat(rows, "\n")
end

local HUDController = {}

function HUDController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local versionTag = Instance.new("TextLabel")
	versionTag.Name = "VersionTag"
	versionTag.AnchorPoint = Vector2.new(1, 0)
	versionTag.Position = UDim2.new(1, -22, 0, 22)
	versionTag.Size = UDim2.fromOffset(200, 24)
	versionTag.BackgroundTransparency = 0.3
	versionTag.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	versionTag.BorderSizePixel = 0
	versionTag.Font = Enum.Font.GothamBold
	versionTag.TextColor3 = Color3.fromRGB(255, 103, 65)
	versionTag.TextSize = 13
	versionTag.TextXAlignment = Enum.TextXAlignment.Center
	versionTag.Text = "Hoonanga v1.6.0 [M6]"
	versionTag.Parent = gui

	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(7, 7)
	crosshair.BackgroundColor3 = Color3.fromRGB(255, 196, 92)
	crosshair.BorderSizePixel = 0
	crosshair.Parent = gui

	local status = makeLabel(
		gui,
		"Status",
		UDim2.new(0, 22, 1, -166),
		UDim2.fromOffset(300, 136),
		18,
		Enum.TextXAlignment.Left
	)
	status.TextYAlignment = Enum.TextYAlignment.Top

	local convoy = makeLabel(
		gui,
		"Convoy",
		UDim2.new(0, 22, 1, -258),
		UDim2.fromOffset(300, 84),
		15,
		Enum.TextXAlignment.Left
	)
	convoy.TextYAlignment = Enum.TextYAlignment.Top

	local ammo = makeLabel(
		gui,
		"Ammo",
		UDim2.new(1, -242, 1, -85),
		UDim2.fromOffset(220, 55),
		26,
		Enum.TextXAlignment.Right
	)

	local weapon = makeLabel(
		gui,
		"Weapon",
		UDim2.new(1, -242, 1, -122),
		UDim2.fromOffset(220, 34),
		18,
		Enum.TextXAlignment.Right
	)

	local warning = makeLabel(
		gui,
		"Warning",
		UDim2.new(0.5, -210, 0, 34),
		UDim2.fromOffset(420, 42),
		22,
		Enum.TextXAlignment.Center
	)
	warning.TextColor3 = Color3.fromRGB(255, 103, 65)
	warning.Visible = false
	local lastTransferSerial = localPlayer:GetAttribute("ControlTransferSerial") or 0
	local transferMessageUntil = 0

	RunService.RenderStepped:Connect(function()
		local vehicle = currentVehicle()
		local visible = vehicle ~= nil
		status.Visible = visible
		convoy.Visible = visible
		ammo.Visible = visible
		weapon.Visible = visible
		crosshair.Visible = visible
		if not vehicle or not vehicle.PrimaryPart then
			warning.Visible = os.clock() < transferMessageUntil
			return
		end
		convoy.Text = convoySummary(vehicle)
		local transferSerial = localPlayer:GetAttribute("ControlTransferSerial")
		if typeof(transferSerial) == "number" and transferSerial ~= lastTransferSerial then
			lastTransferSerial = transferSerial
			transferMessageUntil = os.clock() + 1.6
		end

		local forwardSpeed = vehicle:GetAttribute("ForwardSpeed")
		local speed = if typeof(forwardSpeed) == "number"
			then math.abs(forwardSpeed)
			else vehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude
		local fuel = vehicle:GetAttribute("Fuel") or 0
		local maxFuel = vehicle:GetAttribute("MaxFuel") or 1
		local hull = vehicle:GetAttribute("Hull") or 0
		local maxHull = vehicle:GetAttribute("MaxHull") or 1
		local surface = vehicle:GetAttribute("ServerSurfaceProfile")
			or vehicle:GetAttribute("SurfaceProfile")
			or "UNKNOWN"
		-- Distance travelled is arc length along the road, published by
		-- RoadService. It used to be read straight off the world Z axis,
		-- which stopped meaning anything the moment the road started to bend.
		local runDistance = vehicle:GetAttribute("RunDistance")
		local distance = if typeof(runDistance) == "number" then math.max(0, runDistance) else 0
		local kills = localPlayer:GetAttribute("Kills") or 0
		local weaponConfig = WeaponState.GetActiveWeapon(vehicle)
		local loaded = WeaponState.GetLoaded(vehicle, weaponConfig)
		local pool = WeaponState.GetPool(vehicle, weaponConfig.AmmoPool)

		local kmh = speed * 1.234
		status.Text = string.format(
			" SPEED  %03d KM/H\n FUEL   %03d%%\n HULL   %03d%%\n KILLS  %02d\n %s  |  %.2f km",
			math.floor(kmh + 0.5),
			math.floor((fuel / maxFuel) * 100 + 0.5),
			math.floor((hull / maxHull) * 100 + 0.5),
			kills,
			string.upper(surface),
			distance / 1000
		)
		weapon.Text = weaponConfig.DisplayName
		-- Magazine-fed weapons read "loaded / reserve"; pool-fed ones have no
		-- magazine to separate out, so they show the pool alone rather than
		-- printing the same number twice.
		ammo.Text = if WeaponState.IsReloading(vehicle, weaponConfig)
			then "RELOADING"
			elseif weaponConfig.MagazineSize > 0 then string.format(
				"%02d / %03d",
				loaded,
				pool
			)
			else string.format(
				"%s  %02d",
				WeaponConfig.AmmoPools[weaponConfig.AmmoPool].DisplayName,
				pool
			)

		if vehicle:GetAttribute("MuzzleBlocked") == true then
			crosshair.BackgroundColor3 = CROSSHAIR_BLOCKED
		elseif vehicle:GetAttribute("AimOutOfTraverse") == true then
			crosshair.BackgroundColor3 = CROSSHAIR_OUT_OF_TRAVERSE
		else
			crosshair.BackgroundColor3 = CROSSHAIR_READY
		end

		-- VehicleLocator only ever returns non-destroyed vehicles, so the
		-- destroyed/run-over case is handled by RunResultController instead:
		-- by the time Destroyed is true this HUD's vehicle lookup already
		-- returns nil and the whole status block above is hidden.
		--
		-- Fire outranks fuel: running dry is a slow problem you can plan
		-- around, and burning is not.
		local fireState = vehicle:GetAttribute("FireState")
		local fireText = if typeof(fireState) == "string" then FIRE_STATE_TEXT[fireState] else nil
		if os.clock() < transferMessageUntil then
			warning.Visible = true
			warning.Text = "CONTROL TRANSFER"
		elseif fireText then
			warning.Visible = true
			warning.Text = fireText
		elseif vehicle:GetAttribute("OutOfFuel") == true then
			warning.Visible = true
			warning.Text = "OUT OF FUEL"
		else
			warning.Visible = false
		end
	end)
end

return HUDController
