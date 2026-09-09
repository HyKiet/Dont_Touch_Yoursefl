# DON'T TOUCH YOURSELF — PROTOTYPE GDD

## A. Product Definition

| Thuộc tính | Giá trị |
|---|---|
| Codename nội bộ | **DON'T TOUCH YOURSELF** |
| Tên publish (đề xuất) | **DON'T TOUCH YOUR CLONE!** — xem mục U |
| Thể loại | Co-op Survival / Arcade |
| Engine / Platform | Roblox |
| Số người tối đa | **12 người / server** (xem mục U.2) |
| Camera | Third-person Roblox mặc định |
| Match Duration | **150 giây** |
| Lobby Countdown | **10 giây** |
| Mục tiêu | Cả đội cố sống đến khi hết timer |
| Cơ chế trung tâm | Cứ mỗi 10 giây, chuyển động quá khứ của player trở thành một **Echo** |
| Victory | Timer về 0 và vẫn còn ít nhất 1 player sống |
| Defeat | Tất cả player đều bị hạ |
| Development Scope | Prototype solo-dev trong **7 ngày** (xem mục S) |

Nguyên tắc thiết kế cốt lõi:

> **Every movement you make now becomes a hazard you must deal with later.**

Gameplay phải vui chỉ với **1 map + Core + Echo**. Nếu bộ khung này chưa vui thì chưa thêm progression.

---

# B. Luồng một session

```text id="37guzh"
LOBBY
↓
10s COUNTDOWN
↓
TELEPORT ARENA
↓
RUN + COLLECT CORE
↓
MOVEMENT RECORDED
↓
EVERY 10s CREATE ECHO
↓
AVOID ALL ECHOES
↓
PLAYER DOWNED
↓
TEAMMATE REVIVE
↓
SURVIVE 150s
↓
WIN / TEAM WIPED
↓
REWARD
↓
BACK TO LOBBY
↓
REPEAT
```

Diễn giải gameplay:

| Thứ tự | Hành vi |
|---:|---|
| 1 | Player xuất hiện trong Lobby |
| 2 | Countdown 10 giây |
| 3 | Tất cả được chuyển vào Arena |
| 4 | Player chạy và nhặt **Core** |
| 5 | Movement của từng player được record |
| 6 | Sau mỗi **10 giây**, một Echo mới replay đoạn movement trước đó |
| 7 | Player né toàn bộ Echo trên map |
| 8 | Bị Echo chạm → Downed |
| 9 | Đồng đội có thể Revive |
| 10 | Team cố tồn tại đủ 150 giây |
| 11 | Game tính reward |
| 12 | Tất cả quay lại Lobby |
| 13 | Chuẩn bị match tiếp theo |

---

# C. Match State Machine

Toàn bộ vòng đời trận đấu phải đi qua state rõ ràng:

```text id="zfoouj"
WAITING
   ↓
COUNTDOWN
   ↓
STARTING
   ↓
PLAYING
   ↓
VICTORY / DEFEAT
   ↓
RESULT
   ↓
RETURN_TO_LOBBY
   ↓
COUNTDOWN
```

| State | Trách nhiệm |
|---|---|
| WAITING | Chờ tối thiểu 1 player |
| COUNTDOWN | Chạy timer 10s |
| STARTING | Reset match data và teleport player |
| PLAYING | Match chạy trong 150s |
| VICTORY | Timer = 0 và còn player sống |
| DEFEAT | Không còn player active |
| RESULT | Hiện reward trong 5s |
| RETURN | Đưa player về Lobby |

---

# D. Thiết kế Map

Lobby và Arena tồn tại trong **cùng một Place**.

### Lobby

| Thành phần | Vai trò |
|---|---|
| Spawn Area | Nơi player xuất hiện |
| Match Timer | Hiển thị countdown |
| Best Score Board | Hiện Best Survival / Core |
| Upgrade Area | Prototype có thể để placeholder |
| Arena Portal | Visual cho khu vực sắp chơi |

### Arena

Arena phải nhỏ, dễ đọc và không phụ thuộc vào parkour.

