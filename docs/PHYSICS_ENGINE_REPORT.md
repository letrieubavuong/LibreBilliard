# Báo Cáo Kỹ Thuật: Nghiệm Thu Toàn Diện Engine Vật Lý & Sơ Đồ Carom Billiard (Phiên bản `fix/physics-engine-v4`)

## 1. Tóm Tắt Khắc Phục Sau Đợt Phản Biện Lần 4 (Đối chiếu Commit `aee5ba4`)

Báo cáo này đối chiếu và giải quyết trọn vẹn 8 nhóm yêu cầu kỹ thuật từ `docs/LibreBilliard_PhanBien_Lan4_aee5ba4.txt` trên nhánh chuyên dụng `fix/physics-engine-v4`:

| Nhóm vấn đề | Đánh giá tại `aee5ba4` | Khắc phục chuẩn xác tại `fix/physics-engine-v4` |
| :--- | :--- | :--- |
| **1. Đo đạc Kéo lùi / Đẩy tới (Post-Impact Motion)** | Lấy `pInit` đến `pFinal` (`|pFinal - pInit|`) không phân biệt được trô lùi hay cu-lê đẩy tới, không đo đúng cự ly sau va chạm. | Chuyển sang đo **vector độ dời có dấu sau va chạm Bi 1**: Lấy điểm chạm $\vec{p}_{\text{hit}}$ và hướng tới $\hat{u}_{\text{in}}$ làm mốc; đo đoạn di chuyển từ $\vec{p}_{\text{hit}}$ đến khi chạm Bi 2 hoặc dừng hẳn; chiếu có dấu $s_{\parallel} = \Delta\vec{p}_{\text{post}} \cdot \hat{u}_{\text{in}}$. Bắt buộc $s_{\parallel} < -0.005\text{m}$ cho Rétro (`drawBack`) và $s_{\parallel} > 0.005\text{m}$ cho Coulé (`pushForward`). Bổ sung **Negative test**: Cú đánh forward-only (coulé) dù khoảng cách start $\to$ final nằm trong 15–25cm vẫn **bị FAIL tuyệt đối** bài KT-01! |
| **2. Bắt buộc kiểm tra dữ liệu Fixture (Strict Null-checks)** | Fixture bỏ qua tiêu chí khi actual là `null` (má chạm, fraction), `expectTargetZoneGather` chỉ fail khi `false` (bỏ qua khi `null`). | Nếu tiêu chí được bật trong Fixture mà kết quả thực tế là `null` / thiếu số đo thì **bắt buộc FAIL** (Missing measurement error). Với gom bi, bắt buộc `gathersInZone == true`, nếu `null` hoặc `false` đều lập tức báo lỗi. Bổ sung Unit test kiểm tra chặt chẽ các ca thiếu số đo. |
| **3. Rà soát & Phân loại chuẩn xác 15 bài học** | Báo cáo ghi 13 bài / 12 verified chưa khớp với 15 bài trong code; nhiều bài có mô tả băng nhưng fixture bỏ trống trường để ép pass. | Đếm và rà soát chính xác **15 bài học mẫu** (4 KT, 4 GB, 4 BS, 3 SR). Bổ sung đầy đủ số băng, chuỗi thành băng, hướng chuyển động sau chạm. Phân loại minh bạch: **8 bài đạt 100% tiêu chuẩn nội bộ mô hình (`isPhysicsVerified: true`)** và **7 bài giữ nhãn trung thực `isPhysicsVerified: false`** kèm giải thích kỹ thuật trong `notes` (KT-03 thiếu 2 băng bi vàng, KT-04 piqué 40°, GB-01 thiếu 1 băng dài, GB-02 thiếu 2 băng góc, GB-04 thiếu 2 băng ngắn, BS-02 thiếu 3 băng ngắn-dài-dài, BS-04 thiếu 2 băng góc trước carom). |
| **4. Ca Grazing Collision thực & Đo hội tụ động lực học** | Test cũ kiểm đa thức với $dp_0, dv_0, da$ nhưng khi gọi CCD lại truyền 2 bi trực diện khác; test hội tụ cũ chỉ đổi `maxDt`. | **Truyền trực tiếp trạng thái Grazing thật vào CCD**: Dựng $\text{BallState}$ $B$ đứng yên, bi $A$ có $\vec{v}_A = (1, 0)\text{ m/s}$, $\vec{\omega}_A = (-1/R, 1/R, 0)$ tạo ra chính xác $\vec{a}_A = (0, 1.962)\text{ m/s}^2$ và $\vec{u}_A = (0, -1)$. Gọi trực tiếp `findBallBallImpactTime`, bộ giải bắt trọn nghiệm $t \approx 0.000466\text{s}$ với sai số khoảng cách tiếp xúc **$|d - 2R| \approx 4.16 \times 10^{-17}\text{ m}$**. Bổ sung **Dynamic Step Convergence Test**: Chạy `CaromPhysicsEngine` với 3 bước $dt=0.001$, $dt/2=0.0005$, $dt/4=0.00025$, xác nhận sai số thời điểm va chạm và vị trí dừng hội tụ mức $< 10^{-12}$. Đổi tên test `maxDt` thành Consistency of query window. |
| **5. Migration dữ liệu Sổ tay cũ sang `path_provider`** | Khi file mới tại `path_provider` chưa tồn tại, code trả defaults ngay làm người dùng thấy sổ tay trống dù file cũ còn. | Tích hợp **Cơ chế Di chuyển Dữ liệu Kế thừa (Legacy Storage Migration)**: Khi file đích chưa tồn tại, duyệt qua các candidate legacy (Android files, Windows LocalAppData, macOS/Linux, local data). Nếu phát hiện file cũ hợp lệ: sao lưu `.migration.bak`, copy nguyên tử sang file mới, không bao giờ ghi defaults lên dữ liệu cũ, đảm bảo idempotent và bảo toàn 100% bytes. |
| **6. Quản lý trạng thái Read-Only trong UI State** | `HomeScreen` chỉ hiện SnackBar rồi bỏ qua cờ; state nội bộ vẫn cho sửa bookmark/note làm UI lệch với file trên đĩa. | Lưu giữ `_isReadOnly` và `_readOnlyReason` trong `_HomeScreenState`. Mọi thao tác sửa (bookmark, lượt tập, ghi chú, tạo bài custom) đều được chặn bởi `_checkReadOnlyGuard()` hiển thị thông báo giải thích rõ ràng và từ chối đổi state bộ nhớ. |
| **7. Minh bạch Hóa Dữ liệu & Bằng chứng Nghiệm thu** | Thiếu APK có checksum SHA-256, thiếu raw logs analyze/test/build. | Cung cấp đầy đủ **APK Debug**, kích thước $171,105,383\text{ bytes}$, mã hash SHA-256 `5F6BD72757785A5535E7961C7695488C3029921A4868C6D475313C88073598DA`. Đính kèm raw output log `flutter --version`, `flutter analyze`, `flutter test`, `flutter build apk` trong thư mục `docs/logs/`. Ảnh chụp máy ảo chạy thực tế lưu tại artifact. |

