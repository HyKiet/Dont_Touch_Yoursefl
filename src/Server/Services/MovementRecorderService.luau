--!strict
--[[ MovementRecorderService — Ghi từng đoạn 10 giây bằng đồng hồ server.
	MatchService gọi step; EchoService nhận path từ take, không đọc client packet. ]]
local Config = require(game:GetService("ReplicatedStorage").Shared.GameConfig)
local States = require(script.Parent.PlayerStateService)
local Recorder = {}
local recordings: { [Player]: any } = {}
local segmentStart = 0
local lastSample = 0

-- Mở đoạn ghi mới tại thời gian server đã đồng bộ.
function Recorder.start(now: number)
	table.clear(recordings)
	segmentStart, lastSample = now, now - Config.MovementRecordInterval
end

-- Ghi tối đa 10Hz, giữ thời gian thực nếu frame bị trễ thay vì bịa sample.
function Recorder.step(now: number)
	if now - lastSample < Config.MovementRecordInterval then
		return
	end
	lastSample = now
	for player, entry in States.getAll() do
		if entry.state ~= "ALIVE" or entry.validPosition == false then
			continue
		end
		local path = recordings[player]
		if not path then
			path = {}
			recordings[player] = path
		end
		table.insert(path, {
			time = now - segmentStart,
			frame = entry.acceptedFrame,
			state = entry.humanoid:GetState().Value,
		})
	end
end

-- Kết thúc đoạn: giữ endpoint để replay không thiếu 0.1s; xoá ownership bảng cũ.
function Recorder.take(now: number): { [Player]: any }
	for player, path in recordings do
		local entry = States.get(player)
		if entry and entry.state == "ALIVE" then
			table.insert(path, {
				time = now - segmentStart,
				frame = entry.acceptedFrame,
				state = entry.humanoid:GetState().Value,
			})
		end
	end
	local result = recordings
	recordings = {}
	segmentStart, lastSample = now, now - Config.MovementRecordInterval
	return result
end

-- Xoá bản ghi người rời server, không giữ dữ liệu cho match sau.
function Recorder.remove(player: Player)
	recordings[player] = nil
end
-- Dọn toàn bộ đường chạy khi trận kết thúc.
function Recorder.clear()
	table.clear(recordings)
end
return Recorder
