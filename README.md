# Xavier Billiard Libre (Flutter Android)

Ứng dụng học tập, tra cứu và mô phỏng vật lý **Billiard Libre (Phăng)** trên Android được thiết kế dựa trên phương pháp gom bi, giữ seri góc Amery và hệ thống bộ số kinh điển của **Xavier Gretillat**.

## Tính năng chính

1. **5 Chuyên mục Bottom Navigation Bar:**
   - **Kĩ thuật (`Technique`):** Rétro Amorti, Poussé / Coulé ngắn, Phanh bi (Amorti), Piqué / Massé nhỏ.
   - **Hình gom bi (`Rappel / Gathering`):** Gom bi 1 băng dài, Chữ thập 2 băng (Croisé), Lật bi về vùng Amery, Gom bi khứ hồi băng ngắn.
   - **Bộ số (`Diamond Systems`):** Hệ thống Bộ 50, Hệ thống Cộng 2 (Plus 2), Hệ thống Tia 1 băng hiệu chỉnh Ép-phê, Hệ thống Tia góc 2 băng + **Máy tính Bộ số tương tác 3 hệ thống**.
   - **Seri & Góc (`Serie & Corner Control`):** Thế bi Mắt kính dọc băng (Les Lunettes), Xoay sở qua vạch ô cấm góc (`71×35.5cm`), Nhịp bắc cầu Amery (Le Chevalet).
   - **Sổ tay (`Notebook & Sandbox`):** Lưu Bookmark, đếm số lượt tập tại bàn, ghi chú cá nhân, **Đố hình bi (Flashcard Quiz)** và **Tự xếp hình bi kéo-thả trực tiếp**.

2. **Kiến trúc Kế thừa cho các Sơ đồ Billiard (`lib/widgets/diagrams/`):**
   - `BaseBilliardDiagramWidget` & `BaseBilliardPainter`: Lớp cơ sở hỗ trợ 3 chế độ hiển thị (`thumbnail`, `standard`, `interactive`).
   - `CaromTableDiagram`: Bàn Carom dọc theo màn hình điện thoại (1:2) và chế độ **Cận cảnh 1/2 bàn**, tích hợp **Bộ giải vật lý vật rắn 120 bước không chồng lấp (PBD Rigid-Body Non-Penetration Solver)**, hoạt ảnh cây cơ, bóng bi Aramith 6 chấm đỏ xoay 3D, thanh tua Timeline và chế độ quay chậm `0.5×`.
   - `BallContactDiagram`: Sơ đồ độ dày chạm trái (`1/8`, `1/4`, `1/3`, `1/2`, `2/3`, `3/4` + Má Trái/Phải).
   - `CueBallEffetDiagram`: Mặt đồng hồ bi chủ `12h` (Cu-lê) – `6h` (Trô) và `0..4` mũi Ép-phê.

## Chạy dự án

```bash
flutter pub get
flutter run
```
