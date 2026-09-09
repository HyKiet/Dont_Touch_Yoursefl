# DON'T TOUCH YOUR CLONE!

> **Mọi bước chân bạn đi hôm nay sẽ quay lại săn bạn.**

Prototype game co-op survival trên Roblox. Tối đa **12 người/server**, mỗi trận **150 giây**.
Cứ mỗi 10 giây, đoạn đường bạn vừa chạy biến thành một **Echo** — bản sao trong suốt
chạy lặp lại đúng đường đó. Chạm phải Echo là bị hạ; đồng đội phải tới cứu trong 10 giây.
Càng về cuối trận, map càng đầy những sai lầm của chính bạn.

| | |
|---|---|
| **Engine** | Roblox / Luau (`--!strict`) |
| **Kiến trúc** | Server authoritative, 12 Service + 7 Controller |
| **Đồng bộ code** | Rojo 7.7.0 |
| **Thư viện** | ByteNet (networking), Fusion 0.3 (UI), Janitor (cleanup), ProfileStore (data) |
| **Kiểm thử** | 46 assertion chạy bằng Lune, không cần mở Studio |

---

## Chạy thử trong 3 bước

```powershell
aftman install                 # cài đúng phiên bản Rojo / StyLua / Selene
wally install                  # tải thư viện theo wally.lock
rojo serve                     # mở Studio → plugin Rojo → Connect (localhost:34872)
```

Sau đó mở file place có sẵn `Workspace/Arena` và `Workspace/Lobby`, bấm **Play**.
Chi tiết và cách trang trí map: [PLAYTEST.md](PLAYTEST.md) · [README-ROJO.md](README-ROJO.md).

---

## Bản đồ codebase

```
src/
├── Shared/                      ReplicatedStorage.Shared — cả hai phía đều đọc được
│   ├── GameConfig.luau          MỌI con số gameplay nằm ở đây, không rải trong logic
│   ├── Packets.luau             Hợp đồng ByteNet: server gửi gì, client gửi gì
│   └── ReplayMath.luau          Toán thuần: nội suy đường chạy, tính thưởng
│
├── Server/Services/             ServerScriptService — client KHÔNG đọc được
│   ├── Main.server.luau         Điểm khởi động, sở hữu mọi connection suốt server
│   ├── MatchService.luau        State machine: WAITING → COUNTDOWN → PLAYING → RESULT
│   ├── MovementRecorderService  Ghi vị trí người chơi 10 lần/giây
│   ├── EchoService.luau         Budget Echo + phát hiện va chạm ở 20Hz
│   ├── PlayerStateService.luau  ALIVE / DOWNED / ELIMINATED + chống gian lận vị trí
│   ├── RagdollService.luau      Ngã bằng vật lý thật khi bị hạ
│   ├── ReviveService.luau       Đo 2.5 giây giữ nút ở SERVER, không tin client
│   ├── CoreService.luau         Pool 8 collectible, nhặt bằng khoảng cách server
│   ├── RewardService.luau       ProfileStore session + thưởng cuối trận
│   ├── MapService.luau          Đọc marker map do người làm map dựng trong Studio
│   └── TelemetryService.luau    Analytics, lỗi analytics không làm chết gameplay
│
└── Client/Controllers/          StarterPlayerScripts — chỉ UI, VFX, âm thanh, input
    ├── Main.client.luau         Nối packet và controller đúng một lần
    ├── MatchController.luau     Dịch snapshot của server thành HUD
    ├── EchoVisualController     Pool clone không Humanoid, nội suy mỗi frame
    ├── EchoAnimationController  Phát animation avatar gốc trên clone
    ├── ReviveController.luau    Chọn mục tiêu gần nhất, gửi ý định giữ nút
    ├── UIController.luau        HUD dựng bằng Fusion
    └── FeedbackController.luau  Âm báo sự kiện
```

---

## Những quyết định kỹ thuật đáng nói

### 1. Echo không dùng Humanoid

Cuối trận có tối đa **96 Echo** cùng lúc (12 người × 8). 96 Humanoid sẽ giết server:
mỗi Humanoid tự chạy state machine, raycast tìm mặt đất và mô phỏng vật lý riêng.

Echo ở đây chỉ là `Model` được `PivotTo()` tới CFrame nội suy từ đường đã ghi.
Server thậm chí **không tạo Model nào** — nó chỉ giữ mảng toạ độ và gửi cho client tự vẽ.

### 2. Va chạm tính bằng khoảng cách 20Hz, không dùng `Touched`

`Touched` sinh hàng nghìn event mỗi giây với 96 vật thể đang chuyển động.
Thay vào đó server tự kiểm tra 20 lần/giây bằng bình phương khoảng cách
(so `a² ≤ b²` thay vì gọi `math.sqrt`).

**Bài học đo được, không phải đoán.** Bản đầu dùng spatial grid với khoá dạng chuỗi
`"x:y:z"`. Nghe có vẻ nhanh hơn, nhưng đo lại thì ngược:

