---
name: carom-physics-verification
description: Quy trình kiểm chứng và chuẩn mực kỹ thuật cho engine vật lý bida Carom 3 bi, CCD bậc hai cô lập cực trị, mô hình băng tiêu tán 2.5D, fixture nghiệm thu và timeline playback đồng bộ
---

# Carom Physics Engine & Diagram Verification Skill

Skill này quy định chuẩn mực kỹ thuật bắt buộc khi phát triển, bảo trì hoặc mở rộng bộ giải vật lý bida Carom và sơ đồ bàn tương tác trong dự án `LibreBilliard`.

## 1. Nguyên Tắc Cốt Lõi (Core Tenets)

1. **Tuyệt đối không dùng Heuristic / Hack vị trí nhân tạo:**
   - Không được tự ý cộng/trừ tọa độ bi, không dùng nhánh "ăn gian" theo bài học mẫu, không dùng easing giả trên polyline.
   - Mọi hoạt ảnh và vị trí bi phải được trích xuất trực tiếp từ tích phân động lực học SI (`SimulationResult.sampleAtTime`).

2. **Bảo Toàn Năng Lượng Khắt Khe ($E_{\text{after}} \le E_{\text{before}}$):**
   - **Ra cơ (Cue Strike):** Khối lượng hiệu dụng và mô-men quán tính tuân theo công thức vật rắn giải tích:
     $$\eta = 1 + \frac{5(x_{\text{tip}}^2 + z_{\text{tip}}^2)}{2R^2}$$
     Tổng năng lượng $E_{\text{ball}}' + E_{\text{cue}}' \le E_{\text{cue}}$ với mọi điểm chạm tip và góc nâng cơ.
   - **Chạm băng (Cushion Impact):** Công bố trung thực là **Mô hình Băng Rút Gọn 2.5D Tiêu Tán Năng Lượng (Planar Dissipative Cushion Model)**. Xung lượng pháp tuyến Newton $J_n = m(1 + e_{bc}) v_{n,\text{in}}$, xung lượng ma sát tiếp tuyến ngang Coulomb $|J_t| \le \mu_{bc} J_n$ kẹp theo trượt $u_t = v_t - R\omega_z$, và xoáy ngang $\omega_t$ chịu mô-men cản ma sát (spin damping) giảm dần về 0 mà không tự sinh năng lượng ($E_{\text{after}} \le E_{\text{before}}$). Khi $e_{bc}=1, \mu_{bc}=0$, năng lượng bảo toàn tuyệt đối ($E_{\text{after}} = E_{\text{before}}$). Tuyệt đối không tự xưng là mô hình 3D toàn phần khi chưa giải động học nảy trục Z.

3. **Phát Hiện Va Chạm Liên Tục (CCD) Bậc Hai với Cô Lập Cực Trị Giải Tích:**
   - Bước thời gian con được giới hạn bởi `timeToNextPhaseTransition` để gia tốc $\vec{a}_i$ luôn là hằng số trên từng bước.
   - Khoảng cách bình phương $f(t) = \|\Delta\vec{p}_0 + \Delta\vec{v}_0 t + \frac{1}{2}\Delta\vec{a} t^2\|^2 - (2R)^2$. Đạo hàm $f'(t)$ là đa thức bậc ba giải tích $c_3 t^3 + c_2 t^2 + c_1 t + c_0$.
   - Toàn bộ các điểm cực trị (closest approach) được giải bằng công thức Cardano & dạng lượng giác để chia khoảng đơn điệu, bắt trọn 100% các ca va chạm sượt (grazing collisions) với sai số tiếp xúc $|d - 2R| < 10^{-11}\,\text{m}$ không cần đẩy vị trí nhân tạo.

4. **Nghiệm Thu Bài Học Mẫu Qua Fixture Kỹ Thuật Độc Lập:**
   - Sử dụng `LessonPhysicsVerificationFixture` kiểm chứng 8 tiêu chí: thứ tự chạm bi, dấu má chạm (+1/-1), fraction thực tế ($\pm 0.05$), số băng trước carom, số băng bi vàng, khoảng kéo/tiến cm và gom bi.
   - Không được nới rộng bán kính gom bi hay dung sai để gượng ép gán nhãn `isPhysicsVerified: true`. Bài học chưa đủ dữ liệu đo đạc thực nghiệm (như Piqué nâng cơ 40°) phải đánh nhãn trung thực `isPhysicsVerified: false`.

5. **Đồng Nhất Bố Cục & Timeline Playback Thực Tế:**
   - Sử dụng một tỉ lệ scale duy nhất `pixelsPerMeter = min(availW / visWidthM, availH / visLengthM)` cho cả hai trục để quả bóng tròn hoàn hảo và tiếp xúc đúng ở mọi góc ($0^\circ, 45^\circ, 90^\circ$).
   - Thời lượng phát $1.0\times$ phải ánh xạ chính xác: $0.28\text{s}$ vung cơ và đúng $T_{\text{sim}}$ giây chuyển động bi trong thời gian thực.
   - Kéo thả bi dùng thuật toán chiếu xen kẽ 16 chu kỳ kết hợp binary search fallback (`CaromTableCanvasLayout.constrainBallPosition`) để chống chồng lấn và chống kẹt góc bàn.

6. **Bảo Vệ Dữ Liệu Bền Vững & Write Guard Schema Tương Lai:**
   - Dữ liệu người dùng lưu vào thư mục hệ thống chuẩn qua `path_provider`. Khi JSON lỗi phải tự động tạo `.corrupted.bak`.
   - File có `schemaVersion > currentSchemaVersion` chuyển sang chế độ Read-Only và tạo bản sao `.future_v{version}.bak`. Hàm `saveState` có Write Guard từ chối ghi đè, bảo toàn 100% bytes file gốc trên đĩa.

## 2. Quy Trình Kiểm Thử Chuẩn

Trước khi hoàn tất bất kỳ thay đổi nào liên quan tới vật lý, UI bàn hoặc bài học, luôn chạy:
```powershell
flutter analyze
flutter test test/physics_engine_test.dart
flutter test
```
Tất cả 16 ca kiểm thử trong repo phải vượt qua (`16/16 PASS`, 0 warnings, 0 errors).
