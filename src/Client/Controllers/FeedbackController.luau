--!strict
--[[ FeedbackController — Âm báo sự kiện và flash cơ bản, Main/Match gọi.
	Dùng âm có sẵn trong content Roblox đã kiểm tra trên máy; không cần asset upload. ]]
local SoundService = game:GetService("SoundService")
local Feedback = {}
local sounds: { [string]: Sound } = {}

-- Tạo sound pool một lần, không new Sound mỗi lần nhặt Core.
function Feedback.start()
	local definitions: { [string]: { file: string, speed: number } } = {
		Core = { file = "volume_slider.ogg", speed = 1.5 },
		Echo = { file = "action_get_up.mp3", speed = 0.6 },
		Downed = { file = "ouch.ogg", speed = 0.8 },
		Revived = { file = "action_get_up.mp3", speed = 1.4 },
		Result = { file = "volume_slider.ogg", speed = 0.8 },
	}
	for name, definition in definitions do
		local sound = Instance.new("Sound")
		sound.Name, sound.SoundId = "Clone" .. name, "rbxasset://sounds/" .. definition.file
		sound.PlaybackSpeed, sound.Volume, sound.Parent = definition.speed, 0.5, SoundService
		sounds[name] = sound
	end
end
-- Phát âm ở client; không liên quan authority gameplay (creator-docs: Sound.yaml).
function Feedback.play(name: string)
	local sound = sounds[name]
	if sound then
		sound:Play()
	end
end
-- Dọn sound pool khi Main bị huỷ.
function Feedback.destroy()
	for _, sound in sounds do
		sound:Destroy()
	end
	table.clear(sounds)
end
return Feedback
