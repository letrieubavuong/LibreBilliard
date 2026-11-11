# Báo Cáo Kỹ Thuật: Nghiệm Thu Toàn Diện Engine Vật Lý & Sơ Đồ Carom Billiard (Phiên bản Lần 5 — `feature/slider-8ths-cue-4tiers`)

## 1. Tóm Tắt Khắc Phục Sau Đợt Phản Biện Lần 5 (Đối chiếu Commit `7e16529`)

Báo cáo này đối chiếu và giải quyết trọn vẹn các yêu cầu kỹ thuật từ `docs/LibreBilliard_Lan5_ThanhTruot_8Phan_4Tang.txt` trên nhánh chuyên dụng `feature/slider-8ths-cue-4tiers`:

| Nhóm vấn đề | Đánh giá tại Lần 5 | Khắc phục chuẩn xác tại `feature/slider-8ths-cue-4tiers` |
| :--- | :--- | :--- |
| **1. Ngưỡng âm chặt chẽ cho Chiều Trô (Draw-Back Threshold)** | Điều kiện cũ chỉ fail khi $s_{\parallel} \ge +0.005\text{m}$ dẫn đến $s_{\parallel} = 0$ hoặc $+0.004\text{m}$ (tiến 4mm) vẫn vượt qua tiêu chí trô. | Đổi điều kiện thành **$s_{\parallel} > -\epsilon_{\text{motion}}$** (với $\epsilon_{\text{motion}} = 0.005\text{m} = 5\text{mm}$). Bắt buộc bi chủ phải giật lùi rõ rệt $s_{\parallel} \le -0.005\text{m}$ mới đạt. Bổ sung **Test 9d** kiểm thử bộ ca biên $\{+0.004, 0.0, -0.004, -0.006\}\text{m}$, khẳng định duy nhất ca $-0.006\text{m}$ vượt qua điều kiện chiều trô! |
| **2. Trạng thái Va chạm Động lực học Chính xác** | Vector tới $\vec{v}_{\text{in}}$ nội suy từ snapshot `tHit - 0.002s` có thể bị lệch bước lấy mẫu. | Bổ sung trực tiếp `primaryBallPositionAtCollision`, `primaryBallVelocityBefore`, `secondaryBallVelocityBefore` vào `CollisionEvent` từ thời điểm va chạm giải tích của CCD, bảo đảm $\vec{p}_{\text{hit}}$ và $\hat{u}_{\text{in}}$ đạt độ chính xác giải tích tuyệt đối. |
| **3. Đồng bộ Tiêu chí Sư phạm & Fixture (KT-01 & KT-02)** | KT-01 ghi trô 15–25cm nhưng fixture kiểm 3–12cm; KT-02 ghi tịnh tiến 10–15cm nhưng fixture kiểm 2–10cm sau chạm. | Đồng bộ minh bạch hai cự ly: **Đoạn dịch chuyển sau va chạm Bi 1** (KT-01: $4–8\text{cm}$; KT-02: $3–6\text{cm}$) và **Tổng dịch chuyển từ vị trí xuất phát** (KT-01: $15–25\text{cm}$; KT-02: $12–18\text{cm}$). Cập nhật subtitle bài học và fixture hoàn toàn nhất quán. |
| **4. Thanh trượt Độ dày Chạm Trái 8 phần (1/8 .. 7/8, Tràn mặt 8/8)** | Trước đây dùng `ChoiceChip` tĩnh, thiếu thanh trượt rời rạc và nút $\pm$. | Triển khai **Slider 7 nấc rời rạc** ($k=1..7$, `divisions: 6`), nhãn phần tám kết hợp tên rút gọn phụ ($2/8 (1/4)$, $4/8 (1/2)$, $6/8 (3/4)$). Nút `[-]` và `[+]` dịch chuyển đúng $1/8$. Nút **Tràn mặt 8/8** riêng biệt, có khả năng ghi nhớ và **khôi phục chính xác độ dày và má trước đó**. Điều khiển Má Trái / Má Phải độc lập: đổi độ dày giữ má, đổi má giữ độ dày. Góc cắt tuân thủ hình học `AimGeometry`: $b = 2R(1-f)$, $\theta = \arcsin(1-f)$ ($4/8 \to 30^\circ$, không chia đều $45^\circ$). **Bảo toàn dữ liệu cũ ($1/3, 2/3$)** khi mở màn hình, hiển thị rõ "giá trị gốc". |
| **5. Điểm Mũi Cơ theo mm & Thang 4 mức (Bi 61.5mm, Đầu cơ 11.5–12mm)** | Thang 4 mũi cũ ánh xạ tới $0.8R = 24.6\text{mm}$, thiếu mốc tham khảo an toàn và chưa phân biệt tâm đầu cơ vs điểm tiếp xúc. | Định nghĩa kích thước chuẩn: Bi Carom $2R = 61.5\text{mm}$, bán kính $R = 30.75\text{mm}$. Tùy chọn đầu cơ $11.5, 11.75, 12.0\text{mm}$ (mặc định $12.0\text{mm}$). **Quy ước 4 mức** tính từ tâm trong vùng tham khảo an toàn $r \le 0.50R = 15.375\text{mm}$ (Dr. Dave Cue Tip Limit), mỗi mức ứng với $0.125R = 3.84375\text{mm}$. Ràng buộc hình tròn $x^2 + z^2 \le r_{\text{limit}}^2$. Vẽ **4 vòng đồng tâm** định vị, **vạch mốc Natural Roll** tại $z = +0.40R = +12.30\text{mm}$, vẽ **vòng tròn đầu cơ tỉ lệ thực** làm hình tham chiếu và **chấm đỏ điểm tiếp xúc phân biệt**. Tách biệt hoàn toàn `tipDiameter` và spin (đổi đầu cơ giữ nguyên tọa độ tiếp xúc vật lý). |
| **6. Khớp nối Báo cáo Hội tụ & Bằng chứng Nghiệm thu** | Báo cáo hội tụ bước động lực học cần khớp chuẩn xác giữa assertion và docs. | Assertion hội tụ xác nhận mức sai số $< 10^{-9}$ cho thời điểm và khoảng cách; thực tế chạy hội tụ đạt mức $10^{-13}\text{s}$ và $10^{-12}\text{m}$. |
| **7. Đóng gói & Bằng chứng Kiểm thử Độc lập** | Bổ sung file APK tải được, mã hash SHA-256, kích thước file và raw logs. | Build debug APK `171,126,502 bytes`, SHA-256 `2088521693DD9B6BBE393F64058DCFFB476E72AD932E631E0BFAE6C67340C91C`. Toàn bộ 32 unit/widget tests PASS 100%. Raw logs lưu tại `docs/logs/`. |

