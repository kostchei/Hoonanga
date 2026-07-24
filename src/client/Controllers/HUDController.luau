--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer

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

local HUDController = {}

function HUDController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

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

	local ammo = makeLabel(
		gui,
		"Ammo",
		UDim2.new(1, -242, 1, -85),
		UDim2.fromOffset(220, 55),
		26,
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

	RunService.RenderStepped:Connect(function()
		local vehicle = currentVehicle()
		local visible = vehicle ~= nil
		status.Visible = visible
		ammo.Visible = visible
		crosshair.Visible = visible
		if not vehicle or not vehicle.PrimaryPart then
			warning.Visible = false
			return
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
		local distance = math.max(0, -vehicle.PrimaryPart.Position.Z)
		local magazine = vehicle:GetAttribute("Ammo") or 0
		local reserve = vehicle:GetAttribute("ReserveAmmo") or 0
		local kills = localPlayer:GetAttribute("Kills") or 0

		status.Text = string.format(
			" SPEED  %03d\n FUEL   %03d%%\n HULL   %03d%%\n KILLS  %02d\n %s  |  %.2f km",
			math.floor(speed + 0.5),
			math.floor((fuel / maxFuel) * 100 + 0.5),
			math.floor((hull / maxHull) * 100 + 0.5),
			kills,
			string.upper(surface),
			distance / 1000
		)
		ammo.Text = if vehicle:GetAttribute("Reloading")
			then "RELOADING"
			else string.format("%02d / %03d", magazine, reserve)

		warning.Visible = vehicle:GetAttribute("OutOfFuel") == true
			or vehicle:GetAttribute("Destroyed") == true
		if vehicle:GetAttribute("Destroyed") then
			warning.Text = "VEHICLE DESTROYED"
		elseif vehicle:GetAttribute("OutOfFuel") then
			warning.Text = "OUT OF FUEL"
		end
	end)
end

return HUDController
