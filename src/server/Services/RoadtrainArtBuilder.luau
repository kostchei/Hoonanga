--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoadtrainArtConfig = require(ReplicatedStorage.Shared.Config.RoadtrainArtConfig)

local function validTextureId(textureId: string): boolean
	return string.match(textureId, "^rbxassetid://%d+$") ~= nil
end

local function addDecal(part: BasePart, textureId: string, face: Enum.NormalId)
	part:SetAttribute("RoadtrainTexturePanel", true)
	if not validTextureId(textureId) then
		return
	end
	local decal = Instance.new("Decal")
	decal.Name = "ReferenceArtwork"
	decal.Face = face
	decal.Texture = textureId
	decal.Parent = part
end

local function finishPart(
	vehicle: Model,
	chassis: BasePart,
	part: BasePart,
	offset: CFrame,
	paintable: boolean?
): BasePart
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	part.CastShadow = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = chassis.CFrame * offset
	part:SetAttribute("RoadtrainVisual", true)
	if paintable then
		part:SetAttribute("CosmeticPaintPart", true)
	end
	part.Parent = vehicle

	local weld = Instance.new("WeldConstraint")
	weld.Name = "ChassisWeld"
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	return part
end

local function addPart(
	vehicle: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	paintable: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	return finishPart(vehicle, chassis, part, offset, paintable) :: Part
end

local function addCylinder(
	vehicle: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = addPart(vehicle, chassis, name, size, offset, color, material, false)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function addWedge(
	vehicle: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material,
	paintable: boolean?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	return finishPart(vehicle, chassis, part, offset, paintable) :: WedgePart
end

local RoadtrainArtBuilder = {}

function RoadtrainArtBuilder.Build(vehicle: Model, chassis: BasePart, bodyColor: Color3)
	vehicle:SetAttribute("RoadtrainArtStyle", "ArmoredEightWheelRig")
	vehicle:SetAttribute("RoadtrainTextureReady", true)

	local armor = bodyColor:Lerp(Color3.fromRGB(104, 42, 35), 0.42)
	local armorDark = armor:Lerp(Color3.fromRGB(26, 24, 23), 0.35)
	local armorLight = armor:Lerp(Color3.fromRGB(163, 126, 105), 0.18)
	local inset = Color3.fromRGB(65, 61, 57)
	local blackMetal = Color3.fromRGB(31, 31, 30)
	local silver = Color3.fromRGB(125, 124, 119)
	local glass = Color3.fromRGB(19, 29, 31)

	addPart(
		vehicle,
		chassis,
		"ArmoredLowerHull",
		Vector3.new(8.75, 2.8, 22.2),
		CFrame.new(0, 1.45, 0),
		armorDark,
		Enum.Material.Metal,
		true
	)
	addPart(
		vehicle,
		chassis,
		"CabinArmor",
		Vector3.new(8.25, 4.55, 6.6),
		CFrame.new(0, 4.05, -8.4),
		armor,
		Enum.Material.Metal,
		true
	)
	addWedge(
		vehicle,
		chassis,
		"SlopedCabNose",
		Vector3.new(8.35, 3.2, 2.4),
		CFrame.new(0, 3.2, -11.35) * CFrame.Angles(0, math.rad(180), 0),
		armorDark,
		Enum.Material.Metal,
		true
	)
	local cargo = addPart(
		vehicle,
		chassis,
		"ArmoredCargoBody",
		Vector3.new(8.45, 5.65, 13.8),
		CFrame.new(0, 4.45, 3.15),
		armor,
		Enum.Material.Metal,
		true
	)
	addDecal(cargo, RoadtrainArtConfig.LeftSideTextureId, Enum.NormalId.Left)
	addDecal(cargo, RoadtrainArtConfig.RightSideTextureId, Enum.NormalId.Right)

	local front = addPart(
		vehicle,
		chassis,
		"FrontArmorPanel",
		Vector3.new(7.25, 3.1, 0.28),
		CFrame.new(0, 3.65, -12.45),
		armorLight,
		Enum.Material.Metal,
		true
	)
	addDecal(front, RoadtrainArtConfig.FrontTextureId, Enum.NormalId.Front)
	for _, x in { -2.05, 2.05 } do
		addPart(
			vehicle,
			chassis,
			if x < 0 then "DriverViewportLeft" else "DriverViewportRight",
			Vector3.new(2.65, 0.85, 0.18),
			CFrame.new(x, 5.15, -12.62),
			glass,
			Enum.Material.Glass,
			false
		)
	end
	for _, x in { -3.6, 0, 3.6 } do
		addPart(
			vehicle,
			chassis,
			"FrontArmorRib",
			Vector3.new(0.24, 3.25, 0.18),
			CFrame.new(x, 3.65, -12.64),
			armorDark,
			Enum.Material.Metal,
			true
		)
	end

	local rear = addPart(
		vehicle,
		chassis,
		"RearArmorDoor",
		Vector3.new(7.8, 4.85, 0.3),
		CFrame.new(0, 4.35, 10.18),
		armorLight,
		Enum.Material.Metal,
		true
	)
	addDecal(rear, RoadtrainArtConfig.RearTextureId, Enum.NormalId.Back)
	for _, angle in { -34, 34 } do
		addPart(
			vehicle,
			chassis,
			if angle < 0 then "RearDoorBraceLeft" else "RearDoorBraceRight",
			Vector3.new(0.22, 5.2, 0.16),
			CFrame.new(0, 4.35, 10.38) * CFrame.Angles(0, 0, math.rad(angle)),
			armorDark,
			Enum.Material.Metal,
			true
		)
	end

	local roof = addPart(
		vehicle,
		chassis,
		"CargoRoof",
		Vector3.new(8.55, 0.42, 13.9),
		CFrame.new(0, 7.45, 3.15),
		armorDark,
		Enum.Material.DiamondPlate,
		true
	)
	addDecal(roof, RoadtrainArtConfig.TopTextureId, Enum.NormalId.Top)
	for index, z in { -0.5, 5.75 } do
		addCylinder(
			vehicle,
			chassis,
			if index == 1 then "RoofHatchFront" else "RoofHatchRear",
			Vector3.new(0.34, 3.05, 3.05),
			CFrame.new(0, 7.83, z) * CFrame.Angles(0, 0, math.rad(90)),
			armorLight,
			Enum.Material.Metal
		)
	end
	for _, x in { -3.75, 3.75 } do
		addPart(
			vehicle,
			chassis,
			if x < 0 then "RoofRailLeft" else "RoofRailRight",
			Vector3.new(0.25, 0.55, 12.8),
			CFrame.new(x, 7.92, 3.15),
			armorDark,
			Enum.Material.Metal,
			true
		)
	end

	for _, side in { -1, 1 } do
		local sideName = if side < 0 then "Left" else "Right"
		local sideX = side * 4.36
		for index, z in { -1.1, 3.25, 7.55 } do
			addPart(
				vehicle,
				chassis,
				string.format("SidePanel%s%02d", sideName, index),
				Vector3.new(0.24, 4.45, 3.85),
				CFrame.new(sideX, 4.35, z),
				armorLight,
				Enum.Material.Metal,
				true
			)
			addPart(
				vehicle,
				chassis,
				string.format("SideRib%s%02d", sideName, index),
				Vector3.new(0.32, 5.05, 0.28),
				CFrame.new(side * 4.51, 4.35, z - 1.72),
				armorDark,
				Enum.Material.Metal,
				true
			)
		end
		for index, z in { -1.9, 0.15, 2.2, 4.25, 6.3, 8.35 } do
			addPart(
				vehicle,
				chassis,
				string.format("Vent%s%02d", sideName, index),
				Vector3.new(0.18, 0.32, 1.05),
				CFrame.new(side * 4.51, 6.25, z),
				inset,
				Enum.Material.Metal,
				false
			)
		end
		for level, y in { 3.05, 3.85 } do
			addCylinder(
				vehicle,
				chassis,
				string.format("SidePipe%s%02d", sideName, level),
				Vector3.new(7.2, 0.34, 0.34),
				CFrame.new(side * 4.62, y, -3.2) * CFrame.Angles(0, math.rad(90), 0),
				silver,
				Enum.Material.Metal
			)
		end
		addPart(
			vehicle,
			chassis,
			"DiamondStep" .. sideName,
			Vector3.new(0.75, 0.35, 17.5),
			CFrame.new(side * 4.72, 0.65, 1.4),
			armorDark,
			Enum.Material.DiamondPlate,
			true
		)
	end

	local axlePositions = { -8.5, -2.9, 3.2, 8.25 }
	local axleNames = { "Front", "MidFront", "MidRear", "Rear" }
	for index, z in axlePositions do
		addCylinder(
			vehicle,
			chassis,
			"Axle" .. axleNames[index],
			Vector3.new(9.6, 0.48, 0.48),
			CFrame.new(0, -1.25, z),
			blackMetal,
			Enum.Material.Metal
		)
		for _, side in { -1, 1 } do
			local sideName = if side < 0 then "L" else "R"
			local wheel = addCylinder(
				vehicle,
				chassis,
				string.format("RoadtrainWheel_%s%s", axleNames[index], sideName),
				Vector3.new(1.15, 4.05, 4.05),
				CFrame.new(side * 4.75, -1.15, z),
				Color3.fromRGB(22, 22, 22),
				Enum.Material.Rubber
			)
			wheel:SetAttribute("RoadtrainWheel", true)
			addCylinder(
				vehicle,
				chassis,
				string.format("WheelHub_%s%s", axleNames[index], sideName),
				Vector3.new(0.34, 2.05, 2.05),
				CFrame.new(side * 5.34, -1.15, z),
				silver,
				Enum.Material.Metal
			)
			addPart(
				vehicle,
				chassis,
				string.format("WheelGuard_%s%s", axleNames[index], sideName),
				Vector3.new(0.42, 0.45, 4.55),
				CFrame.new(side * 4.48, 0.9, z),
				armorDark,
				Enum.Material.Metal,
				true
			)
		end
	end

	addPart(
		vehicle,
		chassis,
		"RamBeam",
		Vector3.new(9.75, 0.75, 1.05),
		CFrame.new(0, -0.05, -12.75),
		armorDark,
		Enum.Material.Metal,
		true
	)
	for index, x in { -3.2, -1.6, 0, 1.6, 3.2 } do
		addWedge(
			vehicle,
			chassis,
			string.format("RamTooth%02d", index),
			Vector3.new(1.05, 1.2, 2.25),
			CFrame.new(x, -0.15, -13.85) * CFrame.Angles(0, math.rad(180), 0),
			armorLight,
			Enum.Material.Metal,
			true
		)
	end
	addPart(
		vehicle,
		chassis,
		"RearBumper",
		Vector3.new(9.3, 0.65, 0.85),
		CFrame.new(0, 0.15, 12.2),
		armorDark,
		Enum.Material.Metal,
		true
	)

	addPart(
		vehicle,
		chassis,
		"ForwardGunShield",
		Vector3.new(2.3, 1.35, 0.35),
		CFrame.new(-2.3, 5.9, -11.95),
		armorDark,
		Enum.Material.Metal,
		true
	)
	addPart(
		vehicle,
		chassis,
		"ForwardGunBarrel",
		Vector3.new(0.38, 0.38, 3.6),
		CFrame.new(-2.3, 5.95, -13.15),
		blackMetal,
		Enum.Material.Metal,
		false
	)
	addCylinder(
		vehicle,
		chassis,
		"RadioAntenna",
		Vector3.new(3.8, 0.12, 0.12),
		CFrame.new(3.45, 7.9, -7.4) * CFrame.Angles(0, 0, math.rad(90)),
		blackMetal,
		Enum.Material.Metal
	)
end

return RoadtrainArtBuilder
