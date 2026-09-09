--!strict
--[[ TelemetryService — Ghi sự kiện từ server; PlayerState/Core/Reward/Match gọi.
	Studio chỉ in Output, tránh gửi dữ liệu giả vào analytics production. ]]
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local TelemetryService = {}

-- Nhận player, tên sự kiện và số đo; lỗi analytics không làm gián đoạn gameplay.
function TelemetryService.event(player: Player, name: string, value: number?)
	if RunService:IsStudio() then
		print("[Telemetry]", name, player.UserId, value or 1)
		return
	end
	local success, message = pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
	if not success then
		warn("[Telemetry]", message)
	end
end

-- Ghi nguồn tiền sau mutation atomic. Chữ ký: creator-docs/classes/AnalyticsService.yaml.
function TelemetryService.economy(player: Player, amount: number, balance: number)
	if amount <= 0 then
		return
	end
	if RunService:IsStudio() then
		print("[Economy] MatchReward", player.UserId, amount, balance)
		return
	end
	local success, message = pcall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Coins",
			amount,
			balance,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
			"MatchReward"
		)
	end)
	if not success then
		warn("[Economy]", message)
	end
end
return TelemetryService
