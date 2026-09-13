# Giftcode CFL Redeemer

Web app đơn giản để nhập `userID` và nhiều gift code, sau đó gọi API redeem theo từng code.

## Quick start (1 lệnh)

| Nền tảng | Câu lệnh |
| --- | --- |
| **Termux (Android)** | `curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/termux/termux-bootstrap.sh \| bash` |
| **Linux (systemd)** | `curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/native/install.sh -o install.sh && sudo bash install.sh` |
| **Docker** | `cp .env.example .env && docker compose up -d --build` |

Bản Termux tự cài `golang` + `termux-services` (runit), clone repo, build binary, **enable runit service (auto-start + auto-restart)** và in sẵn địa chỉ truy cập (kèm IP nội bộ).

## Chức năng

- Nhập **ID nhân vật** một lần
- Nhập **nhiều gift code** theo nhiều dòng (hoặc ngăn cách bằng dấu phẩy)
- Backend tự gán:
  - `roleId = userID`
  - `roleName = userID`
- Các trường payload khác được giữ cố định:
  - `profileId = ""`
  - `serverId = "101"`
  - `gameCode = "A49"`
- Hiển thị kết quả từng code (status + phản hồi API)

## Cách chạy

1. Tạo file môi trường:

```bash
cp .env.example .env
```

2. Export biến môi trường và chạy:

```bash
set -a
source .env
set +a

go run .
```

3. Mở trình duyệt:

```text
http://localhost:8386
```

## Chạy bằng Docker Compose

1. Chuẩn bị biến môi trường:

```bash
cp .env.example .env
```

2. Build và chạy:

```bash
docker compose up -d --build
```

3. Xem log:

```bash
docker compose logs -f app
```

4. Dừng dịch vụ:

```bash
docker compose down
```

## Chạy trên Termux (Android)

