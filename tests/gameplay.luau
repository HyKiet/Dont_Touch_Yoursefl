--!strict
--[[ Kiểm thử service độc lập bằng Lune: không mở Studio hay sửa ProfileStore thật.
	Chạy: lune run tests/gameplay.luau ]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local modules = {}
local fakeGame: any = nil
local fakeWorkspace: any = nil
local function loadModule(path: string): any
	return luau.load(fs.readFile(path), { debugName = path, environment = {
		Vector3 = Vector3, Color3 = roblox.Color3, CFrame = CFrame,
		Enum = roblox.Enum,
		game = fakeGame, script = {Parent = setmetatable({}, {__index = function(_, name) return name end})},
		workspace = fakeWorkspace,
		require = function(name) return assert(modules[name], name) end,
	} })()
end
local Config = loadModule("src/Shared/GameConfig.luau")
local Math = loadModule("src/Shared/ReplayMath.luau")
modules.GameConfig, modules.ReplayMath = Config, Math
local pathsSent, downs = {}, {}
local entries = {}
modules.Packets = { Echo = { sendToAll = function(data) table.insert(pathsSent, data) end,
	 sendTo = function() end } }
modules.PlayerStateService = { getAll = function() return entries end,
	get = function(player) return entries[player] end,
	down = function(player) table.insert(downs, player); entries[player].state = "DOWNED" end,
	revive = function(player) entries[player].state = "ALIVE" end }
local playersById = {}
fakeGame = { GetService = function(_, name)
	if name == "Players" then return { GetPlayerByUserId = function(_, id) return playersById[id] end } end
	return { Shared = {GameConfig = "GameConfig", ReplayMath = "ReplayMath", Packets = "Packets"} }
end }
local Echo = loadModule("src/Server/Services/EchoService.luau")
local Recorder = loadModule("src/Server/Services/MovementRecorderService.luau")
local Revive = loadModule("src/Server/Services/ReviveService.luau")
local assertions = 0
local function check(condition: boolean, message: string)
	assert(condition, message)
	assertions += 1
end
local function player(id: number, position: Vector3): any
	local object = { UserId = id }
	playersById[id] = object
	entries[object] = { player = object, state = "ALIVE", colorIndex = id,
		acceptedFrame = CFrame.new(position), downFrame = CFrame.new(position), root = {Parent = true, Position = position},
		humanoid = { GetState = function() return { Value = 8 } end } }
	return object
end
local path = { {time = 0, frame = CFrame.new(0, 5, 0), state = 8},
	{time = 5, frame = CFrame.new(20, 5, 0), state = 3},
	{time = 10, frame = CFrame.new(20, 5, 20), state = 8} }
check((Math.sample(path, 2.5).Position - Vector3.new(10, 5, 0)).Magnitude < 0.001, "interpolation")
check(Math.sample(path, 11).Position == path[3].frame.Position, "endpoint hold")
check(Math.reward(3, 149, false, Config) == 44, "reward defeat rounding")
check(Math.reward(3, 150, true, Config) == 95, "reward victory")

local first = player(1, Vector3.new(0, 5, 0))
local second = player(2, Vector3.new(60, 5, 60))
for generation = 1, 15 do Echo.spawn(first, path, generation * 10, 1) end
check(Echo.count() == 8, "8 Echo owner cap")
for id = 2, 12 do
	local owner = if id == 2 then second else player(id, Vector3.new(id * 10, 5, 90))
	for generation = 1, 15 do Echo.spawn(owner, path, generation * 10, 1) end
end
check(Echo.count() == 96, "96 Echo server cap")
Echo.step(150)
check(entries[first].state == "DOWNED", "cross-cell Echo hit")
check(entries[second].state == "ALIVE", "far player safe")
Echo.clear()
check(Echo.count() == 0, "Echo cleanup")

entries[first].state = "ALIVE"
Recorder.start(100)
for index = 0, 100 do Recorder.step(100 + index * 0.1) end
local recorded = Recorder.take(110)
check(#recorded[first] >= 50 and #recorded[first] <= 102, "recording bounded")
check(recorded[first][#recorded[first]].time == 10, "recording exact endpoint")
Recorder.remove(first); Recorder.clear()
check(next(Recorder.take(120)) == nil, "recorder cleanup")

entries[first].acceptedFrame = CFrame.new(0, 5, 0)
entries[second].acceptedFrame, entries[second].downFrame = CFrame.new(3, 5, 0), CFrame.new(3, 5, 0)
entries[second].state = "DOWNED"
entries[second].root.Position = Vector3.new(3, 5, 0)
Revive.request(first, {targetId = 2, holding = true}, 200)
Revive.step(202.49)
check(entries[second].state == "DOWNED", "early revive rejected")
Revive.step(202.5)
check(entries[second].state == "ALIVE", "revive completes at 2.5s")
entries[second].state = "DOWNED"
Revive.request(first, {targetId = 2, holding = true}, 210)
Revive.request(first, {targetId = 2, holding = false}, 210.01)
Revive.step(213)
check(entries[second].state == "DOWNED", "release cancels immediately")
Revive.request(first, {targetId = 2, holding = true}, 220)
entries[first].acceptedFrame = CFrame.new(1, 5, 0)
Revive.step(223)
check(entries[second].state == "DOWNED", "movement cancels")
entries[first].acceptedFrame = CFrame.new(50, 5, 0)
Revive.request(first, {targetId = 2, holding = true}, 230)
Revive.step(233)
check(entries[second].state == "DOWNED", "distance spoof rejected")
Revive.clear()
entries[first].acceptedFrame = CFrame.new(0, 5, 0)
entries[second].root.Position = Vector3.new(50, 5, 0)
Revive.request(first, {targetId = 2, holding = true}, 240)
Revive.step(243)
check(entries[second].state == "DOWNED", "revive rejects ragdoll moved away from original hit")
entries[second].root.Position = Vector3.new(3, 5, 0)
Revive.request(first, {targetId = 2, holding = true}, 244)
Revive.step(247)
check(entries[second].state == "ALIVE", "revive uses current ragdoll location")
Revive.clear()
check(Revive.progress(first, 250) == 0, "revive cleanup")
print(string.format("PASS: %d gameplay assertions", assertions))

-- Đo workload thật của 96 Echo với 12 người, 20Hz; đây là Lune, không phải FPS Studio/Live.
entries[first].acceptedFrame = CFrame.new(90, 5, 90)
for owner in entries do for generation = 1, 8 do Echo.spawn(owner, path, generation * 10, 2) end end
local began = os.clock()
for index = 1, 3000 do Echo.step(150 + index * 0.05) end
print(string.format("BENCHMARK: %d echoes, 3000 ticks, %.3f ms/tick (Lune only)", Echo.count(), (os.clock() - began) * 1000 / 3000))

-- Kiểm tra PlayerState thật với character giả, không thay đổi nhân vật Studio.
modules.TelemetryService = { event = function() end, economy = function() end }
modules.MapService = { getArenaFloor = function() return { CFrame = CFrame.new(), Size = Vector3.new(200, 2, 200) } end }
modules.RagdollService = { start = function(entry) entry.ragdoll = true; entry.root.Anchored = false end, stop = function(entry) entry.ragdoll = nil end }
local States = loadModule("src/Server/Services/PlayerStateService.luau")
local root: any = { Parent = true, Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0),
	IsA = function(_, name) return name == "BasePart" end }
local humanoid: any = { Parent = true, Health = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2 }
local character: any = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return humanoid end,
	PivotTo = function(_, frame) root.CFrame, root.Position = frame, frame.Position end }
local statePlayer: any = { Character = character, UserId = 100, SetAttribute = function() end }
check(States.add(statePlayer, CFrame.new(0, 5, 0), 1, 300), "register character")
States.down(statePlayer, 301)
check(States.get(statePlayer).state == "ALIVE", "spawn protection 2s")
States.down(statePlayer, 302)
check(States.get(statePlayer).state == "DOWNED" and not root.Anchored and States.get(statePlayer).ragdoll, "down starts unanchored ragdoll")
check(humanoid.WalkSpeed == 0 and humanoid.JumpHeight == 0 and humanoid.JumpPower == 0, "both jump modes disabled")
States.revive(statePlayer, 305)
check(States.get(statePlayer).state == "ALIVE" and not root.Anchored, "revive restores movement")
States.down(statePlayer, 306)
check(States.get(statePlayer).state == "ALIVE", "revive protection 2s")
States.down(statePlayer, 307)
States.step(317, 0.05)
check(States.get(statePlayer).state == "ELIMINATED", "bleedout eliminates after 10s")
States.clear()
check(next(States.getAll()) == nil and humanoid.WalkSpeed == 16, "state cleanup restores defaults")
States.add(statePlayer, CFrame.new(0, 5, 0), 1, 400)
root.Position, root.CFrame = Vector3.new(70, 5, 0), CFrame.new(70, 5, 0)
States.step(400.05, 0.05)
check(States.get(statePlayer).validPosition == false and root.CFrame.Position.X == 0, "teleport cannot collect/record new position")
statePlayer.Character = {}
States.step(400.1, 0.05)
check(States.get(statePlayer).state == "ELIMINATED", "character reset eliminates participation")
States.clear()

-- ProfileStore adapter giả dùng để kiểm tra mutation/idempotency của RewardService thật.
local stored: any = { SchemaVersion = 1, Coins = 0, BestSurvival = 0, BestCores = 0, LastRewardId = "" }
local isActive = true
local session: any = { Data = stored, AddUserId = function() end, Reconcile = function() end,
	IsActive = function() return isActive end, EndSession = function() isActive = false end,
	OnSessionEnd = { Connect = function() end } }
local fakeStore: any = { StartSessionAsync = function() return session end }
fakeStore.Mock = fakeStore
modules.ProfileStore = { New = function() return fakeStore end }
modules.MapService = { refreshBoard = function() end }
local fakePlayers = {}
fakeGame = { GetService = function(_, name)
	if name == "Players" then return fakePlayers end
	if name == "RunService" then return { IsStudio = function() return false end } end
	if name == "ServerScriptService" then return { ServerPackages = { ProfileStore = "ProfileStore" } } end
	return { Shared = { GameConfig = "GameConfig", ReplayMath = "ReplayMath" } }
end }
local Rewards = loadModule("src/Server/Services/RewardService.luau")
local profilePlayer: any = { UserId = 100, Parent = fakePlayers, SetAttribute = function() end,
	Kick = function(message) error(message) end }
Rewards.load(profilePlayer)
local earned = Rewards.grant(profilePlayer, { cores = 3, survival = 150 }, "test:1", true)
check(earned == 95 and stored.Coins == 95, "atomic match grant")
check(Rewards.grant(profilePlayer, { cores = 3, survival = 150 }, "test:1", true) == 0, "duplicate reward rejected")
check(stored.Coins == 95 and stored.BestSurvival == 150 and stored.BestCores == 3, "best score persisted without duplicate coins")
Rewards.release(profilePlayer)
check(not isActive, "profile session released")
local studioAttributes = {}
profilePlayer.SetAttribute = function(_, name, value) studioAttributes[name] = value end
local liveServices = fakeGame.GetService
fakeGame.GetService = function(self, name)
 if name == "RunService" then return {IsStudio = function() return true end} end
 return liveServices(self, name)
end
modules.ProfileStore = nil
local StudioRewards = loadModule("src/Server/Services/RewardService.luau")
StudioRewards.load(profilePlayer)
check(studioAttributes.DataReady and studioAttributes.Coins == 0, "Studio loads without requiring ProfileStore API probe")
check(StudioRewards.grant(profilePlayer, {cores = 3, survival = 150}, "studio:1", true) == 95, "Studio grants in memory")
check(StudioRewards.grant(profilePlayer, {cores = 3, survival = 150}, "studio:1", true) == 0 and studioAttributes.Coins == 95, "Studio duplicate reward rejected")
StudioRewards.release(profilePlayer)
print(string.format("PASS TOTAL: %d gameplay and persistence assertions", assertions))

-- Chạy MatchService thật qua WAITING/COUNTDOWN/PLAYING/RESULT, các service con làm stub.
local stateHistory, snapshots = {}, {}
local grants, clears = 0, 0
local matchEntries = {}
local roster = { profilePlayer }
profilePlayer.DisplayName = "Tester"
profilePlayer.Character = { FindFirstChild = function() return {} end,
	FindFirstChildOfClass = function() return { Health = 100 } end, PivotTo = function() end }
profilePlayer.GetAttribute = function() return true end
fakePlayers.GetPlayers = function() return roster end
modules.Packets.Snapshot = { sendToAll = function(value) table.insert(snapshots, value) end, sendTo = function() end }
modules.PlayerStateService = { getAll = function() return matchEntries end,
	add = function(owner, _, index)
		matchEntries[owner] = { state = "ALIVE", colorIndex = index, cores = 0, survival = 0,
			reward = 0, bleedoutAt = 0, invulnerableUntil = 0 }; return true
	end,
	step = function(_, delta) for _, entry in matchEntries do entry.survival += delta end end,
	clear = function() table.clear(matchEntries) end }
modules.MovementRecorderService = {start = function() end, step = function() end, take = function() return {} end, clear = function() end}
modules.EchoService = {step = function() end, spawn = function() end, clear = function() clears += 1 end, count = function() return 0 end, sync = function() end}
modules.CoreService = {start = function() end, step = function() end, clear = function() end}
modules.ReviveService = {step = function() end, clear = function() end, progress = function() return 0 end}
modules.RewardService = {grant = function() grants += 1; return 5 end}
modules.MapService = {getSpawn = function() return CFrame.new() end, getLobby = function() return CFrame.new() end}
fakeWorkspace = { SetAttribute = function(_, name, value) if name == "MatchState" then table.insert(stateHistory, value) end end }
fakeGame = {GetService = function(_, name)
	if name == "Players" then return fakePlayers end
	if name == "HttpService" then return {GenerateGUID = function() return "test" end, JSONEncode = function(_, value) return value end} end
	return {Shared = {GameConfig = "GameConfig", Packets = "Packets"}}
end}
local Match = loadModule("src/Server/Services/MatchService.luau")
Match.step(500, 0.05)
check(stateHistory[#stateHistory] == "COUNTDOWN", "match starts countdown")
Match.step(510, 0.05)
check(stateHistory[#stateHistory] == "PLAYING", "countdown starts playing")
for index = 1, 3000 do Match.step(510 + index * 0.05, 0.05) end
check(stateHistory[#stateHistory] == "RESULT" and snapshots[#snapshots].outcome == "VICTORY", "150-second victory")
check(grants == 1 and clears == 1, "one reward and cleanup per finish")
Match.step(661, 0.05)
check(grants == 1, "RESULT cannot grant again")
Match.step(665, 0.05)
check(stateHistory[#stateHistory] == "WAITING" and next(matchEntries) == nil, "result returns to lobby")
Match.step(666, 0.05); Match.step(676, 0.05)
matchEntries[profilePlayer].state = "DOWNED"
Match.step(676.1, 0.1)
check(snapshots[#snapshots].outcome == "DEFEAT" and stateHistory[#stateHistory] == "RESULT", "team wipe ends immediately")
Match.step(676.3, 0.2)
check(snapshots[#snapshots].outcome == "DEFEAT" and grants == 2, "all downed gives defeat and single reward")
Match.step(682, 0.05); Match.step(683, 0.05)
roster = {}
Match.step(684, 0.05)
check(stateHistory[#stateHistory] == "WAITING", "empty roster cancels countdown")
Match.clear()
print(string.format("PASS FINAL: %d assertions including full match state machine", assertions))