| Object | Số lượng |
|---|---:|
| Player Spawn | 12 |
| Pillar | 12–16 |
| Low Wall | 8–10 |
| Core Spawn Point | 20–24 |
| Arena Boundary | 1 |
| Revive Zone | Không cần cố định; revive ngay tại vị trí teammate |

Kích thước arena: khoảng **1.6× bản 4 người** (tham chiếu: ~200×200 studs). Đủ rộng để
12 người không dẫm chân nhau, nhưng vẫn phải đủ chật để Echo tích luỹ tạo áp lực.

Map không nên phức tạp. Độ khó phải đến từ **Echo**, không phải level design.

---

# E. Echo System

Đây là hệ thống quan trọng nhất của toàn prototype.

Mỗi player có một Movement Recorder lưu:

```text id="rt45i5"
Timestamp
Position
Rotation
Humanoid State / Jump
```

Không record mỗi RenderStep. Với prototype:

**Record mỗi 0.1 giây.**

### Echo generation

Cứ mỗi:

**10 giây**

server lấy đoạn dữ liệu movement tương ứng và tạo Echo.

Ví dụ:

```text id="iu6sp1"
0–10s
Player chạy A → B → C

10s
Echo #1 spawn

Echo #1:
A → B → C

10–20s
Player chạy D → E → F

20s
Echo #2 spawn

Echo #2:
D → E → F
```

Trong MVP, Echo **loop lại đoạn movement của nó liên tục**. Nhờ vậy độ khó tăng tự nhiên theo thời gian.

### Echo Rules

| Thuộc tính | Rule |
|---|---|
| Appearance | Transparent clone |
| Physical Collision | OFF |
| Damage detection | Hitbox riêng |
| Echo vs Echo | Không tương tác |
| Lifetime | Đến hết match, **nhưng tối đa 8 Echo / player** |
| Movement | Replay recorded positions |
| Speed | Bằng movement gốc |
| Player hit | Down player |
| Spawn protection | 2 giây đầu match |

### Echo Budget (bắt buộc với server 12 người)

Với 12 player × 14 Echo sẽ có tới **168 Echo** cuối trận — server không chịu nổi.
Vì vậy đặt trần cứng:

| Tham số | Giá trị | Lý do |
|---|---|---|
| MaxEchoesPerPlayer | **8** | Echo thứ 9 xuất hiện → Echo cũ nhất fade out trong 1s |
| Trần toàn server | 12 × 8 = **96 Echo** | Con số tối đa phải thiết kế để chịu được |

Việc Echo cũ nhất biến mất còn tốt cho gameplay: người chơi có lý do để "làm sạch"
một vùng bằng cách sống sót thêm, thay vì map bị khoá cứng ở phút cuối.

### Echo Implementation Constraints (bắt buộc)

| Rule | Lý do |
|---|---|
| Echo **KHÔNG có Humanoid** | 96 Humanoid cùng lúc sẽ giết server. Dùng Model + set `CFrame` trực tiếp mỗi tick replay. |
| Echo **KHÔNG dùng `Touched` event** | Touched sinh hàng nghìn event/giây. Dùng kiểm tra khoảng cách ở server, **20 Hz**. |
| Chỉ so Echo với **player còn sống** | Không quét player đã downed/eliminated. |
| Dùng khoảng cách **bình phương** | Tránh `math.sqrt` trong vòng lặp nóng. |
| Model Echo tạo sẵn, **tái sử dụng** | Không `Instance.new` trong vòng lặp. |
| Mọi connection phải `:Disconnect()` khi hết match | Rò connection = server chết dần sau vài trận. |

Mỗi player có Echo color riêng, lấy từ bảng 12 màu phân biệt rõ (tránh 2 màu gần nhau
cạnh nhau trong danh sách gán):

```text id="x9npti"
Blue, Red, Green, Yellow,
Orange, Purple, Cyan, Pink,
Lime, White, Brown, Magenta
```

Ngoài màu, Echo hiển thị **tên chủ nhân** phía trên đầu (BillboardGui). Với 12 người,
chỉ dựa vào màu là không đủ để đọc nhanh "đây là Echo của ai".

---

# F. Player Life State

Player chỉ cần các state sau:

```text id="j1ai23"
ALIVE
 ↓
DOWNED
 ↓
REVIVED
```

