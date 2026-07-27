--!strict

-- Roblox cannot publish a local PNG as part of a Luau/Rojo build. After the
-- supplied pickup artwork is uploaded through Creator Hub, paste its asset ID
-- here as "rbxassetid://123456789". The constructed geometry remains the
-- default so pickups still read correctly if either image is unavailable.
return {
	FuelTextureId = "",
	AmmoTextureId = "",
}
