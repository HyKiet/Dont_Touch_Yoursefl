--!strict
--[[
	GameConfig — Nơi duy nhất chứa mọi con số của gameplay.

	Muốn chỉnh độ khó, thời lượng trận, tốc độ spawn... thì sửa Ở ĐÂY,
	không sửa rải rác trong các Service. Nhờ vậy chỉ cần mở một file là
	thấy toàn bộ "nút vặn" của game.

	Ai gọi file này:  tất cả Service ở server và Controller ở client
	File này gọi ai:  không gọi ai cả (chỉ chứa dữ liệu)

	Nguồn số liệu: GDD mục O.
]]

local GameConfig = {
	--------------------------------------------------------------------
	-- TRẬN ĐẤU
	--------------------------------------------------------------------

	-- Số người tối đa trong một server.
	MaxPlayers = 12,

	-- Thời gian đếm ngược ở Lobby trước khi vào trận (giây).
	LobbyCountdown = 10,

	-- Độ dài một trận (giây). Sống hết chừng này là thắng.
	MatchDuration = 150,

	--------------------------------------------------------------------
	-- ECHO — hệ thống quan trọng nhất của game
	--------------------------------------------------------------------

	-- Cứ sau chừng này giây, đường chạy vừa rồi của người chơi
	-- biến thành một Echo mới (giây).
	EchoInterval = 10,

	-- Khoảng cách giữa 2 lần ghi lại vị trí người chơi (giây).
	-- 0.1 giây = 10 điểm mỗi giây, đủ mượt mà không tốn bộ nhớ.
	MovementRecordInterval = 0.1,

	-- Trần số Echo mỗi người chơi. Echo thứ 9 xuất hiện thì Echo cũ nhất
	-- biến mất. Đây là HÀNG RÀO BẢO VỆ HIỆU NĂNG, không phải nút chỉnh
	-- độ khó: 12 người × 8 Echo = 96 Echo, đó là mức server chịu được.
	MaxEchoesPerPlayer = 8,

	-- Server kiểm tra va chạm Echo bao nhiêu lần mỗi giây.
	-- Kiểm tra mỗi frame (~60 lần/giây) tốn gấp 3 lần CPU mà mắt người
	-- không nhận ra khác biệt, nên dùng 20.
	EchoHitCheckRate = 20,

	-- Khoảng cách được tính là "Echo chạm người chơi" (studs).
	EchoHitRadius = 3,

	--------------------------------------------------------------------
	-- SỐNG / CHẾT / HỒI SINH
	--------------------------------------------------------------------

	-- Sau khi bị hạ, người chơi còn chừng này giây để đồng đội cứu (giây).
	BleedoutTime = 10,

	-- Phải giữ nút cứu liên tục chừng này giây thì mới cứu xong (giây).
	ReviveDuration = 2.5,

	-- Phải đứng trong bán kính này mới cứu được (studs).
	ReviveDistance = 6,

	-- Người cứu nhúc nhích quá chừng này studs là huỷ lượt cứu (GDD mục G).
	-- Nhỏ hơn nhiều so với ReviveDistance: đứng gần thôi chưa đủ, phải ĐỨNG YÊN.
	ReviveMovementTolerance = 0.75,

	-- Vừa được cứu dậy thì miễn nhiễm chừng này giây, để không bị
	-- Echo hạ lại ngay lập tức (giây).
	ReviveInvulnerability = 2,

	--------------------------------------------------------------------
	-- CORE — vật phẩm ép người chơi phải di chuyển
	--------------------------------------------------------------------

	-- Khoảng cách giữa 2 lần spawn Core, chọn ngẫu nhiên trong khoảng này (giây).
	CoreSpawnIntervalMin = 2,
	CoreSpawnIntervalMax = 4,

	-- Số Core cùng tồn tại trên map tối đa.
	MaxActiveCores = 8,

	-- Đứng trong bán kính này thì nhặt được Core (studs). Rộng hơn bán kính
	-- Echo chạm một chút để nhặt đồ không bị hụt gây ức chế.
	CorePickupRadius = 4,

	--------------------------------------------------------------------
	-- THƯỞNG (GDD mục I)
	--------------------------------------------------------------------

	-- Mỗi Core nhặt được đổi ra chừng này Coin.
	CoreReward = 5,

	-- Cứ sống sót chừng này giây thì được 1 Coin.
	SurvivalRewardInterval = 5,

	-- Thưởng thêm khi đội trụ hết 150 giây.
	VictoryBonus = 50,

	--------------------------------------------------------------------
	-- RAGDOLL — người chơi bị hạ thì ngã bằng vật lý thật
	--------------------------------------------------------------------

	-- Giới hạn góc của khớp khi ngã. Chỉ ảnh hưởng hình thể lúc nằm,
	-- KHÔNG đổi thời gian cứu hay bleedout.
	RagdollUpperAngle = 60,
	RagdollTwistAngle = 45,

	-- Một cú xoay nhẹ để người đang đứng yên cũng đổ xuống trông tự nhiên.
	-- Không làm tăng bán kính chạm hay sát thương.
	RagdollFallSpeed = 2,

	--------------------------------------------------------------------
	-- NHỊP CHẠY CỦA HỆ THỐNG
	--------------------------------------------------------------------

	-- Màn hình kết quả hiện chừng này giây trước khi về Lobby.
	ResultDuration = 5,

	-- Miễn nhiễm chừng này giây đầu trận, để Echo cũ không hạ ngay lúc vừa spawn.
	SpawnProtection = 2,

	-- Echo bị đẩy ra khỏi trần budget sẽ mờ dần trong chừng này giây rồi biến mất.
	EchoFadeDuration = 1,

	-- Server gửi snapshot trạng thái xuống client mỗi chừng này giây (5 lần/giây).
	-- Gửi dày hơn không làm game mượt hơn vì client đã tự nội suy Echo mỗi frame.
	SnapshotInterval = 0.2,

	-- Một client chỉ được gửi yêu cầu cứu tối đa mỗi chừng này giây.
	-- Đây là rate limit chống spam packet, không phải nút chỉnh gameplay.
	InboundRequestInterval = 0.15,

	-- Chờ character load tối đa chừng này giây rồi bỏ qua, không chờ vô hạn.
	CharacterLoadTimeout = 10,

	--------------------------------------------------------------------
	-- HÌNH ẢNH ECHO (chỉ client dùng)
	--------------------------------------------------------------------

	-- Mỗi người chơi có sẵn chừng này bản clone: 8 Echo active + 1 slot đang mờ dần.
	EchoPoolSlots = 9,

	-- Chỗ giấu clone chưa dùng tới: rất xa dưới lòng đất nên người chơi không thấy.
	EchoPoolHiddenPosition = Vector3.new(0, -10000, 0),

	-- Chạy nhanh hơn chừng này (studs/giây) thì Echo đổi sang animation chạy.
	EchoAnimationMoveThreshold = 0.5,

	-- Bay lên nhanh hơn chừng này (studs/giây) thì coi như đang nhảy.
	EchoAnimationVerticalThreshold = 1.5,

	-- Tốc độ chạy chuẩn của avatar Roblox, dùng để chỉnh nhịp animation cho khớp.
	EchoAnimationReferenceSpeed = 16,

	-- Thời gian chuyển mượt giữa hai animation (giây).
	EchoAnimationBlendTime = 0.12,

	--------------------------------------------------------------------
	-- CHỐNG GIAN LẬN VỊ TRÍ (server kiểm tra, xem PlayerStateService)
	--------------------------------------------------------------------

	-- Dung sai khoảng cách cho packet về trễ (studs). Đây KHÔNG phải buff tốc độ:
	-- người chơi đi quá mức này trong một tick sẽ bị kéo về vị trí hợp lệ cuối cùng.
	MovementDistanceSlack = 4,

	-- Cho phép nhanh gấp chừng này lần WalkSpeed (tính cả lúc rơi, trượt dốc).
	MovementSpeedMultiplier = 2,

	-- Ra ngoài mép sàn arena quá chừng này studs là vị trí không hợp lệ.
	OutOfBoundsMargin = 2,

	-- Thấp hơn mặt sàn chừng này studs nghĩa là đã rơi khỏi map.
	FallLimit = -15,

	-- Trần chiều cao hợp lệ tính từ mặt sàn (studs), chặn kiểu bay lên trời.
	-- 22 studs là chiều cao tường arena, cộng 5 studs người chơi được spawn cao hơn sàn.
	MaxHeightAboveFloor = 27,

	--------------------------------------------------------------------
	-- ĐỌC MAP TỪ WORKSPACE (xem MapService)
	--------------------------------------------------------------------
	-- Map do người làm map dựng trong Studio, code chỉ đọc marker.
	-- Các số dưới đây nâng điểm spawn lên khỏi mặt marker để không kẹt trong sàn.

	PlayerSpawnMarkerHeight = 3.9,
	CoreSpawnMarkerHeight = 1.85,
	LobbySpawnMarkerHeight = 3.5,

	--------------------------------------------------------------------
	-- LƯU DỮ LIỆU NGƯỜI CHƠI (xem RewardService)
	--------------------------------------------------------------------

	-- Bật thì Studio chỉ giữ dữ liệu trong RAM, KHÔNG chạm vào hồ sơ thật.
	-- Nhờ vậy test thoải mái mà không làm hỏng tiền của người chơi thật.
	UseMockDataInStudio = true,

	-- Phiên bản cấu trúc dữ liệu. Tăng số này khi đổi hình dạng hồ sơ,
	-- để server cũ biết mà từ chối hồ sơ mới thay vì ghi đè làm mất dữ liệu.
	ProfileSchemaVersion = 1,

	-- Tên kho DataStore. ĐỔI TÊN NÀY LÀ MẤT TOÀN BỘ DỮ LIỆU NGƯỜI CHƠI.
	ProfileStoreName = "DontTouchYourClone_Player_v1",

	--------------------------------------------------------------------
	-- MÀU ECHO — 12 màu phân biệt rõ, xếp sao cho 2 màu cạnh nhau không giống nhau
	--------------------------------------------------------------------

	EchoColors = {
		Color3.fromRGB(65, 145, 255),
		Color3.fromRGB(255, 65, 75),
		Color3.fromRGB(45, 205, 100),
		Color3.fromRGB(255, 225, 60),
		Color3.fromRGB(255, 140, 40),
		Color3.fromRGB(145, 80, 240),
		Color3.fromRGB(40, 225, 240),
		Color3.fromRGB(255, 150, 190),
		Color3.fromRGB(170, 255, 40),
		Color3.fromRGB(240, 245, 255),
		Color3.fromRGB(155, 100, 55),
		Color3.fromRGB(245, 45, 230),
	},
}

-- table.freeze khoá bảng lại: từ giờ không code nào sửa được giá trị trong
-- GameConfig lúc game đang chạy. Nếu lỡ viết nhầm `GameConfig.MaxPlayers = 5`
-- thì game báo lỗi ngay, thay vì âm thầm chạy sai và rất khó tìm ra.
return table.freeze(GameConfig)
