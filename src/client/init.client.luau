--!strict

local CameraController = require(script.Controllers.CameraController)
local HUDController = require(script.Controllers.HUDController)
local VehicleController = require(script.Controllers.VehicleController)
local WeaponController = require(script.Controllers.WeaponController)

VehicleController.Start()
CameraController.Start()
WeaponController.Start()
HUDController.Start()

print("[Hoonanga] Client ready")