| Cách làm | ms/tick (96 Echo, Lune) |
|---|---|
| Spatial grid + khoá chuỗi | 1.426 |
| Duyệt thẳng, dùng `Vector3` | 1.975 |
| **Duyệt thẳng, toạ độ số phẳng** | **0.462** |

Thủ phạm là **cấp phát bộ nhớ**: mỗi phép trừ hai `Vector3` tạo một vật thể mới,
1.152 lần mỗi tick là ~23.000 rác mỗi giây. Tách toạ độ thành ba mảng số rời thì
vòng lặp chỉ còn phép tính trên số — **nhanh gấp 3 lần và ít code hơn**.
Xem comment trong [`EchoService.luau`](src/Server/Services/EchoService.luau).

### 3. Server authoritative tuyệt đối

Client **không bao giờ** gửi lên "tôi vừa nhặt Core" hay "tôi đã cứu xong".
Nó chỉ gửi đúng một thứ: *ý định* giữ nút cứu (`{targetId, holding}`).
Server tự đo đủ 2.5 giây, tự kiểm tra khoảng cách, tự kiểm tra người cứu có đứng yên không.

Không có packet nào từ client có thể cộng tiền, hạ người khác, hay báo thắng.

### 4. Chống teleport bằng "credit khoảng cách"

`PlayerStateService` giữ vị trí hợp lệ cuối cùng của mỗi người. Mỗi tick, quãng đường
được phép đi = `WalkSpeed × 2 × thời gian trôi qua`, cộng thêm một khoản dung sai
**có trần** cho packet về trễ. Đi quá mức đó → bị kéo về vị trí cũ, và tick đó không
được ghi vào Echo cũng không được nhặt Core.

### 5. Rò connection là bug số 1 của game Roblox

Mọi `:Connect()` đều thuộc về một `Janitor`. Server có một Janitor sống suốt vòng đời
server và một Janitor riêng cho mỗi người chơi, huỷ khi họ rời game. Không có listener
nào được tạo mới sau mỗi trận — nếu có, sau vài chục trận server sẽ chết dần.

### 6. Dữ liệu người chơi thật được bảo vệ

- **ProfileStore session locking**: một hồ sơ chỉ được mở ở đúng một server.
- **Idempotent reward**: mỗi trận có một id; cấp thưởng lần hai cho cùng id trả về 0.
- **Schema version**: server cũ gặp hồ sơ phiên bản mới hơn thì **từ chối**, không ghi đè.
- **`UseMockDataInStudio = true`**: test trong Studio chỉ đụng RAM, không chạm hồ sơ thật.

---

## Kiểm thử

```powershell
stylua --check src                 # định dạng
selene src                         # lint
lune run tests/gameplay.luau       # 46 assertion + benchmark
rojo build --output prototype.rbxl # build code
```

`tests/gameplay.luau` chạy **chính các Service thật** bằng Lune, chỉ giả lập ở biên
engine và ProfileStore. Nó phủ: nội suy replay, trần budget 8/96 Echo, phát hiện va chạm,
huỷ cứu khi di chuyển / khi giả mạo khoảng cách, miễn nhiễm, bleedout, reset nhân vật,
thưởng idempotent, và trọn vòng đời trận 150 giây (cả thắng lẫn team wipe).

Kết quả QA gần nhất: [QA_REPORT.md](QA_REPORT.md).

---

## Trạng thái hiện tại

**Đã có:** trọn vòng lặp trận đấu, Echo replay + budget, downed/ragdoll/revive,
Core, HUD, onboarding, spectate, thưởng, persistence, analytics.

**Chưa làm (trung thực):**
- Chưa playtest với 6+ người thật → chưa kết luận được game có vui không
  (tiêu chí nghiệm thu ở [GDD mục R](GDD%20Prototype%20%E2%80%94%20DON'T%20TOUCH%20YOURSELF.md)).
- Chưa test 12 client thật, chưa đo network latency và FPS mobile.
- Chưa publish.

Phạm vi cố tình **không** làm nằm ở GDD mục Q: không pet, không trading, không rebirth,
không battle pass. Core loop phải chứng minh là vui trước đã.

---

## Tài liệu

| File | Nội dung |
|---|---|
| [GDD Prototype](GDD%20Prototype%20%E2%80%94%20DON'T%20TOUCH%20YOURSELF.md) | Nguồn thiết kế duy nhất — mọi con số đều truy về đây |
| [CLAUDE.md](CLAUDE.md) | Quy tắc code bắt buộc của dự án |
| [PLAYTEST.md](PLAYTEST.md) | Cách chạy, trang trí map, checklist nghiệm thu |
| [QA_REPORT.md](QA_REPORT.md) | Kết quả kiểm thử thực tế |
| [README-ROJO.md](README-ROJO.md) | Hướng dẫn Rojo cho người mới |
