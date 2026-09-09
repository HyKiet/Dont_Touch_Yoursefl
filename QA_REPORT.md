# QA prototype — 2026-09-08

## Cập nhật 2026-09-09 — map hiện tại, Output và ragdoll

- MCP xác nhận đúng place `125550968845787`. Map thực tế đã tách thành Folder `Workspace/Arena` (65 con) và `Workspace/Lobby` (4 con). Đã sửa MapService đọc cấu trúc này; không di chuyển hay sửa trang trí. Bảng BestScoreBoard đã được bỏ khỏi Lobby, nay là tuỳ chọn.
- Giữ nguyên danh sách file người dùng đã xoá. Không khôi phục prefab/map test/build project/cache cũ. Build và Roblox type definitions dùng thư mục tạm bên ngoài dự án.
- Studio mặc định dùng dữ liệu RAM tại RewardService; không require ProfileStore trong chế độ này, tránh phép thử ghi `____PS` của thư viện 1.0.3. Production vẫn dùng ProfileStore; không thay schema v1 hay bật quyền API.
- Solo Play xác nhận Echo tự chạm người đứng yên → DOWNED với ragdoll server ownership → DEFEAT → lobby → trận mới. Root không Anchored, Humanoid còn sống để tương thích revive. Sau về lobby không còn instance ragdoll, quyền điều khiển trở lại client.
- Fixture Studio R6: 5 khớp được ngắt, 10 attachment tạm; thân ngã xuống Y≈1.58, trục đứng Y≈0; hồi phục trục đứng Y=1. Fixture R15: 14 khớp, tái sử dụng socket có sẵn, chỉ thêm 4 attachment cho khớp còn thiếu; hồi phục Y=1. Cả hai Health=100, không rò instance sau 4 chu kỳ down/revive; fixture đã dọn. Đây là kiểm tra service/physics trong Studio, không phải revive giữa hai client qua mạng.
- Lune: **46 assertions đạt**, gồm hai bài kiểm tra vị trí ragdoll khi cứu và ba bài kiểm tra Studio RAM không require ProfileStore/cấp thưởng/chặn thưởng trùng. Ragdoll physics được kiểm tra ở Studio, Lune chỉ stub phần engine.
- StyLua, Selene (0 errors/warnings/parse errors), Luau LSP (exit 0) và Rojo build code đều đạt. LSP có cảnh báo CLI không đăng ký file watcher, không phải lỗi type trong source.
- Phiên Play cuối sau khi xác nhận Rojo đồng bộ: không còn lỗi map/API hay cảnh báo bảng điểm. Quan sát client khi ragdoll: root Y≈1.53, trục đứng Y≈-0.39, thân nằm trên sàn.
- Kiểm tra Echo được tạo từ avatar đang DOWNED (mô phỏng client vào trễ): 15 khớp bật, 0 khớp tắt, 0 Humanoid, đầu Transparency≈0.55 và 1 animation track đang phát. Đã bổ sung bật lại khớp trong clone để không thừa hưởng trạng thái ragdoll. Dọn fixture rồi Stop, trả Studio về Edit.

Các kết quả phía dưới là lịch sử kiểm tra ngày 2026-09-08; bài test map cũ đã bị xoá theo yêu cầu và không chạy lại ngày 2026-09-09.

## Đã xác minh

