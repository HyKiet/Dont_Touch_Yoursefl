--!strict
--[[ CoreService — Pool collectible và nhặt bằng khoảng cách server.
	Match gọi start/step/clear. PlayerState giữ số Core của mỗi người trong trận. ]]
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.GameConfig)
local ReplayMath = require(Shared.ReplayMath)
local Map = require(script.Parent.MapService)
local States = require(script.Parent.PlayerStateService)
local Telemetry = require(script.Parent.TelemetryService)
local CoreService = {}
local pool: { any } = {}
local random = Random.new()
local nextSpawn = 0
local folder: Folder?

-- Tạo 8 Core trước gameplay; mỗi lần spawn chỉ đổi Parent/CFrame.
function CoreService.start(now: number)
	local createdFolder = Instance.new("Folder")
	createdFolder.Name, createdFolder.Parent = "MatchCores", workspace
	folder = createdFolder
	for index = 1, Config.MaxActiveCores do
		local core = Instance.new("Part")
		core.Name, core.Shape, core.Size =
			"Core" .. index, Enum.PartType.Ball, Vector3.new(2.5, 2.5, 2.5)
		core.Anchored, core.CanCollide, core.CanTouch = true, false, false
		core.Material, core.Color = Enum.Material.Neon, Color3.fromRGB(90, 255, 205)
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Parent = core.Color, 1, 10, core
		pool[index] = { model = core, spawnIndex = 0 }
	end
	nextSpawn = now + random:NextNumber(Config.CoreSpawnIntervalMin, Config.CoreSpawnIntervalMax)
end

local function spawnCore()
	local free, occupied = nil, {}
	for _, core in pool do
		if core.spawnIndex == 0 then
			free = core
		else
			occupied[core.spawnIndex] = true
		end
	end
	if not free then
		return
	end
	local available = {}
	for index in Map.getCoreSpawns() do
		if not occupied[index] then
			table.insert(available, index)
		end
	end
	if #available == 0 then
		return
	end
	local index = available[random:NextInteger(1, #available)]
	free.spawnIndex = index
	free.model.Position, free.model.Parent = Map.getCoreSpawns()[index], folder
end

local function collect(core: any)
	for player, entry in States.getAll() do
		if entry.state ~= "ALIVE" or entry.validPosition == false then
			continue
		end
		if
			ReplayMath.distanceSquared(entry.acceptedFrame.Position, core.model.Position)
			> Config.CorePickupRadius ^ 2
		then
			continue
		end
		-- Không yield giữa đánh dấu đã nhặt và grant: hai người không thể nhận cùng Core.
		core.spawnIndex, core.model.Parent = 0, nil
		entry.cores += 1
		Telemetry.event(player, "CoreCollected", entry.cores)
		break
	end
end

-- Nhịp spawn 2–4s, tối đa 8; xét người sống tại vị trí đã được kiểm tra.
function CoreService.step(now: number)
	if now >= nextSpawn then
		spawnCore()
		nextSpawn = now
			+ random:NextNumber(Config.CoreSpawnIntervalMin, Config.CoreSpawnIntervalMax)
	end
	for _, core in pool do
		if core.spawnIndex ~= 0 then
			collect(core)
		end
	end
end
-- Huỷ cả Core đang nằm ngoài workspace, tránh pool rò giữa các trận.
function CoreService.clear()
	for _, core in pool do
		core.model:Destroy()
	end
	table.clear(pool)
	if folder then
		folder:Destroy()
		folder = nil
	end
end
return CoreService
