-- Regression test for a race in VehicleBuilder's Creator Store asset cache.
--
-- LoadAssetAsync yields on the network. An earlier version flipped an
-- "attempted" flag *before* that yield, so a second vehicle created during
-- the fetch would skip the load, find an empty cache, and silently fall
-- back to a gray-box body. In play that meant whichever of the player ute
-- and the enemy ute lost the startup race got a box instead of the real
-- truck, while every later respawn (warm cache) got the real one.
--
-- This has to run against a cold module cache, which is why it isn't folded
-- into studio_smoke_test.luau - by the time that script builds its extra
-- vehicles, the templates are already loaded and nothing races.

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local function expect(condition, message)
	if not condition then
		error("[CONCURRENT] " .. message, 2)
	end
end

local services = ServerScriptService.Server.Services
local VehicleBuilder = require(services.VehicleBuilder)

local parent = Instance.new("Folder")
parent.Name = "ConcurrentVehicleTest"
parent.Parent = Workspace

local hasBody = {}

local function build(name: string, offsetX: number, color: Color3)
	local vehicle = VehicleBuilder.CreateUte(parent, name, CFrame.new(offsetX, 4, 0), color)
	hasBody[name] = vehicle:FindFirstChild("CreatorStoreBody") ~= nil
end

-- Both start before either can finish its asset fetch.
task.spawn(build, "ConcurrentPlayer", -40, Color3.fromRGB(184, 73, 42))
task.spawn(build, "ConcurrentEnemy", 40, Color3.fromRGB(58, 91, 122))

local deadline = os.clock() + 30
repeat
	task.wait()
until (hasBody.ConcurrentPlayer ~= nil and hasBody.ConcurrentEnemy ~= nil) or os.clock() > deadline

expect(hasBody.ConcurrentPlayer ~= nil, "player ute never finished building")
expect(hasBody.ConcurrentEnemy ~= nil, "enemy ute never finished building")
expect(
	hasBody.ConcurrentPlayer,
	"player ute built during a concurrent asset load fell back to the gray box"
)
expect(
	hasBody.ConcurrentEnemy,
	"enemy ute built during a concurrent asset load fell back to the gray box"
)

print("[CONCURRENT] PASS: both concurrently-built utes got the Creator Store body")
