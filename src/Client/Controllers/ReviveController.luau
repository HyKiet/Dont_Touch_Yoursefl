--!strict
--[[ ReviveController — Chọn đồng đội gần nhất và gửi Begin/End qua ByteNet.
	MatchController cung cấp snapshot; server tự đo thời gian và kiểm tra khoảng cách. ]]
local Players = game:GetService("Players")
local Actions = game:GetService("ContextActionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.GameConfig)
local Packets = require(Shared.Packets)
local ReviveController = {}
local targetId: number? = nil
local holdingId: number? = nil
local isBound = false

local function cancel()
	if holdingId then
		Packets.Revive.send({ targetId = holdingId, holding = false })
		holdingId = nil
	end
end

local function input(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and targetId then
		holdingId = targetId
		Packets.Revive.send({ targetId = targetId, holding = true })
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		cancel()
	end
	return Enum.ContextActionResult.Sink
end

local function nearest(snapshot: any): number?
	local character = Players.LocalPlayer.Character
	local root = if character
		then character:FindFirstChild("HumanoidRootPart") :: BasePart?
		else nil
	if not root then
		return nil
	end
	local closest, distance = nil, Config.ReviveDistance
	for _, row in snapshot.players do
		if row.state ~= "DOWNED" or row.userId == Players.LocalPlayer.UserId then
			continue
		end
		local player = Players:GetPlayerByUserId(row.userId)
		local other = if player and player.Character
			then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			else nil
		if other and (other.Position - root.Position).Magnitude <= distance then
			closest, distance = row.userId, (other.Position - root.Position).Magnitude
		end
	end
	return closest
end

-- Chỉ bind action khi có mục tiêu; BindAction tạo nút touch (creator-docs: ContextActionService.yaml).
function ReviveController.update(snapshot: any, selfRow: any)
	local nextTarget = if snapshot.state == "PLAYING"
			and selfRow
			and selfRow.state == "ALIVE"
		then nearest(snapshot)
		else nil
	if nextTarget ~= targetId then
		cancel()
	end
	targetId = nextTarget
	if targetId and not isBound then
		Actions:BindAction("ReviveTeammate", input, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		Actions:SetTitle("ReviveTeammate", "HOLD\nREVIVE")
		Actions:SetPosition("ReviveTeammate", UDim2.fromScale(0.72, 0.55))
		isBound = true
	elseif not targetId and isBound then
		Actions:UnbindAction("ReviveTeammate")
		isBound = false
	end
end
-- Cho HUD biết khi nào cần hiển thị lời nhắc giữ E.
function ReviveController.hasTarget(): boolean
	return targetId ~= nil
end
-- Huỷ giữ nút và gỡ action khi client đóng hoặc match kết thúc.
function ReviveController.destroy()
	cancel()
	Actions:UnbindAction("ReviveTeammate")
	isBound = false
end
return ReviveController
