--!strict
--[[ MatchController — Diễn giải snapshot thành HUD/onboarding và spectate.
	Main gọi receive/update, không có logic quyết định thưởng hay va chạm. ]]
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local UI = require(script.Parent.UIController)
local EchoVisual = require(script.Parent.EchoVisualController)
local Revive = require(script.Parent.ReviveController)
local Feedback = require(script.Parent.FeedbackController)
local MatchController = {}
local snapshot: any = nil
local selfRow: any = nil
local echoMessageUntil = 0

local function clockText(seconds: number): string
	local rounded = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(rounded / 60), rounded % 60)
end

local function findSelf(rows: any): any
	for _, row in rows do
		if row.userId == Players.LocalPlayer.UserId then
			return row
		end
	end
	return nil
end

local function spectate()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local subject = Players.LocalPlayer.Character
	if snapshot.state == "PLAYING" and (not selfRow or selfRow.state == "ELIMINATED") then
		for _, row in snapshot.players do
			local player = Players:GetPlayerByUserId(row.userId)
			if row.state == "ALIVE" and player and player.Character then
				subject = player.Character
				break
			end
		end
	end
	local humanoid = if subject then subject:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		camera.CameraType, camera.CameraSubject = Enum.CameraType.Custom, humanoid
	end
end

-- Cập nhật dữ liệu server, phát feedback chỉ trên chuyển trạng thái.
function MatchController.receive(data: any)
	local previous = selfRow
	selfRow = findSelf(data.players)
	if selfRow and previous and snapshot and data.matchId == snapshot.matchId then
		if selfRow.cores > previous.cores then
			Feedback.play("Core")
		end
		if selfRow.state == "DOWNED" and previous.state ~= "DOWNED" then
			Feedback.play("Downed")
		end
		if selfRow.state == "ALIVE" and previous.state == "DOWNED" then
			Feedback.play("Revived")
		end
	end
	if data.state == "RESULT" and (not snapshot or snapshot.state ~= "RESULT") then
		Feedback.play("Result")
	end
	snapshot = data
	EchoVisual.prepare(data)
	spectate()
end

-- Báo Echo của mình xuất hiện, chỉ thay lời nhắc và âm thanh.
function MatchController.echo(data: any)
	EchoVisual.receive(data)
	if data.ownerId == Players.LocalPlayer.UserId then
		echoMessageUntil = workspace:GetServerTimeNow() + 2
		Feedback.play("Echo")
	end
end

local function hint(now: number): string
	if snapshot.state ~= "PLAYING" then
		return "DON'T TOUCH YOUR CLONE!\nMove now. Dodge your past later."
	end
	if not selfRow or selfRow.state == "ELIMINATED" then
		return "SPECTATING • Your team is still fighting\nYou return next match"
	end
	if selfRow.state == "DOWNED" then
		return "YOU ARE DOWN!\nTeammate: hold E / X / REVIVE nearby"
	end
	if selfRow.reviveProgress > 0 then
		return string.format("REVIVING  %d%%\nStay still!", selfRow.reviveProgress * 100)
	end
	if Revive.hasTarget() then
		return "HOLD E / X / REVIVE\nStay still for 2.5 seconds"
	end
	if now < echoMessageUntil then
		return "YOUR PAST IS BACK\nAVOID YOUR ECHO!"
	end
	local elapsed = now - snapshot.startedAt
	if elapsed < 5 then
		return "MOVE AND COLLECT CORES"
	end
	if elapsed < 10 then
		return "YOUR MOVEMENT IS BEING RECORDED..."
	end
	if elapsed < 15 then
		return "YOUR PAST IS COMING BACK.\nAVOID YOUR ECHO!"
	end
	return "Avoid every clone • Rescue your teammates"
end

local function teamText(now: number): string
	if snapshot.state ~= "PLAYING" then
		return string.format("PLAYERS\n%d / %d", snapshot.serverPlayers, Config.MaxPlayers)
	end
	local alive, help = 0, {}
	for _, row in snapshot.players do
		if row.state == "ALIVE" then
			alive += 1
		end
		if row.state == "DOWNED" then
			table.insert(help, row)
		end
	end
	table.sort(help, function(first, second)
		return first.bleedoutAt < second.bleedoutAt
	end)
	local lines = { string.format("ALIVE  %d / %d", alive, #snapshot.players) }
	if #help > 0 then
		table.insert(lines, "NEEDS HELP")
	end
	for index, row in help do
		if index > 4 then
			table.insert(lines, "+" .. (#help - 4) .. " teammates")
			break
		end
		table.insert(lines, row.name .. "  " .. math.max(0, math.ceil(row.bleedoutAt - now)) .. "s")
	end
	return table.concat(lines, "\n")
end

local function resultText(): string
	if snapshot.state ~= "RESULT" then
		return ""
	end
	local result = findSelf(snapshot.results)
	if not result then
		return snapshot.outcome .. "\nGet ready for the next match"
	end
	return string.format(
		"%s\n\n%d CORES   •   %s SURVIVED\n+%d COINS\nBack to lobby soon",
		snapshot.outcome,
		result.cores,
		clockText(math.floor(result.survival)),
		result.reward
	)
end

-- Main gọi 10Hz; timer dùng đồng hồ server để không lệch theo FPS máy người chơi.
function MatchController.update(now: number)
	if not snapshot then
		return
	end
	Revive.update(snapshot, selfRow)
	local title = if snapshot.state == "PLAYING"
		then "SURVIVE"
		elseif snapshot.state == "COUNTDOWN" then "NEXT MATCH"
		else snapshot.state
	UI.set("Timer", title .. "\n" .. clockText(snapshot.deadline - now))
	UI.set("Team", teamText(now))
	UI.set(
		"Cores",
		string.format(
			"CORE  %d\nCOINS  %d\nBEST  %ds / %d",
			if selfRow then selfRow.cores else 0,
			Players.LocalPlayer:GetAttribute("Coins") or 0,
			math.floor(Players.LocalPlayer:GetAttribute("BestSurvival") or 0),
			Players.LocalPlayer:GetAttribute("BestCores") or 0
		)
	)
	UI.set("Hint", hint(now))
	UI.set(
		"Echo",
		if snapshot.state == "PLAYING"
			then "NEXT ECHO  " .. math.max(0, math.ceil(snapshot.nextEcho - now)) .. "s"
			else "SURVIVE TOGETHER"
	)
	UI.set("Result", resultText())
end
return MatchController
