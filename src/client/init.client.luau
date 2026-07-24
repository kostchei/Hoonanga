--!strict

local CameraController = require(script.Controllers.CameraController)
local VehicleController = require(script.Controllers.VehicleController)

VehicleController.Start()
CameraController.Start()

print("[Hoonanga] Client ready")
