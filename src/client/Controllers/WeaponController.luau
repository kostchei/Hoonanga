--!strict

-- Input and feedback only. This controller decides *when the player wants to
-- shoot* and what the shot looks like; it never decides whether a shot
-- happened, what it hit, or what it cost. All of that arrives back from the
-- server, which is why local prediction here is limited to rate-limiting the
-- remote and why the tracer is drawn from the server's reported endpoint
-- rather than from a local raycast.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponState = require(ReplicatedStorage.Shared.WeaponState)
local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local fireRemote = remotes:WaitForChild("FireWeapon") :: RemoteEvent
local reloadRemote = remotes:WaitForChild("ReloadWeapon") :: RemoteEvent
local selectRemote = remotes:WaitForChild("SelectWeapon") :: RemoteEvent
local weaponFiredRemote = remotes:WaitForChild("WeaponFired") :: RemoteEvent

-- Weapon-select keys, in loadout order.
local SELECT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
}

-- Each weapon's shot reads differently at a glance: a thin bright bullet
-- tracer, a fat orange flame wash, a rocket exhaust streak.
local TRACER_STYLES: { [string]: { Color: Color3, Thickness: number, Lifetime: number } } = {
	MachineGun = { Color = Color3.fromRGB(255, 181, 74), Thickness = 0.08, Lifetime = 0.055 },
	ForwardGun = { Color = Color3.fromRGB(255, 214, 128), Thickness = 0.12, Lifetime = 0.06 },
	Pistol = { Color = Color3.fromRGB(255, 236, 190), Thickness = 0.07, Lifetime = 0.05 },
	RocketLauncher = { Color = Color3.fromRGB(226, 226, 216), Thickness = 0.2, Lifetime = 0.08 },
	Flamethrower = { Color = Color3.fromRGB(255, 126, 38), Thickness = 2.6, Lifetime = 0.09 },
	Molotov = { Color = Color3.fromRGB(214, 168, 74), Thickness = 0.3, Lifetime = 0.08 },
}

local firing = false
local lastLocalShot = 0

local function currentVehicle(): Model?
	return VehicleLocator.ForPlayer(localPlayer)
end

local function activeWeapon(vehicle: Model): WeaponConfig.WeaponConfig
	return WeaponState.GetActiveWeapon(vehicle)
end

local function drawTracer(weaponId: string, origin: Vector3, endPosition: Vector3)
	local distance = (endPosition - origin).Magnitude
	if distance <= 0.05 then
		return
	end

	local style = TRACER_STYLES[weaponId]
	if not style then
		error(string.format("No tracer style defined for weapon %q", weaponId))
	end

	local tracer = Instance.new("Part")
	tracer.Name = "LocalTracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = style.Color
	tracer.Transparency = if weaponId == "Flamethrower" then 0.45 else 0
	tracer.Size = Vector3.new(style.Thickness, style.Thickness, distance)
	tracer.CFrame = CFrame.lookAt((origin + endPosition) / 2, endPosition)
	tracer.Parent = Workspace
	Debris:AddItem(tracer, style.Lifetime)
end

local WeaponController = {}

function WeaponController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		local vehicle = currentVehicle()
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
			-- Semi-automatic weapons fire once per press rather than
			-- streaming, so the rocket and the molotov cannot be held down.
			if vehicle and not activeWeapon(vehicle).Automatic then
				fireRemote:FireServer(Workspace.CurrentCamera.CFrame.LookVector)
			end
			return
		end

		if not vehicle then
			return
		end

		if input.KeyCode == Enum.KeyCode.R then
			reloadRemote:FireServer()
			return
		end

		for slot, keyCode in SELECT_KEYS do
			if input.KeyCode == keyCode then
				local weaponId = WeaponConfig.Loadout[slot]
				if weaponId then
					selectRemote:FireServer(weaponId)
				end
				return
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		end
	end)

	weaponFiredRemote.OnClientEvent:Connect(function(weaponId, origin, endPosition)
		if
			typeof(weaponId) == "string"
			and typeof(origin) == "Vector3"
			and typeof(endPosition) == "Vector3"
		then
			drawTracer(weaponId, origin, endPosition)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not firing then
			return
		end
		local vehicle = currentVehicle()
		if not vehicle then
			return
		end

		local config = activeWeapon(vehicle)
		if not config.Automatic then
			return
		end

		-- Purely to stop the remote being called every frame for a weapon
		-- that can only fire ten times a second. The server enforces the real
		-- interval; this one is allowed to be approximate.
		local now = os.clock()
		if now - lastLocalShot < config.FireInterval then
			return
		end
		lastLocalShot = now
		fireRemote:FireServer(Workspace.CurrentCamera.CFrame.LookVector)
	end)
end

return WeaponController
