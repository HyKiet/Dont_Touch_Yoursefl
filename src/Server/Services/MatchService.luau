--!strict
--[[ MatchService — State machine điều phối các service, không tự xử lý hit/revive.
	Main gọi step một nhịp 20Hz; mọi deadline dùng GetServerTimeNow (Workspace.yaml). ]]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.GameConfig)
local Packets = require(Shared.Packets)
local States = require(script.Parent.PlayerStateService)
local Map = require(script.Parent.MapService)
local Recorder = require(script.Parent.MovementRecorderService)
local Echoes = require(script.Parent.EchoService)
local Cores = require(script.Parent.CoreService)
local Revive = require(script.Parent.ReviveService)
local Rewards = require(script.Parent.RewardService)
local Telemetry = require(script.Parent.TelemetryService)
local MatchService = {}
local state, outcome = "WAITING", ""
local matchId, deadline, startedAt, nextEcho, lastSnapshot = 0, 0, 0, 0, 0
local sessionId = HttpService:GenerateGUID(false)
local teamSurvival = 0
local resultRows: { any } = {}

local function transition(nextState: string, endAt: number)
	state, deadline = nextState, endAt
	-- Chuyển phase phải gửi ngay trong tick này, không đợi nhịp snapshot định kỳ.
	lastSnapshot = -math.huge
	workspace:SetAttribute("MatchState", state)
	workspace:SetAttribute("MatchId", matchId)
	print("[MatchService]", matchId, state)
end

local function eligible(): { Player }
	local ready = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if
			player:GetAttribute("DataReady")
			and character
			and character:FindFirstChild("HumanoidRootPart")
			and humanoid
			and humanoid.Health > 0
		then
			table.insert(ready, player)
		end
	end
	table.sort(ready, function(first, second)
		return first.UserId < second.UserId
	end)
	return ready
end

local function row(player: Player, entry: any, now: number): any
	return {
		userId = player.UserId,
		name = player.DisplayName,
		state = entry.state,
		colorIndex = entry.colorIndex,
		cores = entry.cores,
		survival = entry.survival,
		reward = entry.reward,
		bleedoutAt = entry.bleedoutAt,
		invulnerableUntil = entry.invulnerableUntil,
		reviveProgress = Revive.progress(player, now),
	}
end

local function snapshot(now: number): string
	local rows = {}
	for player, entry in States.getAll() do
		table.insert(rows, row(player, entry, now))
	end
	table.sort(rows, function(first, second)
		return first.colorIndex < second.colorIndex
	end)
	return HttpService:JSONEncode({
		state = state,
		outcome = outcome,
		matchId = matchId,
		deadline = deadline,
		startedAt = startedAt,
		nextEcho = nextEcho,
		teamSurvival = if state == "PLAYING"
			then math.clamp(now - startedAt, 0, Config.MatchDuration)
			else teamSurvival,
		players = rows,
		results = resultRows,
		serverPlayers = #Players:GetPlayers(),
		echoCount = Echoes.count(),
	})
end

-- Gửi trạng thái và đường chạy hiện tại cho client mới; Main rate-limit Ready.
function MatchService.sync(player: Player)
	Packets.Snapshot.sendTo(snapshot(workspace:GetServerTimeNow()), player)
	if state == "PLAYING" then
		Echoes.sync(player)
	end
end

local function startMatch(now: number)
	matchId += 1
	outcome, resultRows = "", {}
	teamSurvival = 0
	transition("STARTING", now)
	for index, player in eligible() do
		if index > Config.MaxPlayers then
			break
		end
		if States.add(player, Map.getSpawn(index), index, now) then
			Telemetry.event(player, "MatchStarted")
		end
	end
	startedAt, nextEcho = now, now + Config.EchoInterval
	Recorder.start(now)
	Recorder.step(now)
	Cores.start(now)
	transition("PLAYING", now + Config.MatchDuration)
end

local function aliveCount(): number
	local alive = 0
	for _, entry in States.getAll() do
		if entry.state == "ALIVE" then
			alive += 1
		end
	end
	return alive
end

local function finish(now: number, victory: boolean)
	teamSurvival = math.clamp(now - startedAt, 0, Config.MatchDuration)
	outcome = if victory then "VICTORY" else "DEFEAT"
	transition(outcome, now)
	for player, entry in States.getAll() do
		entry.reward = Rewards.grant(player, entry, sessionId .. ":" .. matchId, victory)
		table.insert(resultRows, row(player, entry, now))
		Telemetry.event(player, outcome, math.min(now - startedAt, Config.MatchDuration))
	end
	Recorder.clear()
	Echoes.clear()
	Cores.clear()
	Revive.clear()
	transition("RESULT", now + Config.ResultDuration)
end

local function play(now: number, delta: number)
	States.step(now, math.min(delta, math.max(0, deadline - (now - delta))))
	-- Timer đã hết thì không xử lý thêm cú chạm từ frame đến trễ sau deadline.
	if now >= deadline then
		finish(deadline, aliveCount() > 0)
		return
	end
	Echoes.step(now)
	Revive.step(now)
	if aliveCount() == 0 then
		finish(now, false)
		return
	end
	Cores.step(now)
	if now >= nextEcho then
		local paths = Recorder.take(now)
		for player, path in paths do
			Echoes.spawn(player, path, now, matchId)
		end
		nextEcho = now + Config.EchoInterval
	end
	Recorder.step(now)
end

local function returnToLobby(now: number)
	transition("RETURN_TO_LOBBY", now)
	States.clear()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("LifeState", "LOBBY")
		local character = player.Character
		if character then
			character:PivotTo(Map.getLobby())
		end
	end
	transition("WAITING", now)
end

-- Chạy state machine không yield, tránh hai thread cùng kết thúc và cấp thưởng một trận.
function MatchService.step(now: number, delta: number)
	if state == "WAITING" and #eligible() > 0 then
		transition("COUNTDOWN", now + Config.LobbyCountdown)
	elseif state == "COUNTDOWN" then
		if #eligible() == 0 then
			transition("WAITING", now)
		elseif now >= deadline then
			startMatch(now)
		end
	elseif state == "PLAYING" then
		play(now, delta)
	elseif state == "RESULT" and now >= deadline then
		returnToLobby(now)
	end
	if now - lastSnapshot >= Config.SnapshotInterval then
		lastSnapshot = now
		-- Attribute chẩn đoán giúp QA đọc đúng VM đang chạy, không require lại service qua MCP.
		workspace:SetAttribute("ActiveEchoCount", Echoes.count())
		Packets.Snapshot.sendToAll(snapshot(now))
	end
end

-- Dọn tất cả tài nguyên match khi server đóng hoặc Main bị huỷ.
function MatchService.clear()
	Recorder.clear()
	Echoes.clear()
	Cores.clear()
	Revive.clear()
	States.clear()
end
return MatchService
