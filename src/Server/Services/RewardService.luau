--!strict
--[[ RewardService — ProfileStore session + thưởng cuối trận. Main quản lý session;
	MatchService cấp thưởng từ số liệu server, không có inbound reward packet. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local ReplayMath = require(ReplicatedStorage.Shared.ReplayMath)
local Telemetry = require(script.Parent.TelemetryService)
local Map = require(script.Parent.MapService)
local RewardService = {}
local profiles: { [Player]: any } = {}
local template = {
	SchemaVersion = Config.ProfileSchemaVersion,
	Coins = 0,
	BestSurvival = 0,
	BestCores = 0,
	LastRewardId = "",
}
local isStudioMock = game:GetService("RunService"):IsStudio() and Config.UseMockDataInStudio
local function createStore(): any
	-- ProfileStore 1.0.3 tự ghi ____PS ngay khi require, kể cả dùng .Mock.
	-- Chế độ thử chỉ giữ RAM; server online luôn mở session ProfileStore thật.
	if isStudioMock then
		return nil
	end
	local ProfileStore = require(game:GetService("ServerScriptService").ServerPackages.ProfileStore)
	return ProfileStore.New(Config.ProfileStoreName, template)
end
local store = createStore()

local function expose(player: Player, data: any)
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("BestSurvival", data.BestSurvival)
	player:SetAttribute("BestCores", data.BestCores)
	Map.refreshBoard()
end

local function loadStudio(player: Player)
	if player.Parent ~= Players then
		return
	end
	local active = true
	local profile = {
		Data = table.clone(template),
		IsActive = function()
			return active
		end,
		EndSession = function()
			active = false
		end,
	}
	profiles[player] = profile
	expose(player, profile.Data)
	player:SetAttribute("DataReady", true)
	print("[RewardService] Studio memory data ready; progress is not saved", player.UserId)
end

-- Mở session có cancel khi người chơi rời; không bao giờ dùng dữ liệu mặc định thay lỗi load.
function RewardService.load(player: Player)
	if isStudioMock then
		loadStudio(player)
		return
	end
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		if player.Parent == Players then
			player:Kick("Data unavailable. Please rejoin.")
		end
		return
	end
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profile:AddUserId(player.UserId)
	-- V1 là schema đầu tiên. Hồ sơ chưa có version được reconcile rồi chuyển lên V1;
	-- không hạ version nếu server cũ gặp schema mới hơn.
	if (profile.Data.SchemaVersion or 0) > Config.ProfileSchemaVersion then
		profile:EndSession()
		player:Kick("Please join a newer server.")
		return
	end
	profile:Reconcile()
	profile.Data.SchemaVersion = Config.ProfileSchemaVersion
	profiles[player] = profile
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Data session closed. Please rejoin.")
		end
	end)
	expose(player, profile.Data)
	player:SetAttribute("DataReady", true)
end

-- Kết thúc session khi rời server; ProfileStore tự flush lần cuối.
function RewardService.release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile then
		profile:EndSession()
	end
end

-- Cấp đúng một lần/match: kiểm tra session, tính tiền, cập nhật rồi emit economy, không yield giữa mutation.
function RewardService.grant(player: Player, entry: any, matchId: string, victory: boolean): number
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		warn("[RewardService] Missing active profile", player.UserId)
		return 0
	end
	local data = profile.Data
	if data.LastRewardId == matchId then
		return 0
	end
	local amount = ReplayMath.reward(entry.cores, entry.survival, victory, Config)
	data.Coins += amount
	data.BestSurvival = math.max(data.BestSurvival, entry.survival)
	data.BestCores = math.max(data.BestCores, entry.cores)
	data.LastRewardId = matchId
	expose(player, data)
	Telemetry.economy(player, amount, data.Coins)
	return amount
end
return RewardService
