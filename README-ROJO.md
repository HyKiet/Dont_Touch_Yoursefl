# Rojo 7.7.0 — Hướng dẫn dùng cho dự án này

Rojo giúp bạn viết code trong VS Code, và code tự động chui vào Roblox Studio.
Không cần copy-paste thủ công.

---

## 1. Chạy lần đầu (chỉ làm 1 lần)

Mở terminal ngay trong thư mục dự án, gõ:

```powershell
aftman install
```

Lệnh này cài đúng các công cụ ghi trong `aftman.toml`: Rojo **7.7.0**, StyLua, Selene.

Kiểm tra đã đúng phiên bản chưa:

```powershell
rojo --version    # phải in ra: Rojo 7.7.0
```

> **Vì sao phải đúng 7.7.0?** Plugin Rojo trong Studio của bạn là 7.7.0.
> Nếu CLI khác phiên bản với plugin, khi bấm Connect sẽ báo lỗi không kết nối được.

---

## 2. Mỗi lần ngồi vào làm việc

**Bước 1 — bật server ở terminal:**

```powershell
rojo serve
```

Terminal sẽ hiện `Rojo server listening on port 34872`. **Để nguyên cửa sổ này**,
đừng tắt. Tắt là mất kết nối.

**Bước 2 — trong Roblox Studio:**

Bấm nút **Rojo** trên thanh Plugins → cửa sổ hiện `localhost` / `34872` → bấm **Connect**.

Xong. Từ giờ mỗi lần bạn lưu file `.luau`, Studio tự cập nhật ngay lập tức.

---

## 3. Code nằm ở đâu trong Studio

File `default.project.json` là bản đồ nối thư mục trên máy với các vị trí trong Studio:

| Thư mục trên máy | Vào Studio thành |
|---|---|
| `src/Shared/` | `ReplicatedStorage → Shared` |
| `src/Server/Services/` | `ServerScriptService → Services` |
| `src/Client/Controllers/` | `StarterPlayer → StarterPlayerScripts → Controllers` |

Cấu trúc này lấy đúng theo **GDD mục M**.

---

## 4. Đặt tên file — Rojo tự hiểu bạn muốn loại script nào

Đây là phần người mới hay nhầm nhất. Quy tắc chỉ nằm ở **phần đuôi tên file**:

| Tên file | Thành gì trong Studio | Chạy ở đâu |
|---|---|---|
| `EchoService.luau` | `ModuleScript` | Không tự chạy, phải được `require()` |
| `Main.server.luau` | `Script` | Server |
| `UIController.client.luau` | `LocalScript` | Máy người chơi |
| `init.luau` (trong 1 thư mục) | Biến chính thư mục đó thành ModuleScript | — |
| `*.model.json` | Instance viết bằng tay (Folder, RemoteEvent...) | — |

Ví dụ: muốn có một Script chạy ở server, đặt tên `src/Server/Services/Main.server.luau`.

> Dự án này dùng đuôi `.luau` (không phải `.lua`). Rojo hỗ trợ `.luau` từ bản 7.2.0,
> và đây là đuôi Roblox khuyến nghị hiện nay.

---

## 5. Các lệnh hay dùng

```powershell
rojo serve                          # bật server để Studio kết nối (dùng hàng ngày)
rojo build --output prototype.rbxl  # đóng gói code thành file place (không kèm map)
stylua src                          # tự căn chỉnh lại toàn bộ code cho gọn
selene src                          # soi lỗi và code xấu trước khi chạy game
```

---

## 6. Gặp lỗi thì xem đây

| Triệu chứng | Nguyên nhân & cách sửa |
|---|---|
| Bấm Connect báo lỗi phiên bản | CLI khác plugin. Chạy `rojo --version`, phải là 7.7.0. |
| Connect được nhưng không thấy code | Chưa chạy `rojo serve`, hoặc đang chạy ở thư mục khác. |
| Sửa file mà Studio không đổi | Cửa sổ terminal chạy `rojo serve` đã bị tắt. Bật lại rồi Connect lại. |
| `Address already in use` | Đã có một `rojo serve` đang chạy sẵn ở nền. Tắt bớt đi một cái. |
| Studio hỏi cho phép kết nối | Bấm Allow. Rojo 7.7.0 có kiểm tra bảo mật `Host`/`Origin` nên hỏi kỹ hơn bản cũ. |

---

## 7. Lưu ý khi bấm Play trong Studio

Khi đang kết nối Rojo và bấm Play, Studio dùng bản code **đã đồng bộ lúc đó**.
Nếu bạn sửa code lúc đang chạy game, phải **Stop → sửa → Play lại** thì mới ăn.


## Prototype gameplay

Xem [PLAYTEST.md](PLAYTEST.md) để chạy game, kiểm tra dependency, schema và checklist QA.
Chạy `wally install` trước `rojo serve`. Packages được map vào ReplicatedStorage; ServerPackages vào ServerScriptService.

Map hiện nằm ở `Workspace/Arena` và `Workspace/Lobby`, **chỉ tồn tại trong file place của Studio** — Rojo không quản lý. MapService cũng đọc được cấu trúc cũ `Workspace/ClonePrototypeMap`.
`default.project.json` cố ý không khai báo `Workspace`, nhờ vậy Rojo không bao giờ ghi đè map bạn trang trí.
Đổi lại: **phải tự Save place**, vì không còn bản sao map nào trên ổ cứng.