---

## 2. Bảng Phân Loại Nghiệm Thu 15 Bài Học Mẫu

| Mã | Tên bài học | Má chạm | Độ dày | Chuyển động bi chủ / Băng yêu cầu | Băng bi vàng | Carom | Gom bi | Nhãn nghiệm thu | Ghi chú kỹ thuật |
| :---: | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| **KT-01** | Trô ngắn giữ bi (Rétro) | +1.0 (Trái) | 0.750 (6/8) | `drawBack` ($s_{\parallel} = -4.2\text{cm} < -0.5\text{cm}$) | 1 băng ngắn | Đạt | Đạt | **Verified** | Đạt 100% tiêu chí cơ học trô lùi và gom góc. |
| **KT-02** | Đẩy mượt (Poussé / Coulé) | -1.0 (Phải) | 0.500 (4/8) | `pushForward` ($s_{\parallel} = +2.5\text{cm} > +0.5\text{cm}$) | 0 băng | Đạt | Đạt | **Verified** | Đạt 100% tiêu chí tịnh tiến giữ cự ly. |
| **KT-03** | Phanh bi (Amorti) | +1.0 (Trái) | 0.667 (2/3) | Dừng sát bi 2 ($d_{\text{post}} = 8.0\text{cm}$) | Yêu cầu 2 băng (thực tế 0) | Đạt | Đạt | **Chưa verified** | Lực hãm bi chủ khiến bi vàng chưa đủ lực chạy 2 băng; chờ hiệu chỉnh. |
| **KT-04** | Piqué 40° (Petit Massé) | +1.0 (Trái) | 0.250 (2/8) | Nghiêng cơ 40° bẻ cong | 0 băng | Đạt | Đạt | **Chưa verified** | Pha trượt làm cong quỹ đạo (fraction lệch 0.36 vs 0.25); cần dữ liệu bàn thật. |
| **GB-01** | Gom bi 1 băng dài | -1.0 (Phải) | 0.333 (1/3) | Tách bi sang Bi đỏ | Yêu cầu 1 băng dài (thực tế 0) | Đạt | Đạt | **Chưa verified** | Lực cơ 0.9m/s làm bi vàng dừng trước khi tới băng dài; chưa đóng verified. |
| **GB-02** | Gom bi Chữ thập 2 băng | +1.0 (Trái) | 0.500 (4/8) | Trô ngang chạm mặt bi đỏ | Yêu cầu 2 băng góc (thực tế 1) | Đạt | Đạt | **Chưa verified** | Bi vàng mới chạm 1 băng ngắn; chưa chạm đủ 2 băng góc; chưa đóng verified. |
| **GB-03** | Đòn Lật bi Amery | +1.0 (Trái) | 0.250 (2/8) | 1 băng ngắn chạm bi đỏ | 1 băng ngắn | Đạt | Đạt | **Verified** | Bi vàng 1 băng ngắn dội về vùng Amery chuẩn xác. |
| **GB-04** | Khứ hồi băng ngắn (Rappel) | -1.0 (Phải) | 0.875 (7/8) | Trô sâu lùi góc | Yêu cầu 2 băng ngắn (thực tế 0) | Đạt | Đạt | **Chưa verified** | Bi vàng chưa đủ động lượng chạy hết 2 băng ngắn; chưa đóng verified. |
| **BS-01** | Bộ số 50 (3 băng) | +1.0 (Trái) | 0.250 (2/8) | Chuỗi 3 băng: Ngắn xa - Dài trái - Dài phải | 1 băng | Đạt | N/A | **Verified** | Chuẩn công thức bộ số 50 (50 - 20 = 30). |
| **BS-02** | Plus 2 (Ngắn - Dài - Dài) | -1.0 (Phải) | 0.333 (1/3) | Yêu cầu 3 băng: Ngắn - Dài - Dài (thực tế 2) | 1 băng | Đạt | N/A | **Chưa verified** | Bi chủ mới chạm 2 băng dài; chưa chạm băng ngắn đầu tiên trước carom. |
| **BS-03** | Bricole 1 băng chia đôi | +1.0 (Trái) | 0.516 | Bi chủ 1 băng dài trái trước khi chạm Bi 1 | 0 băng | Đạt | N/A | **Verified** | Chuẩn A-băng chạm băng dài mở góc trước khi trúng bi 1. |
| **BS-04** | Hệ thống Tia Góc 2 Băng | -1.0 (Phải) | 0.250 (2/8) | Yêu cầu 2 băng trước carom (thực tế 0) | 1 băng | Đạt | Đạt | **Chưa verified** | Bi chủ chạm trực tiếp bi 1 trước khi vào băng; chưa đóng verified. |
| **SR-01** | Mắt kính dọc băng | +1.0 (Trái) | 0.250 (2/8) | Chạm mỏng bi ngoài hãm tốc | 0 băng | Đạt | Đạt | **Verified** | Gom 3 bi giữ thế mắt kính tịnh tiến dọc băng. |
| **SR-02** | Xoay sở qua Ô cấm góc | +1.0 (Trái) | 0.500 (4/8) | Bi vàng đập băng dài trái thoát ô cấm | 1 băng dài | Đạt | Đạt | **Verified** | Bi vàng vượt qua vạch ô cấm đúng luật thi đấu Libre. |
| **SR-03** | Nhịp Bắc cầu qua Amery | -1.0 (Phải) | 0.333 (1/3) | Bi vàng đập băng dài vượt vạch Amery | 1 băng dài | Đạt | Đạt | **Verified** | Bi vàng tái lập cự ly gom qua vạch giới hạn Amery. |