hoặc:

```text id="uchh42"
DOWNED
 ↓
ELIMINATED
```

Khi Echo chạm player:

```text id="edz9gr"
WalkSpeed = 0
JumpPower = 0
Player nằm xuống
Start Bleedout Timer
```

Bleedout duration:

**10 giây**

Nếu không được cứu:

```text id="mk4epn"
ELIMINATED
```

Player sau đó spectate những người còn sống.

---

# G. Revive

Một teammate có thể revive khi:

```text id="2ljtqe"
Distance <= 6 studs
```

Interaction:

**Giữ E / Interaction button trong 2.5 giây.**

Revive thành công → player trở lại trạng thái sống và nhận:

**Invulnerability 2 giây**

để tránh vừa đứng dậy đã bị Echo hạ lại.

Revive bị cancel nếu người cứu:

- chạy khỏi vị trí,
- bị Echo chạm,
- hoặc vượt quá khoảng cách cho phép.

---

# H. Core System

Core là collectible nhằm bắt player phải tiếp tục di chuyển thay vì đứng camping.

Core phục vụ ba mục đích:

- buộc player di chuyển,
- tạo score,
- tạo risk/reward.

Core spawn mỗi:

**2–4 giây**

tại một `CoreSpawnPoint` ngẫu nhiên.

Số Core active tối đa:

**8 Core**

(Đã tăng từ 5 → 8 và rút ngắn nhịp spawn vì server 12 người: nếu giữ 5 Core, phần lớn
người chơi sẽ không bao giờ chạm được Core nào và mất hoàn toàn động lực di chuyển.)

Khi player chạm Core:

```text id="p2hvdh"
Core +1
Score +1
```

sau đó Core biến mất.

---

# I. Score và Reward

Prototype chỉ cần track:

```text id="i1gtk5"
CoreCollected
SurvivalTime
TeamSurvivalTime
```

Reward cuối match:

```text id="w8xq3v"
Coins =
CoreCollected × CoreReward
+
SurvivalBonus
+
VictoryBonus
```

Giá trị ví dụ:

```text id="4mr47i"
CoreReward = 5 Coins

Survival:
+1 Coin / 5 seconds

Victory:
+50 Coins
```

Không cần balance chính xác ở giai đoạn prototype.

---

# J. Difficulty Scaling

Nguồn tăng độ khó chính vẫn là số lượng Echo tích lũy.

Có thể bổ sung:

| Match Time | Difficulty Modifier |
|---|---|
| 0–30s | Bình thường |
| 30–60s | Core spawn xa hơn |
| 60–90s | Echo movement x1.05 |
| 90–120s | Echo movement x1.1 |
| 120–150s | Arena boundary thu nhỏ nhẹ |

Trong prototype đầu tiên, có thể chỉ implement **Echo accumulation**. Những modifier còn lại là Optional.

---

# K. UI Requirements

### Lobby

```text id="wvxqru"
DON'T TOUCH YOURSELF

NEXT MATCH
00:08

Players:
3 / 4
```

### Trong match

Top center:

```text id="2wrkn7"
SURVIVE
02:14
```

Top-left — với 12 người **không liệt kê hết danh sách**, màn hình sẽ ngập chữ.
Chỉ hiện số người sống và những người đang cần cứu:

```text id="k5hw7l"
ALIVE  9 / 12

NEEDS HELP
🔴 Player3   8s
🔴 Player7   4s
```

Số bên phải là thời gian bleedout còn lại — đây là thông tin khiến người chơi
phải quyết định "cứu ai trước", nguồn kịch tính chính của chế độ co-op.

Top-right:

```text id="bd9xxa"
CORE
12
```

Bottom hoặc center:

```text id="0e7inz"
NEXT ECHO
7s
```

Khi Echo mới xuất hiện:

```text id="cwgvgl"
YOUR PAST IS BACK
```

---

# L. Onboarding

Không dùng tutorial dài.

Trong khoảng 15 giây đầu, hướng dẫn trực tiếp bằng UI:

```text id="78sple"
MOVE AND COLLECT CORES
```

sau đó:

