--!strict
--[[ EchoVisualController — Pool clone không Humanoid, nội suy đường chạy server.
	MatchController tạo pool khi có roster; Main gọi render và nhận Echo packet. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.GameConfig)
local ReplayMath = require(ReplicatedStorage.Shared.ReplayMath)
local Animation = require(script.Parent.EchoAnimationController)
local EchoVisual = {}
local pools: { [number]: any } = {}
local active: { [number]: any } = {}
local currentMatch = 0
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "LocalEchoes", workspace

local function fallback(): Model
	local model = Instance.new("Model")
	local shapes = {
		{ name = "Torso", size = Vector3.new(2, 2, 1), position = Vector3.zero },
		{ name = "Head", size = Vector3.new(2, 1, 1), position = Vector3.new(0, 1.5, 0) },
		{ name = "LeftArm", size = Vector3.new(1, 2, 1), position = Vector3.new(-1.5, 0, 0) },
		{ name = "RightArm", size = Vector3.new(1, 2, 1), position = Vector3.new(1.5, 0, 0) },
		{ name = "LeftLeg", size = Vector3.new(1, 2, 1), position = Vector3.new(-0.5, -2, 0) },
		{ name = "RightLeg", size = Vector3.new(1, 2, 1), position = Vector3.new(0.5, -2, 0) },
	}
	for _, shape in shapes do
		local part = Instance.new("Part")
		part.Name, part.Size, part.Position, part.Parent =
			shape.name, shape.size, shape.position, model
	end
	model.PrimaryPart = model:FindFirstChild("Torso") :: BasePart
	return model
end

local function cloneBody(ownerId: number): (Model, { [string]: string })
	local player = Players:GetPlayerByUserId(ownerId)
	local character = if player then player.Character else nil
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		warn("[EchoVisual] Character not streamed; using body fallback", ownerId)
		return fallback(), {}
	end
	local oldArchivable = character.Archivable
	local animationIds = Animation.read(character)
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = oldArchivable
	-- Strip trước khi Parent: script hoặc Humanoid trong clone không được chạy dù chỉ 1 frame.
	for _, child in clone:GetDescendants() do
		if
			child:IsA("LuaSourceContainer")
			or child:IsA("Humanoid")
			or (child:IsA("Constraint") and not child:IsA("AnimationConstraint"))
			or child:IsA("Sound")
		then
			child:Destroy()
		elseif child:IsA("AnimationConstraint") then
			-- R15 mới dùng AnimationConstraint thay Motor6D; giữ ở chế độ kinematic, không ragdoll.
			-- creator-docs: AnimationConstraint.yaml. Không sửa Attachment.CFrame/C0/C1.
			child.IsKinematic = true
			-- Client vào trễ có thể clone người đang ragdoll; Echo vẫn phải chạy animation.
			child.Enabled = true
		elseif child:IsA("Motor6D") then
			child.Enabled = true
		end
	end
	clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart") :: BasePart
	return clone, animationIds
end

local function nameTag(model: Model, name: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size, billboard.StudsOffset, billboard.MaxDistance =
		UDim2.fromOffset(140, 24), Vector3.new(0, 3.5, 0), 100
	billboard.Adornee, billboard.Parent =
		assert(model.PrimaryPart, "[EchoVisual] Missing primary part"), model
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text, label.TextColor3, label.TextSize = name, color, 14
	label.Font, label.TextStrokeTransparency, label.Parent = Enum.Font.GothamBold, 0.5, billboard
end

local function makeSlot(template: Model, color: Color3, animationIds: { [string]: string }): any
	local model = template:Clone()
	local parts = {}
	for _, child in model:GetDescendants() do
		if not child:IsA("BasePart") then
			continue
		end
		child.Anchored = child == model.PrimaryPart or next(animationIds) == nil
		child.CanCollide, child.CanTouch, child.CanQuery, child.Massless = false, false, false, true
		child.LocalTransparencyModifier = 0
		-- Dynamic head có texture alpha; xoá texture để đầu neon không chỉ còn nét mặt lơ lửng.
		if child:IsA("MeshPart") then
			child.TextureID = ""
		end
		child.Color, child.Material, child.CastShadow = color, Enum.Material.Neon, false
		local transparency = if child == model.PrimaryPart
				and child.Name == "HumanoidRootPart"
				and #model:GetChildren() > 6
			then 1
			else 0.55
		child.Transparency = transparency
		table.insert(parts, { part = child, transparency = transparency })
	end
	model:PivotTo(CFrame.new(Config.EchoPoolHiddenPosition))
	model.Parent = folder
	local animation = Animation.setup(model, animationIds)
	model.Parent = nil
	return { model = model, parts = parts, animation = animation, echoId = 0, fadeAt = 0 }
end

local function prepareOwner(ownerId: number, name: string, colorIndex: number)
	if pools[ownerId] then
		return
	end
	local color = Config.EchoColors[colorIndex]
	local template, animationIds = cloneBody(ownerId)
	nameTag(template, name, color)
	local pool = {}
	for _ = 1, Config.EchoPoolSlots do
		table.insert(pool, makeSlot(template, color, animationIds))
	end
	template:Destroy()
	pools[ownerId] = pool
end

-- Dọn cả model active lẫn pool chưa parent khi trận thay đổi.
function EchoVisual.clear()
	for _, pool in pools do
		for _, slot in pool do
			Animation.stop(slot.animation)
			slot.model:Destroy()
		end
	end
	table.clear(pools)
	table.clear(active)
end

-- Prewarm tối đa 9 model/người trước Echo đầu tiên, không Clone trong render loop.
function EchoVisual.prepare(snapshot: any)
	if snapshot.matchId ~= currentMatch then
		EchoVisual.clear()
		currentMatch = snapshot.matchId
	end
	if snapshot.state ~= "PLAYING" then
		EchoVisual.clear()
		return
	end
	for _, row in snapshot.players do
		prepareOwner(row.userId, row.name, row.colorIndex)
	end
end

local function availableSlot(pool: any, now: number): any
	local oldest, count, free = nil, 0, nil
	for _, slot in pool do
		if slot.echoId == 0 then
			free = slot
		elseif slot.fadeAt == 0 then
			count += 1
			if not oldest or slot.echoId < oldest.echoId then
				oldest = slot
			end
		end
	end
	if count >= Config.MaxEchoesPerPlayer and oldest then
		oldest.fadeAt = now
		active[oldest.echoId] = nil
	end
	return free
end

-- Nhận path đáng tin từ server; packet trùng do Ready không tạo bản sao.
function EchoVisual.receive(data: any)
	if data.matchId ~= currentMatch or active[data.id] then
		return
	end
	local player = Players:GetPlayerByUserId(data.ownerId)
	prepareOwner(data.ownerId, if player then player.DisplayName else "Echo", data.colorIndex)
	local slot = availableSlot(pools[data.ownerId], workspace:GetServerTimeNow())
	if not slot then
		warn("[EchoVisual] Pool exhausted", data.ownerId)
		return
	end
	slot.echoId, slot.fadeAt, slot.data = data.id, 0, data
	for _, item in slot.parts do
		item.part.Transparency = item.transparency
	end
	slot.model.Parent = folder
	active[data.id] = slot
end

-- Chỉ PivotTo và transparency mỗi frame; không tìm descendants/khởi tạo instance.
function EchoVisual.render(now: number)
	for _, slot in active do
		local elapsed = (now - slot.data.born) % slot.data.duration
		local frame, state = ReplayMath.sample(slot.data.path, elapsed)
		local following = ReplayMath.sample(
			slot.data.path,
			math.min(elapsed + Config.MovementRecordInterval, slot.data.duration)
		)
		local movement = following.Position - frame.Position
		local speed = Vector3.new(movement.X, 0, movement.Z).Magnitude
			/ Config.MovementRecordInterval
		slot.model:PivotTo(frame)
		Animation.update(
			slot.animation,
			state,
			speed,
			elapsed,
			now,
			movement.Y / Config.MovementRecordInterval
		)
	end
	for _, pool in pools do
		for _, slot in pool do
			if slot.fadeAt == 0 then
				continue
			end
			local alpha = math.clamp((now - slot.fadeAt) / Config.EchoFadeDuration, 0, 1)
			for _, item in slot.parts do
				item.part.Transparency = item.transparency + (1 - item.transparency) * alpha
			end
			if alpha == 1 then
				Animation.stop(slot.animation)
				slot.model.Parent = nil
				slot.echoId, slot.fadeAt = 0, 0
			end
		end
	end
end
-- Main gọi khi controller bị huỷ.
function EchoVisual.destroy()
	EchoVisual.clear()
	folder:Destroy()
end
return EchoVisual
