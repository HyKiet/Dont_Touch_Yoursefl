--!strict
--[[ PlayerStateService — Sống, bị hạ, bleedout và xác minh vị trí server.
	Match/Echo/Revive gọi; không phụ thuộc ngược vào các service đó. ]]
local Config = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local Telemetry = require(script.Parent.TelemetryService)
local Map = require(script.Parent.MapService)
local Ragdoll = require(script.Parent.RagdollService)
local PlayerStateService = {}
local entries: { [Player]: any } = {}

local function restore(entry: any)
	Ragdoll.stop(entry)
	local humanoid, root = entry.humanoid, entry.root
	if not humanoid.Parent or not root.Parent then
		return
	end
	root.Anchored = false
	humanoid.PlatformStand, humanoid.AutoRotate = false, true
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight =
		entry.walkSpeed, entry.jumpPower, entry.jumpHeight
end

local function newEntry(
	player: Player,
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	colorIndex: number,
	now: number
): any
	return {
		player = player,
		character = character,
		root = root,
		humanoid = humanoid,
		state = "ALIVE",
		colorIndex = colorIndex,
		cores = 0,
		survival = 0,
		reward = 0,
		invulnerableUntil = now + Config.SpawnProtection,
		bleedoutAt = 0,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		acceptedFrame = root.CFrame,
		checkedAt = now,
		movementCredit = Config.MovementDistanceSlack,
		downFrame = root.CFrame,
	}
end

-- Đăng ký character đã load; trả false nếu character không hợp lệ, không chờ vô hạn.
function PlayerStateService.add(
	player: Player,
	spawn: CFrame,
	colorIndex: number,
	now: number
): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		not character
		or not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
	then
		warn("[PlayerStateService] Character not ready", player.UserId)
		return false
	end
	-- PivotTo dịch toàn model (creator-docs: PVInstance.yaml); server quyết định vị trí spawn.
	character:PivotTo(spawn)
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	entries[player] = newEntry(player, character, root, humanoid, colorIndex, now)
	player:SetAttribute("LifeState", "ALIVE")
	return true
end

-- Trả bảng state chỉ dùng ở server; client chỉ nhận snapshot rút gọn.
function PlayerStateService.getAll(): { [Player]: any }
	return entries
end
-- Lấy state của một người; nil nghĩa là spectator/lobby, không tham gia trận.
function PlayerStateService.get(player: Player): any
	return entries[player]
end

-- Hạ người đang sống; server sở hữu ragdoll nên client không thể tự bò né bleedout.
function PlayerStateService.down(player: Player, now: number)
	local entry = entries[player]
	if not entry or entry.state ~= "ALIVE" or now < entry.invulnerableUntil then
		return
	end
	entry.state, entry.bleedoutAt = "DOWNED", now + Config.BleedoutTime
	entry.downFrame = entry.root.CFrame
	entry.humanoid.WalkSpeed, entry.humanoid.JumpPower, entry.humanoid.JumpHeight = 0, 0, 0
	Ragdoll.start(entry)
	player:SetAttribute("LifeState", "DOWNED")
	Telemetry.event(player, "PlayerDowned")
end

-- Loại player khỏi gameplay, camera phía client chuyển sang đồng đội.
function PlayerStateService.eliminate(player: Player)
	local entry = entries[player]
	if not entry or entry.state == "ELIMINATED" then
		return
	end
	entry.state = "ELIMINATED"
	player:SetAttribute("LifeState", "ELIMINATED")
	Telemetry.event(player, "PlayerEliminated", entry.survival)
end

-- Phục hồi người downed và cấp miễn nhiễm; ReviveService đã kiểm tra người cứu.
function PlayerStateService.revive(player: Player, now: number)
	local entry = entries[player]
	if not entry or entry.state ~= "DOWNED" or now >= entry.bleedoutAt then
		return
	end
	local position = entry.root.Position
	restore(entry)
	-- Dựng lại ngay chỗ thân đang nằm, giữ độ cao đứng đã có trước khi bị hạ.
	entry.character:PivotTo(
		CFrame.new(position.X, math.max(position.Y, entry.downFrame.Y), position.Z)
			* entry.downFrame.Rotation
	)
	entry.state, entry.invulnerableUntil = "ALIVE", now + Config.ReviveInvulnerability
	entry.acceptedFrame, entry.checkedAt = entry.root.CFrame, now
	entry.movementCredit = Config.MovementDistanceSlack
	player:SetAttribute("LifeState", "ALIVE")
	Telemetry.event(player, "PlayerRevived")
end

local function validatePosition(entry: any, now: number): boolean
	local position = entry.root.Position
	local floor = Map.getArenaFloor()
	local offset = floor.CFrame:PointToObjectSpace(position)
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
		return false
	end
	local limitX = floor.Size.X / 2 - Config.OutOfBoundsMargin
	local limitZ = floor.Size.Z / 2 - Config.OutOfBoundsMargin
	-- Credit hữu hạn: packet trễ được dung sai, nhưng không cộng thêm 4 studs mỗi tick.
	local movement = position - entry.acceptedFrame.Position
	local distance = Vector3.new(movement.X, 0, movement.Z).Magnitude
	local replenished = entry.walkSpeed * Config.MovementSpeedMultiplier * (now - entry.checkedAt)
	local allowed =
		math.min(Config.MovementDistanceSlack + replenished, entry.movementCredit + replenished)
	entry.checkedAt = now
	if
		math.abs(offset.X) > limitX
		or math.abs(offset.Z) > limitZ
		or offset.Y < Config.FallLimit
		or offset.Y > Config.MaxHeightAboveFloor
		or distance > allowed
	then
		entry.root.CFrame = entry.acceptedFrame
		entry.root.AssemblyLinearVelocity = Vector3.zero
		return false
	end
	entry.movementCredit = math.max(0, math.min(Config.MovementDistanceSlack, allowed - distance))
	entry.acceptedFrame = entry.root.CFrame
	return true
end

-- Cập nhật 20Hz: loại character mất/reset, bleedout và chỉ tính thời gian còn sống.
function PlayerStateService.step(now: number, delta: number)
	for player, entry in entries do
		if
			entry.character ~= player.Character
			or not entry.root.Parent
			or entry.humanoid.Health <= 0
			or (entry.state == "DOWNED" and now >= entry.bleedoutAt)
		then
			PlayerStateService.eliminate(player)
		elseif entry.state == "ALIVE" then
			entry.validPosition = validatePosition(entry, now)
			entry.survival += delta
		end
	end
end

-- Xoá người rời server để các vòng lặp không giữ Player/character cũ.
function PlayerStateService.remove(player: Player)
	if entries[player] then
		restore(entries[player])
	end
	entries[player] = nil
end
-- Dọn cuối trận, khôi phục movement trước khi teleport lobby.
function PlayerStateService.clear()
	for _, entry in entries do
		restore(entry)
	end
	table.clear(entries)
end
return PlayerStateService