---

## 3. Bảng Kết Quả Kiểm Thử Tự Động (32/32 Test Cases PASS 100%)

Toàn bộ 32 ca kiểm thử tại `test/physics_engine_test.dart`, `test/slider_8ths_cue_4tiers_test.dart` và `test/widget_test.dart` đều vượt qua 100%:

| STT | Tên ca kiểm thử | Kết quả đo đạc thực tế | Trạng thái |
| :---: | :--- | :--- | :---: |
| 1 | Bảo toàn năng lượng khi ra cơ (Cue Strike) | $E_{\text{after}} \le E_{\text{before}}$ trên toàn bộ lưới 2D offset $[-0.8, 0.8]$ và góc nâng $[0^\circ, 60^\circ]$. | **PASS** |
| 2 | Mô hình băng tiêu tán 2.5D | $E_{\text{after}} \le E_{\text{before}}$ với mọi góc tới và spin 3D; $E_{\text{after}} = E_{\text{before}}$ khi $e_{bc}=1, \mu_{bc}=0$. | **PASS** |
| 3 | Nghiệm giải tích nền tảng | Chuyển pha Stun Shot ($t_{\text{roll}}, v_{\text{roll}} = \frac{5}{7}v_0$); va chạm trực diện $v_1'=0, v_2'=v_1$; va chạm xiên $90^\circ$; true-miss không lệch. | **PASS** |
| 4 | CCD Bậc hai & Cô lập Cực trị với Grazing thật | Dựng $\vec{v}_A=(1,0), \vec{\omega}_A=(-1/R, 1/R, 0) \to \vec{a}_A=(0, 1.962)$. CCD bắt trọn $t = 0.000466\text{s}$, sai số tiếp xúc $|d - 2R| \approx 4.16 \times 10^{-17}\text{ m}$. | **PASS** |
| 5 | Tính nhất quán cửa sổ truy vấn CCD | Thời điểm va chạm không phụ thuộc vào `maxDt` ($0.5\text{s}$ vs $0.25\text{s}$) với sai số $< 10^{-12}\text{ s}$. | **PASS** |
| 5b | Kiểm thử Hội tụ Động lực học Carom | Chạy 3 bước $dt=0.001, dt/2=0.0005, dt/4=0.00025\text{s}$; thời điểm va chạm hội tụ $< 10^{-13}\text{s}$, vị trí dừng hội tụ $< 10^{-12}\text{m}$. | **PASS** |
| 6 | Bất biến không chồng lấn xuyên suốt mô phỏng | Khoảng cách giữa các bi luôn $\ge 2R - 10^{-5}\text{ m}$ tại mọi thời điểm mẫu qua `sampleAtTime`. | **PASS** |
| 7 | Giới hạn thời gian mô phỏng | Trả về `maxTimeReached` chính xác khi chạm trần thời gian `maxSimulationSeconds`. | **PASS** |
| 8 | Đơn điệu hóa vận tốc qua `speedLevel` | Tăng mức lực $1 \to 5$ làm tăng đơn điệu vận tốc ra cơ thực tế trên toàn bộ bài học mẫu. | **PASS** |
| 9 | Nghiệm thu độc lập 15 bài học mẫu | 8 bài verified: true đạt 100% tiêu chí khắt khe; 7 bài verified: false bị từ chối trung thực theo đúng tiêu chí chưa đạt. | **PASS** |
| 9b | Negative Test cho Fixture Kéo lùi (KT-01) | Cú đánh forward-only (coulé) dù cự ly start $\to$ final nằm trong 15–25cm vẫn bị **FAIL** do độ dời mang dấu dương $s_{\parallel} > 0$. | **PASS** |
| 9c | Fixture Strict Null Checks | Thiếu số đo má chạm, fraction hoặc gom bi chưa xác định (null) đều lập tức **FAIL** thay vì bỏ qua. | **PASS** |
| 9d | Kiểm tra Ngưỡng Biên Chiều Trô | Bộ ca $s_{\parallel} \in \{+0.004, 0.0, -0.004, -0.006\}\text{m}$; duy nhất $-0.006\text{m}$ qua tiêu chí chiều trô ($s_{\parallel} \le -0.005\text{m}$). | **PASS** |
| 10 | Từ chối `ShotInput` không hợp lệ | Ném `ShotInputValidationException` và trả về `isValid: false`, không tự ý dịch chuyển tọa độ bi. | **PASS** |
| 11 | Thuật toán hạn chế kéo bi sát góc bàn | `CaromTableCanvasLayout.constrainBallPosition` giữ bi trong lòng bàn và khoảng cách $\ge 2R_d$ khi bị kéo đè vào góc $(R_d, R_d)$. | **PASS** |
| 12 | Tỉ lệ khung nhìn đồng nhất `pixelsPerMeter` | Hai bi chạm nhau tiếp xúc hoàn hảo ở mọi phương $0^\circ, 45^\circ, 90^\circ$; chuyển đổi khứ hồi $world \leftrightarrow canvas$ sai số $< 10^{-4}\text{ m}$. | **PASS** |
| 13 | Đồng bộ Timeline Playback thực tế | Thời gian bi chuyển động khớp chính xác $T_{\text{sim}}$ giây thời gian thực (sau $0.28\text{s}$ vung cơ) cho các ca $T=0.5\text{s}, 2.0\text{s}, 14.0\text{s}$. | **PASS** |
| 14 | Bảo vệ dữ liệu Sổ tay & Write Guard | File schema 999 chuyển Read-Only; Write Guard từ chối ghi đè giữ nguyên bytes file gốc; tự tạo `.corrupted.bak` khi file lỗi. | **PASS** |
| 14b | Migration dữ liệu Sổ tay cũ (Legacy Storage) | Di chuyển dữ liệu nguyên tử từ candidate legacy sang file mới tại `path_provider`, tạo `.migration.bak`, không ghi đè defaults. | **PASS** |
| 14c | Khóa tương tác UI khi Sổ tay Read-Only | State UI lưu giữ cờ `_isReadOnly`, từ chối thay đổi bookmark/note và hiển thị SnackBar cảnh báo. | **PASS** |
| 15 | Tách biệt render & Smoke Test tương tác | Chuyển 5 tab, tap mở trực tiếp bài học vào `LessonDetailScreen` thật và quay lại không lỗi. | **PASS** |
| 16 | 7 nấc phần tám $k=1..7$ và AimGeometry | $k=1..7$ tương ứng $0.125..0.875$; tại $4/8$ góc cắt lí tưởng $\theta = 30.0^\circ$; tại $8/8$ góc cắt $0.0^\circ$. | **PASS** |
| 17 | Bảo toàn bài học cũ $1/3$ và $2/3$ | $f = 1/3$ và $2/3$ không nằm trên lưới $k/8$, không bị làm tròn khi build widget, nhãn giữ nguyên gốc. | **PASS** |
| 18 | Slider 7 nấc & nút $[-]/[+]$ | Nút $\pm$ dịch đúng $1/8$; đổi độ dày giữ má, đổi má giữ độ dày. | **PASS** |
| 19 | Nút Tràn mặt 8/8 & Khôi phục trạng thái | Chuyển sang tràn mặt $1.0$; bấm lại khôi phục chính xác độ dày và má trước đó. | **PASS** |
| 20 | Bảo toàn bài $1/3$ cũ trên widget | Render nhãn `1/3 trái (Gốc 33.3%)`, không tự động nhảy slider sang phần tám. | **PASS** |
| 21 | Kích thước Bi 61.5mm & Thang 4 mức | $R = 30.75\text{mm}$, mỗi mức $3.84375\text{mm}$, mức 4 là $15.375\text{mm}$ ($0.5R$). | **PASS** |
| 22 | Ràng buộc đĩa tròn an toàn ($x^2 + z^2 \le r_{\text{limit}}^2$) | Cặp $(4, 4)$ chéo ($21.74\text{mm}$) tự động chiếu về biên tròn bán kính $\le 15.375\text{mm}$. | **PASS** |
| 23 | Mốc tham khảo Natural Roll $+12.30\text{mm}$ | $z = +0.40R = +12.30\text{mm}$ trong mô hình cơ ngang lí tưởng. | **PASS** |
| 24 | Đổi đầu cơ bảo toàn tọa độ tiếp xúc & spin | Đổi $11.5 \to 12.0\text{mm}$ giữ nguyên `contactOffset` và vector xoáy. | **PASS** |
| 25 | Widget Điểm Mũi Cơ tương tác | Hiển thị mm, chọn đầu cơ $11.5, 11.75, 12\text{mm}$, bấm chip Natural Roll đặt đúng $+12.3\text{mm}$. | **PASS** |
| 26–32 | Kiểm thử giao diện cơ bản & Bottom Bar | Render đầy đủ 5 tabs, Card bài học và các sơ đồ tái sử dụng. | **PASS** |

