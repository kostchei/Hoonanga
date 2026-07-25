--!strict

local AIService = require(script.Services.AIService)
local CollisionDamageService = require(script.Services.CollisionDamageService)
local CombatService = require(script.Services.CombatService)
local FuelService = require(script.Services.FuelService)
local PickupService = require(script.Services.PickupService)
local RemoteService = require(script.Services.RemoteService)
local RoadService = require(script.Services.RoadService)
local VehicleService = require(script.Services.VehicleService)

RemoteService.Start()
RoadService.Start()
VehicleService.Start()
PickupService.Start()
FuelService.Start()
CombatService.Start()
CollisionDamageService.Start()
AIService.Start()

print("[Hoonanga] Server ready")
