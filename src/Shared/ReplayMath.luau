--!strict
--[[ ReplayMath — Nội suy đường chạy; recorder, Echo server/client và test dùng chung.
	Không truy cập service để kiểm thử thuật toán độc lập với trận đấu. ]]
local ReplayMath = {}
export type Sample = { time: number, frame: CFrame, state: number }

-- Nhận đường chạy và thời gian tương đối; trả CFrame cùng trạng thái đã ghi.
function ReplayMath.sample(path: { Sample }, elapsed: number): (CFrame, number)
	assert(#path > 0, "[ReplayMath] Empty path")
	if #path == 1 or elapsed <= path[1].time then
		return path[1].frame, path[1].state
	end
	local last = path[#path]
	if elapsed >= last.time then
		return last.frame, last.state
	end
	-- Tìm nhị phân tránh quét 100 sample cho mỗi Echo ở mỗi frame.
	local lower, upper = 1, #path
	while upper - lower > 1 do
		local middle = math.floor((lower + upper) / 2)
		if path[middle].time <= elapsed then
			lower = middle
		else
			upper = middle
		end
	end
	local first, second = path[lower], path[upper]
	local alpha = (elapsed - first.time) / math.max(second.time - first.time, 0.000001)
	return first.frame:Lerp(second.frame, alpha), first.state
end

-- Nhận hai vị trí; trả bình phương khoảng cách, không cần căn bậc hai.
function ReplayMath.distanceSquared(first: Vector3, second: Vector3): number
	local difference = first - second
	return difference:Dot(difference)
end

-- Tính thưởng từ dữ liệu server; không tự sửa số dư hay gọi analytics.
function ReplayMath.reward(cores: number, survival: number, victory: boolean, config: any): number
	return cores * config.CoreReward
		+ math.floor(survival / config.SurvivalRewardInterval)
		+ (if victory then config.VictoryBonus else 0)
end
return ReplayMath
