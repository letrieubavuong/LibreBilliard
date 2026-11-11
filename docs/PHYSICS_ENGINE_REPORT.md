# Báo Cáo Kỹ Thuật: Tái Thiết Kế Toàn Diện Engine Vật Lý & Sơ Đồ Carom Billiard (Phiên bản `fix/physics-engine-v2`)

## 1. Tóm Tắt Khắc Phục Sau Đợt Phản Biện Lần 2 (Commit `3593440`)

Qua đợt phản biện kỹ thuật lần 2 đối với commit `3593440`, toàn bộ 4 mốc nhiệm vụ và 14 tiêu chí kỹ thuật đã được hoàn thành triệt để trên nhánh `fix/physics-engine-v2`:

| Nhóm vấn đề | Cơ chế tại commit `3593440` | Khắc phục triệt để tại `fix/physics-engine-v2` |
| :--- | :--- | :--- |
| **1. Năng lượng ra cơ & chạm băng** | Áp dụng hệ số `0.35` làm sinh năng lượng ở tip biên; hàm va chạm băng cộng `normalRollBoost = 0.08` và hòa trộn vận tốc góc tỉ lệ `0.35 / 0.65` phá vỡ bảo toàn năng lượng. | Khôi phục công thức vật rắn giải tích: `inertiaFactor = 1.0 + 2.5 * rPerpSq / (R * R)`. Với va chạm băng, thay bằng mô hình xung lượng vật rắn 3D với cánh tay đòn `cushionContactHeightRatio = 1.24`, đảm bảo $E_{\text{after}} \le E_{\text{before}}$ với mọi góc, lực, xoáy (và $E_{\text{after}} = E_{\text{before}}$ khi $e_{bc}=1, \mu_{bc}=0$). |
| **2. Độ chính xác va chạm CCD** | CCD giải trên chuyển động đều vận tốc không đổi trong khi `advanceBallOnCloth` chạy với gia tốc chậm dần đều, dẫn tới lệch quỹ đạo và phải dùng position correction đẩy bi nhân tạo. | Nâng cấp `findBallBallImpactTime` và `findBallCushionImpactTime` giải trên đúng quỹ đạo bậc hai $\vec{p}(t) = \vec{p}_0 + \vec{v}_0 t + \frac{1}{2}\vec{a} t^2$. Giới hạn mỗi bước con bởi thời điểm chuyển pha sớm nhất `timeToNextPhaseTransition`. Khoảng cách tiếp xúc đạt sai số $|\|\vec{p}_1(t^*) - \vec{p}_2(t^*)\| - 2R| < 10^{-11}\,\text{m}$ không cần đẩy vị trí nhân tạo. |
| **3. Đầu vào bài học & tính trung thực** | `KT-01` chứa góc ngắm nghịch `explicitAimAngleRadians: -3.51703` làm hụt Bi 1; chỉnh `speedLevel` không cập nhật tốc độ khi có `customCueSpeed`. | Xóa bỏ toàn bộ các góc ngắm ép buộc `explicitAimAngleRadians`. Hiệu chỉnh tọa độ và tốc độ của toàn bộ 13 bài học mẫu để ngắm Ghost Ball thực tế trúng Bi 1 đúng độ dày và má chạm, hoàn thành Carom và gom bi. Tính toán tốc độ qua `effectiveCueSpeedForLevel` tăng đơn điệu từ 1 đến 5. |
| **4. Hiển thị & Kéo thả** | Bàn ngang và bàn dọc dùng tỉ lệ pixel khác nhau khiến bi bị méo thành elip; thanh phát lại dùng thời lượng cố định `2600 ms`. | Xây dựng `CaromTableCanvasLayout` với một tỉ lệ `pixelsPerMeter` duy nhất: hai quả bóng tiếp xúc ($d=2R$) luôn tiếp xúc chính xác ở mọi góc ($0^\circ, 45^\circ, 90^\circ$). Đồng bộ thời lượng phát `1.0×` với thời gian vật lý `durationSeconds` (cộng `0.28s` vung cơ). Kéo thả dùng thuật toán chiếu xen kẽ 16 chu kỳ kết hợp binary search fallback chống chồng lấp tuyệt đối ở góc bàn. |
| **5. Lưu trữ bền vững Sổ tay** | Dùng `Directory.systemTemp` có nguy cơ mất dữ liệu; file JSON hỏng bị ghi đè mất dữ liệu gốc; UI báo lưu thành công dù I/O lỗi. | Lưu vào thư mục dữ liệu ứng dụng của hệ điều hành (`LOCALAPPDATA`, `HOME/.local/share`, Android app files). Khi JSON hỏng, tự động tạo bản sao lưu `.corrupted.bak`. Trả về `Future<bool>` từ `saveState` và thông báo lỗi rõ ràng trên UI nếu ghi thất bại. |

