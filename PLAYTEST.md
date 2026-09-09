# DON'T TOUCH YOUR CLONE! — Prototype handoff

## Chạy game

1. `wally install` để lấy đúng dependency đã khóa trong `wally.lock`.
2. `rojo serve` ở thư mục này; plugin Studio kết nối `localhost:34872`.
3. Nếu vừa đổi `default.project.json`, **Disconnect → Connect** lại để nhận mapping mới.
4. Kiểm tra `ReplicatedStorage/Packages` và `ServerScriptService/ServerPackages` đã xuất hiện.
5. Mở đúng file place đã lưu có `Workspace/Arena` và `Workspace/Lobby`. Bấm Play, đợi dữ liệu thử sẵn sàng và countdown 10 giây.

> **Map sống trong file place của Studio, KHÔNG nằm trong Rojo.** Rojo chỉ đồng bộ code.
> Vì vậy sau mỗi lần chỉnh map phải **Save** place lại — không có bản sao nào khác trên ổ cứng.

## Trang trí map trong Studio

- Trang trí trực tiếp trong `Workspace/Arena` và `Workspace/Lobby`; có thể tạo Folder để sắp xếp đồ trang trí. Cấu trúc cũ `Workspace/ClonePrototypeMap` vẫn được hỗ trợ.
- `default.project.json` chỉ đồng bộ code/thư viện, **không map Workspace**. Rojo sẽ không ghi đè bản trang trí. MapService chỉ đọc marker, không dựng lại hay xoá map.
- Trong Arena giữ `ArenaFloor`, 12 part tên `PlayerSpawn` với attribute `SpawnIndex` duy nhất từ 1 đến 12, và các marker `CoreSpawnPoint1...24`. Trong Lobby giữ `LobbySpawn`. Có thể di chuyển/xoay các pad, điểm Core; server đọc vị trí mới khi Play. `BestScoreBoard/TextLabel` trong Lobby là tuỳ chọn.
- Có thể đổi kích thước/di chuyển/xoay `ArenaFloor`; kiểm tra giới hạn di chuyển dùng CFrame và Size của sàn thực tế. Khi chuyển cả arena, hãy chuyển cả tường và các marker cùng lúc.
- **Lưu file place sau mỗi lần trang trí.** Place là nơi duy nhất chứa map; chưa Save mà Studio đóng đột ngột là mất công trang trí.
- Muốn có bản dự phòng map: chọn Arena và Lobby trong Studio → **Save to File**, cất ra ngoài thư mục dự án.
- `rojo build --output prototype.rbxl` chỉ đóng gói **code**, bản build đó không có map.

## Gameplay đã triển khai

- Lobby, bảng best của người đang trong server, portal trang trí; arena 200×200, 12 spawn, 16 trụ, 8 tường, 24 điểm Core.
- WAITING → COUNTDOWN → STARTING → PLAYING → VICTORY/DEFEAT → RESULT (5s) → RETURN_TO_LOBBY.
- Trận 150s, tối thiểu 1 người. Người vào giữa trận chờ trận sau và spectate; reset nhân vật loại khỏi trận hiện tại.
- Ghi timestamp/CFrame/Humanoid state tại nhịp 0.1s. Mỗi 10s tạo một Echo replay lặp lại đường cũ.
- 8 Echo active/người, 96/server. Pool client có thêm 1 slot/người để fade Echo cũ trong 1s; slot fade không gây hit.
- Clone trong suốt có màu và tên, không Humanoid, không Touched, không physics collision. Client nội suy ở PreRender, server kiểm tra hit 20Hz bằng bình phương khoảng cách trên toạ độ số phẳng (0.46 ms/tick với 96 Echo, đo bằng Lune).
- Echo chạm làm người chơi DOWNED và ngã ragdoll vật lý do server sở hữu, không Anchored. Hỗ trợ Motor6D/R6 và AnimationConstraint/R15; khớp gốc được phục hồi khi cứu hoặc về lobby. Bleedout vẫn 10s; không đặt Health = 0 lúc DOWNED để còn cứu được. Người sống gần vị trí thân hiện tại 6 studs giữ E/X/nút touch 2.5s để cứu; rời vị trí, bị hạ, thả nút hoặc ra xa sẽ huỷ. Miễn nhiễm 2s đầu trận/sau cứu.
- Core xuất hiện mỗi 2–4s, tối đa 8; server kiểm tra vị trí rồi cộng đúng một người.
- HUD timer/alive/những người cần cứu/Core/next Echo, onboarding 15s, spectate, kết quả thưởng, âm báo cơ bản.
- Coins = Core×5 + floor(SurvivalTime/5) + 50 khi đội thắng. SurvivalTime chỉ cộng lúc ALIVE; TeamSurvivalTime giữ thời lượng đội trụ được.
- ProfileStore giữ Coins, BestSurvival, BestCores và id thưởng cuối. Schema **v1** là lần triển khai đầu; hồ sơ chưa có version được reconcile lên v1, schema mới hơn bị từ chối thay vì hạ version. Không có schema production cũ trong workspace này.
- Custom analytics: MatchStarted, PlayerDowned, PlayerRevived, PlayerEliminated, CoreCollected, VICTORY, DEFEAT; economy event MatchReward sau mutation atomic.

## Giới hạn cần biết

