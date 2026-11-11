---
name: carom-physics-verification
description: Quy trình kiểm chứng và chuẩn mực kỹ thuật cho engine vật lý bida Carom 3 bi, CCD bậc hai, bảo toàn năng lượng và sơ đồ tương tác
---

# Carom Physics Engine & Diagram Verification Skill

Skill này quy định chuẩn mực kỹ thuật bắt buộc khi phát triển, bảo trì hoặc mở rộng bộ giải vật lý bida Carom và sơ đồ bàn tương tác trong dự án `LibreBilliard`.

## 1. Nguyên Tắc Cốt Lõi (Core Tenets)

1. **Tuyệt đối không dùng Heuristic / Hack vị trí nhân tạo:**
   - Không được tự ý cộng/trừ tọa độ bi, không dùng nhánh "ăn gian" theo bài học mẫu, không dùng easing giả trên polyline.
   - Mọi hoạt ảnh và vị trí bi phải được trích xuất trực tiếp từ tích phân động lực học SI (`SimulationResult.sampleAtTime`).

2. **Bảo Toàn Năng Lượng Khắt Khe ($E_{\text{after}} \le E_{\text{before}}$):**
   - **Ra cơ (Cue Strike):** Khối lượng hiệu dụng và mô-men quán tính phải tuân theo công thức vật rắn:
     $$\eta = 1 + \frac{5(x_{\text{tip}}^2 + z_{\text{tip}}^2)}{2R^2}$$
     Tổng năng lượng $E_{\text{ball}}' + E_{\text{cue}}' \le E_{\text{cue}}$ với mọi điểm chạm tip và góc nâng cơ.
   - **Chạm băng (Cushion Impact):** Không được cộng thêm `boost` gia tốc hay hòa trộn tỉ lệ vận tốc góc tùy tiện. Dùng mô hình cánh tay đòn vật rắn $h_c = 1.24 R$ và ma sát Coulomb tiếp tuyến để $E_{\text{after}} \le E_{\text{before}}$. Khi $e_{bc}=1, \mu_{bc}=0$, năng lượng phải bảo toàn tuyệt đối.

3. **Phát Hiện Va Chạm Liên Tục (CCD) Đồng Nhất Bậc Hai:**
   - Bước thời gian con phải được giới hạn bởi `timeToNextPhaseTransition` để gia tốc $\vec{a}_i$ luôn là hằng số trên từng bước.
   - CCD giải trên phương trình quỹ đạo $\vec{p}_i(t) = \vec{p}_{i,0} + \vec{v}_{i,0} t + \frac{1}{2}\vec{a}_i t^2$, đảm bảo khoảng cách va chạm đạt $|d - 2R| < 10^{-11}\,\text{m}$ mà không cần đẩy vị trí nhân tạo.

4. **Đồng Nhất Tỉ Lệ Hiển Thị (`pixelsPerMeter`):**
   - Chỉ sử dụng một tỉ lệ scale duy nhất `pixelsPerMeter = min(availW / visWidthM, availH / visLengthM)` cho cả chiều ngang và chiều dọc.
   - Hai bi tiếp xúc ($d=2R$) phải luôn tiếp xúc hoàn hảo ở mọi góc ($0^\circ, 45^\circ, 90^\circ$).

## 2. Quy Trình Kiểm Thử Chuẩn

Trước khi hoàn tất bất kỳ thay đổi nào liên quan tới vật lý, UI bàn hoặc bài học, luôn chạy:
```powershell
flutter analyze
flutter test test/physics_engine_test.dart
flutter test
```
Tất cả 13 ca kiểm thử trong `physics_engine_test.dart` phải vượt qua (`13/13 PASS`).