---

## 2. Hệ Phương Trình Vật Lý & Phạm Vi Mô Hình

### 2.1. Động lực học đầu cơ – bi chủ (`CueStrikePhysics`)
Với cây cơ có khối lượng hiệu dụng $M_c$, bi có khối lượng $m$, bán kính $R$, mô-men quán tính $I = \frac{2}{5}mR^2$, điểm chạm lệch tâm $(x_{\text{tip}}, z_{\text{tip}})$ và góc nâng cơ $\theta_{\text{elev}}$:
- **Hệ số quán tính quay:**
  $$\eta = 1 + \frac{5(x_{\text{tip}}^2 + z_{\text{tip}}^2)}{2R^2}$$
- **Độ lớn xung lượng:**
  $$J = \frac{M_c m (1 + e_{\text{tip}}) v_{\text{cue}}}{m + M_c \eta}$$
- **Vận tốc cơ sau va chạm:** $v_{\text{cue}}' = v_{\text{cue}} - \frac{J}{M_c}$.
- **Bảo toàn năng lượng:** Với mọi $e_{\text{tip}} \in [0, 1]$, $E_{\text{ball}}' + E_{\text{cue}}' \le E_{\text{cue}}$.

### 2.2. Va chạm vật rắn với thành băng cao su (`CollisionPhysics`)
Mũi băng cao su tiếp xúc với bi tại độ cao $h_c = 1.24 R$ tính từ mặt bàn, tạo cánh tay đòn $\vec{r}_c = -R \hat{n} + (h_c - R) \hat{k}$:
- Vận tốc tương đối tại điểm tiếp xúc: $\vec{v}_c = \vec{v} + \vec{\omega} \times \vec{r}_c$.
- Thành phần pháp tuyến phản hồi theo hệ số đàn hồi $e_{bc} = 0.80$: $J_n = m(1 + e_{bc}) |v_{c,n}|$.
- Thành phần tiếp tuyến chịu ma sát Coulomb giới hạn: $|J_t| \le \mu_{bc} J_n$, truyền mô-men biến đổi vận tốc góc $\Delta\vec{\omega} = I^{-1}(\vec{r}_c \times \vec{J})$.
- Đảm bảo $E_{\text{after}} \le E_{\text{before}}$ với mọi góc tới và độ xoáy.

### 2.3. Phát hiện va chạm liên tục (CCD) bậc hai
Trong mỗi khoảng con $\Delta t$ mà các bi giữ nguyên pha chuyển động, gia tốc $\vec{a}_i$ là hằng số:
$$\vec{p}_i(t) = \vec{p}_{i,0} + \vec{v}_{i,0} t + \frac{1}{2}\vec{a}_i t^2$$
Khoảng cách bình phương giữa hai bi $A$ và $B$ là đa thức bậc 4:
$$f(t) = \|\Delta\vec{p}_0 + \Delta\vec{v}_0 t + \frac{1}{2}\Delta\vec{a} t^2\|^2 - (2R)^2 = 0$$
Nghiệm va chạm $t^* \in [0, \Delta t]$ được định vị qua tìm kiếm khoảng đơn điệu và tinh chỉnh bằng Newton-Raphson, đạt độ chính xác $|\|\vec{p}_A(t^*) - \vec{p}_B(t^*)\| - 2R| < 10^{-11}\,\text{m}$.