App chạy trực tiếp trên điện thoại Android thông qua [Termux](https://f-droid.org/packages/com.termux/), không cần root, không cần Docker, không cần server.

### Một lệnh duy nhất

```bash
curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/termux/termux-bootstrap.sh | bash
```

Script `termux-bootstrap.sh` sẽ tự động:

1. Cập nhật `pkg` và cài `curl`, `git`, `ca-certificates` nếu thiếu.
2. Clone repo về `~/gifcodecfl` (hoặc `CFL_APP_HOME` nếu đặt trước).
3. Bàn giao cho `deploy/termux/install.sh` để:
   - Cài `golang` qua Termux.
   - Build binary `~/gifcodecfl/server`.
   - Tạo `.env` mặc định (`REDEEM_CLIENT_REGION=VN`, `PORT=:8386`).
   - **Cài `termux-services` (runit), tạo runit service `gifcodecfl`, enable autostart.**
   - Thêm hook `runsvdir` vào `~/.bashrc` để mỗi lần mở Termux là service tự được supervision.
   - In địa chỉ truy cập `http://localhost:8386` và IP nội bộ để mở từ điện thoại/PC khác trong cùng WiFi.

### Persistence (chạy treo liên tục)

Mặc định sau khi cài, app chạy dưới dạng **runit service** nên:

| Tình huống | App còn sống? |
| --- | --- |
| Tắt màn hình (không có wake-lock) | ⚠️ Có thể bị Android suspend (xem mục wake-lock bên dưới) |
| Tắt màn hình + đã bật `wake-lock` | ✅ Sống bình thường |
| App Go crash (panic, OOM) | ✅ Runit tự restart sau ~1s |
| Reboot điện thoại | ❌ Sau reboot cần mở Termux 1 lần (sau đó service tự chạy mỗi lần mở Termux) |
| Mở Termux sau 1 ngày | ✅ Service tự chạy (nhờ hook trong `~/.bashrc`) |
| Đóng Termux (swipe away khỏi recent) | ⚠️ Android có thể kill; chạy lại khi mở Termux |

### Wake lock (chống Android suspend khi tắt màn hình)

Để app sống 24/7 kể cả khi tắt màn hình, cần cài thêm **[Termux:API](https://f-droid.org/packages/com.termux.api/)** từ F-Droid (cùng repo với Termux), sau đó:

```bash
~/gifcodecfl/deploy/termux/install.sh wake-lock
```

Wake-lock là global (giữ cho cả Termux, không chỉ app), persist cho đến khi gọi `wake-unlock` hoặc reboot. Nếu reboot thì chạy lại lệnh trên.

### Sau khi cài đặt

Mọi thao tác quản lý đi qua một script:

```bash
~/gifcodecfl/deploy/termux/install.sh status       # trạng thái + URL truy cập
~/gifcodecfl/deploy/termux/install.sh start        # khởi động (sv up)
~/gifcodecfl/deploy/termux/install.sh stop         # dừng (sv down)
~/gifcodecfl/deploy/termux/install.sh restart      # khởi động lại
~/gifcodecfl/deploy/termux/install.sh log          # xem log (tail -f)
~/gifcodecfl/deploy/termux/install.sh update       # git pull + rebuild + restart
~/gifcodecfl/deploy/termux/install.sh enable       # bật runit service (autostart)
~/gifcodecfl/deploy/termux/install.sh disable      # tắt runit service (về nohup)
~/gifcodecfl/deploy/termux/install.sh wake-lock    # chống Android suspend (cần Termux:API)
~/gifcodecfl/deploy/termux/install.sh wake-unlock  # tắt wake-lock
~/gifcodecfl/deploy/termux/install.sh tunnel-setup  # Cloudflare Tunnel (tạo public URL)
~/gifcodecfl/deploy/termux/install.sh tunnel-status # xem trạng thái tunnel
~/gifcodecfl/deploy/termux/install.sh uninstall    # dừng + gỡ service + xóa thư mục app
```

Hoặc chạy menu tương tác:

```bash
~/gifcodecfl/deploy/termux/install.sh menu
```

### Cloudflare Tunnel (public URL từ điện thoại)

Để truy cập app từ bất kỳ đâu trên internet (không cần cùng WiFi), cài đặt **Cloudflare Tunnel**. App sẽ có 1 URL HTTPS public ổn định.

**Yêu cầu**: Bạn đã sở hữu 1 domain và đã trỏ nameserver về Cloudflare (vào [dash.cloudflare.com](https://dash.cloudflare.com) → Add Site).

Sau khi cài app xong:

```bash
~/gifcodecfl/deploy/termux/install.sh tunnel-setup
```

Script sẽ tự động:

1. Tải `cloudflared` binary về `$PREFIX/bin/` (auto-detect arm64/arm/amd64).
2. Chạy `cloudflared tunnel login` — bạn sẽ thấy 1 URL, copy mở trong browser, đăng nhập Cloudflare, chọn domain, bấm **Authorize**. Cert tự lưu vào `~/.cloudflared/`.
3. Hỏi tên subdomain (vd: `gifcodecfl.example.com`).
4. Tạo tunnel `gifcodecfl` trên Cloudflare.
5. Copy credentials + cert vào `$PREFIX/etc/cloudflared/`.
6. Gán DNS route (`cloudflared tunnel route dns`).
7. Ghi `config.yml` trỏ vào `http://127.0.0.1:8386`.
8. Cài runit service `gifcodecfl-tunnel` (auto-restart nếu crash, auto-start mỗi lần mở Termux).
9. Khởi động và in URL public: `https://gifcodecfl.example.com`.

Quản lý tunnel:

```bash
~/gifcodecfl/deploy/termux/install.sh tunnel-status   # URL, id, trạng thái
~/gifcodecfl/deploy/termux/install.sh tunnel-start    # sv up (nếu service đã enable)
~/gifcodecfl/deploy/termux/install.sh tunnel-stop     # sv down
~/gifcodecfl/deploy/termux/install.sh tunnel-restart  # restart
~/gifcodecfl/deploy/termux/install.sh tunnel-remove   # xóa tunnel + DNS + config
```

**Lưu ý Cloudflare Tunnel**:
- Cloudflare Tunnel đi ra ngoài qua port 443, nên **không cần port forwarding** trên router.
- Free plan Cloudflare hỗ trợ unlimited tunnels.
- Tunnel tự duy trì kết nối liên tục tới Cloudflare edge gần nhất, latency thấp.
- Nếu muốn tạm dừng public truy cập mà vẫn dùng local: `tunnel-stop` (chỉ tắt cloudflared, app local vẫn chạy).

### Lưu ý quan trọng

- **Đã bật service thì `start`/`stop` dùng `sv` (runit).** Gõ `disable` để chuyển về chế độ nohup cũ (không auto-restart). Có thể `enable` lại bất cứ lúc nào.
- **Port bị chiếm**: Sửa `PORT` trong `~/gifcodecfl/.env`, ví dụ `PORT=:9090`, rồi chạy `restart`.
- **Dùng repo fork**: Set biến trước khi chạy curl:

  ```bash
  CFL_REPO_URL=https://github.com/<owner>/gifcodecfl.git \
  CFL_REPO_BRANCH=main \
  CFL_APP_HOME=$HOME/gifcodecfl \
  curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/termux/termux-bootstrap.sh | bash
  ```

## Deploy native Linux voi systemd

Bo script native nam trong `deploy/native/` va duoc thiet ke cho may Linux chay `systemd`.

### Chuc nang

- Kiem tra va cai bo bien moi truong he thong can thiet trong `/etc/profile.d/cfl.sh`
- Tao file env cho app tai `/etc/gifcodecfl/.env`
- Build binary Go va copy static web vao `/opt/gifcodecfl`
- Cai 2 service `systemd`:
  - `gifcodecfl.service`
  - `gifcodecfl-cloudflared.service`
- Tao lenh menu `cfl` trong `/usr/local/bin/cfl`
- Co the cau hinh Cloudflare Tunnel va luu domain expose

### Cach dung

Tren may Linux:

```bash
sudo bash deploy/native/install.sh
```

Script se lan luot:

1. Kiem tra/cai bo bien moi truong he thong can thiet.
2. Hoi co muon setup Cloudflare Tunnel de chay voi domain web hay khong.
3. Neu co, cai `cloudflared`, chay `cloudflared tunnel login` de nguoi dung xac thuc, hoi domain, tao tunnel + DNS route va luu credential file.
4. Hoi cac thiet lap trong `.env` (`REDEEM_CLIENT_REGION`, `PORT`) de thiet lap nhanh.
5. Build binary Go, copy static web va setup chay native `systemd`.

Sau khi cai dat xong, goi menu bang:

```bash
sudo cfl
```

Menu gom 4 muc:

1. Kiem tra trang thai hoat dong cua app
2. Bat/Tat chay app
3. Cau hinh lai hoac go bo Cloudflare Tunnel
4. Thoat

## API nội bộ

### `POST /api/redeem`

Request body:

```json
{
  "userID": "123456",
  "codes": "CODE1\nCODE2\nCODE3"
}
```

- `codes` hỗ trợ nhiều dòng, dấu phẩy hoặc dấu `;`
- Tự loại bỏ code trùng nhau
