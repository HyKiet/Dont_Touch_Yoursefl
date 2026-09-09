# DON'T TOUCH YOURSELF — Rules cho mọi Agent

Dự án: Roblox co-op survival prototype. Nguồn thiết kế duy nhất là
[GDD Prototype — DON'T TOUCH YOURSELF.md](GDD%20Prototype%20%E2%80%94%20DON'T%20TOUCH%20YOURSELF.md).

> **BẮT BUỘC:** Trước khi viết hoặc sửa BẤT KỲ chức năng nào, gọi skill `rbx-canon`.
> Không có ngoại lệ — kể cả sửa 1 dòng, kể cả "chỉ đổi tên biến".

---

## R1. Creator-docs là kim chỉ nam

Nguồn sự thật về API/engine là **https://github.com/Roblox/creator-docs**, không phải trí nhớ.

- Dùng API nào → tra tài liệu API đó **trước khi viết**, không viết theo trí nhớ rồi sửa sau.
- Trí nhớ về Roblox API có thể lỗi thời (API bị deprecate, đổi chữ ký, đổi hành vi).
- Nếu tra không ra → **nói rõ là chưa xác minh được**, không đoán rồi trình bày như thật.
- Khi tài liệu và trí nhớ mâu thuẫn → tài liệu thắng.

Chi tiết cách tra: xem skill `rbx-canon`.

## R2. Code phải người mới học lập trình đọc hiểu 100%

Người đọc mục tiêu: một người mới học lập trình được 1 tháng. Nếu họ phải dừng lại
tự hỏi "cái này là gì", đoạn code đó **chưa đạt** và phải viết lại.

- Tên biến/hàm nói rõ ý nghĩa: `secondsUntilNextEcho`, không phải `t`, `tmp`, `x2`.
- Không viết tắt tự chế. `playerCount` không phải `plCnt`.
- Mỗi ModuleScript mở đầu bằng comment tiếng Việt: file này làm gì, ai gọi nó.
- Mỗi hàm public có comment: nhận gì, trả gì, làm gì.
- Chỗ nào dùng API Roblox ít gặp → comment 1 dòng giải thích **API đó làm gì**.
- Chỗ nào code trông "lạ" (tối ưu, workaround engine) → comment giải thích **tại sao**
  phải làm vậy, nếu không người sau sẽ tưởng là lỗi và xoá.
- Comment giải thích **tại sao**, không lặp lại **cái gì** code đã nói rõ.

## R3. Clean & đơn giản

- Một hàm làm một việc. Quá 40 dòng → tách.
- Nesting tối đa 3 tầng. Sâu hơn → dùng early return (`if not x then return end`).
- Không metatable, không OOP nhiều tầng, không DI framework, không generic thông minh.
  Đây là prototype: **module trả về table các hàm** là đủ.
- Không viết abstraction cho tương lai tưởng tượng. Chỉ viết cái GDD yêu cầu.
- Không copy-paste 3 lần. Lần thứ 2 lặp lại thì cân nhắc, lần thứ 3 thì tách hàm.

## R4. Tối ưu hoá — bắt buộc nghĩ trước khi viết

Đây là game multiplayer chạy 150 giây với số Echo tăng dần. Trước khi coi một tính năng
là xong, phải trả lời được:

1. Cuối match (~15 Echo/player) tính năng này tốn bao nhiêu? Chi phí phải tuyến tính
   theo số object đang active, không bao giờ là `mọi player × mọi echo × mọi frame`.
2. Có `Instance.new` / `:Clone()` nào chạy trong vòng lặp mỗi frame không? → phải bỏ.
3. Có `GetChildren()` / `GetDescendants()` nào chạy mỗi frame không? → cache lại.
4. Vòng lặp này có thể thành event-driven không? Event luôn thắng polling.
5. Mọi connection (`:Connect`) có được `:Disconnect()` khi match kết thúc không?
   Rò connection = server chết dần sau vài match.
6. Echo **không dùng Humanoid**. Replay bằng cách set CFrame trực tiếp.
   60 Humanoid cùng lúc sẽ giết server.

## R5. Kiến trúc — theo đúng mục M của GDD

- Mỗi system = một Service riêng trong `ServerScriptService/Services`.
- Không nhét nhiều system vào một Script.
- Mọi con số gameplay nằm trong `ReplicatedStorage/Shared/GameConfig` (mục O của GDD).
  Thấy số magic rải trong logic → sai, phải đưa về Config.
- Không circular dependency giữa các Service.

## R6. Server authoritative

Server quyết định: match state, alive/downed, core collection, reward, revive, echo hit.
Client chỉ làm: UI, VFX, sound, input, nội suy hình ảnh.
Không bao giờ tin số liệu client gửi lên — luôn validate lại ở server.

## R7. Không tự ý mở rộng scope

Mục Q của GDD liệt kê những thứ **không** làm. Không thêm feature ngoài GDD.
Thấy ý tưởng hay → nêu ra cho người dùng quyết, đừng tự code.

## R8. Báo cáo trung thực

Chưa test thì nói chưa test. Có lỗi thì đưa nguyên văn lỗi ra.
Không nói "đã xong" khi mới xong một phần.
