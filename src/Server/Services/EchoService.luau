--!strict
--[[
	EchoService — Giữ dữ liệu Echo, trần budget và phát hiện Echo chạm người chơi.

	Echo là đường chạy quá khứ của một người chơi. Service này KHÔNG tạo Model nào
	ở server: nó chỉ giữ danh sách toạ độ đã ghi, rồi gửi cho client tự vẽ.
	Server chỉ tính xem Echo có chạm ai không — đó là quyết định gameplay nên
	không được để client tự làm (GDD mục N).

	Ai gọi file này:  MatchService (spawn / step / clear / sync / count)
	File này gọi ai:  PlayerStateService (báo có người bị hạ), ReplayMath, Packets
]]
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.GameConfig)
local ReplayMath = require(Shared.ReplayMath)
local Packets = require(Shared.Packets)
local States = require(script.Parent.PlayerStateService)

local EchoService = {}

-- Mọi Echo đang sống trong trận hiện tại, cũ nhất nằm đầu danh sách.
-- Thứ tự này quan trọng: khi vượt trần 8 Echo/người, ta xoá cái đầu tiên tìm được.
local echoes: { any } = {}

-- Số thứ tự tăng dần, dùng làm id để client biết Echo nào là Echo nào.
local nextEchoId = 0

-- Bình phương bán kính chạm, tính sẵn một lần. Trong vòng lặp nóng ta so sánh
-- bình phương khoảng cách với số này để khỏi phải gọi math.sqrt.
local HIT_RADIUS_SQUARED = Config.EchoHitRadius * Config.EchoHitRadius

-- Toạ độ người còn sống của tick hiện tại, tách thành ba bảng số rời.
-- Vì sao không giữ một bảng Vector3? Vì mỗi phép trừ hai Vector3 tạo ra một
-- vật thể mới trong bộ nhớ. Vòng lặp dưới chạy 1.152 lần mỗi tick, tức là
-- 23.000 vật thể rác mỗi giây — đủ để bộ dọn rác làm server khựng.
-- Ba bảng số thuần thì phép trừ chỉ là phép tính trên số, không cấp phát gì cả.
local alivePlayers: { any } = {}
local aliveX: { number } = {}
local aliveY: { number } = {}
local aliveZ: { number } = {}

-- Gom người còn sống vào các bảng trên. Trả về số người vừa gom được.
-- Dùng lại đúng những bảng đó cho mọi tick thay vì tạo bảng mới 20 lần/giây.
local function collectAlivePlayers(): number
	local count = 0
	for _, entry in States.getAll() do
		if entry.state == "ALIVE" then
			count += 1
			local position = entry.acceptedFrame.Position
			alivePlayers[count] = entry.player
			aliveX[count], aliveY[count], aliveZ[count] = position.X, position.Y, position.Z
		end
	end
	return count
end

--[[
	Đếm số Echo mà một người chơi đang sở hữu.

	@param ownerId  UserId của chủ Echo
	@return         Số Echo đang sống của người đó
]]
local function countEchoesOf(ownerId: number): number
	local owned = 0
	for _, echo in echoes do
		if echo.ownerId == ownerId then
			owned += 1
		end
	end
	return owned
end

-- Xoá Echo cũ nhất của một người để nhường chỗ cho Echo mới.
local function removeOldestEchoOf(ownerId: number)
	for index, echo in echoes do
		if echo.ownerId == ownerId then
			table.remove(echoes, index)
			return
		end
	end
end

