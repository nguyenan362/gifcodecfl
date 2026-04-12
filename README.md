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

2. Điền token vào `.env`:

```env
REDEEM_AUTHORIZATION=...
```

3. Export biến môi trường và chạy:

```bash
set -a
source .env
set +a

go run .
```

4. Mở trình duyệt:

```text
http://localhost:8080
```

## Chạy bằng Docker Compose

1. Chuẩn bị biến môi trường:

```bash
cp .env.example .env
```

2. Cập nhật token trong `.env`:

```env
REDEEM_AUTHORIZATION=...
```

3. Build và chạy:

```bash
docker compose up -d --build
```

4. Xem log:

```bash
docker compose logs -f app
```

5. Dừng dịch vụ:

```bash
docker compose down
```

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

## Lưu ý bảo mật

- Không đặt token `authorization` ở frontend.
- Token chỉ nên lưu ở backend qua biến môi trường.
