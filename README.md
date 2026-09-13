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

App chạy trực tiếp trên điện thoại Android thông qua [Termux](https://f-droid.org/packages/com.termux/), không cần root, không cần Docker, không cần server. Bộ script được thiết kế **mirror đúng chức năng của `deploy/native/`** (Linux + systemd), chỉ thay thế bằng runit service (`termux-services`) và bổ sung tính năng đặc thù Termux: **wake-lock**.

### Một lệnh duy nhất

```bash
curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/termux/termux-bootstrap.sh | bash
```

Script `termux-bootstrap.sh` sẽ tự động:

1. Cập nhật `pkg` và cài `curl`, `git`, `ca-certificates`, `awk`, `grep`, `sed`, `findutils` nếu thiếu.
2. Clone repo về `~/gifcodecfl` (hoặc `CFL_APP_HOME` nếu đặt trước).
3. Bàn giao cho `deploy/termux/install.sh` để:
   - Tạo bộ biến môi trường mặc định tại `$PREFIX/etc/gifcodecfl/profile.sh`.
   - Tạo file env app tại `$PREFIX/etc/gifcodecfl/.env`.
   - Cài `golang` + `termux-services` (runit) qua `pkg`.
   - Build binary `~/gifcodecfl/server` và copy static web vào `~/gifcodecfl/web/`.
   - Cài 2 runit service: `gifcodecfl` (app) và `gifcodecfl-tunnel` (nếu cấu hình Cloudflare Tunnel).
   - Copy scripts sang `$PREFIX/bin/`: `cfl-install.sh`, `cfl-termux-menu.sh`, `cfl-termux-lib.sh`.
   - Tạo symlink menu `cfl-termux` trong `$PREFIX/bin/`.
   - Thêm hook `runsvdir` vào `~/.bashrc` để mỗi lần mở Termux là service tự được supervision.
   - Hỏi có muốn bật wake-lock (chống Android suspend khi tắt màn hình).

### Cấu trúc file

```
deploy/termux/
├── cfl-termux-lib.sh      # Thu vien dung chung (helpers, runit, tunnel, wake-lock)
├── install.sh             # Cai dat tuong tac + subcommands
├── cfl-termux-menu.sh     # Menu quan ly (goi lenh `cfl-termux`)
└── termux-bootstrap.sh    # Entry point nhe cho curl one-liner
```

### Persistence (chạy treo liên tục)

Mặc định sau khi cài, app chạy dưới dạng **runit service** nên:

| Tình huống | App còn sống? |
| --- | --- |
| Tắt màn hình (không có wake-lock) | ⚠️ Có thể bị Android suspend |
| Tắt màn hình + đã bật `wake-lock` | ✅ Sống bình thường |
| App Go crash (panic, OOM) | ✅ Runit tự restart sau ~1s |
| Reboot điện thoại | ❌ Sau reboot cần mở Termux 1 lần |
| Mở Termux sau 1 ngày | ✅ Service tự chạy (nhờ hook trong `~/.bashrc`) |
| Đóng Termux (swipe away khỏi recent) | ⚠️ Android có thể kill; chạy lại khi mở Termux |

### Wake lock (chống Android suspend khi tắt màn hình)

Để app sống 24/7 kể cả khi tắt màn hình, cần cài thêm **[Termux:API](https://f-droid.org/packages/com.termux.api/)** từ F-Droid (cùng repo với Termux), sau đó:

```bash
cfl-termux          # chon muc 4 de bat/tat wake-lock
# hoac:
~/gifcodecfl/deploy/termux/install.sh --wake-lock
```

Wake-lock là global (giữ cho cả Termux, không chỉ app), persist cho đến khi gọi `--wake-unlock` hoặc reboot. Nếu reboot thì chạy lại lệnh trên.

### Menu tương tác (giống native's `cfl`)

Sau khi cài xong, gọi menu bằng:

```bash
cfl-termux
```

Menu gồm 5 mục:

1. Kiem tra trang thai hoat dong cua app (dịch vụ, URL truy cập, IP nội bộ, trạng thái wake-lock, domain tunnel)
2. Bat/Tat chay app
3. Cau hinh lai hoac go bo Cloudflare Tunnel
4. Bat/Tat wake-lock (chong Android suspend)
5. Thoat

### Các lệnh quản lý khác

```bash
cfl-install.sh --configure-domain   # Cau hinh lai Cloudflare Tunnel
cfl-install.sh --remove-tunnel      # Xoa Cloudflare Tunnel
cfl-install.sh --wake-lock          # Bat termux-wake-lock
cfl-install.sh --wake-unlock        # Tat termux-wake-lock
cfl-install.sh --enable-service     # Bat runit service cho app
cfl-install.sh --disable-service    # Tat runit service cho app
cfl-install.sh --update             # Git pull + rebuild + restart service
cfl-install.sh --uninstall          # Dung app, go service, xoa thu muc app
cfl-install.sh help                 # Hien thi tro giup
```

Hoặc dùng đường dẫn đầy đủ:

```bash
~/gifcodecfl/deploy/termux/install.sh --update
```

### Cloudflare Tunnel (public URL từ điện thoại)

Để truy cập app từ bất kỳ đâu trên internet (không cần cùng WiFi), chọn **Có** khi được hỏi ở bước 2 của cài đặt, hoặc chạy lại:

```bash
cfl-install.sh --configure-domain
```

Yêu cầu: bạn đã sở hữu 1 domain và đã trỏ nameserver về Cloudflare ([dash.cloudflare.com](https://dash.cloudflare.com) → Add Site). Script sẽ:

1. Tải `cloudflared` binary về `$PREFIX/bin/` (auto-detect arm64/arm/amd64/386).
2. Chạy `cloudflared tunnel login` — copy URL hiển thị, mở browser, đăng nhập Cloudflare, chọn domain, bấm **Authorize**. Cert lưu vào `~/.cloudflared/`.
3. Hỏi tên domain expose (vd: `gifcodecfl.example.com`).
4. Tạo tunnel `gifcodecfl` trên Cloudflare (nếu chưa có).
5. Copy credentials + cert vào `$PREFIX/etc/cloudflared/`.
6. Gán DNS route (`cloudflared tunnel route dns`).
7. Ghi `config.yml` trỏ vào `http://127.0.0.1:<PORT>`.
8. Lưu state vào `$PREFIX/etc/gifcodecfl/cloudflare.env`.
9. Cài runit service `gifcodecfl-tunnel` (auto-restart + auto-start).

Gỡ tunnel:

```bash
cfl-install.sh --remove-tunnel
```

**Lưu ý**: Cloudflare Tunnel đi ra ngoài qua port 443, **không cần port forwarding** trên router. Free plan hỗ trợ unlimited tunnels.

### Biến tùy chỉnh

Set trước khi chạy curl:

```bash
CFL_REPO_URL=https://github.com/<owner>/gifcodecfl.git \
CFL_REPO_BRANCH=main \
CFL_APP_HOME=$HOME/gifcodecfl \
curl -fsSL https://raw.githubusercontent.com/nguyenan362/gifcodecfl/main/deploy/termux/termux-bootstrap.sh | bash
```

### So sánh nhanh với Linux native

| Tính năng | Linux (`deploy/native/`) | Termux (`deploy/termux/`) |
| --- | --- | --- |
| Service manager | systemd (`systemctl`) | runit (`sv` qua `termux-services`) |
| Auto-start on boot | ✅ `WantedBy=multi-user.target` | ⚠️ Cần mở Termux 1 lần (hook `.bashrc`) |
| Auto-restart on crash | ✅ `Restart=always` | ✅ Runit mặc định |
| Env vars hệ thống | `/etc/profile.d/cfl.sh` | `$PREFIX/etc/gifcodecfl/profile.sh` |
| File env app | `/etc/gifcodecfl/.env` | `$PREFIX/etc/gifcodecfl/.env` |
| Install root | `/opt/gifcodecfl` | `~/gifcodecfl` |
| Lệnh menu | `sudo cfl` | `cfl-termux` |
| Wake-lock | N/A | ✅ (qua Termux:API) |
| Cloudflare Tunnel | ✅ | ✅ |

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
