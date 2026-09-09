--!strict
--[[ UIController — HUD phản ứng bằng Fusion 0.3; MatchController cấp văn bản.
	Scope sở hữu mọi GUI/value, destroy dọn toàn bộ khi Main bị huỷ. ]]
local Players = game:GetService("Players")
local Fusion = require(game:GetService("ReplicatedStorage").Packages.Fusion)
local UI = {}
local scope = Fusion.scoped(Fusion)
local values: { [string]: any } = {}
local gui: ScreenGui

local function panel(name: string, position: UDim2, size: UDim2, anchor: Vector2, textSize: number)
	values[name] = scope:Value("")
	scope:New("TextLabel")({
		Name = name,
		Parent = gui,
		Position = position,
		Size = size,
		AnchorPoint = anchor,
		BackgroundColor3 = Color3.fromRGB(16, 23, 38),
		BackgroundTransparency = 0.15,
		TextColor3 = Color3.fromRGB(225, 250, 246),
		Font = Enum.Font.GothamBold,
		TextSize = textSize,
		TextWrapped = true,
		Text = values[name],
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		},
	})
end

-- Tạo HUD một lần; dùng phần trăm chiều ngang để không tràn màn hình mobile.
function UI.start()
	gui = scope:New("ScreenGui")({
		Name = "CloneHUD",
		ResetOnSpawn = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	panel("Timer", UDim2.fromScale(0.5, 0.02), UDim2.new(0.36, 0, 0, 76), Vector2.new(0.5, 0), 24)
	panel("Team", UDim2.fromScale(0.02, 0.03), UDim2.new(0.25, 0, 0, 145), Vector2.zero, 14)
	panel("Cores", UDim2.fromScale(0.98, 0.03), UDim2.new(0.22, 0, 0, 100), Vector2.new(1, 0), 16)
	panel("Hint", UDim2.fromScale(0.5, 0.78), UDim2.new(0.64, 0, 0, 66), Vector2.new(0.5, 1), 17)
	panel("Echo", UDim2.fromScale(0.5, 0.98), UDim2.new(0.35, 0, 0, 48), Vector2.new(0.5, 1), 17)
	panel(
		"Result",
		UDim2.fromScale(0.5, 0.45),
		UDim2.new(0.65, 0, 0, 180),
		Vector2.new(0.5, 0.5),
		20
	)
	local result = gui:FindFirstChild("Result") :: TextLabel
	result.Visible = false
end

-- Cập nhật text bằng Value:set; không tái tạo cây UI mỗi snapshot.
function UI.set(name: string, text: string)
	values[name]:set(text)
	if name == "Result" then
		(gui:FindFirstChild("Result") :: TextLabel).Visible = text ~= ""
	end
end
-- Trả ScreenGui để ReviveController gắn nút interaction touch/gamepad.
function UI.getGui(): ScreenGui
	return gui
end
-- Dọn toàn bộ scope theo API Fusion, không để observer tồn tại sau controller.
function UI.destroy()
	scope:doCleanup()
end
return UI
