--!strict
--[[ Packets — Hợp đồng ByteNet; server gửi trạng thái, client chỉ gửi ý định cứu.
	Main hai phía require một lần; không có packet cộng tiền hoặc báo đã thắng. ]]
local ByteNet = require(game:GetService("ReplicatedStorage").Packages.ByteNet)
return ByteNet.defineNamespace("ClonePrototype", function()
	return {
		Snapshot = ByteNet.definePacket({ value = ByteNet.string }),
		Echo = ByteNet.definePacket({
			value = ByteNet.struct({
				matchId = ByteNet.uint32,
				ownerId = ByteNet.float64,
				colorIndex = ByteNet.uint8,
				id = ByteNet.uint32,
				born = ByteNet.float64,
				duration = ByteNet.float32,
				path = ByteNet.array(ByteNet.struct({
					time = ByteNet.float32,
					frame = ByteNet.cframe,
					state = ByteNet.uint8,
				})),
			}),
		}),
		Revive = ByteNet.definePacket({
			value = ByteNet.struct({ targetId = ByteNet.float64, holding = ByteNet.bool }),
		}),
		Ready = ByteNet.definePacket({ value = ByteNet.nothing }),
	}
end)
