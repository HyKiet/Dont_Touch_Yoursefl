---
name: rbx-canon
description: >
  BẮT BUỘC load trước khi viết hoặc sửa bất kỳ code Roblox/Luau nào trong dự án này.
  Quy trình tra cứu Roblox/creator-docs làm nguồn sự thật trước khi code, cộng chuẩn
  code clean / tối ưu / đơn giản có giải thích để người mới học lập trình đọc hiểu được.
  Load cho: viết Service, sửa chức năng, dùng API Roblox, review code, refactor,
  fix bug, thêm RemoteEvent, đụng vào bất cứ file .luau/.lua nào.
user-invocable: true
---

# rbx-canon — Kim chỉ nam code cho dự án này

Skill này có 2 phần bắt buộc chạy theo thứ tự:
**Phần 1 — tra tài liệu trước khi viết. Phần 2 — viết theo chuẩn code của dự án.**

Không được nhảy thẳng vào Phần 2.

---

# PHẦN 1 — CREATOR-DOCS LÀ NGUỒN SỰ THẬT

Repo: `https://github.com/Roblox/creator-docs`

## 1.1 Vì sao bắt buộc

Trí nhớ về Roblox API **không đáng tin**: API bị deprecate, chữ ký thay đổi, hành vi
thay đổi giữa các bản engine. Code viết theo trí nhớ trông đúng nhưng chạy sai là
loại bug tốn thời gian nhất. Tra tài liệu mất 30 giây, debug mất 2 tiếng.

## 1.2 Khi nào phải tra (checklist)

Tra **trước khi viết dòng code đầu tiên** nếu gặp bất kỳ điều nào sau:

- [ ] Dùng một class/method/property/event mà bạn không dùng hàng ngày.
- [ ] Không chắc 100% về **thứ tự hoặc kiểu tham số** của một hàm.
- [ ] Không chắc hàm chạy được ở **server hay client** (hoặc cả hai).
- [ ] Đụng tới: DataStore, Teleport, Humanoid states, CollectionService,
      RunService loops, Remotes, Physics/CFrame, StreamingEnabled, Sound, Tween.
- [ ] Định dùng một API mà bạn "nhớ mang máng là có".
- [ ] Chọn giữa 2 cách làm và không chắc cách nào là cách Roblox khuyến nghị.

Nếu tất cả đều không → vẫn phải ghi rõ trong câu trả lời rằng bạn đang dùng API quen
thuộc và không tra. Người dùng có quyền biết cái gì đã được xác minh, cái gì chưa.

## 1.3 Cách tra — theo thứ tự

**Bước 1: đọc raw file trên GitHub (nhanh nhất, chính xác nhất).**

Dùng `WebFetch` với URL dạng:

```
https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/<đường-dẫn>
```

Tham chiếu API của một class nằm ở:

```
content/en-us/reference/engine/classes/<TênClass>.yaml
```

Ví dụ: `.../reference/engine/classes/Humanoid.yaml`,
`.../reference/engine/classes/RunService.yaml`,
`.../reference/engine/classes/DataStoreService.yaml`.

Các nhóm khác: `reference/engine/datatypes/` (CFrame, Vector3, ...),
`reference/engine/enums/`, `reference/engine/globals/`.
Bài hướng dẫn và khái niệm nằm trong các thư mục chủ đề như `scripting/`, `ui/`,
`cloud-services/`, `projects/`, `production/`, `tutorials/`.

**Bước 2: nếu URL trả 404** — đừng đoán đường dẫn khác nhiều lần. Chuyển sang
`WebSearch` với truy vấn `site:create.roblox.com/docs <chủ đề>` hoặc
`Roblox creator-docs <TênClass> <TênMethod>`.

**Bước 3: nếu vẫn không ra** — nói thẳng với người dùng:
"Tôi không xác minh được API này trong creator-docs, đây là cách tôi hiểu nhưng chưa chắc."
**Tuyệt đối không trình bày phỏng đoán như sự thật đã kiểm chứng.**

## 1.4 Đọc gì trong tài liệu

Không chỉ liếc tên hàm. Phải nắm:

1. **Chữ ký**: tên tham số, kiểu, giá trị trả về, tham số nào optional.
2. **Security / thread**: chạy được ở server, client, hay cả hai.
3. **Deprecated?** Nếu có → dùng API thay thế mà tài liệu chỉ định, và ghi chú
   trong câu trả lời rằng bạn đã tránh API cũ.
4. **Có yield không**: hàm có block luồng không (ảnh hưởng trực tiếp tới game loop).
5. **Giới hạn / rate limit**: đặc biệt DataStore, MessagingService, HttpService.

## 1.5 Ghi lại đã tra

Khi dùng một API vừa tra, **để lại dấu vết trong code** để người sau không phải tra lại:

```lua
-- Humanoid:MoveTo() sẽ tự huỷ lệnh sau 8 giây nếu chưa tới nơi.
-- (creator-docs: reference/engine/classes/Humanoid.yaml)
-- Vì vậy với quãng đường dài phải gọi lại định kỳ.
humanoid:MoveTo(targetPosition)
```

Và trong câu trả lời cho người dùng, nêu ngắn gọn: "Đã đối chiếu `Humanoid:MoveTo` với
creator-docs — có giới hạn timeout 8s nên mình gọi lại theo chu kỳ."

---

# PHẦN 2 — CHUẨN CODE: CLEAN, TỐI ƯU, ĐƠN GIẢN, CÓ GIẢI THÍCH

## 2.1 Người đọc mục tiêu

> Một người **mới học lập trình 1 tháng** phải đọc hiểu 100% file bạn viết,
> không cần hỏi ai.

Đây là tiêu chuẩn nghiệm thu, không phải lời khuyên. Nếu một đoạn code cần người đọc
"tự hiểu ra", đoạn đó chưa đạt và phải viết lại.

## 2.2 Cấu trúc chuẩn một ModuleScript

```lua
--!strict
--[[
	EchoService — Quản lý toàn bộ vòng đời của Echo trong một trận.

	Echo là bản ghi lại đường chạy quá khứ của người chơi. Cứ mỗi 10 giây,
	Service này lấy đoạn di chuyển vừa rồi và tạo ra một Echo chạy lặp lại đoạn đó.

	Ai gọi file này:  MatchService (bắt đầu / kết thúc trận)
	File này gọi ai:  MovementRecorderService (lấy dữ liệu đường chạy)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EchoService = {}

-- Danh sách mọi Echo đang tồn tại trong trận hiện tại.
-- Giữ lại để dọn sạch khi trận kết thúc (nếu quên dọn sẽ rò bộ nhớ).
local activeEchoes: { Model } = {}

--[[
	Tạo một Echo mới chạy lặp lại đoạn đường đã ghi.

	@param owner        Người chơi sở hữu đoạn đường này
	@param recordedPath Danh sách vị trí đã ghi, mỗi 0.1 giây một điểm
	@return             Model của Echo vừa tạo
]]
function EchoService.spawnEcho(owner: Player, recordedPath: { CFrame }): Model
	-- ...
end

return EchoService
```

**Bắt buộc có:** `--!strict`, block comment đầu file (làm gì / ai gọi / gọi ai),
comment cho mọi hàm public, comment cho mọi biến trạng thái không hiển nhiên.

## 2.3 Quy tắc đặt tên

| Loại | Quy tắc | Ví dụ đúng | Ví dụ sai |
|---|---|---|---|
| Biến local | camelCase, danh từ đầy đủ | `secondsUntilNextEcho` | `t`, `sec`, `x` |
| Hàm | camelCase, động từ | `spawnEcho`, `isPlayerDowned` | `echo2`, `doStuff` |
| Boolean | bắt đầu `is` / `has` / `can` | `isMatchRunning` | `flag`, `status` |
| Hằng số | SCREAMING_SNAKE | `MAX_ACTIVE_CORES` | `maxcores` |
| Module | PascalCase = tên file | `EchoService` | `echosvc` |

Không viết tắt tự chế. Định danh viết tiếng Anh, comment viết tiếng Việt.

## 2.4 Comment: giải thích TẠI SAO, không lặp lại CÁI GÌ