```text id="1j3mki"
YOUR MOVEMENT IS BEING RECORDED...
```

Đến mốc 10s:

```text id="8r6z7h"
YOUR PAST IS COMING BACK.
AVOID YOUR ECHO!
```

Player phải hiểu mechanic thông qua chính gameplay.

---

# M. Roblox Project Structure

Cấu trúc đề xuất:

```text id="mpvh8n"
ReplicatedStorage
│
├── Shared
│   ├── GameConfig
│   ├── MatchConfig
│   └── EchoConfig
│
├── Remotes
│   ├── MatchStateChanged
│   ├── PlayerDowned
│   ├── PlayerRevived
│   ├── CoreCollected
│   └── EchoSpawned
│
ServerScriptService
│
├── Services
│   ├── MatchService
│   ├── PlayerStateService
│   ├── EchoService
│   ├── MovementRecorderService
│   ├── CoreService
│   ├── ReviveService
│   └── RewardService
│
StarterPlayer
│
└── StarterPlayerScripts
    └── Controllers
        ├── UIController
        ├── MatchController
        ├── EchoVisualController
        └── ReviveController
```

---

# N. Authority Model

Những thứ bắt buộc do server quyết định:

```text id="ycwk17"
Match State
Player Alive/Downed
Core Collection
Reward
Revive Validation
Echo Hit Detection
```

Client chỉ chịu trách nhiệm cho:

```text id="3rylbn"
UI
VFX
Sound
Visual interpolation
Input
```

Client không được quyền tự quyết reward hoặc player death.

---

# O. Central Config

```lua id="phyojx"
return {

    MaxPlayers = 12,

    LobbyCountdown = 10,

    MatchDuration = 150,

    EchoInterval = 10,

    MovementRecordInterval = 0.1,

    -- Trần Echo mỗi player. Vượt quá thì Echo cũ nhất fade out.
    -- Đây là hàng rào bảo vệ hiệu năng, không phải nút chỉnh độ khó.
    MaxEchoesPerPlayer = 8,

    -- Server kiểm tra va chạm Echo 20 lần/giây thay vì mỗi frame.
    -- Mắt người không phân biệt được, nhưng CPU tiết kiệm ~3 lần.
    EchoHitCheckRate = 20,

    -- Bán kính tính là "chạm" giữa Echo và player (studs).
    EchoHitRadius = 3,

    BleedoutTime = 10,

    ReviveDuration = 2.5,

    ReviveDistance = 6,

    ReviveInvulnerability = 2,

    CoreSpawnIntervalMin = 2,

    CoreSpawnIntervalMax = 4,

    MaxActiveCores = 8,
}
```

---

# P. MVP Checklist

Bản prototype 3–4 ngày phải có đầy đủ:

- [ ] Lobby
- [ ] Countdown
- [ ] Match State Machine
- [ ] Arena teleport
- [ ] 12-player support
- [ ] Echo budget cap (8/player) hoạt động đúng
- [ ] Movement recording
- [ ] Echo replay
- [ ] Echo hit detection
- [ ] Player Downed
- [ ] Revive
- [ ] Core spawning
- [ ] Core collection
- [ ] Match timer
- [ ] Victory / Defeat
- [ ] Return Lobby
- [ ] Basic UI
- [ ] Basic sound/VFX

---

# Q. Out of Scope

Không triển khai trong MVP:

- Pet
- Trading
- Rebirth
- Inventory phức tạp
- Battle Pass
- Multiple maps
- Classes
- Weapons
- PvP
- Crafting
- Quest
- Ranked
- Shop phức tạp
- 20 abilities
- Matchmaking nhiều place

Chỉ thêm những hệ thống trên sau khi **core gameplay chứng minh là vui**.

---

# R. Playtest Acceptance Criteria

Prototype chỉ được xem là đạt nếu thỏa các bài test sau.

### Test 1

Trong **15 giây**, người chơi mới hiểu:

> Echo chính là đường chạy quá khứ.

### Test 2

Ở khoảng phút 1–2, gameplay bắt đầu tạo ra:

> hỗn loạn + la hét + cứu nhau.

### Test 3

Sau khi chết, người chơi có cảm giác:

> “chơi lại một ván nữa.”

