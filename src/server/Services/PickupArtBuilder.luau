--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PickupArtConfig = require(ReplicatedStorage.Shared.Config.PickupArtConfig)

type PrimitiveStyle = {
	Color: Color3,
	Shape: Enum.PartType,
	Size: Vector3,
}

local PRIMITIVE_STYLES: { [string]: PrimitiveStyle } = {
	Rockets = {
		Color = Color3.fromRGB(96, 108, 150),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(3, 3, 5.4),
	},
	FlameFuel = {
		Color = Color3.fromRGB(214, 118, 38),
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 3.4, 3),
	},
	Throwables = {
		Color = Color3.fromRGB(150, 176, 92),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(3.2, 2.8, 3.2),
	},
	Repair = {
		Color = Color3.fromRGB(228, 228, 222),
		Shape = Enum.PartType.Block,
		Size = Vector3.new(4, 3, 4),
	},
}

local CRATE_GREEN = Color3.fromRGB(91, 91, 67)
local CRATE_EDGE = Color3.fromRGB(56, 54, 38)
local CRATE_INSIDE = Color3.fromRGB(30, 27, 20)
local BRASS = Color3.fromRGB(205, 153, 77)
local JERRYCAN_RED = Color3.fromRGB(211, 49, 39)
local JERRYCAN_SHADE = Color3.fromRGB(155, 35, 30)
local SPOUT_YELLOW = Color3.fromRGB(244, 185, 32)
local SPOUT_COLLAR = Color3.fromRGB(38, 29, 28)