---

## 4. Bằng Chứng Build & Artifacts

- **Flutter SDK:** Flutter 3.47.5 (Dart 3.13.4, DevTools 2.60.0).
- **Phân tích tĩnh (`flutter analyze`):** `No issues found! (ran in 3.5s)`.
- **Kiểm thử tự động (`flutter test`):** `All 32 tests passed! (ran in 5.2s)`.
- **Debug APK Build:**
  - Đường dẫn build: `build/app/outputs/flutter-apk/app-debug.apk`
  - Kích thước: `171,126,502 bytes` (~163.20 MB)
  - Mã băm SHA-256: `2088521693DD9B6BBE393F64058DCFFB476E72AD932E631E0BFAE6C67340C91C`
- **Môi trường máy ảo nghiệm thu:** Android 13 (API 33, emulator-5554 x86_64).
- **Raw logs đính kèm trong repository:**
  - `docs/logs/flutter_version.txt`
  - `docs/logs/flutter_analyze.txt`
  - `docs/logs/flutter_test.txt`
  - `docs/logs/flutter_build_apk.txt`
- **Ảnh chụp máy ảo chạy thực tế:**
  - `emulator_v5_home.png`: Màn hình chính danh sách bài học.
  - `emulator_v5_diagrams.png`: Màn hình chi tiết bài học KT-01 với sơ đồ chạm trái và tâm bi chuẩn mới.
  - `emulator_v5_cards_full.png`: Bảng điều khiển tương tác đầy đủ với Slider 7 nấc rời rạc, nút Tràn mặt 8/8 và Điểm mũi cơ theo mm / 4 mức.