### Test 4

Người chơi bắt đầu tự nói những câu kiểu:

> “Đừng chạy đường này, lát clone của mày quay lại đó.”

Khi player chủ động tính toán đường chạy hiện tại dựa trên nguy hiểm mà nó sẽ tạo ra trong tương lai, core mechanic được xem là đã hoạt động đúng.

---

# S. Development Order

Kế hoạch cũ là 3–4 ngày. Đánh giá lại: chỉ riêng recorder + replay + downed + revive +
netcode cho solo dev đã là 5–6 ngày nếu muốn không bug. **Lịch thực tế là 7 ngày.**
Giữ lịch 4 ngày sẽ dẫn tới cắt bừa và bug ở đúng hệ thống quan trọng nhất (Echo).

## Day 1 — Khung trận

```text id="92ddas"
Match State Machine
Lobby
Arena
Teleport
```

Mục tiêu cuối ngày: **trận tự chạy vòng lặp WAITING → PLAYING → RESULT → lặp lại**,
chưa cần gameplay gì bên trong.

## Day 2 — Trái tim của game

```text id="i2ltjq"
Movement Recorder
Echo Replay (CFrame, không Humanoid)
Echo Budget cap
```

Mục tiêu: **Echo chạy đúng con đường player vừa chạy.**
Đây là ngày quan trọng nhất. Nếu ngày này thất bại, cả dự án thất bại.

## Day 3 — Vòng lặp sống chết

```text id="d3loop"
Echo hit detection (20Hz, distance squared)
Downed + Bleedout
Revive
Victory / Defeat
```

Mục tiêu: **một người chơi được trọn 1 match từ đầu đến cuối.**

## Day 4 — Core + Multiplayer thật

```text id="d4multi"
Core spawn / collect
Test 12 người (bot hoặc nhiều client)
Sửa lỗi replication
```

Mục tiêu: **12 người chơi được một match hoàn chỉnh mà server không tụt FPS.**
Bắt buộc test bằng Studio "Server & 4+ Clients", solo Play là chưa đủ.

## Day 5 — UI + Game feel

```text id="yv52q5"
UI (timer, alive count, core, next echo)
Onboarding text
VFX + Sound
"YOUR PAST IS BACK" moment
```

## Day 6 — Playtest thật

```text id="d6test"
Mời người thật chơi (tối thiểu 6 người)
Chạy Test 1-4 mục R
Tuning hitbox + độ khó
DataStore best score
```

Đây là **cổng quyết định**: nếu không qua được Test 1–4, quay lại sửa gameplay,
KHÔNG đi tiếp sang polish và publish.

## Day 7 — Ship

```text id="bp4poq"
Bug fixing
Mobile controls
Performance pass cuối
Analytics
Icon / Thumbnail / Title
Publish
```

---

# T. Coding Constraints cho AI trong codebase

Khi triển khai, phải tuân thủ:

1. Không nhét toàn bộ game vào một Script.
2. Mỗi system phải tách thành Service riêng.
3. Các thông số gameplay phải nằm trong Config, không hard-code rải rác.
4. Server authoritative.
5. Không tạo circular dependency.
6. Không over-engineer prototype.
7. Ưu tiên code dễ đọc thay vì abstraction phức tạp.
8. Mỗi system phải có khả năng test độc lập.
9. Không tự ý thêm feature nằm ngoài GDD.
10. Phải hoàn thành **vertical slice playable trước**, sau đó mới polish.
---

# U. Rủi ro thương mại — phải xử lý trước khi publish

Gameplay không phải là rủi ro lớn nhất của dự án này. Ba thứ dưới đây quyết định
game có người chơi hay không, và cả ba đều nằm ngoài code.

## U.1 Tên game — rủi ro nghiêm trọng nhất

"DON'T TOUCH YOURSELF" là một câu nước đôi. Trên Roblox điều đó dẫn tới:

| Hệ quả | Mức độ |
|---|---|
| Tên/thumbnail có thể bị moderation từ chối | Cao |
| Sponsored Ads gần như chắc chắn bị reject | Rất cao |
| Nếu bị gắn nhãn nội dung nhạy cảm → ẩn khỏi search của tài khoản <13 | Mất phần lớn tệp người chơi |
| Nguy cơ takedown sau khi đã có traffic | Mất trắng công sức |

