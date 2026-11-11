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
   - Toàn bộ các điểm cực trị (closest approach) được giải bằng công thức Cardano & dạng lượng giác để chia khoảng đơn điệu, bắt trọn 100% các ca va chạm sượt (grazing collisions) với sai số tiếp xúc $|d - 2R| < 10^{-11}\,\text{m}$ (kiểm chứng thực tế đạt $\approx 4 \times 10^{-17}\,\text{m}$) không cần đẩy vị trí nhân tạo.

4. **Nghiệm Thu Bài Học Mẫu Qua Fixture Kỹ Thuật Độc Lập:**
   - Sử dụng `LessonPhysicsVerificationFixture` kiểm chứng đầy đủ các tiêu chí: thứ tự chạm bi, dấu má chạm (+1/-1), fraction thực tế ($\pm 0.05$), số băng trước carom, chuỗi thành băng, số băng bi vàng, chuyển động sau va chạm có dấu, và gom bi.
   - Đo đạc chuyển động sau va chạm có dấu: vector sau chạm Bi 1 $s_{\parallel} = \Delta\vec{p}_{\text{post}} \cdot \hat{u}_{\text{in}}$, bắt buộc trô lùi (`drawBack`: $s_{\parallel} \le -0.005\text{m}$) và đẩy tới (`pushForward`: $s_{\parallel} \ge 0.005\text{m}$). Cú đánh forward-only bắt buộc FAIL fixture trô KT-01. Ca kiểm thử biên $\{+0.004, 0.0, -0.004, -0.006\}\text{m}$ khẳng định duy nhất $-0.006\text{m}$ vượt qua điều kiện chiều trô.
   - Lưu trạng thái chính xác trước va chạm (`primaryBallPositionAtCollision`, `primaryBallVelocityBefore`) trong `CollisionEvent` từ thời điểm va chạm giải tích CCD.
   - Strict Null-checks: Bất kỳ tiêu chí nào được bật trong Fixture mà kết quả thực tế là `null` hoặc thiếu số đo thì bắt buộc FAIL. Gom bi bắt buộc `gathersInZone == true`, nếu `null` hoặc `false` đều báo lỗi.
   - Không được nới rộng bán kính gom bi hay dung sai để gượng ép gán nhãn `isPhysicsVerified: true`. Phân biệt minh bạch hai mức chứng nhận: "Verified nội bộ mô hình 2.5D" (8 bài) và "Chưa kiểm chứng thực nghiệm / thiếu số băng mô tả" (7 bài).

5. **Đồng Nhất Bố Cục & Timeline Playback Thực Tế:**
   - Sử dụng một tỉ lệ scale duy nhất `pixelsPerMeter = min(availW / visWidthM, availH / visLengthM)` cho cả hai trục để quả bóng tròn hoàn hảo và tiếp xúc đúng ở mọi góc ($0^\circ, 45^\circ, 90^\circ$).
   - Thời lượng phát $1.0\times$ phải ánh xạ chính xác: $0.28\text{s}$ vung cơ và đúng $T_{\text{sim}}$ giây chuyển động bi trong thời gian thực.
   - Kéo thả bi dùng thuật toán chiếu xen kẽ 16 chu kỳ kết hợp binary search fallback (`CaromTableCanvasLayout.constrainBallPosition`) để chống chồng lấn và chống kẹt góc bàn.

6. **Bảo Vệ Dữ Liệu Bền Vững & Chế Độ Chỉ Đọc:**
   - Dữ liệu người dùng lưu vào thư mục hệ thống chuẩn qua `path_provider`. Khi JSON lỗi phải tự động tạo `.corrupted.bak`.
   - Migration Sổ tay cũ: Khi file mới chưa tồn tại, tìm kiếm các candidate legacy, validate JSON, tạo `.migration.bak` và copy nguyên tử sang file mới; không ghi đè defaults lên dữ liệu cũ.
   - File có `schemaVersion > currentSchemaVersion` chuyển sang chế độ Read-Only và tạo bản sao `.future_v{version}.bak`. Hàm `saveState` có Write Guard từ chối ghi đè, bảo toàn 100% bytes file gốc trên đĩa.
   - UI Read-Only Guard: Trạng thái UI (`HomeScreenState`) lưu giữ cờ `_isReadOnly` và giải thích lý do, từ chối mọi thao tác chỉnh sửa ở tầng giao diện và không thay đổi state hiển thị.