```lua
-- ❌ Vô dụng — code đã nói rõ rồi
-- Cộng 1 vào score
score = score + 1

-- ✅ Có giá trị — giải thích lý do
-- Chỉ cộng điểm ở server. Nếu để client tự cộng, người chơi có thể
-- dùng exploit sửa số này rồi gửi lên.
score = score + 1
```

Ba chỗ **luôn phải** có comment:
1. API Roblox ít gặp → giải thích API đó làm gì (kèm nguồn creator-docs).
2. Code trông lạ / workaround → giải thích tại sao, nếu không người sau sẽ xoá nhầm.
3. Con số ma còn sót lại → giải thích, hoặc tốt hơn là chuyển vào `GameConfig`.

## 2.5 Đơn giản hoá — dùng early return

```lua
-- ❌ 4 tầng lồng nhau, khó đọc
function EchoService.tryHitPlayer(echo, player)
	if player then
		if player.Character then
			if not isInvulnerable(player) then
				if isCloseEnough(echo, player) then
					downPlayer(player)
				end
			end
		end
	end
end

-- ✅ Phẳng, mỗi điều kiện là một "cửa ải" đọc từ trên xuống
function EchoService.tryHitPlayer(echo: Model, player: Player)
	if not player.Character then return end          -- chưa spawn xong
	if isInvulnerable(player) then return end        -- vừa hồi sinh, còn miễn nhiễm
	if not isCloseEnough(echo, player) then return end

	downPlayer(player)
end
```

Giới hạn cứng: **hàm ≤ 40 dòng, lồng nhau ≤ 3 tầng.** Vượt là phải tách.

## 2.6 Không over-engineer

Đây là prototype (GDD mục T.6). **Không** dùng: metatable / OOP kế thừa nhiều tầng,
dependency injection framework, signal library tự viết, generic "cho linh hoạt sau này",
abstraction cho feature chưa tồn tại.

**Dùng:** module trả về một table các hàm. Hết. Đơn giản như vậy là đủ và đúng.

## 2.7 Tối ưu hoá — 6 câu hỏi bắt buộc trước khi coi là xong

1. **Cuối trận tốn bao nhiêu?** Cuối match có ~14 Echo mỗi người chơi.
   Chi phí phải tuyến tính theo số Echo, không được là `echo × player × frame`.
2. **Có `Instance.new` / `:Clone()` trong vòng lặp mỗi frame không?** → phải bỏ,
   tạo sẵn từ trước rồi tái sử dụng.
3. **Có `GetChildren()` / `GetDescendants()` mỗi frame không?** → cache vào biến.
4. **Có thể chuyển từ polling sang event không?** Event luôn thắng vòng lặp.
   Nếu buộc phải lặp, giảm tần suất (10-20 Hz thay vì mỗi frame).
5. **Mọi `:Connect()` có `:Disconnect()` khi hết trận không?**
   Rò connection = server chậm dần rồi chết sau vài trận. Đây là bug số 1 của game Roblox.
6. **Echo có đang dùng Humanoid không?** → **Không được.** Replay bằng cách set
   `CFrame` trực tiếp lên Model. Hàng chục Humanoid cùng lúc sẽ giết server.

Khi tối ưu, luôn kèm comment giải thích, nếu không người mới sẽ tưởng là code thừa:

```lua
-- Kiểm tra va chạm 20 lần/giây thay vì mỗi frame (~60 lần/giây).
-- Với hàng chục Echo, kiểm tra mỗi frame tốn gấp 3 lần CPU mà mắt người
-- không phân biệt được khác nhau.
local HIT_CHECK_INTERVAL = 1 / 20
```

## 2.8 Trước khi báo "xong" — tự kiểm

- [ ] Mọi API lạ đã đối chiếu creator-docs và ghi nguồn trong comment.
- [ ] Người mới học 1 tháng đọc hiểu được toàn bộ file.
- [ ] Không còn số magic — tất cả nằm trong `GameConfig`.
- [ ] Mọi connection đều được dọn khi trận kết thúc.
- [ ] Không hàm nào > 40 dòng, không chỗ nào lồng > 3 tầng.
- [ ] Server authoritative — client không tự quyết damage/reward.
- [ ] Không thêm feature ngoài GDD.
- [ ] Đã nói rõ cái gì đã test, cái gì chưa.