local function addPart(
	root: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = size.Magnitude > 1
	part.Size = size
	part.CFrame = root.CFrame * offset
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = root
	return part
end

local function addTexture(part: BasePart, textureId: string, face: Enum.NormalId)
	if not string.match(textureId, "^rbxassetid://%d+$") then
		return
	end

	local decal = Instance.new("Decal")
	decal.Name = "ReferenceArtwork"
	decal.Face = face
	decal.Texture = textureId
	decal.Parent = part
end

local function buildAmmoCrate(root: BasePart)
	root:SetAttribute("PickupArtStyle", "OpenAmmoCrate")
	root:SetAttribute("PickupTextureReady", true)

	addPart(
		root,
		"CrateFloor",
		Vector3.new(4.2, 0.3, 3),
		CFrame.new(0, -1.05, 0),
		CRATE_GREEN,
		Enum.Material.Metal
	)
	addPart(
		root,
		"CrateInterior",
		Vector3.new(3.55, 0.18, 2.35),
		CFrame.new(0, -0.77, 0),
		CRATE_INSIDE,
		Enum.Material.SmoothPlastic
	)
	addPart(
		root,
		"CrateLeftWall",
		Vector3.new(0.32, 2.25, 3),
		CFrame.new(-1.94, 0, 0),
		CRATE_GREEN,
		Enum.Material.Metal
	)
	addPart(
		root,
		"CrateRightWall",
		Vector3.new(0.32, 2.25, 3),
		CFrame.new(1.94, 0, 0),
		CRATE_GREEN,
		Enum.Material.Metal
	)
	local front = addPart(
		root,
		"CrateFrontWall",
		Vector3.new(3.58, 2.25, 0.32),
		CFrame.new(0, 0, -1.34),
		CRATE_GREEN,
		Enum.Material.Metal
	)
	addPart(
		root,
		"CrateBackWall",
		Vector3.new(3.58, 2.25, 0.32),
		CFrame.new(0, 0, 1.34),
		CRATE_GREEN,
		Enum.Material.Metal
	)
	addTexture(front, PickupArtConfig.AmmoTextureId, Enum.NormalId.Front)

	addPart(
		root,
		"OpenLid",
		Vector3.new(4.15, 0.22, 2.45),
		CFrame.new(0, 1.67, 1.92) * CFrame.Angles(math.rad(-42), 0, 0),
		CRATE_GREEN,
		Enum.Material.Metal
	)
	addPart(
		root,
		"LidDarkPanel",
		Vector3.new(3.5, 0.08, 1.86),
		CFrame.new(0, 1.56, 1.78) * CFrame.Angles(math.rad(-42), 0, 0),
		CRATE_INSIDE,
		Enum.Material.SmoothPlastic
	)

	for _, x in { -1.05, 1.05 } do
		addPart(
			root,
			if x < 0 then "HandlePostLeft" else "HandlePostRight",
			Vector3.new(0.24, 0.9, 0.24),
			CFrame.new(x, 0.6, -1.58),
			CRATE_EDGE,
			Enum.Material.Metal
		)
	end
	addPart(
		root,
		"CarryGrip",
		Vector3.new(2.35, 0.24, 0.24),
		CFrame.new(0, 1.02, -1.58),
		CRATE_EDGE,
		Enum.Material.Metal
	)

	for index = 1, 6 do
		local x = -1.35 + (index - 1) * 0.54
		addPart(
			root,
			string.format("AmmoRound%02d", index),
			Vector3.new(0.92, 0.22, 0.22),
			CFrame.new(x, -0.42 + (index % 2) * 0.14, -0.12) * CFrame.Angles(0, math.rad(18), 0),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end

	for index = 1, 5 do
		local x = 0.45 + (index - 1) * 0.3
		local y = 0.45 - (index - 1) * 0.34
		addPart(
			root,
			string.format("HangingRound%02d", index),
			Vector3.new(0.78, 0.2, 0.2),
			CFrame.new(x, y, -1.58) * CFrame.Angles(0, 0, math.rad(72)),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		addPart(
			root,
			string.format("AmmoLink%02d", index),
			Vector3.new(0.26, 0.16, 0.12),
			CFrame.new(x - 0.15, y + 0.12, -1.57),
			CRATE_EDGE,
			Enum.Material.Metal
		)
	end
end

local function buildFuelJerrycan(root: BasePart)
	root:SetAttribute("PickupArtStyle", "FuelJerrycan")
	root:SetAttribute("PickupTextureReady", true)

	local body = addPart(
		root,
		"CanBody",
		Vector3.new(3.5, 3.35, 2),
		CFrame.new(0, -0.35, 0),
		JERRYCAN_RED,
		Enum.Material.SmoothPlastic
	)
	addTexture(body, PickupArtConfig.FuelTextureId, Enum.NormalId.Front)
	addPart(
		root,
		"CanShoulder",
		Vector3.new(3.05, 0.65, 1.9),
		CFrame.new(-0.1, 1.62, 0),
		JERRYCAN_RED,
		Enum.Material.SmoothPlastic
	)

	for _, angle in { -35, 35 } do
		addPart(
			root,
			if angle < 0 then "EmbossLeft" else "EmbossRight",
			Vector3.new(0.16, 2.55, 0.08),
			CFrame.new(0, -0.4, -1.04) * CFrame.Angles(0, 0, math.rad(angle)),
			JERRYCAN_SHADE,
			Enum.Material.SmoothPlastic
		)
	end

	for _, x in { -0.9, 0.55 } do
		addPart(
			root,
			if x < 0 then "CanHandlePostLeft" else "CanHandlePostRight",
			Vector3.new(0.3, 0.9, 0.55),
			CFrame.new(x, 1.98, 0),
			JERRYCAN_RED,
			Enum.Material.SmoothPlastic
		)
	end
	addPart(
		root,
		"CanHandleGrip",
		Vector3.new(1.75, 0.3, 0.55),
		CFrame.new(-0.18, 2.38, 0),
		JERRYCAN_RED,
		Enum.Material.SmoothPlastic
	)

	addPart(
		root,
		"SpoutCollar",
		Vector3.new(0.72, 0.72, 0.72),
		CFrame.new(1.42, 1.82, 0) * CFrame.Angles(0, 0, math.rad(43)),
		SPOUT_COLLAR,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	addPart(
		root,
		"SpoutTube",
		Vector3.new(2.45, 0.5, 0.5),
		CFrame.new(2.25, 2.66, 0) * CFrame.Angles(0, 0, math.rad(48)),
		SPOUT_YELLOW,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	addPart(
		root,
		"BreatherCap",
		Vector3.new(0.5, 0.38, 0.5),
		CFrame.new(-1.35, 1.92, 0) * CFrame.Angles(0, 0, math.rad(90)),
		SPOUT_YELLOW,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
end

local function buildPrimitive(root: BasePart, pickupType: string)
	local style = PRIMITIVE_STYLES[pickupType]
	if not style then
		error(string.format("No pickup art style defined for %q", pickupType))
	end
	root:SetAttribute("PickupArtStyle", "Primitive")
	addPart(
		root,
		"PickupBody",
		style.Size,
		if style.Shape == Enum.PartType.Cylinder
			then CFrame.Angles(0, 0, math.rad(90))
			else CFrame.identity,
		style.Color,
		Enum.Material.Metal,
		style.Shape
	)
end

local PickupArtBuilder = {}

function PickupArtBuilder.Create(
	parent: Instance,
	cframe: CFrame,
	pickupType: string,
	amount: number
): BasePart
	local root = Instance.new("Part")
	root.Name = pickupType .. "Pickup"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = true
	root.CastShadow = false
	root.Transparency = 1
	root.Size = if pickupType == "Fuel"
		then Vector3.new(5.8, 5.6, 3.2)
		elseif pickupType == "Bullets" then Vector3.new(4.8, 5, 3.6)
		else Vector3.new(4, 4, 5.8)
	root.CFrame = cframe
	root:SetAttribute("PickupType", pickupType)
	root:SetAttribute("PickupAmount", amount)
	root.Parent = parent

	if pickupType == "Fuel" then
		buildFuelJerrycan(root)
	elseif pickupType == "Bullets" then
		buildAmmoCrate(root)
	else
		buildPrimitive(root, pickupType)
	end

	CollectionService:AddTag(root, "HoonangaPickup")
	return root
end

return PickupArtBuilder
