--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local BuildConfig = require(ReplicatedStorage.Shared.Config.BuildConfig)
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

-- The compass is camera-relative: straight up on the dial is wherever the
-- driver is looking, so a needle at the top means "it is in front of you".
-- Positive degrees are clockwise both here and in GuiObject.Rotation, so the
-- bearing is the needle rotation with no conversion.
local function bearingDegrees(facing: Vector3, target: Vector3): number?
	local forward = Vector3.new(facing.X, 0, facing.Z)
	local toward = Vector3.new(target.X, 0, target.Z)
	if forward.Magnitude < 1e-4 or toward.Magnitude < 1e-4 then
		return nil
	end
	forward = forward.Unit
	toward = toward.Unit
	local right = forward:Cross(Vector3.yAxis)
	return math.deg(math.atan2(toward:Dot(right), toward:Dot(forward)))
end

local function findFinishLine(): Model?
	local world = workspace:FindFirstChild("HoonangaWorld")
	local gate = if world then world:FindFirstChild("FinishLine") else nil
	return if gate and gate:IsA("Model") then gate else nil
end

-- One needle: a bar riding the rim of the dial, held in a full-size
-- transparent frame so setting Rotation swings it around the dial's centre
-- rather than spinning the bar on the spot.
local function makeNeedle(compass: Frame, name: string, color: Color3): Frame
	local pivot = Instance.new("Frame")
	pivot.Name = name
	pivot.AnchorPoint = Vector2.new(0.5, 0.5)
	pivot.Position = UDim2.fromScale(0.5, 0.5)
	pivot.Size = UDim2.fromScale(1, 1)
	pivot.BackgroundTransparency = 1
	pivot.Parent = compass

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 7)
	bar.Size = UDim2.fromOffset(7, 26)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = pivot

	return pivot
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
	versionTag.Text =
		string.format("Hoonanga v%s [M%d]", BuildConfig.Version, BuildConfig.Milestone)
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

	-- Wayfinder. Two needles on one camera-relative dial: where the road goes
	-- next, and - once the run has become a race - where the finish is. On a
	-- road that bends through canyons neither is guessable from the horizon.
	local compass = Instance.new("Frame")
	compass.Name = "Compass"
	compass.AnchorPoint = Vector2.new(0.5, 1)
	compass.Position = UDim2.new(0.5, 0, 1, -38)
	compass.Size = UDim2.fromOffset(132, 132)
	compass.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	compass.BackgroundTransparency = 0.28
	compass.BorderSizePixel = 0
	compass.Parent = gui

	local compassCorner = Instance.new("UICorner")
	compassCorner.CornerRadius = UDim.new(0.5, 0)
	compassCorner.Parent = compass

	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(8, 8)
	hub.BackgroundColor3 = Color3.fromRGB(238, 220, 189)
	hub.BorderSizePixel = 0
	hub.Parent = compass

	local roadNeedle = makeNeedle(compass, "RoadNeedle", CROSSHAIR_READY)
	local finishNeedle = makeNeedle(compass, "FinishNeedle", Color3.fromRGB(245, 245, 240))
	finishNeedle.Visible = false

	local compassCaption = makeLabel(
		gui,
		"CompassCaption",
		UDim2.new(0.5, -80, 1, -30),
		UDim2.fromOffset(160, 22),
		13,
		Enum.TextXAlignment.Center
	)
	compassCaption.Text = "ROAD AHEAD"

	-- Green flag: the run has stopped being open-ended and is now a race.
	local flagBanner = Instance.new("Frame")
	flagBanner.Name = "FinalStretch"
	flagBanner.AnchorPoint = Vector2.new(0.5, 0)
	flagBanner.Position = UDim2.new(0.5, 0, 0, 92)
	flagBanner.Size = UDim2.fromOffset(560, 60)
	flagBanner.BackgroundColor3 = Color3.fromRGB(15, 18, 19)
	flagBanner.BackgroundTransparency = 0.2
	flagBanner.BorderSizePixel = 0
	flagBanner.Visible = false
	flagBanner.Parent = gui

	local flagPole = Instance.new("Frame")
	flagPole.Name = "FlagPole"
	flagPole.Position = UDim2.fromOffset(22, 10)
	flagPole.Size = UDim2.fromOffset(4, 40)
	flagPole.BackgroundColor3 = Color3.fromRGB(216, 210, 198)
	flagPole.BorderSizePixel = 0
	flagPole.Parent = flagBanner

	local flagCloth = Instance.new("Frame")
	flagCloth.Name = "FlagCloth"
	flagCloth.Position = UDim2.fromOffset(26, 10)
	flagCloth.Size = UDim2.fromOffset(46, 28)
	flagCloth.BackgroundColor3 = Color3.fromRGB(46, 196, 92)
	flagCloth.BorderSizePixel = 0
	flagCloth.Parent = flagBanner

	local flagText = Instance.new("TextLabel")
	flagText.Name = "FlagText"
	flagText.BackgroundTransparency = 1
	flagText.Position = UDim2.fromOffset(88, 0)
	flagText.Size = UDim2.new(1, -108, 1, 0)
	flagText.Font = Enum.Font.GothamBold
	flagText.TextColor3 = Color3.fromRGB(46, 196, 92)
	flagText.TextSize = 24
	flagText.TextXAlignment = Enum.TextXAlignment.Left
	flagText.Text = "YOU'RE IN THE FINAL STRETCH, RACE FOR THE FINISH!"
	flagText.TextScaled = false
	flagText.Parent = flagBanner

	local flagBannerUntil = 0
	local finishPathDistance: number? = nil

	local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
	local finalStretchRemote = remotes:WaitForChild("FinalStretchStarted") :: RemoteEvent
	finalStretchRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		finishPathDistance = payload.FinishDistance
		flagBannerUntil = os.clock() + payload.BannerSeconds
	end)

	RunService.RenderStepped:Connect(function()
		local vehicle = currentVehicle()
		local visible = vehicle ~= nil
		status.Visible = visible
		convoy.Visible = visible
		ammo.Visible = visible
		weapon.Visible = visible
		crosshair.Visible = visible
		compass.Visible = visible
		compassCaption.Visible = visible
		-- The call-out is on its own timer rather than tied to the vehicle:
		-- being told the race is on matters just as much while spectating.
		flagBanner.Visible = os.clock() < flagBannerUntil
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

		local camera = workspace.CurrentCamera
		local facing = if camera
			then camera.CFrame.LookVector
			else vehicle.PrimaryPart.CFrame.LookVector
		-- RoadForward is published by RoadService against the road's own
		-- spine, so it keeps pointing down the road through a bend rather
		-- than wherever the car is currently slewed.
		local roadForward = vehicle:GetAttribute("RoadForward")
		local roadBearing = if typeof(roadForward) == "Vector3"
			then bearingDegrees(facing, roadForward :: Vector3)
			else nil
		roadNeedle.Visible = roadBearing ~= nil
		roadNeedle.Rotation = roadBearing or 0

		local finishGate = findFinishLine()
		local finishBearing = if finishGate
			then bearingDegrees(
				facing,
				finishGate:GetPivot().Position - vehicle.PrimaryPart.Position
			)
			else nil
		finishNeedle.Visible = finishBearing ~= nil
		finishNeedle.Rotation = finishBearing or 0

		if finishPathDistance then
			compassCaption.Text =
				string.format("FINISH  %.2f km", math.max(0, finishPathDistance - distance) / 1000)
			compassCaption.TextColor3 = Color3.fromRGB(245, 245, 240)
		else
			compassCaption.Text = "ROAD AHEAD"
			compassCaption.TextColor3 = Color3.fromRGB(238, 220, 189)
		end

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
		elseif maxFuel > 0 and fuel / maxFuel <= AudioConfig.LowFuelRatio then
			warning.Visible = true
			warning.Text = "LOW FUEL"
		elseif vehicle:GetAttribute("Bogged") == true then
			warning.Visible = true
			warning.Text = "BOGGED - KEEP POWER ON"
		else
			warning.Visible = false
		end
	end)
end

return HUDController
