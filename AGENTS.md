# AGENTS.md: Quy Chuẩn Phát Triển & Kiểm Chứng Hệ Thống LibreBilliard

Tài liệu này định nghĩa các quy tắc bất biến dành cho các AI Agent khi làm việc trên kho mã nguồn `LibreBilliard`.

## 1. Engine Vật Lý Carom (`lib/physics/`)
- Mọi đơn vị tính trong Engine là chuẩn SI: mét ($\text{m}$), giây ($\text{s}$), kilôgam ($\text{kg}$), radian ($\text{rad}$).
- Không bao giờ thêm các hệ số nhân tạo phá vỡ định luật bảo toàn cơ học ($E_{\text{after}} \le E_{\text{before}}$).
- **Mô hình Băng:** Công bố trung thực là Mô hình Băng Rút Gọn 2.5D Tiêu Tán Năng Lượng (Planar Dissipative Cushion Model) với ma sát Coulomb và suy giảm xoáy mặt băng (spin damping). Tuyệt đối không tuyên bố là mô hình vật rắn 3D toàn phần khi chưa giải động học nâng nảy trục Z.
- **Va chạm CCD:** Giải trên quỹ đạo bậc hai $\vec{p}(t) = \vec{p}_0 + \vec{v}_0 t + \frac{1}{2}\vec{a} t^2$, tích hợp **Cô lập Cực trị Giải tích** giải nghiệm thực của $f'(t) = 0$ (Cardano & lượng giác) để chia khoảng đơn điệu, bắt trọn 100% các ca va chạm sượt (grazing collisions) với sai số tiếp xúc $|d - 2R| < 10^{-11}\,\text{m}$ (thực tế kiểm chứng đạt $\approx 4 \times 10^{-17}\,\text{m}$).
- Đầu vào không hợp lệ (chồng lấp $< 2R$ hoặc ra ngoài biên bàn) phải bị từ chối bằng `ShotInputValidationException` và `validation.isValid == false`. Tuyệt đối không tự ý dịch chuyển tọa độ bi của người dùng.

## 2. Bài Học Sư Phạm & Fixture Kỹ Thuật (`lib/data/sample_lessons.dart`, `lib/models/lesson_verification_fixture.dart`)
- Mọi bài học mẫu (15 bài) phải được nghiệm thu qua `LessonPhysicsVerificationFixture` độc lập:
  + Thứ tự chạm bi, dấu má (+1/-1), fraction thực tế $\pm 0.05$.
  + Số băng trước carom, chuỗi thành băng cụ thể, số băng của bi mục tiêu 1 (vàng).
  + Đo đạc động lực học sau va chạm có dấu: vector sau chạm Bi 1 $s_{\parallel} = \Delta\vec{p}_{\text{post}} \cdot \hat{u}_{\text{in}}$, phân biệt bắt buộc trô lùi (`drawBack`: $s_{\parallel} < -0.005\text{m}$) và đẩy tới (`pushForward`: $s_{\parallel} > 0.005\text{m}$). Cú đánh forward-only bắt buộc FAIL fixture trô KT-01.
  + Kiểm tra dữ liệu khắt khe (Strict Null-checks): Bất kỳ tiêu chí nào được bật trong Fixture mà kết quả thực tế là `null` hoặc thiếu số đo thì bắt buộc FAIL. Gom bi bắt buộc `gathersInZone == true`, thiếu số đo hay `null` đều lập tức báo lỗi.
- Tuyệt đối không được nới rộng bán kính vùng gom (`targetZoneRadius`) hay nới lỏng dung sai để gượng ép làm xanh bài test.
- Phân biệt minh bạch hai mức chứng nhận: "Verified nội bộ mô hình 2.5D" (đạt 100% tiêu chí) và "Đã đối chiếu thực nghiệm bàn thật". Bài học nào phụ thuộc vào hiệu ứng 3D chưa có dữ liệu đo đạc thực nghiệm (như Piqué 40°) hoặc chưa đạt đủ số băng mô tả sư phạm phải đánh nhãn trung thực `isPhysicsVerified: false`.

## 3. Giao Diện & Bàn Carom (`lib/widgets/diagrams/`, `lib/screens/`)
- Tỉ lệ khung nhìn của bàn bida phải sử dụng duy nhất một đại lượng `pixelsPerMeter` cho cả hai trục để giữ bóng tròn hoàn hảo và tiếp xúc đúng ở mọi góc.
- **Thời lượng phát lại:** Tốc độ `1.0×` phải ánh xạ chính xác: $0.28\text{s}$ vung cơ và đúng $T_{\text{sim}}$ giây chuyển động bi trong thời gian thực.
- Kéo thả bi trên bàn phải sử dụng thuật toán chiếu xen kẽ 16 chu kỳ kết hợp binary search fallback (`CaromTableCanvasLayout.constrainBallPosition`) để không bao giờ bị vượt biên hay chồng lấn kể cả khi bị kéo đè vào góc bàn.
- Thao tác chuyển đổi góc nhìn UI (lật bàn, bật tắt số nút băng) chỉ thay đổi trạng thái hiển thị của Painter, không được chạy lại `CaromPhysicsEngine.simulate()`.

## 4. Lưu Trữ Bền Vững & Chế Độ Chỉ Đọc (`lib/data/notebook_storage.dart`, `lib/screens/home_screen.dart`)
- Dữ liệu người dùng (Sổ tay cá nhân, hình bi tự tạo) phải được lưu vào thư mục ứng dụng hệ thống chuẩn (`path_provider`), không dùng thư mục tạm (`systemTemp`).
- **Migration Sổ tay cũ:** Khi file mới chưa tồn tại, phải tìm kiếm các candidate legacy, validate JSON, tạo bản sao `.migration.bak` và copy nguyên tử sang file mới; tuyệt đối không ghi đè dữ liệu mặc định lên dữ liệu tìm thấy. Thao tác migration phải bảo đảm tính idempotent.
- Phải tạo bản sao `.corrupted.bak` khi gặp file JSON lỗi.
- **Write Guard Schema tương lai:** Khi gặp file có `schemaVersion > currentSchemaVersion`, ứng dụng phải tạo bản sao `.future_v{version}.bak` và chuyển sang chế độ Read-Only. Hàm `saveState` phải kiểm tra và từ chối ghi đè lên file trên đĩa để bảo toàn 100% bytes dữ liệu gốc.
- **UI Read-Only Guard:** Trạng thái UI (`HomeScreenState`) phải lưu giữ cờ `_isReadOnly` và giải thích lý do; từ chối mọi thao tác chỉnh sửa ở tầng giao diện và không thay đổi state hiển thị khi không được phép ghi.
- Callback lưu ghi chú trên UI phải thực hiện cập nhật duy nhất một lần và await kết quả lưu, không gọi lặp ghi đôi.
