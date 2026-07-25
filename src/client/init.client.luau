--!strict

local CameraController = require(script.Controllers.CameraController)
local HUDController = require(script.Controllers.HUDController)
local RunResultController = require(script.Controllers.RunResultController)
local VehicleController = require(script.Controllers.VehicleController)
local WeaponController = require(script.Controllers.WeaponController)

VehicleController.Start()
CameraController.Start()
WeaponController.Start()
HUDController.Start()
RunResultController.Start()

print("[Hoonanga] Client ready")
