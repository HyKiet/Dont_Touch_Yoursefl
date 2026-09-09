--!strict
--[[ Main client — Kết nối packet/controller một lần cho mỗi client.
	Server gửi snapshot/path; PreRender chỉ nội suy Echo, không xử lý gameplay. ]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Janitor = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Janitor"))
local Packets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packets"))
local UI = require(script.Parent.UIController)
local Match = require(script.Parent.MatchController)
local EchoVisual = require(script.Parent.EchoVisualController)
local Feedback = require(script.Parent.FeedbackController)
local Revive = require(script.Parent.ReviveController)
local cleanup = Janitor.new()
UI.start()
Feedback.start()
Packets.Snapshot.listen(function(encoded: string)
	Match.receive(HttpService:JSONDecode(encoded))
end)
Packets.Echo.listen(Match.echo)
Packets.Ready.send(nil)
local lastUpdate = 0
-- PreRender chạy mỗi frame ngay trước khi khung hình được vẽ, và chỉ có ở client.
-- Đây là tên mới của RenderStepped — RenderStepped đã bị deprecate
-- (creator-docs: reference/engine/classes/RunService.yaml).
cleanup:Add(RunService.PreRender:Connect(function()
	local now = workspace:GetServerTimeNow()
	EchoVisual.render(now)
	if now - lastUpdate >= 0.1 then
		lastUpdate = now
		Match.update(now)
	end
end))
cleanup:Add(game:GetService("UserInputService").WindowFocusReleased:Connect(Revive.destroy))
cleanup:Add(script.Destroying:Connect(function()
	cleanup:Destroy()
	Revive.destroy()
	EchoVisual.destroy()
	Feedback.destroy()
	UI.destroy()
	table.clear((Packets.Snapshot :: any).getListeners())
	table.clear((Packets.Echo :: any).getListeners())
end))
print("[Client] Prototype controllers ready")