| Kiểm tra | Kết quả |
|---|---|
| MCP | Đúng place `125550968845787`, DataModel `DontTouchYourClone`; ID Studio được lấy lại sau reconnect |
| StyLua | Source game định dạng hợp lệ |
| Selene | 0 errors, 0 warnings, 0 parse errors |
| Luau LSP 1.69.0 | Type-check source game với sourcemap + Roblox definitions: exit 0; bỏ chẩn đoán dependency |
| Gameplay Lune | 41 assertions đạt: replay, hit, cap, revive/cancel, immunity, bleedout, reset, reward/idempotency, vòng thắng 150s, team wipe, countdown trống, cleanup |
| Map Lune | Snapshot có 12 spawn/24 Core markers; pad sửa vị trí được dùng; trang trí không bị xoá khi bind lại |
| Rojo build | `rojo build --output prototype.rbxl` thành công (chỉ code; map thuộc file place Studio) |
| Solo Studio | Server/client khởi động, profile Mock ready, countdown → PLAYING; Echo hạ người đứng yên → DEFEAT → reward → lobby → trận mới |
| Core thực tế | Có `CoreCollected`, HUD tăng Core; trận 64.98s với 1 Core nhận đúng 17 Coins (5 + floor(64.98/5)) |
| Echo mới | Quan sát cận cảnh: đầu neon hiển thị; track run đang phát và CFrame cánh tay tương đối root thay đổi sau 0.2s |
| Animation QA | Chạy/nhảy bằng Humanoid movement thông thường, quan sát Echo: đủ idle/run/jump/fall; 0 Humanoid trong clone ở bài đo trước; tối đa 4 Echo trong bài 38s |
| Sound | 5 âm cơ bản `IsLoaded = true`, TimeLength > 0 trong client; chưa đánh giá âm lượng bằng nghe trên thiết bị thật |
| Map Edit | Model hiện sẵn ở Workspace. Vật trang trí kiểm tra giữ nguyên sau Play → Stop; đã dọn vật kiểm tra |
| Return/cleanup | Các trận tiếp theo chạy được; LocalEchoes rỗng khi về lobby, Core pool được tạo lại theo trận |

Benchmark Lune: 96 Echo × 3.000 tick (tương đương 150s ở 20Hz), các lần đo khoảng **1.4–1.6 ms/tick** trên máy này.
Đây là chi phí thuật toán Echo server trong Lune, **không phải** CPU/FPS của 96 avatar đang animate trong Studio/client/live.

## Điều chỉnh theo phản hồi

- MapService không còn sinh/xoá map runtime; bind `Workspace/ClonePrototypeMap` và dùng marker chỉnh được trong Edit.
- Rojo serve không sở hữu Workspace nên không ghi đè map. Map chỉ tồn tại trong file place Studio (snapshot `.rbxm` đã bị xoá khỏi dự án ngày 2026-09-09 theo yêu cầu).
- Đầu Echo tồn tại trong instance nhưng texture dynamic head gây hiển thị không đúng khi phủ neon. Bản mới xoá MeshPart texture, reset LocalTransparencyModifier; đã quan sát đầu hiển thị lại.
- Giữ Motor6D và AnimationConstraint kinematic thay vì xoá bộ khớp. AnimationController/Animator phát asset từ Animate của avatar; không Humanoid, không va chạm vật lý.
- Jumping có thể ngắn hơn 0.1s nên nhận biết thêm hướng đi lên trong path để chọn jump. Đã thấy jump track trong kiểm tra runtime sau sửa.

## Chưa xác minh / chưa thực hiện

- Chưa chạy Server & 4+ Clients, revive qua mạng giữa hai người, 12 người thật hoặc 96 Echo animation trên client yếu/mobile.
- Chưa đo memory/connection dài hạn, network latency thật, analytics dashboard hay persistence production/rejoin thật.
- Chưa thực hiện 4 tiêu chí trải nghiệm mục R với ít nhất 6 người thật. Không thể kết luận prototype đã đạt nghiệm thu GDD về độ vui/retention.
- Chưa publish QA hoặc Live, chưa đổi Maximum Players trên website. Gameplay giới hạn roster 12; cấu hình place cần đặt 12 trước QA online.
- Không có Git repository trong thư mục nên `git diff --check` không chạy được; không tạo commit/PR.

## Cảnh báo Studio ngày 2026-09-08 (đã xử lý ngày 2026-09-09)

```text
DataStoreService: StudioAccessToApisNotAllowed: Cannot write to DataStore from studio if API access is not enabled. API: SetAsync, Data Store: ____PS
[profilestore]: Roblox API services unavailable - data will not be saved
```

Đây là bước kiểm tra quyền API của thư viện ProfileStore dù dùng `.Mock`. Bản ngày 2026-09-09 không require thư viện khi dùng dữ liệu Studio RAM; lỗi này không còn xuất hiện trong phiên Play mới.

Lịch sử: test map cũ từng cần Rojo chuẩn hoá binary sang XML cho Lune 0.10.4. Bài test và snapshot đó hiện đã bị xoá, không còn là bước kiểm thử của dự án.

Khi kiểm tra MCP, đọc attribute/instance đang replicate. Không dùng `require(Service)` qua MCP để suy ra state module đang chạy: có lần nhận bảng state mới ở VM khác, không phản ánh số Echo thực tế. `Workspace.ActiveEchoCount` là số do loop gameplay phát.
