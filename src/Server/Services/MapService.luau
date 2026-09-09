--!strict
--[[ MapService — Đọc map có sẵn trong Workspace để người làm map tự trang trí.
	Main gọi build để cache marker; không tạo lại/xoá map khi bắt đầu hay kết thúc trận.
	Map thuộc file place trong Studio, code vẫn đồng bộ một chiều qua Rojo. ]]
local Config = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local MapService = {}
local arenaSpawns: { CFrame } = {}
local coreSpawns: { Vector3 } = {}
local bestBoard: TextLabel?
local lobbySpawn: BasePart
local arenaFloor: BasePart

local function requiredPart(map: Instance, name: string): BasePart
	local object = map:FindFirstChild(name, true)
	assert(object and object:IsA("BasePart"), "[MapService] Missing map marker: " .. name)
	return object :: BasePart
end

local function cacheMarker(object: Instance)
	if not object:IsA("BasePart") then
		return
	end
	if object.Name == "PlayerSpawn" then
		local index = object:GetAttribute("SpawnIndex")
		assert(
			type(index) == "number" and index % 1 == 0 and index >= 1 and index <= Config.MaxPlayers,
			"[MapService] PlayerSpawn needs SpawnIndex 1..12"
		)
		assert(not arenaSpawns[index], "[MapService] Duplicate SpawnIndex " .. index)
		arenaSpawns[index] = object.CFrame + Vector3.yAxis * Config.PlayerSpawnMarkerHeight
	elseif object.Name:match("^CoreSpawnPoint%d+$") then
		table.insert(coreSpawns, object.Position + Vector3.yAxis * Config.CoreSpawnMarkerHeight)
	end
end

-- Cache map hiện có; trả map nhưng Main không sở hữu và không được xoá nó.
function MapService.build(): Instance
	local legacyMap = workspace:FindFirstChild("ClonePrototypeMap")
	local arena = workspace:FindFirstChild("Arena") or legacyMap
	local lobby = workspace:FindFirstChild("Lobby") or legacyMap
	assert(
		arena and lobby,
		"[MapService] Workspace needs Arena and Lobby. Open the saved map place before Play."
	)
	table.clear(arenaSpawns)
	table.clear(coreSpawns)
	-- Persistent giữ map nhỏ này khi spectate ở xa (creator-docs: Model.yaml).
	if arena:IsA("Model") then
		arena.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	if lobby:IsA("Model") then
		lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	lobbySpawn, arenaFloor = requiredPart(lobby, "LobbySpawn"), requiredPart(arena, "ArenaFloor")
	for _, object in arena:GetDescendants() do
		cacheMarker(object)
	end
	for index = 1, Config.MaxPlayers do
		assert(arenaSpawns[index], "[MapService] Missing SpawnIndex " .. index)
	end
	assert(#coreSpawns > 0, "[MapService] No CoreSpawnPoint markers")
	local board = lobby:FindFirstChild("BestScoreBoard", true)
	bestBoard = if board then board:FindFirstChildWhichIsA("TextLabel", true) else nil
	-- Bảng điểm là trang trí tuỳ chọn; xoá bảng không được làm hỏng vòng trận.
	return arena
end

-- Cập nhật khi profile load/thưởng, không quét leaderboard mỗi frame.
function MapService.refreshBoard()
	if not bestBoard then
		return
	end
	local players = game:GetService("Players"):GetPlayers()
	table.sort(players, function(first, second)
		return (first:GetAttribute("BestSurvival") or 0)
			> (second:GetAttribute("BestSurvival") or 0)
	end)
	local lines = { "SERVER BEST • SURVIVAL / CORES" }
	for index, player in players do
		if index > 6 then
			break
		end
		table.insert(
			lines,
			string.format(
				"%s   %ds / %d",
				player.DisplayName,
				math.floor(player:GetAttribute("BestSurvival") or 0),
				player:GetAttribute("BestCores") or 0
			)
		)
	end
	bestBoard.Text = table.concat(lines, "\n")
end

-- Trả CFrame pad đã cache; di chuyển pad trong Edit sẽ đổi chỗ spawn khi Play.
function MapService.getSpawn(index: number): CFrame
	return arenaSpawns[index]
end
-- Trả điểm Core do người làm map bố trí trong Workspace.
function MapService.getCoreSpawns(): { Vector3 }
	return coreSpawns
end
-- Trả spawn lobby hiện có, không bỏ qua chỉnh sửa bằng vị trí hard-code.
function MapService.getLobby(): CFrame
	return lobbySpawn.CFrame + Vector3.yAxis * Config.LobbySpawnMarkerHeight
end
-- Trả mặt sàn để kiểm tra giới hạn kể cả khi arena được xoay/di chuyển.
function MapService.getArenaFloor(): BasePart
	return arenaFloor
end
return MapService
