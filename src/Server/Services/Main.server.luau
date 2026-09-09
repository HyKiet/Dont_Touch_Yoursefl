--!strict
--[[ Main — Khởi động server và sở hữu connection suốt vòng đời server.
	Không tạo listener mới sau mỗi match; Janitor dọn khi script/server đóng. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Config = require(ReplicatedStorage.Shared.GameConfig)
local Packets = require(ReplicatedStorage.Shared.Packets)
local Map = require(script.Parent.MapService)
local States = require(script.Parent.PlayerStateService)
local Recorder = require(script.Parent.MovementRecorderService)
local Revive = require(script.Parent.ReviveService)
local Rewards = require(script.Parent.RewardService)
local Match = require(script.Parent.MatchService)
local cleanup = Janitor.new()
local playerCleanup: { [Player]: any } = {}
local lastReady: { [Player]: number } = {}
local isClosed = false
-- Map thuộc người làm map trong Studio, không đưa vào Janitor để tránh xoá bản trang trí.
Map.build()

local function characterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", Config.CharacterLoadTimeout)
	if not root or player.Character ~= character then
		warn("[Main] Missing character root", player.UserId)
		return
	end
	if States.get(player) then
		States.eliminate(player)
	end
	character:PivotTo(Map.getLobby())
	if not States.get(player) then
		player:SetAttribute("LifeState", "LOBBY")
	end
end

local function added(player: Player)
	local owner = Janitor.new()
	playerCleanup[player] = owner
	owner:Add(player.CharacterAdded:Connect(function(character)
		characterAdded(player, character)
	end))
	if player.Character then
		owner:Add(task.spawn(characterAdded, player, player.Character), true)
	end
	owner:Add(task.spawn(Rewards.load, player), true)
end

local function removed(player: Player)
	States.remove(player)
	Recorder.remove(player)
	Revive.remove(player)
	lastReady[player] = nil
	Rewards.release(player)
	local owner = playerCleanup[player]
	playerCleanup[player] = nil
	if owner then
		owner:Destroy()
	end
end

cleanup:Add(Players.PlayerAdded:Connect(added))
cleanup:Add(Players.PlayerRemoving:Connect(removed))
for _, player in Players:GetPlayers() do
	added(player)
end

Packets.Ready.listen(function(_: any, player: Player?)
	if not player then
		return
	end
	-- Client chỉ cần handshake một lần; chặn spam gửi lại toàn bộ 96 đường Echo.
	if lastReady[player] then
		return
	end
	lastReady[player] = workspace:GetServerTimeNow()
	Match.sync(player)
end)
Packets.Revive.listen(function(data: any, player: Player?)
	if player then
		Revive.request(player, data, workspace:GetServerTimeNow())
	end
end)

local lastStep = workspace:GetServerTimeNow()
-- Heartbeat chạy sau physics; giảm nhịp gameplay về 20Hz (creator-docs: RunService.yaml).
cleanup:Add(RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	if now - lastStep < 1 / Config.EchoHitCheckRate then
		return
	end
	local delta = now - lastStep
	lastStep = now
	Match.step(now, delta)
end))

local function shutdown()
	if isClosed then
		return
	end
	isClosed = true
	cleanup:Destroy()
	Match.clear()
	for player in playerCleanup do
		removed(player)
	end
	-- ByteNet 0.4.6 listen không trả Disconnect; Main sở hữu hai listener này suốt server.
	table.clear((Packets.Ready :: any).getListeners())
	table.clear((Packets.Revive :: any).getListeners())
end
game:BindToClose(shutdown)
cleanup:Add(script.Destroying:Connect(shutdown))
print(
	"[Main] Prototype server ready; Studio mock data:",
	RunService:IsStudio() and Config.UseMockDataInStudio
)