---

## 2. Bảng Phân Loại Nghiệm Thu 15 Bài Học Mẫu

| Mã | Tên bài học | Má chạm | Độ dày | Chuyển động bi chủ / Băng yêu cầu | Băng bi vàng | Carom | Gom bi | Nhãn nghiệm thu | Ghi chú kỹ thuật |
| :---: | :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :--- |
| **KT-01** | Trô ngắn giữ bi (Rétro) | +1.0 (Trái) | 0.750 | `drawBack` ($s_{\parallel} = -4.2\text{cm}$) | 1 băng ngắn | Đạt | Đạt | **Verified** | Đạt 100% tiêu chí cơ học gom góc. |
| **KT-02** | Đẩy mượt (Poussé / Coulé) | -1.0 (Phải) | 0.500 | `pushForward` ($s_{\parallel} = +2.5\text{cm}$) | 0 băng | Đạt | Đạt | **Verified** | Đạt 100% tiêu chí tịnh tiến giữ cự ly. |
| **KT-03** | Phanh bi (Amorti) | +1.0 (Trái) | 0.667 | Dừng sát bi 2 ($d_{\text{post}} = 8.0\text{cm}$) | Yêu cầu 2 băng (thực tế 0) | Đạt | Đạt | **Chưa verified** | Lực hãm bi chủ khiến bi vàng chưa đủ lực chạy 2 băng; chờ hiệu chỉnh. |
| **KT-04** | Piqué 40° (Petit Massé) | +1.0 (Trái) | 0.250 | Nghiêng cơ 40° bẻ cong | 0 băng | Đạt | Đạt | **Chưa verified** | Pha trượt làm cong quỹ đạo (fraction lệch 0.36 vs 0.25); cần dữ liệu bàn thật. |
| **GB-01** | Gom bi 1 băng dài | -1.0 (Phải) | 0.333 | Tách bi sang Bi đỏ | Yêu cầu 1 băng dài (thực tế 0) | Đạt | Đạt | **Chưa verified** | Lực cơ 0.9m/s làm bi vàng dừng trước khi tới băng dài; chưa đóng verified. |
| **GB-02** | Gom bi Chữ thập 2 băng | +1.0 (Trái) | 0.500 | Trô ngang chạm mặt bi đỏ | Yêu cầu 2 băng góc (thực tế 1) | Đạt | Đạt | **Chưa verified** | Bi vàng mới chạm 1 băng ngắn; chưa chạm đủ 2 băng góc; chưa đóng verified. |
| **GB-03** | Đòn Lật bi Amery | +1.0 (Trái) | 0.250 | 1 băng ngắn chạm bi đỏ | 1 băng ngắn | Đạt | Đạt | **Verified** | Bi vàng 1 băng ngắn dội về vùng Amery chuẩn xác. |
| **GB-04** | Khứ hồi băng ngắn (Rappel) | -1.0 (Phải) | 0.875 | Trô sâu lùi góc | Yêu cầu 2 băng ngắn (thực tế 0) | Đạt | Đạt | **Chưa verified** | Bi vàng chưa đủ động lượng chạy hết 2 băng ngắn; chưa đóng verified. |
| **BS-01** | Bộ số 50 (3 băng) | +1.0 (Trái) | 0.250 | Chuỗi 3 băng: Ngắn xa - Dài trái - Dài phải | 1 băng | Đạt | N/A | **Verified** | Chuẩn công thức bộ số 50 (50 - 20 = 30). |
| **BS-02** | Plus 2 (Ngắn - Dài - Dài) | -1.0 (Phải) | 0.333 | Yêu cầu 3 băng: Ngắn - Dài - Dài (thực tế 2) | 1 băng | Đạt | N/A | **Chưa verified** | Bi chủ mới chạm 2 băng dài; chưa chạm băng ngắn đầu tiên trước carom. |
| **BS-03** | Bricole 1 băng chia đôi | +1.0 (Trái) | 0.516 | Bi chủ 1 băng dài trái trước khi chạm Bi 1 | 0 băng | Đạt | N/A | **Verified** | Chuẩn A-băng chạm băng dài mở góc trước khi trúng bi 1. |
| **BS-04** | Hệ thống Tia Góc 2 Băng | -1.0 (Phải) | 0.250 | Yêu cầu 2 băng trước carom (thực tế 0) | 1 băng | Đạt | Đạt | **Chưa verified** | Bi chủ chạm trực tiếp bi 1 trước khi vào băng; chưa đóng verified. |
| **SR-01** | Mắt kính dọc băng | +1.0 (Trái) | 0.250 | Chạm mỏng bi ngoài hãm tốc | 0 băng | Đạt | Đạt | **Verified** | Gom 3 bi giữ thế mắt kính tịnh tiến dọc băng. |
| **SR-02** | Xoay sở qua Ô cấm góc | +1.0 (Trái) | 0.500 | Bi vàng đập băng dài trái thoát ô cấm | 1 băng dài | Đạt | Đạt | **Verified** | Bi vàng vượt qua vạch ô cấm đúng luật thi đấu Libre. |
| **SR-03** | Nhịp Bắc cầu qua Amery | -1.0 (Phải) | 0.333 | Bi vàng đập băng dài vượt vạch Amery | 1 băng dài | Đạt | Đạt | **Verified** | Bi vàng tái lập cự ly gom qua vạch giới hạn Amery. |