7. **Sơ Đồ Chạm Trái 8 Phần & Điểm Mũi Cơ 4 Mức theo mm:**
   - Slider rời rạc 7 nấc $k=1..7$ ($1/8 .. 7/8$, `divisions: 6`), nút `[-]`/`[+]` dịch đúng $1/8$, nút `Tràn mặt 8/8` riêng biệt có khôi phục độ dày và má trước đó.
   - Góc cắt ngắm AimGeometry: $b = 2R(1 - f)$, $\theta = \arcsin(1 - f)$ ($4/8 \to 30^\circ$).
   - Bảo toàn phân số bài cũ $1/3$ và $2/3$, hiển thị rõ nhãn gốc khi đọc.
   - Bi Carom $2R = 61.5\text{mm}$, đầu cơ $11.5–12.0\text{mm}$ (mặc định $12.0\text{mm}$).
   - Thang 4 mức quy ước: mỗi mức $0.125R = 3.84375\text{mm}$, biên an toàn tham khảo $r \le 0.50R = 15.375\text{mm}$.
   - Ràng buộc hình tròn tiếp xúc: $x^2 + z^2 \le r_{\text{limit}}^2$.
   - Mốc tham khảo Natural Roll $+12.30\text{mm}$. Vẽ vòng đầu cơ làm hình tham chiếu kích thước và chấm đỏ điểm tiếp xúc phân biệt.

8. **Kiểm Chứng Độc Lập Thế Bi Kéo Về (Rappel de Base) & Ràng Buộc Băng Chặt Chẽ:**
   - **Đo đạc lưới Cadre chuẩn:** Bàn trong tài liệu cổ điển Pháp (Xavier Gretillat / Laurent Guénet) sử dụng lưới bàn Cadre 47/2 (chia 3 cadre theo chiều rộng $W/3$, vạch ngang cách băng $74\text{cm}$). Tọa độ bi phải được đối chiếu trực tiếp trên hệ lưới này.
   - **Động học tiếp tuyến vs Trô lùi:** Trong cú trô có góc cắt ($f = 2/3$, $\theta = 19.47^\circ$), vận tốc tiếp tuyến $v_t = \frac{1}{3}v_0$ vuông góc với pháp tuyến va chạm $\hat{n}$. Hướng ngắm của cơ thủ và phương nối Bi 2 $\to$ Bi 3 phải thẳng hàng đối xứng $180^\circ$ để lực trô lùi kéo bi chủ đi thẳng tắp về Bi 3, không bị văng ngang.
   - **Ràng buộc `maxCushionsBeforeCarom: 0`:** Cú đánh trô kéo về cơ bản nghiệm thu khắt khe qua `maxCushionsBeforeCarom: 0`. Tuyệt đối không cho phép bi chủ va chạm bất kỳ băng nào trước khi chạm Bi 3 (`cushionCountBeforeCarom == 0`).
   - **Đầy đủ điều khiển UI:** Giữ nguyên độ dày $2/3$ qua nút chọn nhanh $1/3$, $1/2$, $2/3$ độc lập với slider 8 phần; cho phép tinh chỉnh liên tục tốc độ ngọn cơ $v_{\text{cue}}$ theo $\text{m/s}$ và độ sâu mũi cơ theo $\text{mm}$.

## 2. Quy Trình Kiểm Thử Chuẩn

Trước khi hoàn tất bất kỳ thay đổi nào liên quan tới vật lý, UI bàn hoặc bài học, luôn chạy:
```powershell
flutter analyze
flutter test test/physics_engine_test.dart
flutter test test/rappel_2_3_survey_test.dart
flutter test
```
Tất cả các ca kiểm thử trong repo phải vượt qua (`100% PASS`, 0 warnings, 0 errors).