**Quyết định: giữ làm codename nội bộ, KHÔNG dùng làm tên publish.**

Tên publish đề xuất, giữ nguyên nhịp điệu và tính tò mò nhưng an toàn:

| Ứng viên | Ghi chú |
|---|---|
| **DON'T TOUCH YOUR CLONE!** | Đề xuất chính. Giữ cấu trúc câu gốc, mô tả đúng gameplay, hợp chuẩn đặt tên Roblox. |
| ESCAPE YOUR PAST | Thi vị hơn, kém trực tiếp hơn |
| MY CLONE IS CHASING ME! | Rất hợp thị hiếu Roblox, dễ làm thumbnail |
| DON'T TOUCH YOUR PAST | Trung tính, an toàn |

Tên phải chứa từ khoá người chơi thực sự gõ vào ô tìm kiếm (`clone`, `escape`, `chase`).

## U.2 Server size — từ 4 lên 12

Bản GDD gốc đặt 4 người/server. Vấn đề: thuật toán hiển thị của Roblox ưu tiên server
đông người, và người chơi mới nhìn thấy "1/4" sẽ thoát ngay.

| | 4 người | 12 người |
|---|---|---|
| Lượng traffic cần để trông "đông" | Gấp 3 lần | Chuẩn |
| Cảm giác khi vào server vắng | "Game chết" | Vẫn chơi được |
| Độ hỗn loạn (Test 2 mục R) | Vừa phải | Cao — đúng cái ta cần |
| Rủi ro hiệu năng | Thấp | Có, đã xử lý bằng Echo Budget (mục E) |

**Quyết định: 12 người/server, kèm trần 8 Echo/player.**
Nếu playtest cho thấy 12 người quá loạn, giảm xuống 8 — đừng quay lại 4.

## U.3 Retention — sau khi core gameplay được xác nhận vui

MVP không cần cái này (mục Q vẫn giữ nguyên). Nhưng phải biết trước bước tiếp theo,
vì sau match thứ 5 người chơi sẽ hết lý do ở lại:

Thứ tự ưu tiên khi thêm (chỉ thêm sau khi qua Test 1–4):

1. **Best Survival Time + leaderboard** — rẻ nhất, hiệu quả nhất, đã có sẵn DataStore.
2. **Daily reward** — lý do quay lại ngày hôm sau.
3. **Cosmetic skin cho Echo** — mua bằng Coin đã có sẵn, không đụng vào balance gameplay.
4. **Map thứ hai** — chỉ khi map 1 đã được chơi chán.

Tuyệt đối không thêm pet / trading / rebirth trước bước 4.

---

# V. Risk Register

| Rủi ro | Xác suất | Tác động | Cách xử lý |
|---|---|---|---|
| Echo replay giật, không khớp đường chạy gốc | Trung bình | Chết dự án | Ưu tiên Day 2, nội suy CFrame ở client |
| Server tụt FPS cuối trận | Trung bình | Cao | Echo Budget 8/player, 20Hz hit check, không Humanoid |
| Tên game bị moderation | Cao | Rất cao | Đổi tên publish (U.1) |
| Server không bao giờ đầy người | Cao | Cao | 12 slot + nội dung TikTok/Shorts |
| Hitbox quá gắt → chơi ức chế | Trung bình | Cao | Tuning ở Day 6 với người thật |
| Trượt lịch 7 ngày | Trung bình | Trung bình | Cắt polish trước, không bao giờ cắt Day 2–3 |

---

# W. Định nghĩa thành công

| Mốc | Tiêu chí |
|---|---|
| Prototype đạt | Qua cả 4 test mục R với ít nhất 6 người chơi thật |
| Soft launch đạt | D1 retention ≥ 15%, session trung bình ≥ 6 phút |
| Đáng đầu tư tiếp | 200+ CCU tự nhiên trong tuần đầu sau khi có nội dung short-form |

Nếu prototype không qua mục R, **dừng lại và sửa gameplay** — không polish,
không publish, không thêm progression để cứu một core loop chưa vui.
