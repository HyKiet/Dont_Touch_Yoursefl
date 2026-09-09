--!strict
--[[ RagdollService — PlayerStateService bật vật lý khi Echo hạ người chơi,
	trả khớp và quyền điều khiển khi cứu/lobby. Không có vòng lặp mỗi frame. ]]
local Config = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local RagdollService = {}

local function addSocket(state: any, joint: any)
	local first, second = joint.Part0, joint.Part1
	if not first or not second or first == state.root or second == state.root then
		return
	end
	table.insert(state.joints, { object = joint, enabled = joint.Enabled })
	if
		joint:IsA("AnimationConstraint")
		and state.sockets[joint.Attachment0] == joint.Attachment1
	then
		-- Avatar mới đã có ball socket giới hạn khớp đúng theo từng bộ phận.
		joint.Enabled = false
		return
	end
	local attachment0, attachment1 = Instance.new("Attachment"), Instance.new("Attachment")
	attachment0.Name, attachment1.Name = "RagdollAttachment", "RagdollAttachment"
	-- Không sửa RigAttachment gốc vì sẽ phá animation retargeting của avatar mới.
	-- creator-docs: classes/AnimationConstraint.yaml, Motor6D.yaml, BallSocketConstraint.yaml.
	attachment0.CFrame, attachment1.CFrame = joint.C0, joint.C1
	attachment0.Parent, attachment1.Parent = first, second
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollSocket"
	socket.Attachment0, socket.Attachment1 = attachment0, attachment1
	socket.LimitsEnabled, socket.TwistLimitsEnabled = true, true
	socket.UpperAngle = Config.RagdollUpperAngle
	socket.TwistLowerAngle, socket.TwistUpperAngle =
		-Config.RagdollTwistAngle, Config.RagdollTwistAngle
	socket.Parent = state.folder
	local noCollision = Instance.new("NoCollisionConstraint")
	noCollision.Part0, noCollision.Part1 = first, second
	noCollision.Parent = state.folder
	table.insert(state.attachments, attachment0)
	table.insert(state.attachments, attachment1)
	joint.Enabled = false
end

local function prepareParts(state: any, character: Model)
	local descendants = character:GetDescendants()
	for _, object in descendants do
		if object:IsA("BallSocketConstraint") and object.Enabled and object.Attachment0 then
			state.sockets[object.Attachment0] = object.Attachment1
		end
	end
	for _, object in character:GetChildren() do
		if not object:IsA("BasePart") then
			continue
		end
		table.insert(state.parts, { object = object, canCollide = object.CanCollide })
		object.CanCollide = object ~= state.root
	end
	for _, object in descendants do
		if object:IsA("Motor6D") or object:IsA("AnimationConstraint") then
			addSocket(state, object)
		end
	end
end

-- Nhận entry server; đổi khớp thành ball socket, giữ Humanoid sống để đồng đội còn cứu được.
function RagdollService.start(entry: any)
	if entry.ragdoll or not entry.root.Parent or not entry.humanoid.Parent then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "RagdollConstraints", entry.character
	local state: any = {
		root = entry.root,
		folder = folder,
		parts = {},
		joints = {},
		attachments = {},
		sockets = {},
		requiresNeck = entry.humanoid.RequiresNeck,
	}
	entry.ragdoll = state
	-- RequiresNeck tránh chết khi tạm ngắt cổ; Physics cần server sở hữu character.
	-- creator-docs: classes/Humanoid.yaml, BasePart.yaml (SetNetworkOwner).
	entry.humanoid.RequiresNeck = false
	entry.root.Anchored = false
	entry.root:SetNetworkOwner(nil)
	entry.humanoid.AutoRotate, entry.humanoid.PlatformStand = false, true
	entry.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	prepareParts(state, entry.character)
	for _, part in state.parts do
		if part.object:CanSetNetworkOwnership() then
			part.object:SetNetworkOwner(nil)
		end
	end
	-- Một vận tốc góc nhỏ giúp nhân vật đứng yên cũng ngã, không tăng hit radius hay damage.
	entry.root.AssemblyAngularVelocity = entry.root.CFrame.RightVector * Config.RagdollFallSpeed
end

local function restoreParts(state: any)
	for _, part in state.parts do
		local object = part.object
		if not object.Parent then
			continue
		end
		object.CanCollide = part.canCollide
		object.AssemblyLinearVelocity, object.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	end
	for _, joint in state.joints do
		if joint.object.Parent then
			joint.object.Enabled = joint.enabled
		end
	end
	state.folder:Destroy()
	for _, attachment in state.attachments do
		attachment:Destroy()
	end
end

-- Nhận entry; dọn toàn bộ vật tạo thêm và trả khớp gốc, gọi nhiều lần vẫn an toàn.
function RagdollService.stop(entry: any)
	local state = entry.ragdoll
	if not state then
		return
	end
	entry.ragdoll = nil
	restoreParts(state)
	if not entry.root.Parent or not entry.humanoid.Parent then
		return
	end
	entry.humanoid.RequiresNeck = state.requiresNeck
	entry.humanoid.PlatformStand = false
	entry.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	if entry.root:CanSetNetworkOwnership() then
		entry.root:SetNetworkOwnershipAuto()
	end
end

return RagdollService