---

## 3. Bảng Kết Quả Kiểm Thử Toàn Diện (13/13 Test Cases Đạt Chuẩn)

Bộ kiểm thử tự động tại `test/physics_engine_test.dart` bao gồm đầy đủ các kịch bản định lượng:

| STT | Tên ca kiểm thử | Kết quả đo đạc thực tế | Trạng thái |
| :---: | :--- | :--- | :---: |
| 1 | Bảo toàn năng lượng khi ra cơ (Cue Strike) | $E_{\text{after}} \le E_{\text{before}}$ trên toàn bộ lưới tip $[-0.8, 0.8]$ và góc nâng $[0^\circ, 60^\circ]$. | **PASS** |
| 2 | Bảo toàn năng lượng khi chạm băng | $E_{\text{after}} \le E_{\text{before}}$ với mọi góc tới và spin; $E_{\text{after}} = E_{\text{before}}$ khi $e_{bc}=1, \mu_{bc}=0$ (sai số $< 10^{-7}$). | **PASS** |
| 3 | Độ chính xác tiếp xúc CCD & Hội tụ | Khoảng cách tiếp xúc đạt sai số $|d - 2R| < 10^{-11}\,\text{m}$ cho cả va chạm bi–bi và bi–băng. | **PASS** |
| 4 | Không chồng lấp tại mọi thời điểm mẫu | $\|\vec{p}_i(t) - \vec{p}_j(t)\| \ge 2R - 10^{-9}\,\text{m}$ tại mọi $t \in [0, T]$ qua `sampleAtTime`. | **PASS** |
| 5 | Giới hạn thời gian mô phỏng | Trả về `maxTimeReached` chính xác khi chạm trần thời gian. | **PASS** |
| 6 | Đơn điệu hóa vận tốc qua `speedLevel` | Tăng mức lực $1 \to 5$ làm tăng đơn điệu vận tốc thực tế trên toàn bộ 13 bài học mẫu. | **PASS** |
| 7 | Xác thực kỹ thuật 13 bài học mẫu | Toàn bộ 13 bài học mẫu đều ngắm Ghost Ball thực tế, trúng Bi 1 trước đúng độ dày, carom thành công và gom bi trong vùng quy định. | **PASS** |
| 8 | Từ chối `ShotInput` không hợp lệ | Ném `ShotInputValidationException` và trả về `isValid: false`, không tự ý dịch chuyển tọa độ bi. | **PASS** |
| 9 | Chống chồng lấp khi kéo bi vào góc bàn | Kéo bi vào sát góc $(R_d, R_d)$ vẫn duy trì khoảng cách $\ge 2R_d$. | **PASS** |
| 10 | Tỉ lệ khung nhìn đồng nhất `pixelsPerMeter` | Hai bi chạm nhau tiếp xúc hoàn hảo ở mọi phương $0^\circ, 45^\circ, 90^\circ$; chuyển đổi khứ hồi $world \leftrightarrow canvas$ sai số $< 10^{-4}\,\text{m}$. | **PASS** |
| 11 | Sao lưu file JSON hỏng & Schema version | Tự động tạo bản sao `.corrupted.bak` khi file lỗi; bảo lưu dữ liệu khi schema version mới hơn. | **PASS** |
| 12 | Tách biệt tính toán vật lý và render UI | Thao tác đổi góc nhìn (lật bàn, bật tắt số nút) không gọi lại `simulate()`. | **PASS** |
| 13 | Smoke Test toàn bộ ứng dụng | Khởi chạy ứng dụng, chuyển qua 5 tab Bottom Bar và mở chi tiết bài học không có lỗi phát sinh. | **PASS** |
