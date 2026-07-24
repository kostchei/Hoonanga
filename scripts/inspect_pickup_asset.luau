local AssetService = game:GetService("AssetService")

local ASSET_ID = 6418225759

local function sortedChildren(instance)
	local children = instance:GetChildren()
	table.sort(children, function(a, b)
		if a.ClassName == b.ClassName then
			return a.Name < b.Name
		end
		return a.ClassName < b.ClassName
	end)
	return children
end

local function printTree(instance, depth)
	local indent = string.rep("  ", depth)
	local details = ""
	if instance:IsA("BasePart") then
		details = string.format(
			" size=(%.3f, %.3f, %.3f) anchored=%s collide=%s",
			instance.Size.X,
			instance.Size.Y,
			instance.Size.Z,
			tostring(instance.Anchored),
			tostring(instance.CanCollide)
		)
	elseif instance:IsA("Model") then
		local _, size = instance:GetBoundingBox()
		details = string.format(" bounds=(%.3f, %.3f, %.3f)", size.X, size.Y, size.Z)
	end

	print(
		string.format(
			"[ASSET_TREE] %s%s <%s>%s",
			indent,
			instance.Name,
			instance.ClassName,
			details
		)
	)
	for _, child in sortedChildren(instance) do
		printTree(child, depth + 1)
	end
end

local success, assetOrError = pcall(function()
	return AssetService:LoadAssetAsync(ASSET_ID)
end)
if not success then
	error(string.format("[ASSET_AUDIT] Failed to load %d: %s", ASSET_ID, tostring(assetOrError)))
end

local asset = assetOrError
-- Keep the package unparented so none of its scripts can execute during inspection.

local descendants = asset:GetDescendants()
local classCounts = {}
local scripts = {}
for _, descendant in descendants do
	classCounts[descendant.ClassName] = (classCounts[descendant.ClassName] or 0) + 1
	if descendant:IsA("LuaSourceContainer") then
		table.insert(scripts, descendant)
	end
end

print(
	string.format(
		"[ASSET_AUDIT] asset=%d descendants=%d scripts=%d",
		ASSET_ID,
		#descendants,
		#scripts
	)
)
for className, count in classCounts do
	print(string.format("[ASSET_CLASS] %s=%d", className, count))
end

printTree(asset, 0)

for _, vehicleVariant in sortedChildren(asset) do
	if vehicleVariant:IsA("Model") then
		local variantPivot = vehicleVariant:GetPivot()
		local variantFrame, variantSize = vehicleVariant:GetBoundingBox()
		print(
			string.format(
				"[ASSET_GEOMETRY] variant=%s pivot=(%.3f, %.3f, %.3f) boundsCenterLocal=(%.3f, %.3f, %.3f) bounds=(%.3f, %.3f, %.3f)",
				vehicleVariant.Name,
				variantPivot.Position.X,
				variantPivot.Position.Y,
				variantPivot.Position.Z,
				variantPivot:PointToObjectSpace(variantFrame.Position).X,
				variantPivot:PointToObjectSpace(variantFrame.Position).Y,
				variantPivot:PointToObjectSpace(variantFrame.Position).Z,
				variantSize.X,
				variantSize.Y,
				variantSize.Z
			)
		)

		local body = vehicleVariant:FindFirstChild("Body")
		if body and body:IsA("Model") then
			local bodyFrame, bodySize = body:GetBoundingBox()
			local bodyCenterLocal = variantPivot:PointToObjectSpace(bodyFrame.Position)
			print(
				string.format(
					"[ASSET_GEOMETRY] variant=%s bodyCenterLocal=(%.3f, %.3f, %.3f) bodyBounds=(%.3f, %.3f, %.3f)",
					vehicleVariant.Name,
					bodyCenterLocal.X,
					bodyCenterLocal.Y,
					bodyCenterLocal.Z,
					bodySize.X,
					bodySize.Y,
					bodySize.Z
				)
			)
			for _, bodyChild in sortedChildren(body) do
				if bodyChild:IsA("BasePart") then
					local position = variantPivot:PointToObjectSpace(bodyChild.Position)
					print(
						string.format(
							"[ASSET_GEOMETRY_PART] variant=%s part=%s local=(%.3f, %.3f, %.3f) size=(%.3f, %.3f, %.3f)",
							vehicleVariant.Name,
							bodyChild.Name,
							position.X,
							position.Y,
							position.Z,
							bodyChild.Size.X,
							bodyChild.Size.Y,
							bodyChild.Size.Z
						)
					)
				end
			end
		end

		local driverSeat = vehicleVariant:FindFirstChildWhichIsA("VehicleSeat", true)
		if driverSeat then
			local seatPosition = variantPivot:PointToObjectSpace(driverSeat.Position)
			print(
				string.format(
					"[ASSET_GEOMETRY_SEAT] variant=%s local=(%.3f, %.3f, %.3f) look=(%.3f, %.3f, %.3f)",
					vehicleVariant.Name,
					seatPosition.X,
					seatPosition.Y,
					seatPosition.Z,
					variantPivot:VectorToObjectSpace(driverSeat.CFrame.LookVector).X,
					variantPivot:VectorToObjectSpace(driverSeat.CFrame.LookVector).Y,
					variantPivot:VectorToObjectSpace(driverSeat.CFrame.LookVector).Z
				)
			)
		end
	end
end

table.sort(scripts, function(a, b)
	return a:GetFullName() < b:GetFullName()
end)
for index, sourceContainer in scripts do
	local sourceSuccess, sourceOrError = pcall(function()
		return sourceContainer.Source
	end)
	print(
		string.format(
			"[SCRIPT_META] index=%d class=%s enabled=%s path=%s",
			index,
			sourceContainer.ClassName,
			tostring(
				if sourceContainer:IsA("Script") or sourceContainer:IsA("LocalScript")
					then sourceContainer.Enabled
					else true
			),
			sourceContainer:GetFullName()
		)
	)
	if sourceSuccess then
		print(string.format("[SCRIPT_BEGIN] index=%d bytes=%d", index, #sourceOrError))
		print(sourceOrError)
		print(string.format("[SCRIPT_END] index=%d", index))
	else
		print(
			string.format("[SCRIPT_UNREADABLE] index=%d error=%s", index, tostring(sourceOrError))
		)
	end
end

print("[ASSET_AUDIT] PASS")