- Studio mặc định `UseMockDataInStudio = true`: giữ dữ liệu thử trong RAM, không require ProfileStore nên không chạy phép thử ghi `____PS`. Dữ liệu mất khi rời/Stop. Server online luôn dùng ProfileStore thật; schema vẫn v1. Không dùng thử RAM để kết luận persistence qua rejoin đã đạt.
- Chưa thêm modifier độ khó optional, shop, pet, quest, daily reward hoặc map thứ hai.
- Echo giữ rig `Motor6D` hoặc `AnimationConstraint` và dùng `AnimationController/Animator`, không Humanoid. Asset idle/run/walk/jump/fall lấy từ Animate của avatar gốc; lựa chọn track dựa vào state/tốc độ đoạn đã record. Đây không phải bản ghi chính xác mọi pose/emote của avatar.
- Texture trên MeshPart được xoá để phủ màu neon thống nhất và tránh dynamic head chỉ còn mặt nổi. Không cần thay avatar người chơi.
- Khi avatar chưa stream tới client, Echo dùng body đơn giản có màu/tên và in warning.
- Best board chỉ xếp hạng những người đang ở server, không phải global leaderboard.
- Chống teleport dùng credit khoảng cách và giới hạn arena; không được coi là hệ thống chống mọi kiểu exploit movement.
- `MaxPlayers = 12` giới hạn roster gameplay. Trước QA online cần đặt **Maximum Players = 12** trong cấu hình place; chưa đổi cấu hình website/publish.
- Âm báo dùng các file content Roblox có sẵn; cần nghe lại trên thiết bị thật.

## Kiểm tra tự động

```powershell
stylua --check src
selene src
lune run tests/gameplay.luau
rojo build --output prototype.rbxl
```

Test Lune thực thi ReplayMath, Recorder, Echo, Revive, PlayerState, Reward và MatchService với adapter giả ở biên engine/ProfileStore.
Bao gồm trận thắng đủ 150s, team wipe, countdown hết người, reset, miễn nhiễm, huỷ cứu, budget, idempotent reward và cleanup.
Benchmark 96 Echo × 3.000 tick là số đo **Lune**, không thay thế FPS/CPU/network của Studio hoặc Live.

Kết quả thực tế của lần triển khai này nằm trong [QA_REPORT.md](QA_REPORT.md).

## Nghiệm thu Studio / QA

| Bài thử | Kết quả cần thấy |
|---|---|
| Solo đứng yên qua Echo đầu | Clone xuất hiện ở đường cũ, bị hạ, DEFEAT, nhận đúng thưởng, quay lobby và trận mới |
| Chạy vòng và nhảy 10s | Echo replay đúng vị trí/rotation/jump; không có Humanoid trong LocalEchoes |
| Nhặt Core cùng lúc bằng 2 client | Core biến mất, chỉ một người tăng điểm |
| 2 người: down một người và cứu | 2.49s chưa được cứu; 2.5s thành ALIVE; miễn nhiễm 2s |
| Thả E/touch, di chuyển, ra ngoài 6 studs, người cứu bị hạ | Tiến độ huỷ; không tự cứu tiếp khi đứng lại |
| Bleedout | Sau 10s thành ELIMINATED, camera theo người sống |
| Rời game/reset/late join | Không ảnh hưởng sai đội; không được cấp thưởng lặp; late join vào trận sau |
| Sống đủ 150s | VICTORY chỉ khi còn người ALIVE; RESULT 5s và RETURN_TO_LOBBY |
| Chạy liên tiếp 5 trận | Không tích luỹ MatchCores/LocalEchoes/connection trận trước |
| Cuối trận 12 người | 96 Echo active tối đa; đo CPU, memory, network trong MicroProfiler/Developer Console |
| Mobile landscape + gamepad | HUD không che điều khiển, nút giữ cứu dùng được, sound nghe rõ |
| QA persistence thật | Dùng nơi QA/store cách ly, nhận thưởng → rời → vào lại; best/Coins được giữ, session lock hoạt động |

GDD yêu cầu **Server & 4+ Clients** và ít nhất **6 người thật** thực hiện 4 tiêu chí mục R. Test tự động hay solo Play không chứng minh được mức độ vui/hiểu mechanic/retention.
Chỉ publish QA sau kiểm tra local. Chỉ Live khi có yêu cầu rõ ràng và QA regression đạt.

## API và dependency đã đối chiếu

- [Roblox creator-docs](https://github.com/Roblox/creator-docs): RunService, PVInstance/PivotTo, Humanoid, BasePart, Workspace, Model streaming, Camera, ContextActionService, Sound, AnalyticsService, AnimationController, Animator, AnimationConstraint, Motor6D, SerializationService, EncodingService.
- [ByteNet](https://github.com/ffrostfall/ByteNet): 0.4.6, packet schema/path binary; Snapshot là JSON string đóng gói bằng ByteNet, không raw RemoteEvent.
- [ProfileStore](https://github.com/MadStudioRoblox/ProfileStore): 1.0.3; StartSessionAsync, Mock, IsActive, Reconcile, EndSession.
- Fusion 0.3.0 và Janitor 1.16.0: đã đọc source package cài thực tế. Janitor mới gặp lỗi giải dependency của Wally nên ghim 1.16.0 tương thích.