--[[
	Tạo một Echo mới từ đoạn đường vừa ghi được và gửi cho toàn bộ client.

	@param player   Chủ của đoạn đường này
	@param path     Danh sách sample { time, frame, state } do MovementRecorder ghi
	@param now      Thời gian server lúc tạo Echo
	@param matchId  Số hiệu trận, để client bỏ qua Echo của trận cũ
]]
function EchoService.spawn(player: Player, path: any, now: number, matchId: number)
	local entry = States.get(player)
	-- Dưới 2 điểm thì không nội suy được thành đường chạy, bỏ qua.
	if not entry or #path < 2 then
		return
	end

	-- Trần 8 Echo/người là hàng rào bảo vệ hiệu năng, không phải nút chỉnh độ khó.
	-- 12 người × 8 Echo = 96, đó là mức server chịu được (GDD mục E).
	if countEchoesOf(player.UserId) >= Config.MaxEchoesPerPlayer then
		removeOldestEchoOf(player.UserId)
	end

	nextEchoId += 1
	local echo = {
		id = nextEchoId,
		matchId = matchId,
		ownerId = player.UserId,
		colorIndex = entry.colorIndex,
		born = now,
		duration = Config.EchoInterval,
		path = path,
	}
	table.insert(echoes, echo)
	Packets.Echo.sendToAll(echo)
end

--[[
	Kiểm tra một Echo có chạm ai không, gọi cho từng Echo ở mỗi tick.

	@param echoX,echoY,echoZ  Vị trí Echo đang đứng ở tick này
	@param aliveCount         Số người còn sống đang nằm trong các bảng ở trên
	@param now                Thời gian server, truyền xuống PlayerStateService
]]
local function checkEchoAgainstPlayers(
	echoX: number,
	echoY: number,
	echoZ: number,
	aliveCount: number,
	now: number
)
	for index = 1, aliveCount do
		-- So sánh BÌNH PHƯƠNG khoảng cách để khỏi gọi math.sqrt trong vòng lặp nóng.
		-- Nếu a² ≤ b² thì a ≤ b, nên kết quả giống hệt mà rẻ hơn nhiều.
		local dx = echoX - aliveX[index]
		local dy = echoY - aliveY[index]
		local dz = echoZ - aliveZ[index]
		if dx * dx + dy * dy + dz * dz <= HIT_RADIUS_SQUARED then
			States.down(alivePlayers[index], now)
		end
	end
end

--[[
	Nhịp kiểm tra va chạm, MatchService gọi 20 lần/giây.

	Vì sao duyệt thẳng "mọi Echo × mọi người sống" mà không dùng lưới không gian
	(spatial grid)? Vì server chỉ có tối đa 12 người: 96 Echo × 12 người = 1.152
	phép so sánh mỗi tick, và mỗi phép chỉ là vài phép tính trên số.
	Bản dùng lưới đã được đo thử: nó phải ghép chuỗi làm khoá cho từng ô rồi tra
	27 ô quanh mỗi Echo, kết quả CHẬM HƠN khoảng 2,3 lần so với đoạn code này.
	Đừng "tối ưu" lại thành lưới — lưới chỉ đáng dùng khi số người chơi lên tới
	hàng trăm, mà GDD đã chốt trần là 12.

	@param now  Thời gian server hiện tại
]]
function EchoService.step(now: number)
	local aliveCount = collectAlivePlayers()
	-- Không còn ai sống thì không có gì để chạm, thoát sớm.
	if aliveCount == 0 then
		return
	end
	for _, echo in echoes do
		-- Echo lặp lại đoạn đường của nó mãi mãi, nên lấy phần dư của thời gian.
		local elapsed = (now - echo.born) % echo.duration
		local position = ReplayMath.sample(echo.path, elapsed).Position
		checkEchoAgainstPlayers(position.X, position.Y, position.Z, aliveCount, now)
	end
end

-- Gửi lại mọi Echo đang sống cho một client vừa vào giữa trận; không tạo Echo mới.
function EchoService.sync(player: Player)
	for _, echo in echoes do
		Packets.Echo.sendTo(echo, player)
	end
end

-- Trả số Echo đang sống, dùng để QA đo budget có đúng trần không.
function EchoService.count(): number
	return #echoes
end

-- Dọn dữ liệu khi trận kết thúc; client tự dọn pool khi snapshot rời trạng thái PLAYING.
function EchoService.clear()
	table.clear(echoes)
	table.clear(alivePlayers)
end

return EchoService