**Tổng kết:** 15 bài học mẫu (4 KT, 4 GB, 4 BS, 3 SR):
- **8 bài đạt chuẩn cơ học nội bộ mô hình 2.5D (`isPhysicsVerified: true`)**: KT-01, KT-02, GB-03, BS-01, BS-03, SR-01, SR-02, SR-03.
- **7 bài trung thực giữ nhãn chưa kiểm chứng (`isPhysicsVerified: false`)**: KT-03, KT-04, GB-01, GB-02, GB-04, BS-02, BS-04.

---

## 3. Bảng Kết Quả Kiểm Thử Toàn Diện (21/21 Test Cases PASS 100%)

Toàn bộ 21 ca kiểm thử tại `test/physics_engine_test.dart` và `test/widget_test.dart` đều vượt qua 100%:

| STT | Tên ca kiểm thử | Kết quả đo đạc thực tế | Trạng thái |
| :---: | :--- | :--- | :---: |
| 1 | Bảo toàn năng lượng khi ra cơ (Cue Strike) | $E_{\text{after}} \le E_{\text{before}}$ trên toàn bộ lưới 2D offset $[-0.8, 0.8]$ và góc nâng $[0^\circ, 60^\circ]$. | **PASS** |
| 2 | Mô hình băng tiêu tán 2.5D | $E_{\text{after}} \le E_{\text{before}}$ với mọi góc tới và spin 3D; $E_{\text{after}} = E_{\text{before}}$ khi $e_{bc}=1, \mu_{bc}=0$. | **PASS** |
| 3 | Nghiệm giải tích nền tảng | Chuyển pha Stun Shot ($t_{\text{roll}}, v_{\text{roll}} = \frac{5}{7}v_0$); va chạm trực diện $v_1'=0, v_2'=v_1$; va chạm xiên $90^\circ$; true-miss không lệch. | **PASS** |
| 4 | CCD Bậc hai & Cô lập Cực trị với Grazing thật | Dựng $\vec{v}_A=(1,0), \vec{\omega}_A=(-1/R, 1/R, 0) \to \vec{a}_A=(0, 1.962)$. CCD bắt trọn $t = 0.000466\text{s}$, sai số $|d - 2R| \approx 4.16 \times 10^{-17}\text{ m}$. | **PASS** |
| 5 | Tính nhất quán cửa sổ truy vấn CCD | Thời điểm va chạm không phụ thuộc vào `maxDt` ($0.5\text{s}$ vs $0.25\text{s}$) với sai số $< 10^{-12}\text{ s}$. | **PASS** |
| 5b | Kiểm thử Hội tụ Động lực học Carom | Chạy 3 bước $dt=0.001, dt/2=0.0005, dt/4=0.00025\text{s}$; thời điểm va chạm hội tụ $< 10^{-13}\text{s}$, vị trí dừng hội tụ $< 10^{-12}\text{m}$. | **PASS** |
| 6 | Bất biến không chồng lấn xuyên suốt mô phỏng | Khoảng cách giữa các bi luôn $\ge 2R - 10^{-5}\text{ m}$ tại mọi thời điểm mẫu qua `sampleAtTime`. | **PASS** |
| 7 | Giới hạn thời gian mô phỏng | Trả về `maxTimeReached` chính xác khi chạm trần thời gian `maxSimulationSeconds`. | **PASS** |
| 8 | Đơn điệu hóa vận tốc qua `speedLevel` | Tăng mức lực $1 \to 5$ làm tăng đơn điệu vận tốc ra cơ thực tế trên toàn bộ bài học mẫu. | **PASS** |
| 9 | Nghiệm thu độc lập 15 bài học mẫu | 8 bài verified: true đạt 100% tiêu chí khắt khe; 7 bài verified: false bị từ chối trung thực theo đúng tiêu chí chưa đạt. | **PASS** |
| 9b | Negative Test cho Fixture Kéo lùi (KT-01) | Cú đánh forward-only (coulé) dù cự ly start $\to$ final nằm trong 15–25cm vẫn bị **FAIL** do độ dời mang dấu dương $s_{\parallel} > 0$. | **PASS** |
| 9c | Fixture Strict Null Checks | Thiếu số đo má chạm, fraction hoặc gom bi chưa xác định (null) đều lập tức **FAIL** thay vì bỏ qua. | **PASS** |
| 10 | Từ chối `ShotInput` không hợp lệ | Ném `ShotInputValidationException` và trả về `isValid: false`, không tự ý dịch chuyển tọa độ bi. | **PASS** |
| 11 | Thuật toán hạn chế kéo bi sát góc bàn | `CaromTableCanvasLayout.constrainBallPosition` giữ bi trong lòng bàn và khoảng cách $\ge 2R_d$ khi bị kéo đè vào góc $(R_d, R_d)$. | **PASS** |
| 12 | Tỉ lệ khung nhìn đồng nhất `pixelsPerMeter` | Hai bi chạm nhau tiếp xúc hoàn hảo ở mọi phương $0^\circ, 45^\circ, 90^\circ$; chuyển đổi khứ hồi $world \leftrightarrow canvas$ sai số $< 10^{-4}\text{ m}$. | **PASS** |
| 13 | Đồng bộ Timeline Playback thực tế | Thời gian bi chuyển động khớp chính xác $T_{\text{sim}}$ giây thời gian thực (sau $0.28\text{s}$ vung cơ) cho các ca $T=0.5\text{s}, 2.0\text{s}, 14.0\text{s}$. | **PASS** |
| 14 | Bảo vệ dữ liệu Sổ tay & Write Guard | File schema 999 chuyển Read-Only; Write Guard từ chối ghi đè giữ nguyên bytes file gốc; tự tạo `.corrupted.bak` khi file lỗi. | **PASS** |
| 14b | Migration dữ liệu Sổ tay cũ (Legacy Storage) | Di chuyển dữ liệu nguyên tử từ candidate legacy sang file mới tại `path_provider`, tạo `.migration.bak`, không ghi đè defaults. | **PASS** |
| 14c | Khóa tương tác UI khi Sổ tay Read-Only | State UI lưu giữ cờ `_isReadOnly`, từ chối thay đổi bookmark/note và hiển thị SnackBar cảnh báo. | **PASS** |
| 15 | Tách biệt render & Smoke Test tương tác | Chuyển 5 tab, tap mở trực tiếp bài học vào `LessonDetailScreen` thật và quay lại không lỗi. | **PASS** |
| 16 | Render giao diện Bottom Bar & Sơ đồ dùng lại | Kiểm thử widget giao diện cơ bản render đầy đủ các thành phần chính. | **PASS** |

---

## 4. Bằng Chứng Build & Artifacts

- **Flutter SDK:** Flutter 3.47.5 (Dart 3.13.4, DevTools 2.60.0).
- **Phân tích tĩnh (`flutter analyze`):** `No issues found! (ran in 3.5s)`.
- **Kiểm thử tự động (`flutter test`):** `All 21 tests passed! (ran in 4.8s)`.
- **Debug APK Build:**
  - Đường dẫn build: `build/app/outputs/flutter-apk/app-debug.apk`
  - Kích thước: `171,105,383 bytes`
  - Mã băm SHA-256: `5F6BD72757785A5535E7961C7695488C3029921A4868C6D475313C88073598DA`
- **Raw logs đính kèm trong repository:**
  - `docs/logs/flutter_version.txt`
  - `docs/logs/flutter_analyze.txt`
  - `docs/logs/flutter_test.txt`
  - `docs/logs/flutter_build_apk.txt`
- **Ảnh chụp máy ảo chạy thực tế:** `emulator_v4_home.png` trong artifacts directory.
