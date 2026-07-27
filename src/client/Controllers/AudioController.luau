--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AudioConfig = require(ReplicatedStorage.Shared.Config.AudioConfig)
local VehicleLocator = require(script.Parent.VehicleLocator)

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("HoonangaRemotes")
local playAudioRemote = remotes:WaitForChild("PlayAudioEffect") :: RemoteEvent
local weaponFiredRemote = remotes:WaitForChild("WeaponFired") :: RemoteEvent

local engineSound: Sound? = nil
local activeVehicle: Model? = nil
local lastEffectAt: { [string]: number } = {}
local lastLowFuelWarning = 0
local lastFireWarning = 0
local subtitleLabel: TextLabel? = nil
local subtitleSerial = 0

local function safeCreateSound(assetId: string, volume: number, pitch: number): Sound?
	if assetId == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = assetId
	sound.Volume = math.clamp(volume, 0, 2)
	sound.PlaybackSpeed = math.clamp(pitch, 0.25, 4)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 18
	sound.RollOffMaxDistance = 520
	return sound
end

local function showSubtitle(text: string)
	if localPlayer:GetAttribute("SubtitlesEnabled") == false or not subtitleLabel then
		return
	end
	subtitleSerial += 1
	local serial = subtitleSerial
	subtitleLabel.Text = "[ " .. text .. " ]"
	subtitleLabel.Visible = true
	task.delay(1.6, function()
		if subtitleLabel and serial == subtitleSerial then
			subtitleLabel.Visible = false
		end
	end)
end

local function playEffect(effectId: string, position: Vector3?)
	local effect = AudioConfig.Effects[effectId]
	if not effect then
		return
	end
	local now = os.clock()
	if now - (lastEffectAt[effectId] or 0) < 0.055 then
		return
	end
	lastEffectAt[effectId] = now
	local sound = safeCreateSound(effect.AssetId, effect.Volume, effect.Pitch)
	if not sound then
		return
	end

	if position then
		local emitter = Instance.new("Part")
		emitter.Name = "AudioEmitter"
		emitter.Anchored = true
		emitter.CanCollide = false
		emitter.CanQuery = false
		emitter.CanTouch = false
		emitter.Transparency = 1
		emitter.Position = position
		emitter.Parent = Workspace
		sound.Parent = emitter
		Debris:AddItem(emitter, 8)
	else
		sound.Parent = Workspace
		Debris:AddItem(sound, 8)
	end
	sound:Play()
	showSubtitle(effect.Subtitle)
end

local AudioController = {}

function AudioController.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoonangaSubtitles"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = localPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Subtitle"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -92)
	label.Size = UDim2.fromOffset(520, 38)
	label.BackgroundColor3 = Color3.fromRGB(8, 9, 10)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 17
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Visible = false
	label.Parent = gui
	subtitleLabel = label

	playAudioRemote.OnClientEvent:Connect(function(effectId: string, position: Vector3?)
		playEffect(effectId, position)
	end)
	weaponFiredRemote.OnClientEvent:Connect(function(weaponId: unknown, origin: unknown)
		if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" then
			return
		end
		local effectId = AudioConfig.WeaponEffects[weaponId]
		if effectId then
			playEffect(effectId, origin)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local vehicle = VehicleLocator.ForPlayer(localPlayer)
		if vehicle ~= activeVehicle then
			activeVehicle = vehicle
			if engineSound then
				engineSound:Destroy()
				engineSound = nil
			end

			if vehicle and vehicle.PrimaryPart then
				local sound = safeCreateSound(
					AudioConfig.EngineSoundAssetId,
					0.35,
					AudioConfig.EngineMinPitch
				)
				if sound then
					sound.Name = "EngineRPM"
					sound.Looped = true
					sound.RollOffMaxDistance = 260
					sound.Parent = vehicle.PrimaryPart
					sound:Play()
					engineSound = sound
				end
			end
		end

		if engineSound and activeVehicle and activeVehicle.PrimaryPart then
			local speed = activeVehicle.PrimaryPart.AssemblyLinearVelocity.Magnitude
			local speedRatio = math.clamp(speed / 120, 0, 1)
			local throttle = activeVehicle:GetAttribute("ServerThrottle")
			local demand = if typeof(throttle) == "number" then math.abs(throttle) else 0
			local engineLoad = math.max(speedRatio, demand * 0.82)
			engineSound.PlaybackSpeed = AudioConfig.EngineMinPitch
				+ (AudioConfig.EngineMaxPitch - AudioConfig.EngineMinPitch) * engineLoad
			engineSound.Volume = 0.28 + AudioConfig.EngineMaxVolume * engineLoad

			local now = os.clock()
			local fuel = activeVehicle:GetAttribute("Fuel")
			local maxFuel = activeVehicle:GetAttribute("MaxFuel")
			if
				typeof(fuel) == "number"
				and typeof(maxFuel) == "number"
				and maxFuel > 0
				and fuel / maxFuel <= AudioConfig.LowFuelRatio
				and now - lastLowFuelWarning >= AudioConfig.WarningRepeatSeconds
			then
				lastLowFuelWarning = now
				playEffect("LowFuelAlarm", nil)
			end
			local fireState = activeVehicle:GetAttribute("FireState")
			if
				(fireState == "Burning" or fireState == "Critical")
				and now - lastFireWarning >= AudioConfig.WarningRepeatSeconds
			then
				lastFireWarning = now
				playEffect("FireAlarm", nil)
			end
		end
	end)
end

function AudioController.PlayLocalEffect(effectId: string)
	playEffect(effectId, nil)
end

return AudioController
