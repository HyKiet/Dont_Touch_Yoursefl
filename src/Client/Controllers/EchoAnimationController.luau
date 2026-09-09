--!strict
--[[ EchoAnimationController — Phát animation avatar gốc trên clone không Humanoid.
	EchoVisual gọi setup lúc tạo pool và update ở nhịp hình ảnh; không LoadAnimation mỗi frame. ]]
local Config = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local EchoAnimation = {}

-- Lấy asset đang có trong Animate của chính avatar, không hard-code animation người khác.
function EchoAnimation.read(character: Model): { [string]: string }
	local ids: { [string]: string } = {}
	local animate = character:FindFirstChild("Animate")
	if not animate then
		warn("[EchoAnimation] Avatar has no Animate", character.Name)
		return ids
	end
	for _, name in { "idle", "run", "walk", "jump", "fall" } do
		local group = animate:FindFirstChild(name)
		local animation = if group then group:FindFirstChildWhichIsA("Animation", true) else nil
		if animation then
			ids[name] = animation.AnimationId
		end
	end
	return ids
end

-- Model phải ở Workspace khi LoadAnimation (creator-docs: Animator.yaml).
function EchoAnimation.setup(model: Model, ids: { [string]: string }): any
	local controller = Instance.new("AnimationController")
	controller.Name, controller.Parent = "EchoAnimationController", model
	local animator = Instance.new("Animator")
	animator.Parent = controller
	local tracks: { [string]: AnimationTrack } = {}
	for name, id in ids do
		local animation = Instance.new("Animation")
		animation.Name, animation.AnimationId, animation.Parent = name, id, controller
		local success, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not success then
			warn("[EchoAnimation] Cannot load", id, track)
			continue
		end
		track.Looped = name == "idle" or name == "run" or name == "walk" or name == "fall"
		track.Priority = if name == "idle"
			then Enum.AnimationPriority.Idle
			else Enum.AnimationPriority.Movement
		tracks[name] = track
	end
	return { tracks = tracks, current = "", checkedAt = 0 }
end

local function choose(state: number, speed: number, verticalSpeed: number): string
	-- Jumping có thể ngắn hơn nhịp record 0.1s; hướng đi lên vẫn nằm trong path server.
	if
		state == Enum.HumanoidStateType.Jumping.Value
		or verticalSpeed > Config.EchoAnimationVerticalThreshold
	then
		return "jump"
	end
	if state == Enum.HumanoidStateType.Freefall.Value then
		return "fall"
	end
	return if speed > Config.EchoAnimationMoveThreshold then "run" else "idle"
end

-- Dựa vào state đã record và tốc độ đoạn replay, không đọc movement hiện tại của chủ Echo.
function EchoAnimation.update(
	animation: any,
	state: number,
	speed: number,
	elapsed: number,
	now: number,
	verticalSpeed: number
)
	if now - animation.checkedAt < Config.MovementRecordInterval then
		return
	end
	animation.checkedAt = now
	local name = choose(state, speed, verticalSpeed)
	local track = animation.tracks[name] or animation.tracks.walk or animation.tracks.idle
	if not track then
		return
	end
	if animation.current ~= name then
		for _, playing in animation.tracks do
			playing:Stop(Config.EchoAnimationBlendTime)
		end
		track:Play(Config.EchoAnimationBlendTime)
		if track.Length > 0 and track.Looped then
			track.TimePosition = elapsed % track.Length
		end
		animation.current = name
	end
	local rate = if name == "run"
		then math.clamp(speed / Config.EchoAnimationReferenceSpeed, 0.2, 2)
		else 1
	track:AdjustSpeed(rate)
end

-- Dừng track khi trả model về pool, tránh animator tiếp tục chạy ngoài trận.
function EchoAnimation.stop(animation: any)
	for _, track in animation.tracks do
		track:Stop(0)
	end
	animation.current, animation.checkedAt = "", 0
end
return EchoAnimation
