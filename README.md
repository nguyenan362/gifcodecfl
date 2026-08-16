# Giftcode CFL Redeemer

Web app đơn giản để nhập `userID` và nhiều gift code, sau đó gọi API redeem theo từng code.

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
