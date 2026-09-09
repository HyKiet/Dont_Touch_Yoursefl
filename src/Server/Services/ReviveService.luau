--!strict
--[[ ReviveService — Kiểm tra ý định giữ nút, tự đo 2.5s ở server.
	Main nối ByteNet một lần; Match gọi step/clear. Không tin thời gian client gửi. ]]
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.GameConfig)
local ReplayMath = require(Shared.ReplayMath)
local States = require(script.Parent.PlayerStateService)
local ReviveService = {}
local holds: { [Player]: any } = {}
local lastRequests: { [Player]: number } = {}

local function canRevive(rescuer: any, target: any): boolean
	return rescuer ~= nil
		and target ~= nil
		and rescuer ~= target
		and rescuer.state == "ALIVE"
		and target.state == "DOWNED"
		and rescuer.validPosition ~= false
		and target.root.Parent ~= nil
		and ReplayMath.distanceSquared(rescuer.acceptedFrame.Position, target.root.Position)
			<= Config.ReviveDistance ^ 2
end

-- Nhận ý định từ ByteNet; validate identity, khoảng cách, trạng thái và rate limit trước khi bắt đầu.
function ReviveService.request(player: Player, data: any, now: number)
	if not data.holding then
		holds[player] = nil
		return
	end
	if now - (lastRequests[player] or 0) < Config.InboundRequestInterval then
		return
	end
	lastRequests[player] = now
	if data.targetId ~= data.targetId or math.abs(data.targetId) == math.huge then
		return
	end
	local targetPlayer = Players:GetPlayerByUserId(data.targetId)
	if not targetPlayer then
		return
	end
	local rescuer, target = States.get(player), States.get(targetPlayer)
	if not canRevive(rescuer, target) then
		return
	end
	if holds[player] then
		return
	end
	holds[player] =
		{ target = targetPlayer, started = now, position = rescuer.acceptedFrame.Position }
end

-- Huỷ ngay khi người cứu di chuyển/bị hạ/xa mục tiêu; hoàn tất chỉ sau đủ thời gian server.
function ReviveService.step(now: number)
	for player, hold in holds do
		local rescuer, target = States.get(player), States.get(hold.target)
		if not canRevive(rescuer, target) then
			holds[player] = nil
			continue
		end
		if
			ReplayMath.distanceSquared(rescuer.acceptedFrame.Position, hold.position)
			> Config.ReviveMovementTolerance ^ 2
		then
			holds[player] = nil
			continue
		end
		if now - hold.started >= Config.ReviveDuration then
			States.revive(hold.target, now)
			holds[player] = nil
		end
	end
end
-- Trả tiến độ để UI hiển thị thời gian thực do server đo.
function ReviveService.progress(player: Player, now: number): number
	local hold = holds[player]
	return if hold then math.clamp((now - hold.started) / Config.ReviveDuration, 0, 1) else 0
end
-- Quên state của người rời game, cả khi họ là mục tiêu đang được cứu.
function ReviveService.remove(player: Player)
	holds[player], lastRequests[player] = nil, nil
	for rescuer, hold in holds do
		if hold.target == player then
			holds[rescuer] = nil
		end
	end
end
-- Dọn intent và rate limit cuối match.
function ReviveService.clear()
	table.clear(holds)
	table.clear(lastRequests)
end
return ReviveService
